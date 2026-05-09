import SwiftUI

/// A decorator that overlays an animated diagonal slash on any `EntryIconView`.
///
/// The slash is drawn slightly larger than the base icon (1.1× `iconSize`) so
/// it visually crosses through the shape. The layout footprint remains
/// `iconSize × iconSize`.
///
/// On appear the slash draws in with an easeOut animation.
///
/// Example:
/// ```swift
/// SlashDecorator(base: TaskCircleIcon(color: .secondary, iconSize: 12), color: .secondary)
/// ```
public struct SlashDecorator<Base: EntryIconView>: EntryIconView {

    // MARK: - Properties

    public let base: Base
    public let color: Color

    @State private var drawProgress: CGFloat = 0

    // MARK: - Initialization

    /// Creates a slash decorator.
    ///
    /// - Parameters:
    ///   - base: The base icon to decorate.
    ///   - color: The stroke color for the slash.
    public init(base: Base, color: Color) {
        self.base = base
        self.color = color
    }

    // MARK: - EntryIconView

    public var iconSize: CGFloat { base.iconSize }

    // MARK: - Body

    public var body: some View {
        base
            .overlay(alignment: .center) {
                SlashShape()
                    .trim(from: 0, to: drawProgress)
                    .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                    .frame(width: canvasSize, height: canvasSize)
                    .allowsHitTesting(false)
            }
            .frame(width: iconSize, height: iconSize)
            .onAppear {
                withAnimation(.easeOut(duration: 0.18)) {
                    drawProgress = 1
                }
            }
    }

    // MARK: - Geometry

    private var canvasSize: CGFloat { iconSize * 1.1 }

    private var strokeWidth: CGFloat { max(1.5, iconSize * 0.13) }
}

// MARK: - Previews

#Preview("SlashDecorator — task cancelled") {
    HStack(spacing: 16) {
        SlashDecorator(
            base: TaskCircleIcon(color: .secondary, iconSize: 12),
            color: .secondary
        )
        SlashDecorator(
            base: TaskCircleIcon(color: .secondary, iconSize: 17),
            color: .secondary
        )
        SlashDecorator(
            base: TaskCircleIcon(color: .secondary, iconSize: 22),
            color: .secondary
        )
    }
    .padding()
}
