import SwiftUI

extension SafetyLevel {
    var color: Color {
        switch self {
        case .safe: return .green
        case .review: return .orange
        case .protected: return .red
        }
    }

    var iconName: String {
        switch self {
        case .safe: return "checkmark.circle.fill"
        case .review: return "exclamationmark.triangle.fill"
        case .protected: return "lock.fill"
        }
    }
}

struct SafetyBadge: View {
    let level: SafetyLevel

    var body: some View {
        Label(level.title, systemImage: level.iconName)
            .font(.caption)
            .foregroundStyle(level.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(level.color.opacity(0.1), in: Capsule())
    }
}
