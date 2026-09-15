import Foundation

enum SafetyLevel: Int, CaseIterable, Codable, Comparable {
    case safe = 0
    case review = 1
    case protected = 2

    static func < (lhs: SafetyLevel, rhs: SafetyLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var title: String {
        switch self {
        case .safe: return "低"
        case .review: return "需要確認"
        case .protected: return "已保護"
        }
    }

    var recommendation: String {
        switch self {
        case .safe: return "可以移到垃圾桶"
        case .review: return "請確認內容後再處理"
        case .protected: return "重要工作檔，Nono Cleaner 不允許刪除"
        }
    }
}

enum ScanSource: String, CaseIterable, Codable, Identifiable {
    case codex = "ChatGPT / Codex"
    case systemTemporary = "System Temporary"
    case adobeCache = "Adobe Cache"
    case downloads = "Downloads"
    case desktop = "Desktop"
    case userCache = "User Cache"
    case unknown = "Unknown"

    var id: String { rawValue }
}

struct CleanerItem: Identifiable, Hashable, Codable {
    let id: String
    let url: URL
    let name: String
    let size: Int64
    let createdAt: Date?
    let modifiedAt: Date?
    let source: ScanSource
    let purpose: String
    let locationDescription: String
    let typeDescription: String
    let safety: SafetyLevel
    let isDirectory: Bool
    let sourceApp: String
    let matchedRule: String
    let containedFileCount: Int

    init(
        url: URL,
        size: Int64,
        createdAt: Date?,
        modifiedAt: Date?,
        source: ScanSource,
        purpose: String,
        locationDescription: String,
        typeDescription: String,
        safety: SafetyLevel,
        isDirectory: Bool,
        sourceApp: String,
        matchedRule: String,
        containedFileCount: Int
    ) {
        self.id = url.standardizedFileURL.path
        self.url = url
        self.name = url.lastPathComponent
        self.size = size
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.source = source
        self.purpose = purpose
        self.locationDescription = locationDescription
        self.typeDescription = typeDescription
        self.safety = safety
        self.isDirectory = isDirectory
        self.sourceApp = sourceApp
        self.matchedRule = matchedRule
        self.containedFileCount = containedFileCount
    }
}

struct ScanOptions: Sendable {
    var scanDownloads = true
    var scanDesktop = true
    var scanUserCaches = true
    var scanSystemTemporary = true
    var scanAdobeCaches = true
}
