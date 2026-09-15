import SwiftUI

struct SafeGroupedItemListView: View {
    @ObservedObject var store: CleanerStore
    let requestDelete: (CleanerItem) -> Void

    @State private var groupSort = SafeItemGroupSortComparator.sizeLargestFirst
    @State private var expandedGroupIDs: Set<SafeItemGroup.ID> = []

    private var groups: [SafeItemGroup] {
        SafeItemGrouping.groups(items: store.items(for: .safeCleanup))
            .sorted(using: groupSort)
    }

    private var itemSort: CleanerItemSortComparator {
        CleanerItemSortComparator(groupSort.field, order: groupSort.order)
    }

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                columnHeader
                Divider()
                List(selection: $store.selectedItemID) {
                    ForEach(groups) { group in
                        DisclosureGroup(isExpanded: expansionBinding(for: group.id)) {
                            ForEach(group.items.sorted(using: itemSort)) { item in
                                itemRow(item)
                                    .tag(item.id)
                            }
                        } label: {
                            groupRow(group)
                        }
                    }
                }
                .listStyle(.inset)
            }
            .frame(minWidth: 640)

            detailPane
                .frame(minWidth: 270, idealWidth: 340)
        }
    }

    private var columnHeader: some View {
        HStack(spacing: 8) {
            sortButton("來源名稱", field: .name)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("項目數")
                .frame(width: 55, alignment: .trailing)
            sortButton("最後修改", field: .modifiedAt)
                .frame(width: 120, alignment: .leading)
            sortButton("總容量", field: .size)
                .frame(width: 72, alignment: .trailing)
            sortButton("風險", field: .safety)
                .frame(width: 72, alignment: .leading)
            Text("可重新產生")
                .frame(width: 85, alignment: .leading)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.leading, 30)
        .padding(.trailing, 10)
        .frame(height: 28)
    }

    private func sortButton(_ title: String, field: ItemSortField) -> some View {
        Button {
            if groupSort.field == field {
                groupSort.order = groupSort.order == .forward ? .reverse : .forward
            } else {
                groupSort = SafeItemGroupSortComparator(field)
            }
        } label: {
            HStack(spacing: 3) {
                Text(title)
                if groupSort.field == field {
                    Image(systemName: groupSort.order == .forward ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.semibold))
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("按一下依\(title)排序；再次按下可反轉順序")
    }

    private func groupRow(_ group: SafeItemGroup) -> some View {
        HStack(spacing: 8) {
            Label(group.name, systemImage: "square.stack.3d.up.fill")
                .fontWeight(.semibold)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(group.itemCount)")
                .monospacedDigit()
                .frame(width: 55, alignment: .trailing)
            Text(AppFormatters.date(group.latestModifiedAt))
                .lineLimit(1)
                .frame(width: 120, alignment: .leading)
            Text(AppFormatters.bytes(group.totalSize))
                .monospacedDigit()
                .frame(width: 72, alignment: .trailing)
            SafetyBadge(level: group.safety)
                .frame(width: 72, alignment: .leading)
            Text(group.regenerationSummary)
                .lineLimit(1)
                .frame(width: 85, alignment: .leading)
        }
    }

    private func itemRow(_ item: CleanerItem) -> some View {
        HStack(spacing: 8) {
            Label(item.name, systemImage: item.isDirectory ? "folder.fill" : "doc.fill")
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(item.containedFileCount)")
                .monospacedDigit()
                .frame(width: 55, alignment: .trailing)
            Text(AppFormatters.date(item.modifiedAt))
                .lineLimit(1)
                .frame(width: 120, alignment: .leading)
            Text(AppFormatters.bytes(item.size))
                .monospacedDigit()
                .frame(width: 72, alignment: .trailing)
            SafetyBadge(level: item.safety)
                .frame(width: 72, alignment: .leading)
            Text(regenerationSummary(for: item))
                .lineLimit(1)
                .frame(width: 85, alignment: .leading)
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        if let item = store.selectedItem,
           item.safety == .safe,
           !store.ignoredPaths.contains(item.id) {
            ItemDetailView(
                item: item,
                isIgnored: false,
                reveal: { store.reveal(item) },
                delete: { requestDelete(item) },
                ignore: { store.ignore(item) }
            )
        } else {
            VStack(spacing: 8) {
                Image(systemName: "cursorarrow.click.2")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("展開群組並選取項目以查看詳細資訊")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func expansionBinding(for id: SafeItemGroup.ID) -> Binding<Bool> {
        Binding(
            get: { expandedGroupIDs.contains(id) },
            set: { isExpanded in
                if isExpanded {
                    expandedGroupIDs.insert(id)
                } else {
                    expandedGroupIDs.remove(id)
                }
            }
        )
    }

    private func regenerationSummary(for item: CleanerItem) -> String {
        let value = OriginKnowledge.description(for: item).regeneration
        if value.hasPrefix("會") { return "會" }
        if value.contains("需要時") { return "需要時會" }
        return "依來源規則"
    }
}
