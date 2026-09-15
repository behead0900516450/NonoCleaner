import AppKit
import Foundation

enum ScanRootKind: Sendable {
    case userFolder
    case explicitCache
    case temporary
}

enum GuardedApplication: String, CaseIterable, Sendable {
    case microsoftEdge = "Microsoft Edge"
    case premierePro = "Adobe Premiere Pro"
    case lightroom = "Adobe Lightroom"
    case photoshop = "Adobe Photoshop"
    case codex = "Codex / ChatGPT"
    case novis = "NOVIS"
    case notion = "Notion"
    case ollama = "Ollama"
    case chatcut = "ChatCut"

    func matchesRunningApplication(bundleIdentifier: String, localizedName: String) -> Bool {
        let bundle = bundleIdentifier.lowercased()
        let name = localizedName.lowercased()
        switch self {
        case .microsoftEdge:
            return bundle.contains("microsoft.edgemac") || name.contains("microsoft edge")
        case .premierePro:
            return bundle.contains("adobe.premiere") || name.contains("premiere pro")
        case .lightroom:
            return bundle.contains("adobe.lightroom") || name.contains("lightroom")
        case .photoshop:
            return bundle.contains("adobe.photoshop") || name.contains("photoshop")
        case .codex:
            return bundle == "com.openai.codex" || bundle.hasPrefix("com.openai.codex.") ||
                bundle == "com.openai.chatgpt" || bundle.hasPrefix("com.openai.chatgpt.") ||
                name == "codex" || name.contains("chatgpt")
        case .novis:
            return bundle.contains("novis") || name == "novis"
        case .notion:
            return bundle.contains("notion") || name == "notion"
        case .ollama:
            return bundle.contains("ollama") || name == "ollama"
        case .chatcut:
            return bundle.contains("chatcut") || name.contains("chatcut")
        }
    }
}

struct RunningApplicationSnapshot: Sendable {
    let applications: Set<GuardedApplication>

    init(applications: Set<GuardedApplication> = []) {
        self.applications = applications
    }

    @MainActor
    static func capture() -> RunningApplicationSnapshot {
        var detected = Set<GuardedApplication>()
        for application in NSWorkspace.shared.runningApplications {
            let bundle = application.bundleIdentifier ?? ""
            let name = application.localizedName ?? ""
            for candidate in GuardedApplication.allCases
            where candidate.matchesRunningApplication(bundleIdentifier: bundle, localizedName: name) {
                detected.insert(candidate)
            }
        }
        return RunningApplicationSnapshot(applications: detected)
    }
}

struct SafetyClassificationInput: Sendable {
    let url: URL
    let rootKind: ScanRootKind
    let rootSource: ScanSource
    let latestModifiedAt: Date?
    let protectedExtension: String?
    let reviewExtension: String?
    let runningApplications: RunningApplicationSnapshot
    let now: Date
}

struct SafetyClassificationOutput: Sendable {
    let source: ScanSource
    let safety: SafetyLevel
    let matchedRule: String
}

enum SafetyClassifier {
    private static let recentThreshold: TimeInterval = 60 * 60

    static func classify(_ input: SafetyClassificationInput) -> SafetyClassificationOutput {
        let source = detectedSource(for: input.url, rootSource: input.rootSource)
        let base = baseClassification(input, source: source)
        let guardedApps = guardedApplications(for: input.url, source: source)
        let running = guardedApps.intersection(input.runningApplications.applications)

        let isRecent: Bool
        if let modified = input.latestModifiedAt {
            let age = input.now.timeIntervalSince(modified)
            isRecent = age >= 0 && age < recentThreshold
        } else {
            isRecent = false
        }

        let recentGuardApplied = base.level == .safe && isRecent
        let runningGuardApplied = base.level == .safe && !running.isEmpty
        let finalLevel: SafetyLevel = (recentGuardApplied || runningGuardApplied) ? .review : base.level

        let recentDescription = recentGuardApplied
            ? "applied — Recently modified cache; excluded from automatic safe cleanup"
            : "not applied"
        let runningDescription: String
        if runningGuardApplied {
            let names = running.map(\.rawValue).sorted().joined(separator: ", ")
            runningDescription = "applied — 目前 App 正在執行，請關閉後再清理（\(names)）"
        } else {
            runningDescription = "not applied"
        }

        let rule = [
            "Original Rule: \(base.rule)",
            "Recent Modification Guard: \(recentDescription)",
            "Running App Guard: \(runningDescription)",
            "Final Risk: \(riskName(finalLevel))"
        ].joined(separator: " | ")

        return SafetyClassificationOutput(source: source, safety: finalLevel, matchedRule: rule)
    }

    private static func baseClassification(
        _ input: SafetyClassificationInput,
        source: ScanSource
    ) -> (level: SafetyLevel, rule: String) {
        if isCodexPreviewPath(input.url.path) {
            return (.safe, "Safe Allowlist: ChatGPT/Codex file-preview temporary data")
        }

        switch input.rootKind {
        case .userFolder:
            if let ext = input.protectedExtension {
                return (.protected, "Protected work-file extension in user location: .\(ext)")
            }
            return (.review, "User-created location requires explicit review")

        case .explicitCache:
            if source == .codex {
                return (.review, "No Safe Allowlist match: OpenAI/ChatGPT/Codex cache is not an approved file-preview path")
            }
            if isNovisPath(input.url.path) {
                return (.review, "No Safe Allowlist match: NOVIS cache is not proven fully regeneratable")
            }
            if isAppleSystemCachePath(input.url.path) {
                return (.review, "No Safe Allowlist match: Apple system or daemon cache is excluded from one-click safe cleanup")
            }
            if let allowlist = safeAllowlistMatch(for: input.url, source: source) {
                return (.safe, "Safe Allowlist: \(allowlist)")
            }
            return (.review, "No Safe Allowlist match: generic ~/Library/Caches item requires review")

        case .temporary:
            if source == .codex {
                return (.review, "No Safe Allowlist match: OpenAI/ChatGPT/Codex temporary data is not an approved file-preview path")
            }
            if isNovisPath(input.url.path) {
                return (.review, "No Safe Allowlist match: NOVIS temporary data is not proven fully regeneratable")
            }
            if isAppleSystemCachePath(input.url.path) {
                return (.review, "No Safe Allowlist match: Apple system or daemon temporary data is excluded from one-click safe cleanup")
            }
            if let ext = input.protectedExtension {
                return (.protected, "Protected work-file extension in unclassified temporary location: .\(ext)")
            }
            if let ext = input.reviewExtension {
                return (.review, "Temporary location contains user-document or archive type: .\(ext)")
            }
            let name = input.url.lastPathComponent.lowercased()
            if input.url.pathExtension.lowercased() == "tmp" {
                return (.safe, "Safe Allowlist: explicit .tmp temporary file")
            }
            if name == "node-compile-cache" || name.hasPrefix("node-compile-cache-") {
                return (.safe, "Safe Allowlist: Node.js compile cache")
            }
            return (.review, "No Safe Allowlist match: temporary item purpose is not fully classified")
        }
    }

    static func detectedSource(for url: URL, rootSource: ScanSource) -> ScanSource {
        let components = url.pathComponents.map { $0.lowercased() }
        if components.contains(where: isCodexComponent) {
            return .codex
        }
        if rootSource == .userCache,
           components.contains(where: isAdobeCacheComponent) {
            return .adobeCache
        }
        return rootSource
    }

    static func isCodexPreviewPath(_ path: String) -> Bool {
        path.split(separator: "/").contains {
            let value = $0.lowercased()
            return value.hasPrefix("codex-file-preview-") ||
                value.hasPrefix("chatgpt-file-preview-") ||
                value.hasPrefix("codex-preview-")
        }
    }

    private static func isCodexComponent(_ value: String) -> Bool {
        value == "codex" ||
            value == "chatgpt" ||
            value.hasPrefix(".com.openai.") ||
            value.hasPrefix("com.openai.") ||
            value.hasPrefix("codex-clipboard-") ||
            value.hasPrefix("chatgpt-clipboard-") ||
            value.hasPrefix("codex-file-preview-") ||
            value.hasPrefix("chatgpt-file-preview-") ||
            value.hasPrefix("codex-preview-")
    }

    private static func isAdobeCacheComponent(_ value: String) -> Bool {
        value == "adobe" || value.hasPrefix("adobe camera raw") || value.hasPrefix("com.adobe.")
    }

    private static func isNovisPath(_ path: String) -> Bool {
        path.split(separator: "/").contains { $0.caseInsensitiveCompare("NOVIS") == .orderedSame }
    }

    private static func isAppleSystemCachePath(_ path: String) -> Bool {
        let components = path.pathComponentsForClassification
        return components.contains { component in
            component.hasPrefix("com.apple.") ||
                component == "passkit" ||
                component.contains("spotlight") ||
                component.contains("icloud")
        }
    }

    private static func safeAllowlistMatch(for url: URL, source: ScanSource) -> String? {
        let path = url.path.lowercased()
        let components = path.pathComponentsForClassification
        let name = url.lastPathComponent.lowercased()
        let ext = url.pathExtension.lowercased()

        if components.contains("pip") { return "pip package download cache" }
        if components.contains("pnpm") { return "pnpm package content cache" }
        if components.contains("node-gyp") { return "node-gyp downloaded headers/build cache" }
        if components.contains("homebrew") { return "Homebrew download/cache" }
        if components.contains("ms-playwright") || components.contains("playwright") {
            return "Playwright downloaded browser/runtime cache"
        }

        if components.contains("microsoft edge") || components.contains(where: { $0.hasPrefix("com.microsoft.edgemac") }) {
            return "Microsoft Edge browser cache"
        }

        if source == .adobeCache {
            if path.contains("/media cache files/") || name == "media cache files" {
                return "Adobe Media Cache Files"
            }
            if path.contains("/media cache/") || name == "media cache" {
                return "Adobe Premiere Media Cache"
            }
            if path.contains("/peak files/") || name == "peak files" || ext == "pek" {
                return "Adobe Peak Files"
            }
            if ext == "cfa" { return "Adobe conformed audio cache (.cfa)" }
            if ext == "ims" { return "Adobe media index cache (.ims)" }
            if components.contains(where: { $0.hasPrefix("adobe camera raw") || $0 == "camera raw" }) {
                return "Adobe Camera Raw cache"
            }
            if components.contains(where: { $0.contains("premiere") && $0.contains("cache") }) {
                return "Adobe Premiere explicit cache"
            }
        }

        if (path.contains("/library/caches/ollama") && components.contains("updates")) ||
            path.hasSuffix("/library/caches/ollama") {
            return "Ollama updater download archive cache"
        }
        if components.contains("chatcut-desktop-updater") {
            return "ChatCut updater/download cache"
        }
        if components.contains(where: { $0.contains("updater") }) &&
            ["zip", "dmg", "pkg", "blockmap"].contains(ext) {
            return "verified updater download artifact"
        }
        return nil
    }

    private static func guardedApplications(for url: URL, source: ScanSource) -> Set<GuardedApplication> {
        let path = url.path.lowercased()
        var applications = Set<GuardedApplication>()
        if source == .codex { applications.insert(.codex) }
        if source == .adobeCache || path.contains("/adobe/") || path.contains("com.adobe.") {
            applications.formUnion([.premierePro, .lightroom, .photoshop])
        }
        if path.contains("microsoft edge") || path.contains("microsoft.edgemac") || path.contains("msedge") {
            applications.insert(.microsoftEdge)
        }
        if path.contains("premiere") { applications.insert(.premierePro) }
        if path.contains("lightroom") { applications.insert(.lightroom) }
        if path.contains("photoshop") { applications.insert(.photoshop) }
        if isNovisPath(path) { applications.insert(.novis) }
        if path.contains("/notion") || path.contains("notion.id") { applications.insert(.notion) }
        if path.contains("/library/caches/ollama") { applications.insert(.ollama) }
        if path.contains("chatcut-desktop-updater") { applications.insert(.chatcut) }
        return applications
    }

    private static func riskName(_ safety: SafetyLevel) -> String {
        switch safety {
        case .safe: return "Safe"
        case .review: return "Review"
        case .protected: return "Protected"
        }
    }
}

private extension String {
    var pathComponentsForClassification: [String] {
        split(separator: "/").map { String($0).lowercased() }
    }
}
