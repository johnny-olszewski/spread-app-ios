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
