import SwiftUI
import JohnnyOFoundationUI

/// Constructs a composed entry icon view for a given entry status.
///
/// This factory is the only place in the app that knows which combination of
/// `EntryIconView` primitives and decorators corresponds to each entry state.
/// Call sites (e.g. `EntryStatusIcon`) remain unaware of the concrete generic types.
@MainActor
enum EntryIconFactory {

    // MARK: - Public

    /// Creates the appropriate icon view for the given status.
    ///
    /// The base shape and overlay are read from the `EntryStatusButtonRepresentable`
    /// conformance, eliminating the need for entry-type branching at call sites.
    ///
    /// - Parameters:
    ///   - status: A value conforming to `EntryStatusButtonRepresentable`.
    ///   - size: The icon dimension in points (use `EntryIconSize` to convert from `Font.TextStyle`).
    ///   - color: The icon color.
    @ViewBuilder
    static func icon(
        status: any EntryStatusButtonRepresentable,
        size: CGFloat = 12,
        color: Color = .primary
    ) -> some View {
        switch (status.iconBaseShape, status.iconOverlay) {
        case (.filledCircle, nil):
            TaskCircleIcon(color: color, iconSize: size)
        case (.filledCircle, .xmark?):
            XMarkDecorator(
                base: TaskCircleIcon(color: color, iconSize: size),
                color: color,
                configuration: .init(strokeWidthFraction: 0.28)
            )
        case (.filledCircle, .arrowRight?):
            ArrowDecorator(base: TaskCircleIcon(color: color, iconSize: size), color: color)
        case (.filledCircle, .slash?):
            SlashDecorator(base: TaskCircleIcon(color: color, iconSize: size), color: color)
        case (.emptyCircle, nil):
            EventCircleIcon(color: color, iconSize: size)
        case (.emptyCircle, .xmark?):
            XMarkDecorator(
                base: EventCircleIcon(color: color, iconSize: size),
                color: color,
                configuration: .init(strokeWidthFraction: 0.28)
            )
        case (.emptyCircle, .arrowRight?):
            ArrowDecorator(base: EventCircleIcon(color: color, iconSize: size), color: color)
        case (.emptyCircle, .slash?):
            SlashDecorator(base: EventCircleIcon(color: color, iconSize: size), color: color)
        case (.dash, nil):
            NoteDashIcon(color: color, iconSize: size)
        case (.dash, .xmark?):
            XMarkDecorator(
                base: NoteDashIcon(color: color, iconSize: size),
                color: color,
                configuration: .init(strokeWidthFraction: 0.28)
            )
        case (.dash, .arrowRight?):
            ArrowDecorator(base: NoteDashIcon(color: color, iconSize: size), color: color)
        case (.dash, .slash?):
            SlashDecorator(base: NoteDashIcon(color: color, iconSize: size), color: color)
        }
    }
}
