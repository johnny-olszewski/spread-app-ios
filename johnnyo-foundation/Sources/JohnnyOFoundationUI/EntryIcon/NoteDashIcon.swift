import SwiftUI

/// A horizontal dash icon representing a note entry.
///
/// Renders as a short `Rectangle` fill centered in the icon frame.
/// Use as the base for note status decorators.
public struct NoteDashIcon: EntryIconView {

    public let color: Color
    public let iconSize: CGFloat

    /// Creates a dash icon.
    ///
    /// - Parameters:
    ///   - color: The fill color.
    ///   - iconSize: The bounding square dimension in points. The dash width
    ///     is 75% of this value and the height is fixed at 1.5pt.
    public init(color: Color, iconSize: CGFloat) {
        self.color = color
        self.iconSize = iconSize
    }

    private var dashWidth: CGFloat { iconSize * 0.75 }
    private var dashHeight: CGFloat { 1.5 }

    public var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: dashWidth, height: dashHeight)
            .frame(width: iconSize, height: iconSize)
    }
}

#Preview {
    HStack(spacing: 12) {
        NoteDashIcon(color: .primary, iconSize: 12)
        NoteDashIcon(color: .primary, iconSize: 17)
        NoteDashIcon(color: .primary, iconSize: 22)
        NoteDashIcon(color: .primary, iconSize: 28)
    }
    .padding()
}
