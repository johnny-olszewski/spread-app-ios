import Foundation

/// Configuration for the global overdue toolbar button.
struct OverdueButtonConfiguration: Sendable {
    let overdueCount: Int

    var isVisible: Bool {
        overdueCount > 0
    }

    var iconName: String {
        "exclamationmark.circle.fill"
    }

    var accessibilityLabel: String {
        switch overdueCount {
        case ..<1:
            return "Overdue tasks"
        case 1:
            return "Overdue tasks, 1 task"
        default:
            return "Overdue tasks, \(overdueCount) tasks"
        }
    }
}
