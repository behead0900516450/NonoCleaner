import SwiftUI

struct ContentView: View {
    @StateObject private var store = CleanerStore()
    @State private var pendingDeleteItem: CleanerItem?
    @State private var confirmsSafeCleanup = false

    var body: some View {
        NavigationSplitView {
            List(selection: $store.destination) {
                ForEach(SidebarDestination.allCases) { destination in
                    Button {
                        store.destination = destination
                    } label: {
                        Label(destination.rawValue, systemImage: destination.systemImage)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                        .tag(destination)
                        .badge(badgeCount(for: destination))
                        .listRowBackground(
                            selectedDestination == destination
                                ? Color.accentColor.opacity(0.24)
                                : Color.clear
                        )
                }
            }
            .navigationTitle("Nono Cleaner")
            .navigationSplitViewColumnWidth(min: 180, ideal: 210)
        } detail: {
            Group {
                switch selectedDestination {
                case .overview:
                    OverviewView(
                        store: store,
                        showItems: { store.destination = .safeCleanup },
                        requestSafeCleanup: { confirmsSafeCleanup = true }
                    )
                case .settings:
                    SettingsView(store: store)
                case .scanReport:
                    ScanReportView(store: store)
                case .byDate:
                    TimeOrganizedView(
                        store: store,
                        requestDelete: { pendingDeleteItem = $0 }
                    )
                default:
                    ItemListView(
                        store: store,
                        destination: selectedDestination,
                        requestDelete: { pendingDeleteItem = $0 }
                    )
                }
            }
            .frame(minWidth: 760, minHeight: 560)
        }
        .confirmationDialog(
            "確定要移到垃圾桶？",
            isPresented: Binding(
                get: { pendingDeleteItem != nil },
                set: { if !$0 { pendingDeleteItem = nil } }
            ),
            presenting: pendingDeleteItem
        ) { item in
            Button("將「\(item.name)」移到垃圾桶", role: .destructive) {
                store.moveToTrash(item)
                pendingDeleteItem = nil
            }
            Button("取消", role: .cancel) { pendingDeleteItem = nil }
        } message: { item in
            Text("這個動作不會直接永久刪除。\n\(item.url.path)")
        }
        .confirmationDialog("低風險清理", isPresented: $confirmsSafeCleanup) {
            Button("將 \(store.safeItems.count) 個項目移到垃圾桶", role: .destructive) {
                store.moveAllSafeItemsToTrash()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("僅處理綠色低風險項目，合計 \(AppFormatters.bytes(store.safeBytes))。紅色保護項目永遠不會包含在內。")
        }
        .alert("無法完成操作", isPresented: Binding(
            get: { store.presentedError != nil },
            set: { if !$0 { store.presentedError = nil } }
        )) {
            Button("好") { store.presentedError = nil }
        } message: {
            Text(store.presentedError ?? "")
        }
    }

    private var selectedDestination: SidebarDestination {
        store.destination ?? .overview
    }

    private func badgeCount(for destination: SidebarDestination) -> Int {
        switch destination {
        case .overview, .scanReport, .settings: return 0
        default: return store.count(for: destination)
        }
    }
}
