import Foundation

enum SafeItemGroupKind: String, CaseIterable, Identifiable, Sendable {
    case adobeMediaCache = "Adobe Media Cache Files"
    case adobePeakFiles = "Adobe Peak Files"
    case adobeCameraRaw = "Adobe Camera Raw"
    case pip = "pip"
    case pnpm = "pnpm"
    case nodeGyp = "node-gyp"
    case playwright = "Playwright"
    case homebrew = "Homebrew"
    case chatCutUpdater = "ChatCut updater"
    case codexFilePreview = "Codex file-preview"
    case otherAllowlist = "其他明確 Safe allowlist"

    var id: String { rawValue }

    var regenerationSummary: String {
        switch self {
        case .codexFilePreview:
            return "需要時會"
        case .otherAllowlist:
            return "依來源規則"
        default:
            return "會"
        }
    }
}

struct SafeItemGroup: Identifiable, Sendable {
    let kind: SafeItemGroupKind
    let items: [CleanerItem]

    var id: String { kind.id }
    var name: String { kind.rawValue }
    var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
    var itemCount: Int { items.count }
    var safety: SafetyLevel { .safe }
    var regenerationSummary: String { kind.regenerationSummary }
    var latestModifiedAt: Date? { items.compactMap(\.modifiedAt).max() }
}

enum SafeItemGrouping {
    static func groups(items: [CleanerItem]) -> [SafeItemGroup] {
        let safeItems = items.filter { $0.safety == .safe }
        let grouped = Dictionary(grouping: safeItems, by: groupKind(for:))
        return SafeItemGroupKind.allCases.compactMap { kind in
            guard let items = grouped[kind], !items.isEmpty else { return nil }
            return SafeItemGroup(kind: kind, items: items)
        }
    }

    static func groupKind(for item: CleanerItem) -> SafeItemGroupKind {
        let path = item.url.path.lowercased()
        let components = path.split(separator: "/").map { String($0) }
        let ext = item.url.pathExtension.lowercased()
        let rule = item.matchedRule.lowercased()

        if path.contains("/media cache files/") ||
            (item.source == .adobeCache && (ext == "cfa" || ext == "ims")) {
            return .adobeMediaCache
        }
        if path.contains("/peak files/") || (item.source == .adobeCache && ext == "pek") {
            return .adobePeakFiles
        }
        if path.contains("camera raw") { return .adobeCameraRaw }
        if components.contains("pip") { return .pip }
        if components.contains("pnpm") { return .pnpm }
        if components.contains("node-gyp") { return .nodeGyp }
        if components.contains("ms-playwright") || components.contains("playwright") { return .playwright }
        if components.contains("homebrew") { return .homebrew }
        if components.contains("chatcut-desktop-updater") { return .chatCutUpdater }
        if components.contains(where: {
            $0.hasPrefix("codex-file-preview-") || $0.hasPrefix("chatgpt-file-preview-") || $0.hasPrefix("codex-preview-")
        }) {
            return .codexFilePreview
        }
        if rule.contains("chatcut updater") { return .chatCutUpdater }
        return .otherAllowlist
    }
}

struct SafeItemGroupSortComparator: SortComparator, Hashable, Sendable {
    typealias Compared = SafeItemGroup

    let field: ItemSortField
    var order: SortOrder

    init(_ field: ItemSortField, order: SortOrder? = nil) {
        self.field = field
        self.order = order ?? field.preferredOrder
    }

    func compare(_ lhs: SafeItemGroup, _ rhs: SafeItemGroup) -> ComparisonResult {
        let base: ComparisonResult
        switch field {
        case .name:
            base = lhs.name.localizedStandardCompare(rhs.name)
        case .modifiedAt:
            base = compareDates(lhs.latestModifiedAt, rhs.latestModifiedAt)
        case .size:
            base = compareValues(lhs.totalSize, rhs.totalSize)
        case .safety:
            base = compareValues(lhs.safety.sortPriority, rhs.safety.sortPriority)
        }
        let tied = base == .orderedSame ? lhs.id.localizedStandardCompare(rhs.id) : base
        return order == .forward ? tied : tied.opposite
    }

    private func compareDates(_ lhs: Date?, _ rhs: Date?) -> ComparisonResult {
        switch (lhs, rhs) {
        case let (lhs?, rhs?): return compareValues(lhs, rhs)
        case (nil, nil): return .orderedSame
        case (nil, _): return order == .forward ? .orderedDescending : .orderedAscending
        case (_, nil): return order == .forward ? .orderedAscending : .orderedDescending
        }
    }

    private func compareValues<Value: Comparable>(_ lhs: Value, _ rhs: Value) -> ComparisonResult {
        if lhs < rhs { return .orderedAscending }
        if lhs > rhs { return .orderedDescending }
        return .orderedSame
    }

    static let sizeLargestFirst = SafeItemGroupSortComparator(.size, order: .reverse)
}

private extension ComparisonResult {
    var opposite: ComparisonResult {
        switch self {
        case .orderedAscending: return .orderedDescending
        case .orderedDescending: return .orderedAscending
        case .orderedSame: return .orderedSame
        }
    }
}
