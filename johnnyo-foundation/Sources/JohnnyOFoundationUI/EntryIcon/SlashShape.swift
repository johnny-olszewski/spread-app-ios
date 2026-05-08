import SwiftUI

/// A `Shape` that draws a single diagonal line from bottom-left to top-right.
///
/// Intended for use in `SlashDecorator` with `.trim` animation.
public struct SlashShape: Shape, Sendable {

    public init() {}

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX * 0.2, y: rect.maxY * 0.8))
        path.addLine(to: CGPoint(x: rect.maxX * 0.8, y: rect.maxY * 0.2))
        return path
    }
}
