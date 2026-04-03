import Foundation
import Observation

/// Coordinates sheet presentation for `ConventionalSpreadsView`.
///
/// Owns a single `activeSheet` enum instead of multiple booleans,
/// guaranteeing only one sheet is presented at a time. Child views
/// call action methods to trigger presentation.
@Observable
@MainActor
final class SpreadsCoordinator {
    struct SpreadCreationPrefill: Equatable {
        let period: Period
        let date: Date
    }

    // MARK: - Sheet Destinations

    /// All possible sheet presentations in the spreads view.
    enum SheetDestination: Identifiable {
        case spreadCreation(SpreadCreationPrefill?)
        case taskCreation
        case noteCreation
        case taskDetail(DataModel.Task)
        case noteDetail(DataModel.Note)
        case inbox
        case auth
        case migrationSelection
        case overdueReview

        var id: String {
            switch self {
            case .spreadCreation(let prefill):
                if let prefill {
                    return "spreadCreation-\(prefill.period.rawValue)-\(prefill.date.timeIntervalSince1970)"
                }
                return "spreadCreation"
            case .taskCreation:
                return "taskCreation"
            case .noteCreation:
                return "noteCreation"
            case .taskDetail(let task):
                return "taskDetail-\(task.id)"
            case .noteDetail(let note):
                return "noteDetail-\(note.id)"
            case .inbox:
                return "inbox"
            case .auth:
                return "auth"
            case .migrationSelection:
                return "migrationSelection"
            case .overdueReview:
                return "overdueReview"
            }
        }
    }

    // MARK: - Properties

    /// The currently active sheet, or `nil` if no sheet is presented.
    var activeSheet: SheetDestination?

    // MARK: - Actions

    /// Presents the spread creation sheet.
    func showSpreadCreation(prefill: SpreadCreationPrefill? = nil) {
        activeSheet = .spreadCreation(prefill)
    }

    /// Presents the task creation sheet.
    func showTaskCreation() {
        activeSheet = .taskCreation
    }

    /// Presents the note creation sheet.
    func showNoteCreation() {
        activeSheet = .noteCreation
    }

    /// Presents the task detail sheet for editing.
    func showTaskDetail(_ task: DataModel.Task) {
        activeSheet = .taskDetail(task)
    }

    /// Presents the note detail sheet for editing.
    func showNoteDetail(_ note: DataModel.Note) {
        activeSheet = .noteDetail(note)
    }

    /// Presents the inbox sheet.
    func showInbox() {
        activeSheet = .inbox
    }

    /// Presents the auth sheet (login or profile).
    func showAuth() {
        activeSheet = .auth
    }

    /// Presents the migration selection sheet.
    func showMigrationSelection() {
        activeSheet = .migrationSelection
    }

    /// Presents the overdue review sheet.
    func showOverdueReview() {
        activeSheet = .overdueReview
    }

    /// Dismisses the currently active sheet.
    func dismiss() {
        activeSheet = nil
    }
}
