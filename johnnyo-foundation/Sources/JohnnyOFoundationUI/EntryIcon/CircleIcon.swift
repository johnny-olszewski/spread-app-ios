import SwiftUI

/// A filled circle icon representing a task entry.
///
/// Renders as a solid `Circle` fill. Use as the base for task status decorators.
public struct CircleIcon: EntryIconView {

    public let color: Color
    public let iconSize: CGFloat

    /// Creates a filled circle icon.
    ///
    /// - Parameters:
    ///   - color: The fill color.
    ///   - iconSize: The diameter in points.
    public init(color: Color, iconSize: CGFloat) {
        self.color = color
        self.iconSize = iconSize
    }

    public var body: some View {
        Circle()
            .fill(color)
            .frame(width: iconSize, height: iconSize)
    }
}

#Preview {
    HStack(spacing: 12) {
        CircleIcon(color: .primary, iconSize: 12)
        CircleIcon(color: .green, iconSize: 17)
        CircleIcon(color: .orange, iconSize: 22)
        CircleIcon(color: .secondary, iconSize: 28)
    }
    .padding()
}
