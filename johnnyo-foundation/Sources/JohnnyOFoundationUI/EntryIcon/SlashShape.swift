import SwiftUI

/// A `Shape` that draws a single diagonal line from top-right to bottom-left.
///
/// The line is centered in the bounding rect and scaled by `armLength`.
/// Intended for use in `SlashDecorator` with `.trim` animation.
public struct SlashShape: Shape, Sendable {

    /// The end-to-end length of the diagonal line in points.
    public var armLength: CGFloat

    /// Creates a slash shape.
    ///
    /// - Parameter armLength: The end-to-end length of the diagonal line.
    public init(armLength: CGFloat) {
        self.armLength = armLength
    }

    public func path(in rect: CGRect) -> Path {
        let cx = rect.midX
        let cy = rect.midY
        let half = armLength / 2

        var path = Path()
        // Top-right → bottom-left
        path.move(to: CGPoint(x: cx + half, y: cy - half))
        path.addLine(to: CGPoint(x: cx - half, y: cy + half))
        return path
    }
}
