import Foundation
import Observation

/// Shell UI state owner for the spreads root view.
///
/// Owns selection, recenter token, and sheet presentation state.
/// Does not absorb journal business logic.
@Observable
@MainActor
final class SpreadsCoordinator {

    // MARK: - Sheet Destinations

    struct SpreadCreationPrefill: Equatable {
        let period: Period
        let date: Date
    }

    /// All possible sheet presentations in the spreads view.
    enum SheetDestination: Identifiable {
        case spreadCreation(SpreadCreationPrefill?)
        case spreadNameEdit(DataModel.Spread)
        case spreadDateEdit(DataModel.Spread)
        case taskCreation
        case noteCreation
        case taskDetail(DataModel.Task)
        case noteDetail(DataModel.Note)
        case peekData(SpreadPeekPanelView.Data)
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
            case .spreadDateEdit(let spread):
                return "spreadDateEdit-\(spread.id)"
            case .taskCreation:
                return "taskCreation"
            case .noteCreation:
                return "noteCreation"
            case .taskDetail(let task):
                return "taskDetail-\(task.id)"
            case .noteDetail(let note):
                return "noteDetail-\(note.id)"
            case .peekData(let data):
                return "peekData-\(data.id)"
            case .auth:
                return "auth"
            }
        }
    }

    /// All possible alert presentations in the spreads view.
    enum AlertDestination: Identifiable {
        case deleteSpreadConfirmation(DataModel.Spread)
        case deleteSpreadFailed(message: String)

        var id: String {
            switch self {
            case .deleteSpreadConfirmation(let spread):
                return "deleteSpreadConfirmation-\(spread.id)"
            case .deleteSpreadFailed:
                return "deleteSpreadFailed"
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

    /// The currently active alert, or nil if no alert is presented.
    var activeAlert: AlertDestination?

    /// State for the convenience navigation button in `SpreadHeaderView`.
    /// Non-nil means the button is visible. `.offer` fades after a timeout if not tapped.
    var convenienceNavigation: ConvenienceNavigationButtonState?

    private var convenienceNavigationFadeTask: Task<Void, Never>?

    // MARK: - Actions

    /// Presents the spread creation sheet.
    func showSpreadCreation(prefill: SpreadCreationPrefill? = nil) {
        activeSheet = .spreadCreation(prefill)
    }

    /// Presents the spread naming editor.
    func showSpreadNameEdit(_ spread: DataModel.Spread) {
        activeSheet = .spreadNameEdit(spread)
    }

    /// Presents the multiday spread date-range editor.
    func showSpreadDateEdit(_ spread: DataModel.Spread) {
        activeSheet = .spreadDateEdit(spread)
    }

    /// Updates selection after a multiday date edit and asks navigator/pager surfaces to recenter.
    func finishSpreadDateEdit(_ spread: DataModel.Spread) {
        selectedSelection = .conventional(spread)
        recenterToken += 1
    }

    /// Shows a convenience navigation button for the newly created spread without auto-navigating.
    ///
    /// The button label reflects whether tasks were auto-migrated or the spread was simply created.
    /// If the current selection is not a conventional spread, falls back to direct navigation.
    func finishSpreadCreation(
        _ result: SpreadCreationOperationResult,
        currentSelection: SpreadHeaderNavigatorModel.Selection,
        calendar: Calendar
    ) {
        guard let source = conventionalSpread(from: currentSelection) else {
            selectedSelection = .conventional(result.spread)
            recenterToken += 1
            return
        }

        let label: String
        if let summary = result.autoMigrationSummary, summary.totalCount > 0 {
            label = summary.message
        } else {
            label = "New spread created"
        }

        convenienceNavigation = .offer(label: label, destination: result.spread, source: source)
        startConvenienceNavigationFade()
    }

    /// Presents spread deletion confirmation for a conventional explicit spread.
    func showSpreadDeleteConfirmation(_ spread: DataModel.Spread) {
        activeAlert = .deleteSpreadConfirmation(spread)
    }

    /// Presents a spread deletion failure alert.
    func showSpreadDeleteFailure(message: String) {
        activeAlert = .deleteSpreadFailed(message: message)
    }

    /// Presents the task creation sheet.
    func showTaskCreation() {
        activeSheet = .taskCreation
    }

    /// Presents the note creation sheet.
    func showNoteCreation() {
        activeSheet = .noteCreation
    }

    /// Navigates to `destination` and records `source` as the navigation origin,
    /// enabling the "Go Back" button in `SpreadHeaderView`.
    func navigateViaPeek(to destination: DataModel.Spread, from source: DataModel.Spread) {
        selectedSelection = .conventional(destination)
        recenterToken += 1
        // Cancel any active fade — go-back state does not fade
        convenienceNavigationFadeTask?.cancel()
        convenienceNavigationFadeTask = nil
        convenienceNavigation = .goBack(source: source)
    }

    /// Clears the convenience navigation button state.
    func clearConvenienceNavigation() {
        convenienceNavigationFadeTask?.cancel()
        convenienceNavigationFadeTask = nil
        convenienceNavigation = nil
    }

    /// Navigates to a conventional spread and clears any active convenience navigation.
    func selectSpread(_ spread: DataModel.Spread) {
        selectedSelection = .conventional(spread)
        clearConvenienceNavigation()
    }

    /// Navigates to the given selection, clearing convenience navigation and recentering.
    ///
    /// If the selection is already active, only recenters (increments `recenterToken`) without
    /// changing `selectedSelection`. If it differs, updates `selectedSelection` and recenters.
    func navigate(to selection: SpreadHeaderNavigatorModel.Selection) {
        clearConvenienceNavigation()
        if isSameSelection(selection, selectedSelection) {
            recenterToken += 1
        } else {
            selectedSelection = selection
            recenterToken += 1
        }
    }

    /// Handles a tap on the convenience navigation button.
    ///
    /// - `.offer`: navigates to the destination and transitions the button to `.goBack`.
    /// - `.goBack`: navigates to the source and clears the button.
    func handleConvenienceNavButtonTapped() {
        switch convenienceNavigation {
        case .offer(_, let destination, let source):
            convenienceNavigationFadeTask?.cancel()
            convenienceNavigationFadeTask = nil
            selectedSelection = .conventional(destination)
            recenterToken += 1
            convenienceNavigation = .goBack(source: source)
        case .goBack(let source):
            convenienceNavigation = nil
            selectedSelection = .conventional(source)
            recenterToken += 1
        case nil:
            break
        }
    }

    /// Presents the task detail sheet for editing.
    func showTaskDetail(_ task: DataModel.Task) {
        activeSheet = .taskDetail(task)
    }

    /// Presents the note detail sheet for editing.
    func showNoteDetail(_ note: DataModel.Note) {
        activeSheet = .noteDetail(note)
    }

    /// Presents the spread peek panel sheet.
    func showSpreadPeek(_ data: SpreadPeekPanelView.Data) {
        activeSheet = .peekData(data)
    }

    /// Presents the auth sheet.
    func showAuth() {
        activeSheet = .auth
    }

    /// Dismisses the currently active sheet.
    func dismiss() {
        activeSheet = nil
    }

    /// Dismisses the currently active alert.
    func dismissAlert() {
        activeAlert = nil
    }

    // MARK: - Private

    private func isSameSelection(
        _ lhs: SpreadHeaderNavigatorModel.Selection,
        _ rhs: SpreadHeaderNavigatorModel.Selection?
    ) -> Bool {
        guard let rhs else { return false }
        switch (lhs, rhs) {
        case (.conventional(let a), .conventional(let b)): return a.id == b.id
        case (.traditionalYear(let a), .traditionalYear(let b)): return a == b
        case (.traditionalMonth(let a), .traditionalMonth(let b)): return a == b
        case (.traditionalDay(let a), .traditionalDay(let b)): return a == b
        default: return false
        }
    }

    private func conventionalSpread(from selection: SpreadHeaderNavigatorModel.Selection) -> DataModel.Spread? {
        guard case .conventional(let spread) = selection else { return nil }
        return spread
    }

    private func startConvenienceNavigationFade() {
        convenienceNavigationFadeTask?.cancel()
        convenienceNavigationFadeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            if case .offer = self?.convenienceNavigation {
                self?.convenienceNavigation = nil
            }
            self?.convenienceNavigationFadeTask = nil
        }
    }
}
