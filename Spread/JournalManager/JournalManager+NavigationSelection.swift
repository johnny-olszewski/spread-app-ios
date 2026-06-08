import Foundation

extension JournalManager {

    /// The default navigation selection for today's date.
    ///
    /// Used as the initial selection on first appear and as a fallback when the
    /// currently-selected spread is deleted. Always returns a valid selection.
    var defaultNavigationSelection: DataModel.Spread {
        bestSpread(for: today)
            ?? spreads.first
            ?? DataModel.Spread(period: .year, date: today, calendar: calendar)
    }
}
