import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ScanReportView: View {
    @ObservedObject var store: CleanerStore
    @State private var mode: ScanReportMode = .normal
    @State private var copiedMessageVisible = false

    private var reportText: String {
        guard let report = store.scanReport else { return "" }
        return ScanReportBuilder.text(for: report, mode: mode, ignoredPaths: store.ignoredPaths)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("掃描報告")
                        .font(.title2.bold())
                    if let report = store.scanReport {
                        Text("掃描於 \(AppFormatters.date(report.scannedAt)) 完成")
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if copiedMessageVisible {
                    Label("已複製掃描報告", systemImage: "checkmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(.green)
                        .transition(.opacity)
                }
                Button("複製全部", action: copyAll)
                    .disabled(store.scanReport == nil)
                Menu("匯出…") {
                    ForEach(ReportExportFormat.allCases) { format in
                        Button(format.title) { export(format: format) }
                    }
                }
                .disabled(store.scanReport == nil)
            }
            .padding()

            Divider()

            if store.scanReport == nil {
                VStack(spacing: 10) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 42))
                        .foregroundStyle(.secondary)
                    Text("尚無掃描報告，請先執行掃描。")
                        .font(.title3.bold())
                    Button("開始掃描") { store.startScan() }
                        .buttonStyle(.borderedProminent)
                        .disabled(store.isScanning)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    Picker("報告模式", selection: $mode) {
                        ForEach(ScanReportMode.allCases) { reportMode in
                            Text(reportMode.rawValue).tag(reportMode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 420)
                    .padding(12)

                    SelectableReportTextView(text: reportText)
                        .background(.background)
                }
            }
        }
    }

    private func copyAll() {
        guard !reportText.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(reportText, forType: .string)
        withAnimation { copiedMessageVisible = true }
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run { withAnimation { copiedMessageVisible = false } }
        }
    }

    private func export(format: ReportExportFormat) {
        guard let report = store.scanReport else { return }
        let panel = NSSavePanel()
        panel.title = "匯出 Nono Cleaner 掃描報告"
        panel.prompt = "匯出"
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = ScanReportBuilder.suggestedFilename(format: format)
        switch format {
        case .text: panel.allowedContentTypes = [.plainText]
        case .markdown: panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        case .json: panel.allowedContentTypes = [.json]
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let output: String
            if format == .json {
                output = try ScanReportBuilder.json(for: report, mode: mode, ignoredPaths: store.ignoredPaths)
            } else {
                output = reportText
            }
            try output.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            store.presentedError = "無法匯出掃描報告：\(error.localizedDescription)"
        }
    }
}
