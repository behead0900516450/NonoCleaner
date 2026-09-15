import Foundation

enum CleanupError: LocalizedError {
    case protectedItem
    case unsafeLocation
    case missingItem

    var errorDescription: String? {
        switch self {
        case .protectedItem: return "這是受保護的工作檔，不允許清理。"
        case .unsafeLocation: return "此路徑不在 Nono Cleaner 允許的清理範圍內。"
        case .missingItem: return "項目已不存在。"
        }
    }
}

struct CleanupService {
    func moveToTrash(_ item: CleanerItem) throws {
        guard item.safety != .protected else { throw CleanupError.protectedItem }
        guard isAllowed(item.url) else { throw CleanupError.unsafeLocation }
        guard FileManager.default.fileExists(atPath: item.url.path) else { throw CleanupError.missingItem }
        try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
    }

    private func isAllowed(_ url: URL) -> Bool {
        let fileManager = FileManager.default
        let candidate = url.standardizedFileURL.path
        let home = fileManager.homeDirectoryForCurrentUser.standardizedFileURL.path
        let roots = [
            fileManager.temporaryDirectory.standardizedFileURL.path,
            "/private/var/folders",
            "/var/folders",
            home + "/Downloads",
            home + "/Desktop",
            home + "/Library/Caches",
            home + "/Library/Application Support/Adobe/Common/Media Cache",
            home + "/Library/Application Support/Adobe/Common/Media Cache Files",
            home + "/Library/Application Support/Adobe/Common/Peak Files"
        ]
        return roots.contains { root in
            candidate.hasPrefix(root + "/") && candidate != root
        }
    }
}
