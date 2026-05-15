import SwiftUI

/// A capsule-shaped label chip with a configurable title and tinted color identity.
///
/// Renders a short text label inside a capsule with a transparent fill and a
/// slightly opaque stroke in the same hue, suitable for list or tag labels.
public struct LabelChip: View {
    let title: String
    let color: Color

    public init(title: String, color: Color) {
        self.title = title
        self.color = color
    }

    public var body: some View {
        Text(title)
            .font(.caption2.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule(style: .continuous)
                    .fill(color.opacity(0.12))
            )
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(color.opacity(0.5), lineWidth: 0.75)
            }
    }
}

#Preview {
    HStack(spacing: 8) {
        LabelChip(title: "Work", color: .blue)
        LabelChip(title: "Home", color: .green)
        LabelChip(title: "Personal", color: .purple)
    }
    .padding()
}
