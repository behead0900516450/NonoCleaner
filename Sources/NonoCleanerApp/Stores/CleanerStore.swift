import AppKit
import Foundation

@MainActor
final class CleanerStore: ObservableObject {
    @Published var items: [CleanerItem] = []
    @Published var scanReport: ScanReport?
    @Published var destination: SidebarDestination? = .overview
    @Published var selectedItemID: CleanerItem.ID?
    @Published var isScanning = false
    @Published var statusMessage = "按下「開始掃描」來檢查本機檔案。"
    @Published var presentedError: String?
    @Published private(set) var ignoredPaths: Set<String>

    @Published var scanDownloads: Bool
    @Published var scanDesktop: Bool
    @Published var scanUserCaches: Bool
    @Published var scanSystemTemporary: Bool
    @Published var scanAdobeCaches: Bool

    private let scanner = FileScanner()
    private let cleanupService = CleanupService()
    private let defaults = UserDefaults.standard
    private var scanTask: Task<Void, Never>?
    private var currentScanID = UUID()

    init() {
        ignoredPaths = Set(defaults.stringArray(forKey: "ignoredPaths") ?? [])
        scanDownloads = defaults.object(forKey: "scanDownloads") as? Bool ?? true
        scanDesktop = defaults.object(forKey: "scanDesktop") as? Bool ?? true
        scanUserCaches = defaults.object(forKey: "scanUserCaches") as? Bool ?? true
        scanSystemTemporary = defaults.object(forKey: "scanSystemTemporary") as? Bool ?? true
        scanAdobeCaches = defaults.object(forKey: "scanAdobeCaches") as? Bool ?? true
    }

    deinit {
        scanTask?.cancel()
    }

    var visibleItems: [CleanerItem] {
        items.filter { !ignoredPaths.contains($0.id) }
    }

    var safeItems: [CleanerItem] {
        visibleItems.filter { $0.safety == .safe }
    }

    var safeBytes: Int64 {
        safeItems.reduce(0) { $0 + $1.size }
    }

    var selectedItem: CleanerItem? {
        guard let selectedItemID else { return nil }
        return items.first { $0.id == selectedItemID }
    }

    func items(for destination: SidebarDestination) -> [CleanerItem] {
        switch destination {
        case .overview:
            return visibleItems
        case .safeCleanup:
            return safeItems
        case .needsReview:
            return visibleItems.filter { $0.safety != .safe }
        case .largeFiles:
            return visibleItems.filter { $0.size >= 500_000_000 }
        case .ignored:
            return items.filter { ignoredPaths.contains($0.id) }
        case .byDate:
            return visibleItems.sorted {
                ($0.modifiedAt ?? .distantPast) > ($1.modifiedAt ?? .distantPast)
            }
        case .scanReport, .settings:
            return []
        }
    }

    func totalBytes(for source: ScanSource) -> Int64 {
        visibleItems.filter { $0.source == source }.reduce(0) { $0 + $1.size }
    }

    func count(for destination: SidebarDestination) -> Int {
        items(for: destination).count
    }

    func startScan() {
        scanTask?.cancel()
        let scanID = UUID()
        currentScanID = scanID
        selectedItemID = nil
        isScanning = true
        statusMessage = "正在掃描可存取的本機資料夾…"
        let options = ScanOptions(
            scanDownloads: scanDownloads,
            scanDesktop: scanDesktop,
            scanUserCaches: scanUserCaches,
            scanSystemTemporary: scanSystemTemporary,
            scanAdobeCaches: scanAdobeCaches
        )

        scanTask = Task { [weak self] in
            guard let self else { return }
            let report = await scanner.scan(options: options)
            guard currentScanID == scanID else { return }
            items = report.items
            scanReport = report
            isScanning = false
            if report.diagnostics.wasInterrupted {
                statusMessage = "掃描已中斷：保留 \(report.items.count) 個部分結果與除錯資訊。"
            } else {
                var summary = "掃描完成：找到 \(report.items.count) 個項目。"
                let protectedCount = report.diagnostics.macOSProtectedPaths.count
                if protectedCount > 0 {
                    summary += " macOS 保護項目 \(protectedCount) 個已安全略過。"
                }
                let errorCount = report.diagnostics.nonPermissionErrors.count
                if errorCount > 0 {
                    summary += " 另有 \(errorCount) 個掃描錯誤，請查看掃描報告。"
                }
                statusMessage = summary + " 不會自動刪除任何檔案。"
            }
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        isScanning = false
        statusMessage = "正在停止掃描並整理部分報告…"
    }

    func reveal(_ item: CleanerItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    func ignore(_ item: CleanerItem) {
        ignoredPaths.insert(item.id)
        persistIgnoredPaths()
        if selectedItemID == item.id { selectedItemID = nil }
    }

    func restore(_ item: CleanerItem) {
        ignoredPaths.remove(item.id)
        persistIgnoredPaths()
    }

    func moveToTrash(_ item: CleanerItem) {
        do {
            try cleanupService.moveToTrash(item)
            items.removeAll { $0.id == item.id }
            ignoredPaths.remove(item.id)
            selectedItemID = nil
            statusMessage = "已將「\(item.name)」移到垃圾桶。"
        } catch {
            presentedError = error.localizedDescription
        }
    }

    func moveAllSafeItemsToTrash() {
        let targets = safeItems
        var removed = Set<String>()
        var failures: [String] = []
        for item in targets {
            do {
                try cleanupService.moveToTrash(item)
                removed.insert(item.id)
            } catch {
                failures.append("\(item.name): \(error.localizedDescription)")
            }
        }
        items.removeAll { removed.contains($0.id) }
        statusMessage = "已將 \(removed.count) 個低風險項目移到垃圾桶。"
        if !failures.isEmpty {
            presentedError = "部分項目無法處理：\n" + failures.prefix(5).joined(separator: "\n")
        }
    }

    func saveScanPreferences() {
        defaults.set(scanDownloads, forKey: "scanDownloads")
        defaults.set(scanDesktop, forKey: "scanDesktop")
        defaults.set(scanUserCaches, forKey: "scanUserCaches")
        defaults.set(scanSystemTemporary, forKey: "scanSystemTemporary")
        defaults.set(scanAdobeCaches, forKey: "scanAdobeCaches")
    }

    private func persistIgnoredPaths() {
        defaults.set(Array(ignoredPaths).sorted(), forKey: "ignoredPaths")
    }
}
