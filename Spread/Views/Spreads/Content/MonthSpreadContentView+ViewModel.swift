import SwiftUI

extension MonthSpreadContentView {

    /// Owns the content model for `MonthSpreadContentView`.
    @Observable @MainActor
    final class ViewModel {
        private(set) var contentModel: MonthSpreadContentModel?

        init() {}

        /// Builds the content model. Called once when the spread-id changes.
        func configure(
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
