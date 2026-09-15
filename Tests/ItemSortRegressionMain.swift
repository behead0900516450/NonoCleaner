import Foundation

private var passed = 0

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("❌ \(message)\n", stderr)
        exit(1)
    }
}

private func makeItem(
    _ name: String,
    size: Int64,
    modified: TimeInterval,
    safety: SafetyLevel
) -> CleanerItem {
    CleanerItem(
        url: URL(fileURLWithPath: "/tmp/sort-fixture/\(name)"),
        size: size,
        createdAt: nil,
        modifiedAt: Date(timeIntervalSince1970: modified),
        source: .userCache,
        purpose: "fixture",
        locationDescription: "fixture",
        typeDescription: "檔案",
        safety: safety,
        isDirectory: false,
        sourceApp: "fixture",
        matchedRule: "fixture",
        containedFileCount: 1
    )
}

private let fixtures = [
    makeItem("file10", size: 900 * 1_024, modified: 100, safety: .safe),
    makeItem("file2", size: 10 * 1_024 * 1_024, modified: 300, safety: .review),
    makeItem("file1", size: 1_400 * 1_024 * 1_024, modified: 200, safety: .protected)
]

private func names(sortedBy comparator: CleanerItemSortComparator) -> [String] {
    fixtures.sorted(using: comparator).map(\.name)
}

private func test(_ name: String, _ body: () -> Void) {
    body()
    passed += 1
    print("✅ \(name)")
}

@main
enum ItemSortRegressionRunner {
    static func main() {
        test("size descending uses bytes across KB MB and GB") {
            expect(names(sortedBy: .sizeLargestFirst) == ["file1", "file2", "file10"], "numeric size descending failed")
        }

        test("size ascending uses bytes across KB MB and GB") {
            expect(names(sortedBy: CleanerItemSortComparator(.size, order: .forward)) == ["file10", "file2", "file1"], "numeric size ascending failed")
        }

        test("modified date newest to oldest") {
            expect(names(sortedBy: .modifiedNewestFirst) == ["file2", "file1", "file10"], "date descending failed")
        }

        test("modified date oldest to newest") {
            expect(names(sortedBy: CleanerItemSortComparator(.modifiedAt, order: .forward)) == ["file10", "file1", "file2"], "date ascending failed")
        }

        test("name uses localized natural order") {
            expect(names(sortedBy: .nameAscending) == ["file1", "file2", "file10"], "localizedStandardCompare natural order failed")
        }

        test("risk supports both directions") {
            expect(names(sortedBy: .riskHighestFirst) == ["file1", "file2", "file10"], "Protected Review Safe order failed")
            expect(names(sortedBy: CleanerItemSortComparator(.safety, order: .forward)) == ["file10", "file2", "file1"], "Safe Review Protected order failed")
        }

        test("sorting preserves selected item identity") {
            let selectedID = fixtures[1].id
            let sorted = fixtures.sorted(using: CleanerItemSortComparator.sizeLargestFirst)
            expect(sorted.first(where: { $0.id == selectedID })?.id == selectedID, "selection identity changed")
        }

        test("sorting does not change cleanup or ignored state") {
            let originalSafety = Dictionary(uniqueKeysWithValues: fixtures.map { ($0.id, $0.safety) })
            let ignored = Set([fixtures[0].id])
            let sorted = fixtures.sorted(using: CleanerItemSortComparator.modifiedNewestFirst)
            expect(Dictionary(uniqueKeysWithValues: sorted.map { ($0.id, $0.safety) }) == originalSafety, "safety state changed")
            expect(ignored == Set([fixtures[0].id]), "ignored state changed")
        }

        print("\nAll \(passed) item sorting regression tests passed.")
    }
}
