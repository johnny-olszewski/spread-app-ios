import SwiftUI

/// A decorator that overlays an animated X mark on any `EntryIconView`.
///
/// The X arms extend beyond the base icon's layout frame by `overhangFraction`.
/// The layout footprint remains `iconSize × iconSize`, so surrounding views are
/// not affected by the overhang.
///
/// On appear the X strokes draw in with an easeOut animation. This means that
/// when a status changes and this decorator enters the view tree, the draw-in
/// plays automatically — no external coordination required.
///
/// Example:
/// ```swift
/// XMarkDecorator(base: TaskCircleIcon(color: .green, iconSize: 12), color: .green)
/// ```
public struct XMarkDecorator<Base: EntryIconView>: EntryIconView {

    /// Geometry and animation settings for an `XMarkDecorator`.
    public struct Configuration: Sendable {

        /// How much the arms extend beyond the base frame as a fraction of `iconSize`.
        public var overhangFraction: CGFloat

        /// The fraction of the decorator canvas used as the end-to-end arm length.
        public var armLengthFraction: CGFloat

        /// The stroke width as a fraction of `iconSize`.
        public var strokeWidthFraction: CGFloat

        /// The minimum stroke width in points.
        public var minimumStrokeWidth: CGFloat

        /// The draw-in animation duration in seconds.
        public var animationDuration: TimeInterval

        /// Creates X mark decorator configuration.
        ///
        /// - Parameters:
        ///   - overhangFraction: How much the arms extend beyond the base frame as
        ///     a fraction of `iconSize`.
        ///   - armLengthFraction: The fraction of the decorator canvas used as the
        ///     end-to-end arm length.
        ///   - strokeWidthFraction: The stroke width as a fraction of `iconSize`.
        ///   - minimumStrokeWidth: The minimum stroke width in points.
        ///   - animationDuration: The draw-in animation duration in seconds.
        public init(
            overhangFraction: CGFloat = 0.35,
            armLengthFraction: CGFloat = 0.6,
            strokeWidthFraction: CGFloat = 0.22,
            minimumStrokeWidth: CGFloat = 2.0,
            animationDuration: TimeInterval = 0.22
        ) {
            self.overhangFraction = overhangFraction
            self.armLengthFraction = armLengthFraction
            self.strokeWidthFraction = strokeWidthFraction
            self.minimumStrokeWidth = minimumStrokeWidth
            self.animationDuration = animationDuration
        }
    }

    // MARK: - Properties

    public let base: Base
    public let color: Color
    public let configuration: Configuration

    /// The fraction by which the X arms extend beyond the base icon on each side.
    ///
    /// A value of `0.35` means the X canvas is `iconSize × 1.7` wide and tall,
    /// giving 35% overhang on all sides.
    public var overhangFraction: CGFloat { configuration.overhangFraction }

    @State private var drawProgress: CGFloat = 0

    // MARK: - Initialization

    /// Creates an X mark decorator.
    ///
    /// - Parameters:
    ///   - base: The base icon to decorate.
    ///   - color: The stroke color for the X mark.
    ///   - configuration: Geometry and animation settings for the X mark.
    public init(base: Base, color: Color, configuration: Configuration = Configuration()) {
        self.base = base
        self.color = color
        self.configuration = configuration
    }

    /// Creates an X mark decorator.
    ///
    /// - Parameters:
    ///   - base: The base icon to decorate.
    ///   - color: The stroke color for the X mark.
    ///   - overhangFraction: How much the arms extend beyond the base frame as
    ///     a fraction of `iconSize` (defaults to `0.35`).
    public init(base: Base, color: Color, overhangFraction: CGFloat) {
        self.init(
            base: base,
            color: color,
            configuration: Configuration(overhangFraction: overhangFraction)
        )
    }

    // MARK: - EntryIconView

    public var iconSize: CGFloat { base.iconSize }

    // MARK: - Body

    public var body: some View {
        base
            .overlay(alignment: .center) {
                XMarkShape(armLength: armLength)
                    .trim(from: 0, to: drawProgress)
                    .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                    .frame(width: decoratorSize, height: decoratorSize)
                    .allowsHitTesting(false)
            }
            .frame(width: iconSize, height: iconSize)
            .onAppear {
                withAnimation(.easeOut(duration: configuration.animationDuration)) {
                    drawProgress = 1
                }
            }
    }

    // MARK: - Geometry

    private var decoratorSize: CGFloat {
        iconSize * (1 + 2 * overhangFraction)
    }

    private var armLength: CGFloat {
        decoratorSize * configuration.armLengthFraction
    }

    private var strokeWidth: CGFloat {
        max(configuration.minimumStrokeWidth, iconSize * configuration.strokeWidthFraction)
    }
}

// MARK: - Previews

#Preview("XMarkDecorator — task complete") {
    HStack(spacing: 16) {
        XMarkDecorator(
            base: TaskCircleIcon(color: .green, iconSize: 12),
            color: .green
        )
        XMarkDecorator(
            base: TaskCircleIcon(color: .green, iconSize: 17),
            color: .green
        )
        XMarkDecorator(
            base: TaskCircleIcon(color: .green, iconSize: 22),
            color: .green
        )
        XMarkDecorator(
            base: TaskCircleIcon(color: .green, iconSize: 28),
            color: .green
        )
    }
    .padding()
}

#Preview("XMarkDecorator — past event") {
    XMarkDecorator(
        base: EventCircleIcon(color: .secondary, iconSize: 12),
        color: .secondary
    )
    .padding()
}

#Preview("XMarkDecorator — custom overhang") {
    HStack(spacing: 16) {
        XMarkDecorator(
            base: TaskCircleIcon(color: .green, iconSize: 17),
            color: .green,
            configuration: .init(overhangFraction: 0.1)
        )
        XMarkDecorator(
            base: TaskCircleIcon(color: .green, iconSize: 17),
            color: .green,
            configuration: .init(overhangFraction: 0.25)
        )
        XMarkDecorator(
            base: TaskCircleIcon(color: .green, iconSize: 17),
            color: .green,
            configuration: .init(overhangFraction: 0.5)
        )
    }
    .padding()
}

#Preview("XMarkDecorator — custom stroke") {
    HStack(spacing: 16) {
        XMarkDecorator(
            base: TaskCircleIcon(color: .green, iconSize: 17),
            color: .green
        )
        XMarkDecorator(
            base: TaskCircleIcon(color: .green, iconSize: 17),
            color: .green,
            configuration: .init(strokeWidthFraction: 0.3)
        )
    }
    .padding()
}
