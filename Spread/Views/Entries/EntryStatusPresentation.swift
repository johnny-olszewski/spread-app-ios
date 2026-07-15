import SwiftUI

// MARK: - Icon Presentation

extension EntryStatus {

    var overlayShape: EntryStatusIcon.OverlayShape? {
        switch self {
        case .open, .active, .upcoming, .inFlight:
            return nil
        case .complete:
            return .xmark
        case .migrated:
            return .arrowRight
        case .cancelled:
            return .slash
        }
    }

    var iconColor: Color {
        switch self {
        case .open, .active, .upcoming, .inFlight: return .primary
        case .complete, .migrated, .cancelled: return .secondary
        }
    }

    /// A full-replacement icon for statuses that render as a standalone glyph instead of
    /// the base-shape-plus-overlay composite. Non-nil only for `.inFlight`, which renders
    /// as the Phosphor airplane-tilt icon with no circle beneath and no overlay. [SPRD-316]
    var iconOverride: SpreadTheme.Icon? {
        switch self {
        case .inFlight: return .airplaneTilt
        case .open, .active, .complete, .migrated, .cancelled, .upcoming: return nil
        }
    }
}

extension Entry {

    /// The status icon's effective tint: an entry-specific `iconColor` (e.g. an event's
    /// calendar color) takes precedence over the status's default; once the status is
    /// terminal, an entry-specific tint renders subdued rather than switching to the
    /// status gray, so e.g. a passed event reads as "dimmed" rather than "flagged" like a
    /// cancelled task. Entries with no `iconColor` (tasks, notes) are unaffected either way. [SPRD-315]
    var resolvedIconColor: Color {
        switch status {
        case .open, .active, .upcoming, .inFlight:
            return iconColor ?? status.iconColor
        case .complete, .migrated, .cancelled:
            guard let iconColor else { return status.iconColor }
            return iconColor.opacity(Self.subduedIconOpacity)
        }
    }

    private static var subduedIconOpacity: Double { 0.45 }
}

extension EntryType {
    var statusIconBaseShape: EntryStatusIcon.BaseShape {
        switch self {
        case .task:
            return .filledCircle
        case .event:
            return .emptyCircle
        case .note:
            return .dash
        }
    }
}

// MARK: - Display

extension EntryStatus {

    /// The single source of truth for user-editable task statuses, used by BOTH the row
    /// status-icon tap cycle and the task sheet's Status picker. The order IS the tap-cycle
    /// order: open → inFlight → complete → cancelled → wraps to open. [SPRD-316]
    static var userEditableTaskStatuses: [EntryStatus] {
        [.open, .inFlight, .complete, .cancelled]
    }

    // MARK: Task sheet interaction

    var allowsAssignmentEditingInTaskSheet: Bool { self == .open }

    var toggledCompletionStatusInTaskSheet: Self {
        switch self {
        case .open:     return .complete
        case .complete: return .open
        default:        return self
        }
    }

    var lifecycleActionTitleInTaskSheet: String? {
        switch self {
        case .open, .complete: return "Cancel Task"
        case .cancelled:       return "Restore Task"
        default:               return nil
        }
    }

    var lifecycleActionIconInTaskSheet: SpreadTheme.Icon? {
        switch self {
        case .open, .complete: return .xmarkCircle
        case .cancelled:       return .arrowUTurnLeft
        default:               return nil
        }
    }

    var lifecycleActionRoleInTaskSheet: ButtonRole? {
        switch self {
        case .open, .complete: return .destructive
        default:               return nil
        }
    }

    var lifecycleActionResultInTaskSheet: Self? {
        switch self {
        case .open, .complete: return .cancelled
        case .cancelled:       return .open
        default:               return nil
        }
    }

}

// MARK: - DataModel.Task.Priority

extension DataModel.Task.Priority {
    var displayName: String {
        switch self {
        case .none:   return "None"
        case .low:    return "Low"
        case .medium: return "Medium"
        case .high:   return "High"
        }
    }

    var badgeTitle: String? {
        switch self {
        case .none:   return nil
        case .low:    return "Low"
        case .medium: return "Medium"
        case .high:   return "High"
        }
    }

    var badgeColor: Color {
        switch self {
        case .none:   return .secondary
        case .low:    return .blue
        case .medium: return .orange
        case .high:   return .red
        }
    }
}
