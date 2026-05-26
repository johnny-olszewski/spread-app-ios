import Foundation

/// A section in the task browser list view.
struct TaskBrowserSection: Identifiable {

    /// Distinguishes lifecycle sections. Open tasks are split into subsections by assignment.
    enum Kind {
        /// Open tasks with no preferred assignment.
        case inbox
        /// Open tasks assigned to a specific date and period.
        case dated(Date, Period)
        /// Completed or cancelled tasks.
        case terminal
    }

    let kind: Kind
    /// Display title pre-computed by `TaskBrowserSectionBuilder`.
    let title: String
    let rows: [TaskBrowserRow]

    var id: String {
        switch kind {
        case .inbox: "inbox"
        case let .dated(date, period): "\(date.timeIntervalSinceReferenceDate)-\(period.rawValue)"
        case .terminal: "terminal"
        }
    }
}

/// A single row in the task browser.
struct TaskBrowserRow: Identifiable {
    let task: DataModel.Task

    var id: UUID { task.id }
}
