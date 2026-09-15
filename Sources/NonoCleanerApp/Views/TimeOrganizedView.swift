import SwiftUI

struct TimeOrganizedView: View {
    @ObservedObject var store: CleanerStore
    let requestDelete: (CleanerItem) -> Void

    @State private var selectedBucket: ItemAgeBucket = .today
    @State private var sortOrder = [CleanerItemSortComparator.modifiedNewestFirst]

    private var displayedItems: [CleanerItem] {
        store.visibleItems
            .filter { selectedBucket.contains($0.modifiedAt) }
            .sorted(using: sortOrder)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("依時間整理")
                        .font(.title2.bold())
                    Text("依最後修改時間篩選，不會改變項目的安全等級。")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    store.startScan()
                } label: {
                    Label("重新掃描", systemImage: "arrow.clockwise")
                }
                .disabled(store.isScanning)
            }
            .padding()

            Picker("時間範圍", selection: $selectedBucket) {
                ForEach(ItemAgeBucket.allCases) { bucket in
                    Text("\(bucket.rawValue)  \(count(for: bucket))")
                        .tag(bucket)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 12)

            Divider()

            if store.scanReport == nil {
                emptyState(
                    icon: "calendar.badge.clock",
                    title: "尚無掃描結果",
                    message: "請先執行掃描，再依最後修改時間查看項目。"
                )
            } else if displayedItems.isEmpty {
                emptyState(
                    icon: "calendar",
                    title: "\(selectedBucket.rawValue)沒有項目",
                    message: "可以切換其他時間範圍查看。"
                )
            } else {
                HSplitView {
                    Table(displayedItems, selection: $store.selectedItemID, sortOrder: $sortOrder) {
                        TableColumn("名稱", sortUsing: CleanerItemSortComparator.nameAscending) { item in
                            HStack {
                                Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                                    .foregroundStyle(item.isDirectory ? .blue : .secondary)
                                Text(item.name).lineLimit(1)
                            }
                        }
                        .width(min: 165, ideal: 220, max: 280)

                        TableColumn("最後修改", sortUsing: CleanerItemSortComparator.modifiedNewestFirst) { item in
                            Text(AppFormatters.date(item.modifiedAt))
                                .lineLimit(1)
                        }
                        .width(min: 125, ideal: 145, max: 165)

                        TableColumn("大小", sortUsing: CleanerItemSortComparator.sizeLargestFirst) { item in
                            Text(AppFormatters.bytes(item.size)).monospacedDigit()
                        }
                        .width(min: 75, ideal: 85, max: 95)

                        TableColumn("風險", sortUsing: CleanerItemSortComparator.riskHighestFirst) { item in
                            SafetyBadge(level: item.safety)
                        }
                        .width(min: 85, ideal: 95, max: 105)
                    }
                    .frame(minWidth: 560)

                    if let item = selectedDisplayedItem {
                        ItemDetailView(
                            item: item,
                            isIgnored: store.ignoredPaths.contains(item.id),
                            reveal: { store.reveal(item) },
                            delete: { requestDelete(item) },
                            ignore: {
                                if store.ignoredPaths.contains(item.id) {
                                    store.restore(item)
                                } else {
                                    store.ignore(item)
                                }
                            }
                        )
                        .frame(minWidth: 300, idealWidth: 360)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "cursorarrow.click.2")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("選取項目以查看詳細資訊")
                                .foregroundStyle(.secondary)
                        }
                        .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .onChange(of: selectedBucket) { _ in
            if selectedDisplayedItem == nil { store.selectedItemID = nil }
        }
    }

    private var selectedDisplayedItem: CleanerItem? {
        guard let item = store.selectedItem,
              displayedItems.contains(where: { $0.id == item.id }) else { return nil }
        return item
    }

    private func count(for bucket: ItemAgeBucket) -> Int {
        store.visibleItems.filter { bucket.contains($0.modifiedAt) }.count
    }

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            Text(title).font(.title3.bold())
            Text(message).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
