import Foundation

extension EntryRowConfiguration {

    /// Combined accessibility label for the row: "Title, Type, Status".
    var accessibilityLabel: String {
        let typeName: String
        switch entryType {
        case .task: typeName = "Task"
        case .note: typeName = "Note"
        case .event: typeName = "Event"
        }

        var parts = [title, typeName]

        if let status = taskStatus {
            parts.append(status.displayName)
        } else if let status = noteStatus {
            parts.append(status.displayName)
        }

        return parts.joined(separator: ", ")
    }

    /// Accessibility value describing priority and due date when set.
    var accessibilityValue: String? {
        var parts: [String] = []

        if taskPriority != .none, let badge = taskPriority.badgeTitle {
            parts.append("\(badge) priority")
        }

        if let dueDate = taskDueDateLabel {
            parts.append("Due \(dueDate)")
        }

        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}
