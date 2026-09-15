import Foundation

enum SidebarDestination: String, CaseIterable, Identifiable, Hashable, Codable {
    case overview = "總覽"
    case safeCleanup = "低風險可清理"
    case needsReview = "需要確認"
    case largeFiles = "大型檔案"
    case ignored = "忽略清單"
    case byDate = "依時間整理"
    case scanReport = "掃描報告"
    case settings = "設定"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .safeCleanup: return "checkmark.shield"
        case .needsReview: return "exclamationmark.triangle"
        case .largeFiles: return "externaldrive"
        case .ignored: return "eye.slash"
        case .byDate: return "calendar.badge.clock"
        case .scanReport: return "doc.text.magnifyingglass"
        case .settings: return "gearshape"
        }
    }
}
