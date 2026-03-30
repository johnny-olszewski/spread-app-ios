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

    // MARK: - Sheet Destinations

    /// All possible sheet presentations in the spreads view.
    enum SheetDestination: Identifiable {
        case spreadCreation
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
            case .spreadCreation: "spreadCreation"
            case .taskCreation: "taskCreation"
            case .noteCreation: "noteCreation"
            case .taskDetail(let task): "taskDetail-\(task.id)"
            case .noteDetail(let note): "noteDetail-\(note.id)"
            case .inbox: "inbox"
            case .auth: "auth"
            case .migrationSelection: "migrationSelection"
            case .overdueReview: "overdueReview"
            }
        }
    }

    // MARK: - Properties

    /// The currently active sheet, or `nil` if no sheet is presented.
    var activeSheet: SheetDestination?

    // MARK: - Actions

    /// Presents the spread creation sheet.
    func showSpreadCreation() {
        activeSheet = .spreadCreation
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
