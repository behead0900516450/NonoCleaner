import Foundation

struct ScanDiagnostics: Codable, Sendable {
    var scannedPaths: [String] = []
    var inaccessiblePaths: [String] = []
    var permissionDeniedPaths: [String] = []
    var symbolicLinksSkipped = 0
    var errors: [String] = []
    var appliedRules: [String] = []
    var unclassifiedItemCount = 0
    var wasInterrupted = false

    var macOSProtectedPaths: [String] {
        unique(permissionDeniedPaths)
    }

    var nonPermissionInaccessiblePaths: [String] {
        let protected = Set(macOSProtectedPaths)
        return unique(inaccessiblePaths.filter { !protected.contains($0) })
    }

    var nonPermissionErrors: [String] {
        let protectedPaths = macOSProtectedPaths
        return unique(errors.filter { message in
            let lowercased = message.lowercased()
            let hasPermissionText = lowercased.contains("permission denied") ||
                lowercased.contains("operation not permitted") ||
                lowercased.contains("you don’t have permission") ||
                lowercased.contains("you don't have permission")
            let belongsToProtectedPath = protectedPaths.contains { message.hasPrefix("\($0):") }
            return !hasPermissionText && !belongsToProtectedPath
        })
    }

    private func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}

struct ScanReport: Codable, Sendable {
    let scannedAt: Date
    let duration: TimeInterval
    let items: [CleanerItem]
    let diagnostics: ScanDiagnostics
}

enum ScanReportMode: String, CaseIterable, Identifiable {
    case normal = "一般報告"
    case debug = "完整除錯報告"

    var id: String { rawValue }
}

enum ReportExportFormat: String, CaseIterable, Identifiable {
    case text = "txt"
    case markdown = "md"
    case json = "json"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .text: return "純文字 (.txt)"
        case .markdown: return "Markdown (.md)"
        case .json: return "JSON (.json)"
        }
    }
}
