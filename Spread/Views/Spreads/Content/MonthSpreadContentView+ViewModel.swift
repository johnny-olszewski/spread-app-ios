import SwiftUI

extension MonthSpreadContentView {

    /// Owns the content model and entry row configuration map for `MonthSpreadContentView`.
    @Observable @MainActor
    final class ViewModel {
        private(set) var contentModel: MonthSpreadContentModel?
        private(set) var configurationMap: [EntryType: EntryRowView.Configuration] = [:]

        init() {}

        /// Full setup: content model and configuration map.
        /// Called once when the spread-id changes.
        func configure(
            spread: DataModel.Spread,
            spreadDataModel: SpreadDataModel,
            journalManager: JournalManager,
            syncEngine: SyncEngine?,
            coordinator: SpreadsCoordinator
        ) {
            let cal = journalManager.firstWeekday.configuredCalendar(from: journalManager.calendar)
            contentModel = MonthSpreadContentSupport.model(
                for: spread,
                spreadDataModel: spreadDataModel,
                spreads: journalManager.spreads,
                calendar: cal
            )
            configurationMap = [
                .task: .standardTaskConfig(journalManager: journalManager, syncEngine: syncEngine, coordinator: coordinator),
                .note: .standardNoteConfig(journalManager: journalManager, syncEngine: syncEngine, coordinator: coordinator)
            ]
        }

        /// Refreshes the content model when journal data changes.
        func refreshContentModel(
            spread: DataModel.Spread,
            spreadDataModel: SpreadDataModel,
            journalManager: JournalManager
        ) {
            let cal = journalManager.firstWeekday.configuredCalendar(from: journalManager.calendar)
            contentModel = MonthSpreadContentSupport.model(
                for: spread,
                spreadDataModel: spreadDataModel,
                spreads: journalManager.spreads,
                calendar: cal
            )
        }
    }
}
