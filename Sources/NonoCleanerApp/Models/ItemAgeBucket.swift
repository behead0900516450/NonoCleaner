import Foundation

enum ItemAgeBucket: String, CaseIterable, Identifiable {
    case today = "今天"
    case twoToSevenDays = "2–7 天"
    case eightToThirtyDays = "8–30 天"
    case olderThanThirtyDays = "30 天以上"
    case unknown = "未知日期"

    var id: String { rawValue }

    func contains(_ date: Date?, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let date else { return self == .unknown }
        let startOfToday = calendar.startOfDay(for: now)
        let startOfDate = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: startOfDate, to: startOfToday).day ?? 0

        switch self {
        case .today:
            return days <= 0
        case .twoToSevenDays:
            return (1...7).contains(days)
        case .eightToThirtyDays:
            return (8...30).contains(days)
        case .olderThanThirtyDays:
            return days > 30
        case .unknown:
            return false
        }
    }
}
