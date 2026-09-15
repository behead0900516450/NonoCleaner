import Foundation

enum OriginConfidence: String, Codable, Sendable {
    case high = "High"
    case medium = "Medium"
    case unknown = "Unknown"

    var displayName: String {
        switch self {
        case .high: return "高信心"
        case .medium: return "可能"
        case .unknown: return "來源未知"
        }
    }
}

struct SourceDescription: Sendable {
    let sourceAppTool: String
    let sourceType: String
    let overview: String
    let purpose: String
    let creationReason: String
    let commonContents: [String]
    let usageContext: String
    let deletionImpact: String
    let regeneration: String
    let mayReappear: String
    let confidence: OriginConfidence
    let evidence: String
}
