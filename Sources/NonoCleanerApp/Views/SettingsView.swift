import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: CleanerStore

    var body: some View {
        Form {
            Section("掃描範圍") {
                Toggle("Downloads", isOn: setting(\.scanDownloads))
                Toggle("Desktop", isOn: setting(\.scanDesktop))
                Toggle("~/Library/Caches", isOn: setting(\.scanUserCaches))
                Toggle("macOS Temporary folders 與 /private/var/folders", isOn: setting(\.scanSystemTemporary))
                Toggle("Adobe / Premiere Cache", isOn: setting(\.scanAdobeCaches))
            }

            Section("安全性") {
                Label("應用程式不會自動刪除任何項目。", systemImage: "hand.raised.fill")
                Label("清理會將檔案移到垃圾桶，並且一定要先確認。", systemImage: "trash")
                Label("影片原始檔、Premiere Project、PSD 與 Lightroom Catalog 已預設保護。", systemImage: "lock.fill")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("設定")
        .onDisappear { store.saveScanPreferences() }
    }

    private func setting(_ keyPath: ReferenceWritableKeyPath<CleanerStore, Bool>) -> Binding<Bool> {
        Binding(
            get: { store[keyPath: keyPath] },
            set: {
                store[keyPath: keyPath] = $0
                store.saveScanPreferences()
            }
        )
    }
}
