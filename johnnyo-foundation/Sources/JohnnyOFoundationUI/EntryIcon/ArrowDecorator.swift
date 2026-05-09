import SwiftUI

/// A decorator that overlays an animated right-pointing arrow on any `EntryIconView`.
///
/// The arrowhead extends to the right of the base icon by `tailFraction × iconSize`.
/// The layout footprint remains `iconSize × iconSize`, so surrounding views are
/// not affected by the rightward extension.
///
/// On appear the arrow strokes draw in with an easeOut animation.
///
/// Example:
/// ```swift
/// ArrowDecorator(base: TaskCircleIcon(color: .orange, iconSize: 12), color: .orange)
/// ```
public struct ArrowDecorator<Base: EntryIconView>: EntryIconView {

    // MARK: - Properties

    public let base: Base
    public let color: Color

    /// How far the arrow extends to the right, as a multiple of `iconSize`.
    ///
    /// A value of `1.0` means the arrowhead tip is one full icon-width to the
    /// right of the base icon's right edge.
    public var tailFraction: CGFloat

    @State private var drawProgress: CGFloat = 0

    // MARK: - Initialization

    /// Creates an arrow decorator.
    ///
    /// - Parameters:
    ///   - base: The base icon to decorate.
    ///   - color: The stroke color for the arrow.
    ///   - tailFraction: Rightward extension as a multiple of `iconSize` (defaults to `1.0`).
    public init(base: Base, color: Color, tailFraction: CGFloat = 1.0) {
        self.base = base
        self.color = color
        self.tailFraction = tailFraction
    }

    // MARK: - EntryIconView

    public var iconSize: CGFloat { base.iconSize }

    // MARK: - Body

    public var body: some View {
        base
            .overlay(alignment: .leading) {
                ArrowShape()
                    .trim(from: 0, to: drawProgress)
                    .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round))
                    .frame(width: arrowWidth, height: iconSize)
                    .allowsHitTesting(false)
            }
            .frame(width: iconSize, height: iconSize)
            .onAppear {
                withAnimation(.easeOut(duration: 0.22)) {
                    drawProgress = 1
                }
            }
    }

    // MARK: - Geometry

    private var arrowWidth: CGFloat {
        iconSize * (1 + tailFraction)
    }

    private var strokeWidth: CGFloat {
        max(1.5, iconSize * 0.13)
    }
}

// MARK: - Previews

#Preview("ArrowDecorator — task migrated") {
    HStack(spacing: 24) {
        ArrowDecorator(
            base: TaskCircleIcon(color: .orange, iconSize: 12),
            color: .orange
        )
        ArrowDecorator(
            base: TaskCircleIcon(color: .orange, iconSize: 17),
            color: .orange
        )
        ArrowDecorator(
            base: TaskCircleIcon(color: .orange, iconSize: 22),
            color: .orange
        )
    }
    .padding()
}

#Preview("ArrowDecorator — note migrated") {
    ArrowDecorator(
        base: NoteDashIcon(color: .orange, iconSize: 12),
        color: .orange
    )
    .padding()
}
