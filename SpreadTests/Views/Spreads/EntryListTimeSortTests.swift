import Foundation
import Testing
@testable import Spread

/// Tests for the SPRD-301 `.time` sort option and the time-integrated day-spread section
/// shape built by `DaySpreadContentView.ViewModel.makeSections`/`makeTimeSortedSections`.
/// See `Documentation/Specs/TaskScheduledTime.md` — Time sort integration.
@Suite("Entry List Time Sort Tests")
@MainActor
struct EntryListTimeSortTests {

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

    // MARK: - Comparator Ordering

    /// Conditions: A timed task scheduled between a timed event before it and a timed
    /// event after it, sorted with the `.time` comparator.
    /// Expected: Chronological interleaving across mixed types — event, task, event.
    @Test("Time comparator interleaves tasks and events chronologically")
    func timeComparatorInterleavesMixedTypes() {
        let day = makeDate(year: 2026, month: 7, day: 10)
        let morningCall = makeTimedEvent(
            title: "Morning call",
            start: makeDate(year: 2026, month: 7, day: 10, hour: 9),
            end: makeDate(year: 2026, month: 7, day: 10, hour: 10)
        )
        let task = DataModel.Task(
            title: "Prep notes",
            scheduledTime: makeDate(year: 2026, month: 7, day: 10, hour: 11),
            date: day
        )
        let afternoonCall = makeTimedEvent(
            title: "Afternoon call",
            start: makeDate(year: 2026, month: 7, day: 10, hour: 14),
            end: makeDate(year: 2026, month: 7, day: 10, hour: 15)
        )

        let entries: [any Entry] = [afternoonCall, task, morningCall]
        let sorted = entries.sorted(by: EntrySortOption.time.areInOrder!)

        #expect(sorted.map(\.title) == ["Morning call", "Prep notes", "Afternoon call"])
    }

    /// Conditions: Two timed entries sharing the same instant, plus untimed entries,
    /// sorted with the `.time` comparator.
    /// Expected: Timed entries precede untimed ones; equal instants tie-break
    /// alphabetically by title.
    @Test("Time comparator puts untimed last and tie-breaks equal instants by title")
    func timeComparatorUntimedLastAndTitleTiebreak() {
        let day = makeDate(year: 2026, month: 7, day: 10)
        let instant = makeDate(year: 2026, month: 7, day: 10, hour: 9)
        let taskB = DataModel.Task(title: "Beta", scheduledTime: instant, date: day)
        let taskA = DataModel.Task(title: "Alpha", scheduledTime: instant, date: day)
        let untimed = DataModel.Task(title: "Someday", date: day)

        let entries: [any Entry] = [untimed, taskB, taskA]
        let sorted = entries.sorted(by: EntrySortOption.time.areInOrder!)

        #expect(sorted.map(\.title) == ["Alpha", "Beta", "Someday"])
    }

    // MARK: - Section Construction

    /// Conditions: A day spread's entries contain timed tasks, timed events, an untimed
    /// task, a note, and an all-day event, with `.time` sorting selected.
    /// Expected: No fixed "Events" section. First section is headerless and chronological
    /// across types; second section is titled "No time" with `.unnamed` style and holds
    /// the untimed task, the note, and the all-day event.
    @Test("Time sort dissolves the Events section into timed-top/untimed-below")
    func timeSortSectionShape() {
        let spreadDate = makeDate(year: 2026, month: 7, day: 10)
        let event = makeTimedEvent(
            title: "Standup",
            start: makeDate(year: 2026, month: 7, day: 10, hour: 9, minute: 30),
            end: makeDate(year: 2026, month: 7, day: 10, hour: 10)
        )
        let earlyTask = DataModel.Task(
            title: "Gym",
            scheduledTime: makeDate(year: 2026, month: 7, day: 10, hour: 7),
            date: spreadDate
        )
        let untimedTask = DataModel.Task(title: "Errand", date: spreadDate)
        let note = DataModel.Note(title: "Idea", date: spreadDate)
        let allDay = DataModel.Event(title: "Holiday", timing: .allDay, startDate: spreadDate, endDate: spreadDate)

        let sections = DaySpreadContentView.ViewModel.makeSections(
            from: [untimedTask, event, note, allDay, earlyTask],
            spreadDate: spreadDate,
            groupingOption: .none,
            sortingOption: .time,
            eventConfigurationMap: [:]
        )

        #expect(sections.count == 2)
        #expect(sections.allSatisfy { $0.title != "Events" })
        #expect(sections[0].title.isEmpty)
        #expect(sections[0].entries.map(\.title) == ["Gym", "Standup"])
        #expect(sections[1].title == "No time")
        #expect(sections[1].headerStyle == .unnamed)
        #expect(Set(sections[1].entries.map(\.title)) == ["Errand", "Idea", "Holiday"])
    }

    /// Conditions: `.time` sorting with only untimed entries.
    /// Expected: A single "No time" section and no empty timed section.
    @Test("Time sort with no timed entries produces only the No time section")
    func timeSortAllUntimed() {
        let spreadDate = makeDate(year: 2026, month: 7, day: 10)
        let sections = DaySpreadContentView.ViewModel.makeSections(
            from: [DataModel.Task(title: "Errand", date: spreadDate), DataModel.Note(title: "Idea", date: spreadDate)],
            spreadDate: spreadDate,
            groupingOption: .none,
            sortingOption: .time,
            eventConfigurationMap: [:]
        )

        #expect(sections.count == 1)
        #expect(sections[0].title == "No time")
    }

    /// Conditions: Non-`.time` sorting with events present (the pre-existing shape).
    /// Expected: The fixed "Events" section still appears last — the SPRD-301 path only
    /// activates for `.time`.
    @Test("Non-time sort keeps the fixed Events section")
    func nonTimeSortKeepsEventsSection() {
        let spreadDate = makeDate(year: 2026, month: 7, day: 10)
        let event = makeTimedEvent(
            title: "Standup",
            start: makeDate(year: 2026, month: 7, day: 10, hour: 9),
            end: makeDate(year: 2026, month: 7, day: 10, hour: 10)
        )
        let task = DataModel.Task(title: "Errand", date: spreadDate)

        let sections = DaySpreadContentView.ViewModel.makeSections(
            from: [task, event],
            spreadDate: spreadDate,
            groupingOption: .none,
            sortingOption: .dueDate,
            eventConfigurationMap: [:]
        )

        #expect(sections.last?.title == "Events")
    }

    // MARK: - Timezone Invariance (regression)

    /// Conditions: A task scheduled between two events, all as absolute instants. The
    /// ordering is evaluated as-is and again conceptually "viewed" from a different
    /// timezone (instants are timezone-independent, so no conversion applies).
    /// Expected: The task stays between the two events — the defining SPRD-296 design
    /// scenario. This regression test pins the absolute-instant semantics so wall-clock
    /// (time-of-day) representations are never reintroduced: any representation that
    /// re-derives the instant from local clock components would break this invariant.
    @Test("Task scheduled between two events stays between them across timezones")
    func taskBetweenEventsIsTimezoneInvariant() {
        // 3 PM PDT == 22:00 UTC on the same calendar day.
        let eventBefore = makeTimedEvent(
            title: "Call PDT-morning",
            start: makeDate(year: 2026, month: 7, day: 10, hour: 21),
            end: makeDate(year: 2026, month: 7, day: 10, hour: 21, minute: 30)
        )
        let task = DataModel.Task(
            title: "Between calls",
            scheduledTime: makeDate(year: 2026, month: 7, day: 10, hour: 22),
            date: makeDate(year: 2026, month: 7, day: 10)
        )
        let eventAfter = makeTimedEvent(
            title: "Call PDT-afternoon",
            start: makeDate(year: 2026, month: 7, day: 10, hour: 23),
            end: makeDate(year: 2026, month: 7, day: 10, hour: 23, minute: 30)
        )

        let entries: [any Entry] = [eventAfter, task, eventBefore]
        let comparator = EntrySortOption.time.areInOrder!

        // The comparator consumes Date instants directly — no Calendar/TimeZone input
        // exists to vary. Sorting in any "viewing" timezone is the same sort.
        let sortedUTC = entries.sorted(by: comparator)
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = TimeZone(identifier: "America/New_York")!
        let sortedEastern = entries.sorted(by: comparator)

        #expect(sortedUTC.map(\.title) == ["Call PDT-morning", "Between calls", "Call PDT-afternoon"])
        #expect(sortedEastern.map(\.title) == sortedUTC.map(\.title))
    }
}
