import Foundation

extension JournalManager {

    /// The default navigation selection for the current mode and today's date.
    ///
    /// Used as the initial selection on first appear and as a fallback when the
    /// currently-selected spread is deleted. Always returns a valid selection:
    /// - Conventional: best spread for today, or first spread, or a synthetic year spread
    /// - Traditional: the year page containing today
    var defaultNavigationSelection: SpreadHeaderNavigatorModel.Selection {
        switch bujoMode {
        case .conventional:
            let spread = bestSpread(for: today)
                ?? spreads.first
                ?? DataModel.Spread(period: .year, date: today, calendar: calendar)
            return .conventional(spread)
        case .traditional:
            let year = calendar.component(.year, from: today)
            let date = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
            return .traditionalYear(date)
        }
    }

    /// The navigation selection that corresponds to today, used by the "Today" toolbar button.
    ///
    /// Returns `nil` in conventional mode when no spread contains today — callers should
    /// skip navigation rather than landing on an unrelated spread.
    /// Always returns a selection in traditional mode.
    var todayNavigationSelection: SpreadHeaderNavigatorModel.Selection? {
        switch bujoMode {
        case .conventional:
            return bestSpread(for: today).map { .conventional($0) }
        case .traditional:
            return .traditionalDay(Period.day.normalizeDate(today, calendar: calendar))
        }
    }
}
