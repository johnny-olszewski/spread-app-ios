import SwiftUI

/// Configuration for a status icon that determines symbols and styling.
///
/// Encapsulates the logic for selecting the appropriate SF Symbol based on
/// entry type, status, and context. This separation enables snapshot-free unit
/// testing of the symbol selection logic.
struct StatusIconConfiguration: Sendable {

    // MARK: - Properties

    /// The type of entry (task, event, or note).
    let entryType: EntryType

    /// The task status, if this is a task entry.
    ///
    /// Only tasks use this value for overlay selection.
    let taskStatus: DataModel.Task.Status?

    /// The note status, if this is a note entry.
    ///
    /// Notes with `.migrated` status show an arrow overlay.
    let noteStatus: DataModel.Note.Status?

    /// Whether the event is past (only used for events).
    ///
    /// Past events show an X overlay on the empty circle.
    let isEventPast: Bool

    /// The text style size for the icon.
    let size: Font.TextStyle

    // MARK: - Initialization

    /// Creates a status icon configuration.
    ///
    /// - Parameters:
    ///   - entryType: The type of entry.
    ///   - taskStatus: The task status (only used for tasks).
    ///   - noteStatus: The note status (only used for notes).
    ///   - isEventPast: Whether the event is past (only used for events).
    ///   - size: The text style size (defaults to `.body`).
    init(
        entryType: EntryType,
        taskStatus: DataModel.Task.Status? = nil,
        noteStatus: DataModel.Note.Status? = nil,
        isEventPast: Bool = false,
        size: Font.TextStyle = .body
    ) {
        self.entryType = entryType
        self.taskStatus = taskStatus
        self.noteStatus = noteStatus
        self.isEventPast = isEventPast
        self.size = size
    }

    // MARK: - Symbol Selection

    /// The base SF Symbol name for this entry type.
    ///
    /// - Task: solid circle (●) - "circle.fill"
    /// - Event: empty circle (○) - "circle"
    /// - Note: dash (—) - "minus"
    var baseSymbol: String {
        entryType.imageName
    }

    /// The overlay SF Symbol name based on entry type and status.
    ///
    /// Task overlays:
    /// - Open: no overlay
    /// - Complete: xmark
    /// - Migrated: arrow.right
    /// - Cancelled: line.diagonal (slash)
    ///
    /// Note overlays:
    /// - Active: no overlay
    /// - Migrated: arrow.right
    ///
    /// Event overlays:
    /// - Current: no overlay
    /// - Past: xmark
    var overlaySymbol: String? {
        switch entryType {
        case .task:
            guard let status = taskStatus else { return nil }
            switch status {
            case .open:
                return nil
            case .complete:
                return "xmark"
            case .migrated:
                return "arrow.right"
            case .cancelled:
                return "line.diagonal"
            }

        case .note:
            guard let status = noteStatus else { return nil }
            switch status {
            case .active:
                return nil
            case .migrated:
                return "arrow.right"
            }

        case .event:
            return isEventPast ? "xmark" : nil
        }
    }

    /// The scale factor for the overlay symbol relative to the base symbol.
    ///
    /// The overlay is rendered at half the size of the base symbol.
    var overlayScale: CGFloat {
        0.5
    }
}
