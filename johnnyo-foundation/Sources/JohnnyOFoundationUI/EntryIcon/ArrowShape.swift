import SwiftUI

/// A `Shape` that draws a right-pointing arrow with a shaft and arrowhead.
///
/// The arrow spans the full width of the bounding rect and is centered
/// vertically. The arrowhead size scales with the rect height.
///
/// Intended for use in `ArrowDecorator` with `.trim` animation.
public struct ArrowShape: Shape, Sendable {

    public init() {}

    public func path(in rect: CGRect) -> Path {
        let midY = rect.midY
        let headSize = rect.height * 0.35

        var path = Path()
        // Shaft: full width
        path.move(to: CGPoint(x: rect.minX, y: midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: midY))
        // Arrowhead: upper stroke
        path.move(to: CGPoint(x: rect.maxX - headSize, y: midY - headSize))
        path.addLine(to: CGPoint(x: rect.maxX, y: midY))
        // Arrowhead: lower stroke
        path.addLine(to: CGPoint(x: rect.maxX - headSize, y: midY + headSize))
        return path
    }
}
