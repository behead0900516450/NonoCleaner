import SwiftUI

struct ItemDetailView: View {
    let item: CleanerItem
    let isIgnored: Bool
    let reveal: () -> Void
    let delete: () -> Void
    let ignore: () -> Void

    private var origin: SourceDescription {
        OriginKnowledge.description(for: item)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("這是什麼？")
                        .font(.title2.bold())

                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                            .font(.largeTitle)
                            .foregroundStyle(item.isDirectory ? .blue : .secondary)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.name)
                                .font(.title3.bold())
                                .textSelection(.enabled)
                            SafetyBadge(level: item.safety)
                        }
                    }

                    Text(origin.overview)
                        .font(.body)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }

                informationSection(title: "來源", systemImage: "app.badge") {
                    detail("來源 App / Tool", origin.sourceAppTool)
                    detail("來源類型", origin.sourceType)
                    detail("來源判斷", origin.confidence.displayName)
                    detail("判斷依據", origin.evidence)
                }

                informationSection(title: "用途", systemImage: "questionmark.circle") {
                    Text(origin.purpose)
                        .textSelection(.enabled)
                    detail("常見內容", origin.commonContents.joined(separator: "、"))
                    detail("使用情境", origin.usageContext)
                }

                informationSection(title: "為什麼會出現在這裡", systemImage: "arrow.down.doc") {
                    Text(origin.creationReason)
                        .textSelection(.enabled)
                }

                informationSection(title: "刪除後會怎樣", systemImage: "trash") {
                    Text(origin.deletionImpact)
                        .textSelection(.enabled)
                }

                informationSection(title: "會不會重新產生", systemImage: "arrow.clockwise") {
                    detail("是否可重新產生", origin.regeneration)
                    detail("是否可能再次出現", origin.mayReappear)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Button(action: reveal) {
                        Label("在 Finder 顯示", systemImage: "finder")
                    }

                    Button(role: .destructive, action: delete) {
                        Label("移到垃圾桶", systemImage: "trash")
                    }
                    .disabled(item.safety == .protected)
                    .help(item.safety == .protected ? "重要工作檔已受保護" : "需要再次確認")

                    Button(action: ignore) {
                        Label(isIgnored ? "取消忽略" : "忽略", systemImage: isIgnored ? "eye" : "eye.slash")
                    }
                }
                .buttonStyle(.bordered)

                Divider()

                Text("技術資訊")
                    .font(.headline)

                detail("完整路徑", item.url.path)
                detail("位置", item.locationDescription)
                detail("大小", AppFormatters.bytes(item.size))
                detail("檔案類型", item.typeDescription)
                if item.isDirectory {
                    detail("檔案數", "\(item.containedFileCount) 個")
                }
                detail("建立時間", AppFormatters.date(item.createdAt))
                detail("修改時間", AppFormatters.date(item.modifiedAt))
                detail("刪除風險", item.safety.title)
                detail("建議", item.safety.recommendation)
                detail("Matched Rule", item.matchedRule)
            }
            .padding(20)
        }
    }

    private func informationSection<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
        } label: {
            Label(title, systemImage: systemImage)
                .font(.headline)
        }
    }

    private func detail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
        }
    }
}
