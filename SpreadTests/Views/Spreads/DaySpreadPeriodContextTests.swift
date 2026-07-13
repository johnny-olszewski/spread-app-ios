import Foundation
import Testing
@testable import Spread

/// Tests for SPRD-309: the containing-period open-task card sections rendered below a day
/// spread's own entry list — multiday containment scan, open-only filtering, per-period
/// ordering, omission of empty spreads, and sort-option application inside cards.
/// See `Documentation/Specs/DaySpreadComposition.md` — Containing-period open tasks.
@Suite("Day Spread Period Context Tests")
@MainActor
struct DaySpreadPeriodContextTests {

    // MARK: - Test Helpers

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    // MARK: - Multiday containment scan

    /// Conditions: A spread list holding a multiday spread containing the day, a multiday
    /// spread not containing it, a later-starting multiday spread also containing it, and
    /// non-multiday spreads.
    /// Expected: Only the two containing multiday spreads are returned, earliest-starting
    /// first; the range end day is inclusive.
    @Test("Containing multiday scan returns covering spreads earliest first")
    func containingMultidayScan() {
        let day = makeDate(year: 2026, month: 7, day: 10)
        let covering = DataModel.Spread(
            startDate: makeDate(year: 2026, month: 7, day: 6),
            endDate: makeDate(year: 2026, month: 7, day: 12),
            calendar: calendar
        )
        let coveringLater = DataModel.Spread(
            startDate: makeDate(year: 2026, month: 7, day: 10),
            endDate: makeDate(year: 2026, month: 7, day: 10),
            calendar: calendar
        )
        let notCovering = DataModel.Spread(
            startDate: makeDate(year: 2026, month: 7, day: 1),
            endDate: makeDate(year: 2026, month: 7, day: 9),
            calendar: calendar
        )
        let month = DataModel.Spread(period: .month, date: day, calendar: calendar)
        let daySpread = DataModel.Spread(period: .day, date: day, calendar: calendar)

        let result = DaySpreadContentView.ViewModel.containingMultidaySpreads(
            for: day,
            in: [notCovering, coveringLater, month, covering, daySpread],
            calendar: calendar
        )

        #expect(result.map(\.id) == [covering.id, coveringLater.id])
    }

    /// Conditions: A multiday spread whose range ends the day before the target day.
    /// Expected: Not returned — containment is inclusive of the end day, exclusive beyond it.
    @Test("Multiday range end is inclusive and days after it are excluded")
    func multidayEndBoundary() {
        let endDay = makeDate(year: 2026, month: 7, day: 9)
        let spread = DataModel.Spread(
            startDate: makeDate(year: 2026, month: 7, day: 6),
            endDate: endDay,
            calendar: calendar
        )

        let onEnd = DaySpreadContentView.ViewModel.containingMultidaySpreads(
            for: endDay, in: [spread], calendar: calendar
        )
        let afterEnd = DaySpreadContentView.ViewModel.containingMultidaySpreads(
            for: makeDate(year: 2026, month: 7, day: 10), in: [spread], calendar: calendar
        )

        #expect(onEnd.map(\.id) == [spread.id])
        #expect(afterEnd.isEmpty)
    }

    // MARK: - Card section building

    /// Conditions: A month data model holding an open task, a completed task, a cancelled
    /// task, and a note.
    /// Expected: One card section containing only the open task, titled via the display
    /// name closure, with the `.card` style and the spread's period/date as creation context.
    @Test("Cards hold only open tasks and carry card style")
    func cardsHoldOnlyOpenTasks() {
        let day = makeDate(year: 2026, month: 7, day: 10)
        let monthSpread = DataModel.Spread(period: .month, date: day, calendar: calendar)
        let dataModel = SpreadDataModel(
            spread: monthSpread,
            tasks: [
                DataModel.Task(title: "Open", date: day, period: .month, status: .open),
                DataModel.Task(title: "Done", date: day, period: .month, status: .complete),
                DataModel.Task(title: "Dropped", date: day, period: .month, status: .cancelled)
            ],
            notes: [DataModel.Note(title: "Note", date: day)],
            events: []
        )

        let sections = DaySpreadContentView.ViewModel.makeContainingPeriodSections(
            from: [dataModel],
            orderedBy: .default,
            displayName: { _ in "July 2026" }
        )

        #expect(sections.count == 1)
        #expect(sections[0].title == "July 2026")
        #expect(sections[0].entries.map(\.title) == ["Open"])
        #expect(sections[0].style != nil)
        #expect(sections[0].creationPeriod == .month)
    }

    /// Conditions: Three data models (multiday, month, year) passed in nearest-horizon
    /// order; the month one has no open tasks.
    /// Expected: Two sections in the caller's order (multiday, then year) — the taskless
    /// month spread produces no card.
    @Test("Empty spreads produce no card and caller order is preserved")
    func emptySpreadsOmittedAndOrderPreserved() {
        let day = makeDate(year: 2026, month: 7, day: 10)
        let multiday = DataModel.Spread(
            startDate: makeDate(year: 2026, month: 7, day: 6),
            endDate: makeDate(year: 2026, month: 7, day: 12),
            calendar: calendar
        )
        let month = DataModel.Spread(period: .month, date: day, calendar: calendar)
        let year = DataModel.Spread(period: .year, date: day, calendar: calendar)

        let dataModels = [
            SpreadDataModel(
                spread: multiday,
                tasks: [DataModel.Task(title: "Week task", date: day, period: .multiday, status: .open)],
                notes: [],
                events: []
            ),
            SpreadDataModel(
                spread: month,
                tasks: [DataModel.Task(title: "Done", date: day, period: .month, status: .complete)],
                notes: [],
                events: []
            ),
            SpreadDataModel(
                spread: year,
                tasks: [DataModel.Task(title: "Year task", date: day, period: .year, status: .open)],
                notes: [],
                events: []
            )
        ]

        let sections = DaySpreadContentView.ViewModel.makeContainingPeriodSections(
            from: dataModels,
            orderedBy: .default,
            displayName: { $0.period == .year ? "2026" : "Week" }
        )

        #expect(sections.map(\.title) == ["Week", "2026"])
    }

    /// Conditions: No data models.
    /// Expected: No sections — the day spread renders nothing extra.
    @Test("No containing spreads produces no sections")
    func noSpreadsNoSections() {
        let sections = DaySpreadContentView.ViewModel.makeContainingPeriodSections(
            from: [],
            orderedBy: .default,
            displayName: { _ in "" }
        )
        #expect(sections.isEmpty)
    }

    /// Conditions: A card's open tasks with differing priorities, sorted by `.priority`.
    /// Expected: The selected sort option applies within the card (high priority first,
    /// ties through the Default chain).
    @Test("Sort option applies within a card")
    func sortOptionAppliesWithinCard() {
        let day = makeDate(year: 2026, month: 7, day: 10)
        let monthSpread = DataModel.Spread(period: .month, date: day, calendar: calendar)
        let dataModel = SpreadDataModel(
            spread: monthSpread,
            tasks: [
                DataModel.Task(title: "Zebra", priority: .low, date: day, period: .month, status: .open),
                DataModel.Task(title: "Urgent", priority: .high, date: day, period: .month, status: .open),
                DataModel.Task(title: "Apple", priority: .low, date: day, period: .month, status: .open)
            ],
            notes: [],
            events: []
        )

        let sections = DaySpreadContentView.ViewModel.makeContainingPeriodSections(
            from: [dataModel],
            orderedBy: .priority,
            displayName: { _ in "July 2026" }
        )

        #expect(sections.count == 1)
        #expect(sections[0].entries.map(\.title) == ["Urgent", "Apple", "Zebra"])
    }
}
