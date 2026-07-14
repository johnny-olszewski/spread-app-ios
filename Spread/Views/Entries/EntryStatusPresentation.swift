import SwiftUI

// MARK: - Icon Presentation

extension EntryStatus {

    var overlayShape: EntryStatusIcon.OverlayShape? {
        switch self {
        case .open, .active, .upcoming:
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
        case .open, .active, .upcoming: return .primary
        case .complete, .migrated, .cancelled: return .secondary
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
        case .open, .active, .upcoming:
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

    static var userEditableTaskStatuses: [EntryStatus] {
        [.open, .complete, .cancelled]
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
