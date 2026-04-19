import Foundation
import Observation

/// Shell UI state owner for the spreads root view.
///
/// Owns selection, recenter token, and sheet presentation state.
/// Does not absorb journal business logic.
@Observable
@MainActor
final class SpreadsViewModel {

    // MARK: - Sheet Destinations

    struct SpreadCreationPrefill: Equatable {
        let period: Period
        let date: Date
    }

    /// All possible sheet presentations in the spreads view.
    enum SheetDestination: Identifiable {
        case spreadCreation(SpreadCreationPrefill?)
        case spreadNameEdit(DataModel.Spread)
        case taskCreation
        case noteCreation
        case taskDetail(DataModel.Task)
        case noteDetail(DataModel.Note)
        case auth

        var id: String {
            switch self {
            case .spreadCreation(let prefill):
                if let prefill {
                    return "spreadCreation-\(prefill.period.rawValue)-\(prefill.date.timeIntervalSince1970)"
                }
                return "spreadCreation"
            case .spreadNameEdit(let spread):
                return "spreadNameEdit-\(spread.id)"
            case .taskCreation:
                return "taskCreation"
            case .noteCreation:
                return "noteCreation"
            case .taskDetail(let task):
                return "taskDetail-\(task.id)"
            case .noteDetail(let note):
                return "noteDetail-\(note.id)"
            case .auth:
                return "auth"
            }
        }
    }

    // MARK: - Shell State

    /// The current navigator selection, nil until resolved on appear.
    var selectedSelection: SpreadHeaderNavigatorModel.Selection?

    /// Incremented to force the pager and strip to recenter on the current selection.
    var recenterToken: Int = 0

    /// The currently active sheet, or nil if no sheet is presented.
    var activeSheet: SheetDestination?

    // MARK: - Actions

    /// Presents the spread creation sheet.
    func showSpreadCreation(prefill: SpreadCreationPrefill? = nil) {
        activeSheet = .spreadCreation(prefill)
    }

    /// Presents the spread naming editor.
    func showSpreadNameEdit(_ spread: DataModel.Spread) {
        activeSheet = .spreadNameEdit(spread)
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

    /// Presents the auth sheet.
    func showAuth() {
        activeSheet = .auth
    }

    /// Dismisses the currently active sheet.
    func dismiss() {
        activeSheet = nil
    }
}
