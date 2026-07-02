import Foundation
import SwiftUI

extension DataModel.Task.Priority {
    /// The icon representing this priority level, or `nil` for `.none`.
    var icon: SpreadTheme.Icon? {
        switch self {
        case .none: nil
        case .high: .caretDoubleUp
        case .medium: .caretUp
        case .low: .caretDoubleDown
        }
    }

    /// The tint color for the priority icon, or `nil` for `.none`.
    var iconColor: Color? {
        switch self {
        case .none: nil
        case .high: .red
        case .medium: .yellow
        case .low: .green
        }
    }
}

extension DataModel.Task {
    /// Trimmed body text, or nil if empty. Used for row preview rendering.
    var bodyPreview: String? {
        guard let body = body?.trimmingCharacters(in: .whitespacesAndNewlines),
              !body.isEmpty else {
            return nil
        }
        return body
    }

    /// Formatted "Due MMM d" label, or nil if no due date is set.
    func dueDateLabel(calendar: Calendar) -> String? {
        guard let dueDate else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return "Due \(formatter.string(from: dueDate))"
    }

    /// Whether the due date should be visually highlighted (open task with due date on or before today).
    func isDueDateHighlighted(today: Date, calendar: Calendar) -> Bool {
        guard status == .open, let dueDate else { return false }
        return dueDate.startOfDay(calendar: calendar) <= today.startOfDay(calendar: calendar)
    }

    // MARK: - Entry display protocol requirements

    var displayBodyPreview: String? { bodyPreview }
    var displayPriority: DataModel.Task.Priority { priority }
}
