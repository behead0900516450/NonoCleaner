import Foundation

private var passed = 0

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("❌ \(message)\n", stderr)
        exit(1)
    }
}

private func makeItem(
    path: String,
    size: Int64,
    source: ScanSource = .userCache,
    rule: String
) -> CleanerItem {
    CleanerItem(
        url: URL(fileURLWithPath: path),
        size: size,
        createdAt: nil,
        modifiedAt: Date(timeIntervalSince1970: Double(size)),
        source: source,
        purpose: "fixture",
        locationDescription: "fixture",
        typeDescription: "fixture",
        safety: .safe,
        isDirectory: path.hasSuffix("pip") || path.hasSuffix("pnpm"),
        sourceApp: source.rawValue,
        matchedRule: rule,
        containedFileCount: 1
    )
}

private func test(_ name: String, _ body: () throws -> Void) {
    do {
        try body()
        passed += 1
        print("✅ \(name)")
    } catch {
        fputs("❌ \(name): \(error)\n", stderr)
        exit(1)
    }
}

@main
enum ProductizationRegressionRunner {
    static func main() {
        let safeItems = [
            makeItem(path: "/Users/test/Library/Application Support/Adobe/Common/Media Cache Files/a.cfa", size: 1_000, source: .adobeCache, rule: "Safe Allowlist: Adobe Media Cache"),
            makeItem(path: "/Users/test/Library/Application Support/Adobe/Common/Peak Files/a.pek", size: 2_000, source: .adobeCache, rule: "Safe Allowlist: Adobe Peak Files"),
            makeItem(path: "/Users/test/Library/Caches/Adobe Camera Raw 2", size: 3_000, source: .adobeCache, rule: "Safe Allowlist: Camera Raw cache"),
            makeItem(path: "/Users/test/Library/Caches/pip", size: 4_000, rule: "Safe Allowlist: pip package download cache"),
            makeItem(path: "/Users/test/Library/Caches/pnpm", size: 5_000, rule: "Safe Allowlist: pnpm package cache"),
            makeItem(path: "/Users/test/Library/Caches/node-gyp", size: 6_000, rule: "Safe Allowlist: node-gyp cache"),
            makeItem(path: "/Users/test/Library/Caches/ms-playwright", size: 7_000, rule: "Safe Allowlist: Playwright runtime"),
            makeItem(path: "/Users/test/Library/Caches/Homebrew", size: 8_000, rule: "Safe Allowlist: Homebrew download cache"),
            makeItem(path: "/Users/test/Library/Caches/chatcut-desktop-updater", size: 9_000, rule: "Safe Allowlist: ChatCut updater"),
            makeItem(path: "/private/var/folders/test/T/codex-file-preview-ABC/a.pdf", size: 10_000, source: .codex, rule: "Safe Allowlist: codex file preview"),
            makeItem(path: "/private/var/folders/test/T/node-compile-cache/a", size: 11_000, source: .systemTemporary, rule: "Safe Allowlist: node compile cache")
        ]

        test("safe source groups and total bytes are exact") {
            let groups = SafeItemGrouping.groups(items: safeItems)
            let expectedKinds: Set<SafeItemGroupKind> = [
                .adobeMediaCache, .adobePeakFiles, .adobeCameraRaw, .pip, .pnpm,
                .nodeGyp, .playwright, .homebrew, .chatCutUpdater,
                .codexFilePreview, .otherAllowlist
            ]
            expect(Set(groups.map(\.kind)) == expectedKinds, "one or more priority groups are missing")
            expect(groups.reduce(0) { $0 + $1.totalSize } == safeItems.reduce(0) { $0 + $1.size }, "group total bytes do not equal child bytes")
            for group in groups {
                expect(group.totalSize == group.items.reduce(0) { $0 + $1.size }, "group \(group.name) has an incorrect total")
                expect(group.itemCount == group.items.count, "group \(group.name) has an incorrect count")
            }
        }

        test("group and item identities survive sorting") {
            let groups = SafeItemGrouping.groups(items: safeItems)
            let beforeGroupIDs = Set(groups.map(\.id))
            let beforeItemIDs = Set(groups.flatMap(\.items).map(\.id))
            let sorted = groups.sorted(using: SafeItemGroupSortComparator(.size, order: .forward))
            expect(Set(sorted.map(\.id)) == beforeGroupIDs, "group identity changed after sorting")
            expect(Set(sorted.flatMap(\.items).map(\.id)) == beforeItemIDs, "item selection identity changed after sorting")
        }

        let protectedPath = "/Users/test/Library/Caches/com.apple.protected"
        let realError = "/Users/test/Downloads/broken: Input/output error"
        let diagnostics = ScanDiagnostics(
            scannedPaths: ["/Users/test/Library/Caches"],
            inaccessiblePaths: [protectedPath, "/Users/test/Downloads/broken"],
            permissionDeniedPaths: [protectedPath],
            symbolicLinksSkipped: 0,
            errors: ["\(protectedPath): Permission denied", realError],
            appliedRules: [],
            unclassifiedItemCount: 0,
            wasInterrupted: false
        )
        let report = ScanReport(scannedAt: Date(), duration: 1, items: safeItems, diagnostics: diagnostics)

        test("normal text report presents permission denials as macOS protection") {
            let normal = ScanReportBuilder.text(for: report, mode: .normal, ignoredPaths: [])
            expect(normal.contains("macOS 保護項目：1"), "normal report is missing macOS protection count")
            expect(normal.contains("已安全略過，不影響其他掃描結果"), "normal report is missing protection explanation")
            expect(!normal.contains("Permission denied"), "normal report leaked raw permission error wording")
            expect(normal.contains(realError), "real non-permission error was hidden")
        }

        test("debug text report retains raw permission diagnostics") {
            let debug = ScanReportBuilder.text(for: report, mode: .debug, ignoredPaths: [])
            expect(debug.contains("Permission denied：1"), "debug report lost permission diagnostic section")
            expect(debug.contains("\(protectedPath): Permission denied"), "debug report lost raw permission error")
            expect(debug.contains(realError), "debug report lost real scan error")
        }

        test("normal and debug JSON diagnostics use different keys") {
            let normal = try ScanReportBuilder.json(for: report, mode: .normal, ignoredPaths: [])
            let debug = try ScanReportBuilder.json(for: report, mode: .debug, ignoredPaths: [])
            expect(normal.contains("\"macOSProtectedPaths\""), "normal JSON lacks macOS protection key")
            expect(!normal.contains("\"permissionDeniedPaths\""), "normal JSON exposes debug permission key")
            expect(debug.contains("\"permissionDeniedPaths\""), "debug JSON lacks raw permission key")
        }

        print("\nAll \(passed) productization regression tests passed.")
    }
}
