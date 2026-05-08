import SwiftUI

/// A `Shape` that draws an X mark as two crossing diagonal lines.
///
/// The two diagonals are joined into a single `Path`, which enables
/// `.trim(from:to:)` to animate both arms drawing simultaneously: at
/// `progress == 0.5` the first arm is fully drawn; at `progress == 1.0`
/// both arms are complete.
///
/// The arms are centered in the bounding rect and scaled by `armLength`.
public struct XMarkShape: Shape, Sendable {

    /// The end-to-end length of each arm in points.
    public var armLength: CGFloat

    /// Creates an X mark shape.
    ///
    /// - Parameter armLength: The end-to-end length of each diagonal arm.
    public init(armLength: CGFloat) {
        self.armLength = armLength
    }

    public func path(in rect: CGRect) -> Path {
        let cx = rect.midX
        let cy = rect.midY
        let half = armLength / 2

        var path = Path()
        // First arm: top-left → bottom-right
        path.move(to: CGPoint(x: cx - half, y: cy - half))
        path.addLine(to: CGPoint(x: cx + half, y: cy + half))
        // Second arm: top-right → bottom-left (continues on the same path
        // so trim animates both arms proportionally from a single value)
        path.move(to: CGPoint(x: cx + half, y: cy - half))
        path.addLine(to: CGPoint(x: cx - half, y: cy + half))
        return path
    }
}
