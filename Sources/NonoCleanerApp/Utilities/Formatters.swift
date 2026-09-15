import Foundation

enum AppFormatters {
    static let byteCount: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter
    }()

    static let date: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static func bytes(_ value: Int64) -> String {
        byteCount.string(fromByteCount: value)
    }

    static func date(_ value: Date?) -> String {
        guard let value else { return "無法取得" }
        return date.string(from: value)
    }
}
