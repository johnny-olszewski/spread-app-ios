import SwiftUI

public protocol LabelChipRepresentable {
    var title: String { get }
    var fillColor: Color { get }
    var strokeColor: Color? { get }
}

/// A capsule-shaped label chip with a configurable title and tinted color identity.
///
/// Renders a short text label inside a capsule with a transparent fill and a
/// slightly opaque stroke in the same hue, suitable for list or tag labels.
public struct LabelChip: View {
    let title: String
    let fillColor: Color
    let strokeColor: Color

    public init(title: String, fillColor: Color, strokeColor: Color? = nil) {
        self.title = title
        self.fillColor = fillColor
        self.strokeColor = strokeColor ?? fillColor
    }
    
    public init(_ representable: any LabelChipRepresentable) {
        self.init(
            title: representable.title,
            fillColor: representable.fillColor,
            strokeColor: representable.strokeColor
        )
    }

    public var body: some View {
        Text(title)
            .font(.caption2.weight(.medium))
            .foregroundStyle(fillColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule(style: .continuous)
                    .fill(fillColor.opacity(0.12))
            )
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(strokeColor.opacity(0.5), lineWidth: 0.75)
            }
    }
}

#Preview {
    HStack(spacing: 8) {
        LabelChip(title: "Work", fillColor: .blue)
        LabelChip(title: "Home", fillColor: .green)
        LabelChip(title: "Personal", fillColor: .purple)
    }
    .padding()
}
