import SwiftUI

extension DataModel.Task.Status {

    static var userEditableTaskStatuses: [Self] {
        [.open, .complete, .cancelled]
    }

    var displayName: String {
        switch self {
        case .open:
            return "Open"
        case .complete:
            return "Complete"
        case .migrated:
            return "Migrated"
        case .cancelled:
            return "Cancelled"
        }
    }

    var statusIconOverlaySymbol: String? {
        switch self {
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

    var statusIconColor: Color {
        switch self {
        case .open:
            return .primary
        case .complete:
            return .green
        case .migrated:
            return .orange
        case .cancelled:
            return .secondary
        }
    }

    var allowsAssignmentEditingInTaskSheet: Bool {
        self == .open
    }

    var canToggleCompletionInTaskSheet: Bool {
        self == .open || self == .complete
    }

    var toggledCompletionStatusInTaskSheet: Self {
        switch self {
        case .open:
            return .complete
        case .complete:
            return .open
        case .migrated, .cancelled:
            return self
        }
    }

    var lifecycleActionTitleInTaskSheet: String? {
        switch self {
        case .open, .complete:
            return "Cancel Task"
        case .cancelled:
            return "Restore Task"
        case .migrated:
            return nil
        }
    }

    var lifecycleActionIconInTaskSheet: String? {
        switch self {
        case .open, .complete:
            return "xmark.circle"
        case .cancelled:
            return "arrow.uturn.backward.circle"
        case .migrated:
            return nil
        }
    }

    var lifecycleActionRoleInTaskSheet: ButtonRole? {
        switch self {
        case .open, .complete:
            return .destructive
        case .cancelled, .migrated:
            return nil
        }
    }

    var lifecycleActionResultInTaskSheet: Self? {
        switch self {
        case .open, .complete:
            return .cancelled
        case .cancelled:
            return .open
        case .migrated:
            return nil
        }
    }
}

extension DataModel.Task.Priority {
    var displayName: String {
        switch self {
        case .none:
            return "None"
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        }
    }

    var badgeTitle: String? {
        switch self {
        case .none:
            return nil
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        }
    }

    var badgeColor: Color {
        switch self {
        case .none:
            return .secondary
        case .low:
            return .blue
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }
}

extension DataModel.Note.Status {
    var displayName: String {
        switch self {
        case .active:
            return "Active"
        case .migrated:
            return "Migrated"
        }
    }

    var statusIconOverlaySymbol: String? {
        switch self {
        case .active:
            return nil
        case .migrated:
            return "arrow.right"
        }
    }
}
