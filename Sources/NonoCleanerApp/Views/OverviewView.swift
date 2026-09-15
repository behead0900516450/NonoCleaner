import SwiftUI

struct OverviewView: View {
    @ObservedObject var store: CleanerStore
    let showItems: () -> Void
    let requestSafeCleanup: () -> Void

    private let columns = [GridItem(.adaptive(minimum: 210), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Nono Cleaner")
                        .font(.largeTitle.bold())
                    Text("安全地看見磁碟上的暫存與雜物，所有處理都由你決定。")
                        .foregroundStyle(.secondary)
                }

                if store.isScanning {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text(store.statusMessage)
                        Spacer()
                        Button("取消") { store.cancelScan() }
                    }
                    .padding()
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                }

                LazyVGrid(columns: columns, spacing: 14) {
                    sourceCard(.codex, icon: "bubble.left.and.text.bubble.right")
                    sourceCard(.systemTemporary, icon: "clock.arrow.circlepath")
                    sourceCard(.adobeCache, icon: "film.stack")
                    sourceCard(.downloads, icon: "arrow.down.circle")
                    sourceCard(.desktop, icon: "menubar.dock.rectangle")
                    sourceCard(.userCache, icon: "shippingbox")
                }

                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Label("低風險可清理", systemImage: "checkmark.shield.fill")
                            .foregroundStyle(.green)
                        Text(AppFormatters.bytes(store.safeBytes))
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                        Text("\(store.safeItems.count) 個明確為快取、暫存或預覽的項目")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(18)
                .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.green.opacity(0.2)))

                HStack(spacing: 10) {
                    Button {
                        store.startScan()
                    } label: {
                        Label("開始掃描", systemImage: "magnifyingglass")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.isScanning)

                    Button("查看項目", action: showItems)
                        .buttonStyle(.bordered)
                        .disabled(store.items.isEmpty)

                    Button("低風險清理", action: requestSafeCleanup)
                        .buttonStyle(.bordered)
                        .disabled(store.safeItems.isEmpty || store.isScanning)
                }

                Label(store.statusMessage, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(28)
        }
    }

    private func sourceCard(_ source: ScanSource, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
            Text(source.rawValue)
                .font(.headline)
            Text(AppFormatters.bytes(store.totalBytes(for: source)))
                .font(.title3.monospacedDigit())
            Text("\(store.visibleItems.filter { $0.source == source }.count) 個項目")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary))
    }
}
