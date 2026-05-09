import SwiftUI

/// A stroked circle icon representing an event entry.
///
/// Renders as an empty `Circle` strokeBorder. Use as the base for event status decorators.
public struct EventCircleIcon: EntryIconView {

    public let color: Color
    public let iconSize: CGFloat

    /// The stroke line width, proportional to icon size.
    public var strokeWidth: CGFloat

    /// Creates a stroked circle icon.
    ///
    /// - Parameters:
    ///   - color: The stroke color.
    ///   - iconSize: The diameter in points.
    ///   - strokeWidth: The stroke line width (defaults to 1.5).
    public init(color: Color, iconSize: CGFloat, strokeWidth: CGFloat = 1.5) {
        self.color = color
        self.iconSize = iconSize
        self.strokeWidth = strokeWidth
    }

    public var body: some View {
        Circle()
            .strokeBorder(color, lineWidth: strokeWidth)
            .frame(width: iconSize, height: iconSize)
    }
}

#Preview {
    HStack(spacing: 12) {
        EventCircleIcon(color: .primary, iconSize: 12)
        EventCircleIcon(color: .primary, iconSize: 17)
        EventCircleIcon(color: .primary, iconSize: 22)
        EventCircleIcon(color: .primary, iconSize: 28)
    }
    .padding()
}
