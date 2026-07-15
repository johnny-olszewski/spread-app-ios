import Foundation
import Testing
@testable import Spread

/// Tests for SPRD-308: calendar events flow through the day spread's grouping/sorting
/// pipeline as ordinary entries — no fixed trailing "Events" section, nil-bucket placement
/// under list/tag grouping, own bucket under status/type grouping, chronological interleave
/// with timed tasks under Default sort.
/// See `Documentation/Specs/DaySpreadComposition.md` — Events integrated into the day entry list.
@Suite("Day Spread Event Integration Tests")
@MainActor
struct DaySpreadEventIntegrationTests {

    // MARK: - Test Helpers

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func makeTimedEvent(title: String, start: Date, end: Date) -> DataModel.Event {
        DataModel.Event(
            title: title,
            timing: .timed,
            startDate: start,
            endDate: end,
            startTime: start,
            endTime: end
        )
    }

    // MARK: - No fixed Events section

    /// Conditions: A day spread with a timed event, a timed task scheduled between two
    /// event-adjacent instants, and an untimed task, grouped by None with Default sort.
    /// Expected: One section, chronologically interleaved across types with the untimed
    /// task last — no trailing "Events" section exists.
    @Test("Events interleave with tasks under None grouping and Default sort")
    func eventsInterleaveUnderDefaultSort() {
        let spreadDate = makeDate(year: 2026, month: 7, day: 10)
        let standup = makeTimedEvent(
            title: "Standup",
            start: makeDate(year: 2026, month: 7, day: 10, hour: 9),
            end: makeDate(year: 2026, month: 7, day: 10, hour: 9, minute: 30)
        )
        let prep = DataModel.Task(
            title: "Prep notes",
            scheduledTime: makeDate(year: 2026, month: 7, day: 10, hour: 8),
            date: spreadDate
        )
        let errand = DataModel.Task(title: "Errand", date: spreadDate)

        let sections = DaySpreadContentView.ViewModel.makeSections(
            from: [errand, standup, prep],
            spreadDate: spreadDate,
            groupingOption: .none,
            sortingOption: .default
        )

        #expect(sections.count == 1)
        #expect(sections.allSatisfy { $0.title != "Events" })
        #expect(sections[0].entries.map(\.title) == ["Prep notes", "Standup", "Errand"])
    }

    // MARK: - Grouping placement

    /// Conditions: A listed task, an unlisted task, and an event, grouped by list.
    /// Expected: The event lands in the "No list" bucket alongside the unlisted task —
    /// events have no list assignment and are not split into a separate section.
    @Test("Events land in the No list bucket under list grouping")
    func eventsBucketAsNoListUnderListGrouping() {
        let spreadDate = makeDate(year: 2026, month: 7, day: 10)
        let list = DataModel.List(name: "Work")
        let listed = DataModel.Task(title: "Listed", date: spreadDate, list: list)
        let unlisted = DataModel.Task(title: "Unlisted", date: spreadDate)
        let event = makeTimedEvent(
            title: "Standup",
            start: makeDate(year: 2026, month: 7, day: 10, hour: 9),
            end: makeDate(year: 2026, month: 7, day: 10, hour: 10)
        )

        let sections = DaySpreadContentView.ViewModel.makeSections(
            from: [unlisted, event, listed],
            spreadDate: spreadDate,
            groupingOption: .list,
            sortingOption: .default
        )

        #expect(sections.count == 2)
        #expect(sections[0].title == "Work")
        #expect(sections[1].title == "No list")
        #expect(Set(sections[1].entries.map(\.title)) == ["Unlisted", "Standup"])
    }

    /// Conditions: A task, a note, and an event, grouped by type.
    /// Expected: The event occupies its own "Event" bucket.
    @Test("Events occupy their own bucket under type grouping")
    func eventsOwnBucketUnderTypeGrouping() {
        let spreadDate = makeDate(year: 2026, month: 7, day: 10)
        let task = DataModel.Task(title: "A Task", date: spreadDate)
        let note = DataModel.Note(title: "A Note", date: spreadDate)
        let event = makeTimedEvent(
            title: "Standup",
            start: makeDate(year: 2026, month: 7, day: 10, hour: 9),
            end: makeDate(year: 2026, month: 7, day: 10, hour: 10)
        )

        let sections = DaySpreadContentView.ViewModel.makeSections(
            from: [note, event, task],
            spreadDate: spreadDate,
            groupingOption: .type,
            sortingOption: .default
        )

        #expect(sections.count == 3)
        #expect(sections.first { $0.id == "Event" }?.entries.map(\.title) == ["Standup"])
    }

    /// Conditions: An open task and an event, grouped by status.
    /// Expected: The event appears in its own bucket keyed by the event status
    /// (`.upcoming`), not in a fixed Events section.
    @Test("Events bucket by their status under status grouping")
    func eventsBucketByStatusUnderStatusGrouping() {
        let spreadDate = makeDate(year: 2026, month: 7, day: 10)
        let task = DataModel.Task(title: "Open task", date: spreadDate)
        let event = makeTimedEvent(
            title: "Standup",
            start: makeDate(year: 2026, month: 7, day: 10, hour: 9),
            end: makeDate(year: 2026, month: 7, day: 10, hour: 10)
        )

        let sections = DaySpreadContentView.ViewModel.makeSections(
            from: [task, event],
            spreadDate: spreadDate,
            groupingOption: .status,
            sortingOption: .default
        )

        #expect(sections.count == 2)
        #expect(sections.first { $0.id == EntryStatus.upcoming.displayName }?.entries.map(\.title) == ["Standup"])
    }

    // MARK: - All-day events

    /// Conditions: An all-day event (no `scheduledStart`), a timed task, and an untimed
    /// task under None grouping with Default sort.
    /// Expected: The timed task leads; the all-day event sorts among the untimed entries
    /// alphabetically by title.
    @Test("All-day events sort as untimed entries")
    func allDayEventsSortAsUntimed() {
        let spreadDate = makeDate(year: 2026, month: 7, day: 10)
        let holiday = DataModel.Event(title: "Holiday", timing: .allDay, startDate: spreadDate, endDate: spreadDate)
        let timed = DataModel.Task(
            title: "Zebra walk",
            scheduledTime: makeDate(year: 2026, month: 7, day: 10, hour: 8),
            date: spreadDate
        )
        let untimed = DataModel.Task(title: "Errand", date: spreadDate)

        #expect(holiday.scheduledStart == nil)

        let sections = DaySpreadContentView.ViewModel.makeSections(
            from: [holiday, untimed, timed],
            spreadDate: spreadDate,
            groupingOption: .none,
            sortingOption: .default
        )

        #expect(sections.count == 1)
        #expect(sections[0].entries.map(\.title) == ["Zebra walk", "Errand", "Holiday"])
    }
}
