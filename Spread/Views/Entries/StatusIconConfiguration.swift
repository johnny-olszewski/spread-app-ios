import SwiftUI

/// Configuration for a status icon that determines symbols and styling.
///
/// Encapsulates the logic for selecting the appropriate SF Symbol based on
/// entry type and task status. This separation enables snapshot-free unit
/// testing of the symbol selection logic.
struct StatusIconConfiguration: Sendable {

    // MARK: - Properties

    /// The type of entry (task, event, or note).
    let entryType: EntryType

    /// The task status, if this is a task entry.
    ///
    /// Only tasks have status overlays. Events and notes ignore this value.
    let taskStatus: DataModel.Task.Status?

    /// The text style size for the icon.
    let size: Font.TextStyle

    // MARK: - Initialization

    /// Creates a status icon configuration.
    ///
    /// - Parameters:
    ///   - entryType: The type of entry.
    ///   - taskStatus: The task status (only used for tasks).
    ///   - size: The text style size (defaults to `.body`).
    init(
        entryType: EntryType,
        taskStatus: DataModel.Task.Status? = nil,
        size: Font.TextStyle = .body
    ) {
        self.entryType = entryType
        self.taskStatus = taskStatus
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

    /// The overlay SF Symbol name for task status, if applicable.
    ///
    /// Returns `nil` for non-task entries or tasks without a status overlay.
    /// - Open: no overlay
    /// - Complete: xmark
    /// - Migrated: arrow.right
    /// - Cancelled: line.diagonal (slash)
    var overlaySymbol: String? {
        guard entryType == .task, let status = taskStatus else {
            return nil
        }

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
    }

    /// The scale factor for the overlay symbol relative to the base symbol.
    ///
    /// The overlay is rendered at half the size of the base symbol.
    var overlayScale: CGFloat {
        0.5
    }
}
