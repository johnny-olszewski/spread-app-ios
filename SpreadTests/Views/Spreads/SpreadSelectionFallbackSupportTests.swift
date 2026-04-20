import Foundation
import Testing
@testable import Spread

struct SpreadSelectionFallbackSupportTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int = 1) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// Conditions: The selected conventional spread was deleted and another spread still contains today.
    /// Expected: The fallback selection moves to the best today-based spread.
    @Test func replacementSelectionUsesTodayFallbackWhenDeletedSelectionIsGone() {
        let today = date(2026, 4, 15)
        let deletedSpread = DataModel.Spread(period: .day, date: today, calendar: calendar)
        let monthSpread = DataModel.Spread(period: .month, date: today, calendar: calendar)

        let replacement = SpreadSelectionFallbackSupport.replacementSelection(
            currentSelection: .conventional(deletedSpread),
            spreads: [monthSpread],
            calendar: calendar,
            today: today
        )

        guard case .conventional(let selectedSpread) = replacement else {
            Issue.record("Expected conventional replacement selection")
            return
        }
        #expect(selectedSpread.id == monthSpread.id)
    }

    /// Conditions: The selected conventional spread was deleted and no remaining spread contains today.
    /// Expected: The fallback selection still moves to an existing spread instead of leaving a stale selection.
    @Test func replacementSelectionUsesFirstSpreadWhenNoTodayFallbackExists() {
        let today = date(2026, 4, 15)
        let deletedSpread = DataModel.Spread(period: .day, date: today, calendar: calendar)
        let remainingSpread = DataModel.Spread(period: .month, date: date(2026, 2), calendar: calendar)

        let replacement = SpreadSelectionFallbackSupport.replacementSelection(
            currentSelection: .conventional(deletedSpread),
            spreads: [remainingSpread],
            calendar: calendar,
            today: today
        )

        guard case .conventional(let selectedSpread) = replacement else {
            Issue.record("Expected conventional replacement selection")
            return
        }
        #expect(selectedSpread.id == remainingSpread.id)
    }

    /// Conditions: The selected conventional spread still exists after a data refresh.
    /// Expected: The current selection is preserved.
    @Test func replacementSelectionKeepsExistingSelectionWhenStillAvailable() {
        let today = date(2026, 4, 15)
        let currentSpread = DataModel.Spread(period: .day, date: today, calendar: calendar)

        let replacement = SpreadSelectionFallbackSupport.replacementSelection(
            currentSelection: .conventional(currentSpread),
            spreads: [currentSpread],
            calendar: calendar,
            today: today
        )

        guard case .conventional(let selectedSpread) = replacement else {
            Issue.record("Expected conventional replacement selection")
            return
        }
        #expect(selectedSpread.id == currentSpread.id)
    }

    /// Conditions: The selected conventional spread was deleted and no spreads remain.
    /// Expected: The explicit selection clears so the view can fall back to its empty-state default.
    @Test func replacementSelectionClearsWhenNoSpreadsRemain() {
        let today = date(2026, 4, 15)
        let deletedSpread = DataModel.Spread(period: .day, date: today, calendar: calendar)

        let replacement = SpreadSelectionFallbackSupport.replacementSelection(
            currentSelection: .conventional(deletedSpread),
            spreads: [],
            calendar: calendar,
            today: today
        )

        if case .some = replacement {
            Issue.record("Expected selection to clear when no spreads remain")
        }
    }
}
