import SwiftUI

struct ItemListView: View {
    @ObservedObject var store: CleanerStore
    let destination: SidebarDestination
    let requestDelete: (CleanerItem) -> Void

    @State private var sortOrder = [CleanerItemSortComparator.sizeLargestFirst]

    private var displayedItems: [CleanerItem] {
        store.items(for: destination).sorted(using: sortOrder)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(destination.rawValue)
                        .font(.title2.bold())
                    Text("\(displayedItems.count) 個項目")
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

            Divider()

            if displayedItems.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: destination == .ignored ? "eye.slash" : "tray")
                        .font(.system(size: 42))
                        .foregroundStyle(.secondary)
                    Text(destination == .ignored ? "沒有忽略的項目" : "沒有掃描結果")
                        .font(.title3.bold())
                    Text("按下重新掃描，或調整設定中的掃描範圍。")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                if destination == .safeCleanup {
                    SafeGroupedItemListView(store: store, requestDelete: requestDelete)
                } else {
                    HSplitView {
                    Table(displayedItems, selection: $store.selectedItemID, sortOrder: $sortOrder) {
                        TableColumn("名稱", sortUsing: CleanerItemSortComparator.nameAscending) { item in
                            HStack {
                                Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                                    .foregroundStyle(item.isDirectory ? .blue : .secondary)
                                Text(item.name)
                                    .lineLimit(1)
                            }
                        }
                        .width(min: 155, ideal: 205, max: 250)

                        TableColumn("來源") { item in
                            Text(item.source.rawValue).lineLimit(1)
                        }
                        .width(min: 90, ideal: 105, max: 125)

                        TableColumn("最後修改", sortUsing: CleanerItemSortComparator.modifiedNewestFirst) { item in
                            Text(AppFormatters.date(item.modifiedAt))
                                .lineLimit(1)
                        }
                        .width(min: 120, ideal: 130, max: 145)

                        TableColumn("大小", sortUsing: CleanerItemSortComparator.sizeLargestFirst) { item in
                            Text(AppFormatters.bytes(item.size)).monospacedDigit()
                        }
                        .width(min: 70, ideal: 80, max: 90)

                        TableColumn("風險", sortUsing: CleanerItemSortComparator.riskHighestFirst) { item in
                            SafetyBadge(level: item.safety)
                        }
                        .width(min: 80, ideal: 90, max: 100)
                    }
                    .frame(minWidth: 620)

                    if let item = store.selectedItem,
                       displayedItems.contains(where: { $0.id == item.id }) {
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
        }
    }
}
