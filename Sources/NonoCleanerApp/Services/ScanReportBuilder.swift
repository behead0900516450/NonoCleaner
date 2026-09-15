import Foundation

enum ScanReportBuilder {
    private struct JSONExport: Encodable {
        let reportType: String
        let appVersion: String
        let operatingSystem: String
        let architecture: String
        let scan: JSONScanExport
        let ignoredPaths: [String]
    }

    private struct JSONScanExport: Encodable {
        let scannedAt: Date
        let duration: TimeInterval
        let items: [CleanerItem]
        let diagnostics: JSONDiagnosticsExport
    }

    private struct JSONDiagnosticsExport: Encodable {
        let scannedPaths: [String]
        let inaccessiblePaths: [String]
        let macOSProtectedPaths: [String]?
        let permissionDeniedPaths: [String]?
        let symbolicLinksSkipped: Int
        let errors: [String]
        let appliedRules: [String]
        let unclassifiedItemCount: Int
        let wasInterrupted: Bool
    }

    static func text(for report: ScanReport, mode: ScanReportMode, ignoredPaths: Set<String>) -> String {
        let totalBytes = report.items.reduce(0) { $0 + $1.size }
        var lines: [String] = [
            "NONO CLEANER SCAN REPORT",
            "",
            "掃描時間：\(AppFormatters.date(report.scannedAt))",
            "App Version：\(appVersion)",
            "macOS：\(ProcessInfo.processInfo.operatingSystemVersionString)",
            "Architecture：\(architecture)",
            "掃描耗時：\(String(format: "%.2f", report.duration)) 秒",
            "報告模式：\(mode.rawValue)",
            "",
            "=== SUMMARY ===",
            "",
            "掃描總項目：\(report.items.count)",
            "掃描總容量：\(AppFormatters.bytes(totalBytes))"
        ]

        appendSafety(.safe, title: "低風險可清理", report: report, to: &lines)
        appendSafety(.review, title: "需要確認", report: report, to: &lines)
        appendSafety(.protected, title: "保護項目", report: report, to: &lines)

        lines += ["", "=== CATEGORY SUMMARY ===", ""]
        for source in ScanSource.allCases {
            let items = report.items.filter { $0.source == source }
            let bytes = items.reduce(0) { $0 + $1.size }
            lines.append("\(source.rawValue)：\(items.count) 個項目，\(AppFormatters.bytes(bytes))")
        }

        lines += ["", "=== TIME SUMMARY ===", ""]
        for bucket in ItemAgeBucket.allCases {
            let items = report.items.filter { bucket.contains($0.modifiedAt, now: report.scannedAt) }
            let bytes = items.reduce(0) { $0 + $1.size }
            lines.append("\(bucket.rawValue)：\(items.count) 個項目，\(AppFormatters.bytes(bytes))")
        }

        lines += ["", "=== ITEMS ===", ""]
        let selectedItems = itemsForOutput(report.items, mode: mode)
        for (index, item) in selectedItems.enumerated() {
            lines += [
                "[#\(index + 1)]",
                "名稱：\(item.name)",
                "完整路徑：\(item.url.path)",
                "來源 App：\(item.sourceApp)",
                "分類：\(item.source.rawValue)",
                "類型：\(item.typeDescription)",
                "大小：\(AppFormatters.bytes(item.size))",
                "包含檔案：\(item.containedFileCount)",
                "建立時間：\(AppFormatters.date(item.createdAt))",
                "最後修改：\(AppFormatters.date(item.modifiedAt))",
                "風險：\(riskName(item.safety))",
                "建議：\(item.safety.recommendation)",
                "判斷原因 / Matched Rule：\(item.matchedRule)",
                ""
            ]
        }
        if selectedItems.count < report.items.count {
            lines.append("一般報告已省略 \(report.items.count - selectedItems.count) 個極小或較低優先項目；可切換至「完整除錯報告」查看。")
            lines.append("")
        }

        appendDiagnostics(report.diagnostics, mode: mode, ignoredPaths: ignoredPaths, to: &lines)
        return lines.joined(separator: "\n")
    }

    static func json(for report: ScanReport, mode: ScanReportMode, ignoredPaths: Set<String>) throws -> String {
        let diagnostics = report.diagnostics
        let exportedDiagnostics = JSONDiagnosticsExport(
            scannedPaths: diagnostics.scannedPaths,
            inaccessiblePaths: mode == .normal ? diagnostics.nonPermissionInaccessiblePaths : diagnostics.inaccessiblePaths,
            macOSProtectedPaths: mode == .normal ? diagnostics.macOSProtectedPaths : nil,
            permissionDeniedPaths: mode == .debug ? diagnostics.permissionDeniedPaths : nil,
            symbolicLinksSkipped: diagnostics.symbolicLinksSkipped,
            errors: mode == .normal ? diagnostics.nonPermissionErrors : diagnostics.errors,
            appliedRules: diagnostics.appliedRules,
            unclassifiedItemCount: diagnostics.unclassifiedItemCount,
            wasInterrupted: diagnostics.wasInterrupted
        )
        let exportedReport = JSONScanExport(
            scannedAt: report.scannedAt,
            duration: report.duration,
            items: mode == .normal ? itemsForOutput(report.items, mode: mode) : report.items,
            diagnostics: exportedDiagnostics
        )
        let payload = JSONExport(
            reportType: mode.rawValue,
            appVersion: appVersion,
            operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
            architecture: architecture,
            scan: exportedReport,
            ignoredPaths: ignoredPaths.sorted()
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return String(decoding: try encoder.encode(payload), as: UTF8.self)
    }

    static func suggestedFilename(format: ReportExportFormat) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return "NonoCleaner-Scan-\(formatter.string(from: Date())).\(format.rawValue)"
    }

    private static func appendSafety(_ safety: SafetyLevel, title: String, report: ScanReport, to lines: inout [String]) {
        let items = report.items.filter { $0.safety == safety }
        lines += [
            "",
            "\(title)：",
            "項目數：\(items.count)",
            "容量：\(AppFormatters.bytes(items.reduce(0) { $0 + $1.size }))"
        ]
    }

    private static func itemsForOutput(_ items: [CleanerItem], mode: ScanReportMode) -> [CleanerItem] {
        let ordered = items.sorted { $0.size > $1.size }
        guard mode == .normal else { return ordered }
        let important = ordered.filter { $0.size >= 1_000_000 || $0.safety != .safe }
        return Array((important.isEmpty ? ordered : important).prefix(200))
    }

    private static func appendDiagnostics(
        _ diagnostics: ScanDiagnostics,
        mode: ScanReportMode,
        ignoredPaths: Set<String>,
        to lines: inout [String]
    ) {
        lines += ["", "=== SCAN DIAGNOSTICS ===", ""]
        appendList("實際掃描的路徑", diagnostics.scannedPaths, mode: mode, to: &lines)
        if mode == .normal {
            lines.append("macOS 保護項目：\(diagnostics.macOSProtectedPaths.count)")
            lines.append("說明：這些位置受到 macOS 權限保護，Nono Cleaner 已安全略過，不影響其他掃描結果。")
            let limit = min(diagnostics.macOSProtectedPaths.count, 30)
            for value in diagnostics.macOSProtectedPaths.prefix(limit) { lines.append("- \(value)") }
            if limit < diagnostics.macOSProtectedPaths.count {
                lines.append("- …其餘 \(diagnostics.macOSProtectedPaths.count - limit) 筆請見完整除錯報告")
            }
            appendList("其他無法存取的路徑", diagnostics.nonPermissionInaccessiblePaths, mode: mode, to: &lines)
        } else {
            appendList("無法存取的路徑", diagnostics.inaccessiblePaths, mode: mode, to: &lines)
            appendList("Permission denied", diagnostics.permissionDeniedPaths, mode: mode, to: &lines)
        }
        lines.append("Symbolic links skipped：\(diagnostics.symbolicLinksSkipped)")
        appendList("掃描錯誤", mode == .normal ? diagnostics.nonPermissionErrors : diagnostics.errors, mode: mode, to: &lines)
        appendList("被忽略的項目", ignoredPaths.sorted(), mode: mode, to: &lines)
        appendList("套用的分類規則", diagnostics.appliedRules, mode: mode, to: &lines)
        lines.append("無法分類的項目數：\(diagnostics.unclassifiedItemCount)")
        lines.append("掃描是否被中斷：\(diagnostics.wasInterrupted ? "是" : "否")")
    }

    private static func appendList(_ title: String, _ values: [String], mode: ScanReportMode, to lines: inout [String]) {
        lines.append("\(title)：\(values.count)")
        let limit = mode == .debug ? values.count : min(values.count, 30)
        for value in values.prefix(limit) { lines.append("- \(value)") }
        if limit < values.count { lines.append("- …其餘 \(values.count - limit) 筆請見完整除錯報告") }
    }

    private static func riskName(_ safety: SafetyLevel) -> String {
        switch safety {
        case .safe: return "Safe"
        case .review: return "Review"
        case .protected: return "Protected"
        }
    }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }

    private static var architecture: String {
        #if arch(arm64)
        return "arm64 (Apple Silicon)"
        #elseif arch(x86_64)
        return "x86_64 (Intel)"
        #else
        return "Unknown"
        #endif
    }
}
