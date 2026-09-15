import Foundation

enum ItemSortField: String, CaseIterable, Hashable, Sendable {
    case name
    case modifiedAt
    case size
    case safety

    var preferredOrder: SortOrder {
        switch self {
        case .name:
            return .forward
        case .modifiedAt, .size, .safety:
            return .reverse
        }
    }
}

struct CleanerItemSortComparator: SortComparator, Hashable, Sendable {
    typealias Compared = CleanerItem

    let field: ItemSortField
    var order: SortOrder

    init(_ field: ItemSortField, order: SortOrder? = nil) {
        self.field = field
        self.order = order ?? field.preferredOrder
    }

    func compare(_ lhs: CleanerItem, _ rhs: CleanerItem) -> ComparisonResult {
        if field == .modifiedAt, lhs.modifiedAt == nil || rhs.modifiedAt == nil {
            switch (lhs.modifiedAt, rhs.modifiedAt) {
            case (nil, nil): return compareIDs(lhs, rhs)
            case (nil, _): return .orderedDescending
            case (_, nil): return .orderedAscending
            default: break
            }
        }

        let base = baseComparison(lhs, rhs)
        let ordered = base == .orderedSame ? compareIDs(lhs, rhs) : base
        return order == .forward ? ordered : ordered.reversed
    }

    private func baseComparison(_ lhs: CleanerItem, _ rhs: CleanerItem) -> ComparisonResult {
        switch field {
        case .name:
            return lhs.name.localizedStandardCompare(rhs.name)
        case .modifiedAt:
            return compareValues(lhs.modifiedAt!, rhs.modifiedAt!)
        case .size:
            return compareValues(lhs.size, rhs.size)
        case .safety:
            return compareValues(lhs.safety.sortPriority, rhs.safety.sortPriority)
        }
    }

    private func compareIDs(_ lhs: CleanerItem, _ rhs: CleanerItem) -> ComparisonResult {
        lhs.id.localizedStandardCompare(rhs.id)
    }

    private func compareValues<Value: Comparable>(_ lhs: Value, _ rhs: Value) -> ComparisonResult {
        if lhs < rhs { return .orderedAscending }
        if lhs > rhs { return .orderedDescending }
        return .orderedSame
    }

    static let nameAscending = CleanerItemSortComparator(.name, order: .forward)
    static let modifiedNewestFirst = CleanerItemSortComparator(.modifiedAt, order: .reverse)
    static let sizeLargestFirst = CleanerItemSortComparator(.size, order: .reverse)
    static let riskHighestFirst = CleanerItemSortComparator(.safety, order: .reverse)
}

private extension ComparisonResult {
    var reversed: ComparisonResult {
        switch self {
        case .orderedAscending: return .orderedDescending
        case .orderedDescending: return .orderedAscending
        case .orderedSame: return .orderedSame
        }
    }
}

extension SafetyLevel {
    var sortPriority: Int {
        switch self {
        case .safe: return 0
        case .review: return 1
        case .protected: return 2
        }
    }
}
