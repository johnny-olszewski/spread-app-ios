import SwiftUI
import JohnnyOFoundationUI

/// Constructs a composed entry icon view for a given entry type and status.
///
/// This factory is the only place in the app that knows which combination of
/// `EntryIconView` primitives and decorators corresponds to each entry state.
/// Call sites (e.g. `StatusIcon`) remain unaware of the concrete generic types.
@MainActor
enum EntryIconFactory {

    // MARK: - Public

    /// Creates the appropriate icon view for the given entry type and state.
    ///
    /// - Parameters:
    ///   - entryType: The type of journal entry.
    ///   - taskStatus: The task status, if entry type is `.task`.
    ///   - noteStatus: The note status, if entry type is `.note`.
    ///   - isEventPast: Whether the event is in the past, if entry type is `.event`.
    ///   - size: The icon dimension in points (use `EntryIconSize` to convert from `Font.TextStyle`).
    ///   - color: The icon color.
    @ViewBuilder
    static func icon(
        entryType: EntryType,
        taskStatus: DataModel.Task.Status? = nil,
        noteStatus: DataModel.Note.Status? = nil,
        isEventPast: Bool = false,
        size: CGFloat = 12,
        color: Color = .primary
    ) -> some View {
        switch entryType {
        case .task:  taskIcon(status: taskStatus, size: size, color: color)
        case .event: eventIcon(isPast: isEventPast, size: size, color: color)
        case .note:  noteIcon(status: noteStatus, size: size, color: color)
        }
    }

    // MARK: - Private

    @ViewBuilder
    private static func taskIcon(
        status: DataModel.Task.Status?,
        size: CGFloat,
        color: Color
    ) -> some View {
        switch status {
        case .none, .open:
            TaskCircleIcon(color: color, iconSize: size)
        case .complete:
            XMarkDecorator(
                base: TaskCircleIcon(color: color, iconSize: size),
                color: color,
                configuration: .init(strokeWidthFraction: 0.28)
            )
        case .migrated:
            ArrowDecorator(base: TaskCircleIcon(color: color, iconSize: size), color: color)
        case .cancelled:
            SlashDecorator(base: TaskCircleIcon(color: color, iconSize: size), color: color)
        }
    }

    @ViewBuilder
    private static func eventIcon(isPast: Bool, size: CGFloat, color: Color) -> some View {
        if isPast {
            XMarkDecorator(
                base: EventCircleIcon(color: color, iconSize: size),
                color: color,
                configuration: .init(strokeWidthFraction: 0.28)
            )
        } else {
            EventCircleIcon(color: color, iconSize: size)
        }
    }

    @ViewBuilder
    private static func noteIcon(
        status: DataModel.Note.Status?,
        size: CGFloat,
        color: Color
    ) -> some View {
        switch status {
        case .none, .active:
            NoteDashIcon(color: color, iconSize: size)
        case .migrated:
            ArrowDecorator(base: NoteDashIcon(color: color, iconSize: size), color: color)
        }
    }
}
