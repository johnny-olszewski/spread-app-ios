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

    /// A localized accessibility label describing the status in context of the entry type.
    func accessibilityLabel(for entryType: EntryType) -> String {
        switch (entryType, self) {
        case (.task, .open):      return "Open task"
        case (.task, .complete):  return "Complete task"
        case (.task, .migrated):  return "Migrated task"
        case (.task, .cancelled): return "Cancelled task"
        case (.note, .active):    return "Active note"
        case (.note, .migrated):  return "Migrated note"
        case (.event, _):         return "Event"
        default:                  return displayName
        }
    }
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

    var displayName: String {
        switch self {
        case .open:      return "Open"
        case .active:    return "Active"
        case .complete:  return "Complete"
        case .migrated:  return "Migrated"
        case .cancelled: return "Cancelled"
        case .upcoming:  return "Upcoming"
        }
    }

    var statusIconOverlaySymbol: String? {
        switch self {
        case .open, .active, .upcoming: return nil
        case .complete:  return "xmark"
        case .migrated:  return "arrow.right"
        case .cancelled: return "line.diagonal"
        }
    }

    // MARK: Task sheet interaction

    var allowsAssignmentEditingInTaskSheet: Bool { self == .open }

    var canToggleCompletionInTaskSheet: Bool { self == .open || self == .complete }

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

    var lifecycleActionIconInTaskSheet: String? {
        switch self {
        case .open, .complete: return "xmark.circle"
        case .cancelled:       return "arrow.uturn.backward.circle"
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

    var leadingIconAccessibilityLabel: String {
        switch self {
        case .open:      return "Mark complete"
        case .complete:  return "Reopen"
        case .migrated:  return "Migrated task"
        case .cancelled: return "Cancelled task"
        default:         return displayName
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
