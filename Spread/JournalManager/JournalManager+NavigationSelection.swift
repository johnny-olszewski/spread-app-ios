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

    /// The navigation selection that corresponds to today, used by the "Today" toolbar button.
    ///
    /// Returns `nil` when no spread contains today — callers should skip navigation rather
    /// than landing on an unrelated spread.
    var todayNavigationSelection: DataModel.Spread? {
        bestSpread(for: today)
    }
}
