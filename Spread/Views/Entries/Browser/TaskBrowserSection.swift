import Foundation

/// A section in the task browser list view.
struct TaskBrowserSection: Identifiable {

    /// Distinguishes the two lifecycle sections.
    enum Kind: String {
        case open
        case terminal
    }

    let kind: Kind
    let rows: [TaskBrowserRow]

    var id: String { kind.rawValue }

    var title: String {
        switch kind {
        case .open: "Open"
        case .terminal: "Completed / Cancelled"
        }
    }
}

/// A single row in the task browser.
struct TaskBrowserRow: Identifiable {
    let task: DataModel.Task

    var id: UUID { task.id }
}
