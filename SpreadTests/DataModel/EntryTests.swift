import Foundation
import Testing
@testable import Spread

/// Tests for Entry protocol, EntryType, and model conformances.
struct EntryTests {

    // MARK: - Test Helpers

    private var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return testCalendar.date(from: components)!
    }

    // MARK: - EntryType Tests

    /// Conditions: Access EntryType.allCases.
    /// Expected: Should contain exactly 3 cases: task, event, note.
    @Test func testEntryTypeCases() {
        let cases = EntryType.allCases
        #expect(cases.count == 3)
        #expect(cases.contains(.task))
        #expect(cases.contains(.event))
        #expect(cases.contains(.note))
    }

    /// Conditions: Access task imageName.
    /// Expected: Should return "circle.fill" (solid circle per BuJo spec).
    @Test func testTaskImageName() {
        #expect(EntryType.task.imageName == "circle.fill")
    }

    /// Conditions: Access event imageName.
    /// Expected: Should return "circle" (empty circle per BuJo spec).
    @Test func testEventImageName() {
        #expect(EntryType.event.imageName == "circle")
    }

    /// Conditions: Access note imageName.
    /// Expected: Should return "minus" (dash per BuJo spec).
    @Test func testNoteImageName() {
        #expect(EntryType.note.imageName == "minus")
    }

    /// Conditions: Access task displayName.
    /// Expected: Should return "Task".
    @Test func testTaskDisplayName() {
        #expect(EntryType.task.displayName == "Task")
    }

    /// Conditions: Access event displayName.
    /// Expected: Should return "Event".
    @Test func testEventDisplayName() {
        #expect(EntryType.event.displayName == "Event")
    }

    /// Conditions: Access note displayName.
    /// Expected: Should return "Note".
    @Test func testNoteDisplayName() {
        #expect(EntryType.note.displayName == "Note")
    }

    /// Conditions: Access rawValue for all entry types.
    /// Expected: Should return lowercase type names.
    @Test func testEntryTypeRawValues() {
        #expect(EntryType.task.rawValue == "task")
        #expect(EntryType.event.rawValue == "event")
        #expect(EntryType.note.rawValue == "note")
    }

    /// Conditions: Initialize EntryType from raw values.
    /// Expected: Valid values should create types; invalid should return nil.
    @Test func testEntryTypeInitFromRawValue() {
        #expect(EntryType(rawValue: "task") == .task)
        #expect(EntryType(rawValue: "event") == .event)
        #expect(EntryType(rawValue: "note") == .note)
        #expect(EntryType(rawValue: "invalid") == nil)
    }

    // MARK: - Task Entry Protocol Tests

    /// Conditions: Create Task with title and createdDate.
    /// Expected: Task should conform to Entry with correct entryType, title, and createdDate.
    @Test func testTaskConformsToEntry() {
        let createdDate = makeDate(year: 2026, month: 6, day: 1)
        let task = DataModel.Task(title: "Test Task", createdDate: createdDate)

        #expect(task.entryType == .task)
        #expect(task.title == "Test Task")
        #expect(task.createdDate == createdDate)
    }

    /// Conditions: Create Task with default initializer.
    /// Expected: entryType should be .task.
    @Test func testTaskEntryType() {
        let task = DataModel.Task()
        #expect(task.entryType == .task)
    }

    /// Conditions: Create Task with all properties specified.
    /// Expected: All properties should be set correctly.
    @Test func testTaskHasRequiredEntryProperties() {
        let now = makeDate(year: 2026, month: 6, day: 15)
        let assignments = [
            TaskAssignment(period: .day, date: now, status: .complete)
        ]
        let task = DataModel.Task(
            title: "My Task",
            createdDate: now,
            date: now,
            period: .day,
            status: .complete,
            assignments: assignments
        )

        #expect(task.title == "My Task")
        #expect(task.createdDate == now)
        #expect(task.date == now)
        #expect(task.period == .day)
        #expect(task.status == .complete)
        #expect(task.assignments == assignments)
    }

    /// Conditions: Access Task.Status.allCases.
    /// Expected: Should contain 4 statuses: open, complete, migrated, cancelled.
    @Test func testTaskStatusCases() {
        let cases = DataModel.Task.Status.allCases
        #expect(cases.count == 4)
        #expect(cases.contains(.open))
        #expect(cases.contains(.complete))
        #expect(cases.contains(.migrated))
        #expect(cases.contains(.cancelled))
    }

    /// Conditions: Access Task.Status rawValues.
    /// Expected: Should return lowercase status names.
    @Test func testTaskStatusRawValues() {
        #expect(DataModel.Task.Status.open.rawValue == "open")
        #expect(DataModel.Task.Status.complete.rawValue == "complete")
        #expect(DataModel.Task.Status.migrated.rawValue == "migrated")
        #expect(DataModel.Task.Status.cancelled.rawValue == "cancelled")
    }

    /// Conditions: Create Task with default initializer.
    /// Expected: Should have empty title, day period, open status, empty assignments.
    @Test func testTaskDefaultValues() {
        let task = DataModel.Task()
        #expect(task.title == "")
        #expect(task.period == .day)
        #expect(task.status == .open)
        #expect(task.assignments.isEmpty)
    }

    // MARK: - Event Entry Protocol Tests

    /// Conditions: Create Event with title.
    /// Expected: Event should conform to DateRangeEntry with correct entryType.
    @Test func testEventConformsToDateRangeEntry() {
        let event = DataModel.Event(title: "Test Event")

        #expect(event.entryType == .event)
        #expect(event.startDate <= event.endDate)
    }

    /// Conditions: Create Event with default initializer.
    /// Expected: entryType should be .event.
    @Test func testEventEntryType() {
        let event = DataModel.Event()
        #expect(event.entryType == .event)
    }

    /// Conditions: Create Event with all properties specified.
    /// Expected: All properties should be set correctly.
    @Test func testEventHasRequiredProperties() {
        let now = Date.now
        let event = DataModel.Event(
            title: "Meeting",
            timing: .timed,
            startDate: now,
            endDate: now,
            startTime: now,
            endTime: now
        )

        #expect(event.title == "Meeting")
        #expect(event.timing == .timed)
        #expect(event.startDate == now)
        #expect(event.endDate == now)
        #expect(event.startTime == now)
        #expect(event.endTime == now)
    }

    /// Conditions: Access EventTiming.allCases.
    /// Expected: Should contain 4 timings: singleDay, allDay, timed, multiDay.
    @Test func testEventTimingCases() {
        let cases = EventTiming.allCases
        #expect(cases.count == 4)
        #expect(cases.contains(.singleDay))
        #expect(cases.contains(.allDay))
        #expect(cases.contains(.timed))
        #expect(cases.contains(.multiDay))
    }

    /// Conditions: Access EventTiming displayNames.
    /// Expected: Should return human-readable names.
    @Test func testEventTimingDisplayNames() {
        #expect(EventTiming.singleDay.displayName == "Single Day")
        #expect(EventTiming.allDay.displayName == "All Day")
        #expect(EventTiming.timed.displayName == "Timed")
        #expect(EventTiming.multiDay.displayName == "Multi-Day")
    }

    /// Conditions: Create Event with default initializer.
    /// Expected: Should have empty title, singleDay timing, nil times.
    @Test func testEventDefaultValues() {
        let event = DataModel.Event()
        #expect(event.title == "")
        #expect(event.timing == .singleDay)
        #expect(event.startTime == nil)
        #expect(event.endTime == nil)
    }

    // MARK: - Note Entry Protocol Tests

    /// Conditions: Create Note with title.
    /// Expected: Note should conform to AssignableEntry with correct entryType and default period.
    @Test func testNoteConformsToAssignableEntry() {
        let note = DataModel.Note(title: "Test Note")

        #expect(note.entryType == .note)
        #expect(note.period == .day)
    }

    /// Conditions: Create Note with default initializer.
    /// Expected: entryType should be .note.
    @Test func testNoteEntryType() {
        let note = DataModel.Note()
        #expect(note.entryType == .note)
    }

    /// Conditions: Create Note with all properties specified.
    /// Expected: All properties should be set correctly including extended content.
    @Test func testNoteHasRequiredProperties() {
        let now = makeDate(year: 2026, month: 6, day: 15)
        let assignments = [
            NoteAssignment(period: .month, date: now, status: .migrated)
        ]
        let note = DataModel.Note(
            title: "My Note",
            content: "Extended content here",
            createdDate: now,
            date: now,
            period: .month,
            status: .migrated,
            assignments: assignments
        )

        #expect(note.title == "My Note")
        #expect(note.content == "Extended content here")
        #expect(note.createdDate == now)
        #expect(note.date == now)
        #expect(note.period == .month)
        #expect(note.status == .migrated)
        #expect(note.assignments == assignments)
    }

    /// Conditions: Access Note.Status.allCases.
    /// Expected: Should contain 2 statuses: active, migrated.
    @Test func testNoteStatusCases() {
        let cases = DataModel.Note.Status.allCases
        #expect(cases.count == 2)
        #expect(cases.contains(.active))
        #expect(cases.contains(.migrated))
    }

    /// Conditions: Access Note.Status rawValues.
    /// Expected: Should return lowercase status names.
    @Test func testNoteStatusRawValues() {
        #expect(DataModel.Note.Status.active.rawValue == "active")
        #expect(DataModel.Note.Status.migrated.rawValue == "migrated")
    }

    /// Conditions: Create Note with default initializer.
    /// Expected: Should have empty title/content, day period, active status, empty assignments.
    @Test func testNoteDefaultValues() {
        let note = DataModel.Note()
        #expect(note.title == "")
        #expect(note.content == "")
        #expect(note.period == .day)
        #expect(note.status == .active)
        #expect(note.assignments.isEmpty)
    }

    /// Conditions: Create Note with very long content.
    /// Expected: Content should be stored without truncation.
    @Test func testNoteCanHaveExtendedContent() {
        let longContent = String(repeating: "Lorem ipsum dolor sit amet. ", count: 100)
        let note = DataModel.Note(content: longContent)
        #expect(note.content == longContent)
    }

    // MARK: - Event appearsOn() Tests

    /// Conditions: Event on June 15, checking day spread for June 15.
    /// Expected: Should return true (same day).
    @Test func testEventAppearsOnSameDaySpread() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let event = DataModel.Event(
            startDate: date,
            endDate: date
        )

        let result = event.appearsOn(
            period: .day,
            date: date,
            calendar: testCalendar
        )
        #expect(result == true)
    }

    /// Conditions: Event on June 15, checking day spread for June 16.
    /// Expected: Should return false (different day).
    @Test func testEventDoesNotAppearOnDifferentDaySpread() {
        let eventDate = makeDate(year: 2026, month: 6, day: 15)
        let spreadDate = makeDate(year: 2026, month: 6, day: 16)
        let event = DataModel.Event(
            startDate: eventDate,
            endDate: eventDate
        )

        let result = event.appearsOn(
            period: .day,
            date: spreadDate,
            calendar: testCalendar
        )
        #expect(result == false)
    }

    /// Conditions: Event on June 15, checking month spread for June.
    /// Expected: Should return true (event is within month).
    @Test func testEventAppearsOnContainingMonthSpread() {
        let eventDate = makeDate(year: 2026, month: 6, day: 15)
        let monthStart = makeDate(year: 2026, month: 6, day: 1)
        let event = DataModel.Event(
            startDate: eventDate,
            endDate: eventDate
        )

        let result = event.appearsOn(
            period: .month,
            date: monthStart,
            calendar: testCalendar
        )
        #expect(result == true)
    }

    /// Conditions: Event on June 15, checking month spread for July.
    /// Expected: Should return false (different month).
    @Test func testEventDoesNotAppearOnDifferentMonthSpread() {
        let eventDate = makeDate(year: 2026, month: 6, day: 15)
        let differentMonthStart = makeDate(year: 2026, month: 7, day: 1)
        let event = DataModel.Event(
            startDate: eventDate,
            endDate: eventDate
        )

        let result = event.appearsOn(
            period: .month,
            date: differentMonthStart,
            calendar: testCalendar
        )
        #expect(result == false)
    }

    /// Conditions: Event on June 15 2026, checking year spread for 2026.
    /// Expected: Should return true (event is within year).
    @Test func testEventAppearsOnContainingYearSpread() {
        let eventDate = makeDate(year: 2026, month: 6, day: 15)
        let yearStart = makeDate(year: 2026, month: 1, day: 1)
        let event = DataModel.Event(
            startDate: eventDate,
            endDate: eventDate
        )

        let result = event.appearsOn(
            period: .year,
            date: yearStart,
            calendar: testCalendar
        )
        #expect(result == true)
    }

    /// Conditions: Event on June 15 2026, checking year spread for 2027.
    /// Expected: Should return false (different year).
    @Test func testEventDoesNotAppearOnDifferentYearSpread() {
        let eventDate = makeDate(year: 2026, month: 6, day: 15)
        let differentYearStart = makeDate(year: 2027, month: 1, day: 1)
        let event = DataModel.Event(
            startDate: eventDate,
            endDate: eventDate
        )

        let result = event.appearsOn(
            period: .year,
            date: differentYearStart,
            calendar: testCalendar
        )
        #expect(result == false)
    }

    /// Conditions: Multi-day event from June 15-17, checking day spreads.
    /// Expected: Should appear on June 15, 16, and 17.
    @Test func testMultiDayEventAppearsOnSpanningDays() {
        let startDate = makeDate(year: 2026, month: 6, day: 15)
        let endDate = makeDate(year: 2026, month: 6, day: 17)
        let event = DataModel.Event(
            timing: .multiDay,
            startDate: startDate,
            endDate: endDate
        )

        // Should appear on start, middle, and end days
        let day15 = makeDate(year: 2026, month: 6, day: 15)
        let day16 = makeDate(year: 2026, month: 6, day: 16)
        let day17 = makeDate(year: 2026, month: 6, day: 17)

        #expect(event.appearsOn(period: .day, date: day15, calendar: testCalendar) == true)
        #expect(event.appearsOn(period: .day, date: day16, calendar: testCalendar) == true)
        #expect(event.appearsOn(period: .day, date: day17, calendar: testCalendar) == true)
    }

    /// Conditions: Multi-day event from June 15-17, checking days outside range.
    /// Expected: Should not appear on June 14 or June 18.
    @Test func testMultiDayEventDoesNotAppearOutsideRange() {
        let startDate = makeDate(year: 2026, month: 6, day: 15)
        let endDate = makeDate(year: 2026, month: 6, day: 17)
        let event = DataModel.Event(
            timing: .multiDay,
            startDate: startDate,
            endDate: endDate
        )

        let dayBefore = makeDate(year: 2026, month: 6, day: 14)
        let dayAfter = makeDate(year: 2026, month: 6, day: 18)

        #expect(event.appearsOn(period: .day, date: dayBefore, calendar: testCalendar) == false)
        #expect(event.appearsOn(period: .day, date: dayAfter, calendar: testCalendar) == false)
    }

    /// Conditions: Multi-day event from June 28 to July 3, checking month spreads.
    /// Expected: Should appear on both June and July month spreads.
    @Test func testMultiDayEventSpanningMonthsAppearsOnBothMonths() {
        let startDate = makeDate(year: 2026, month: 6, day: 28)
        let endDate = makeDate(year: 2026, month: 7, day: 3)
        let event = DataModel.Event(
            timing: .multiDay,
            startDate: startDate,
            endDate: endDate
        )

        let juneStart = makeDate(year: 2026, month: 6, day: 1)
        let julyStart = makeDate(year: 2026, month: 7, day: 1)

        #expect(event.appearsOn(period: .month, date: juneStart, calendar: testCalendar) == true)
        #expect(event.appearsOn(period: .month, date: julyStart, calendar: testCalendar) == true)
    }

    /// Conditions: Multi-day event from Dec 28 2026 to Jan 3 2027, checking year spreads.
    /// Expected: Should appear on both 2026 and 2027 year spreads.
    @Test func testMultiDayEventSpanningYearsAppearsOnBothYears() {
        let startDate = makeDate(year: 2026, month: 12, day: 28)
        let endDate = makeDate(year: 2027, month: 1, day: 3)
        let event = DataModel.Event(
            timing: .multiDay,
            startDate: startDate,
            endDate: endDate
        )

        let year2026Start = makeDate(year: 2026, month: 1, day: 1)
        let year2027Start = makeDate(year: 2027, month: 1, day: 1)

        #expect(event.appearsOn(period: .year, date: year2026Start, calendar: testCalendar) == true)
        #expect(event.appearsOn(period: .year, date: year2027Start, calendar: testCalendar) == true)
    }

    /// Conditions: Event on June 1 (first day of month), checking June month spread.
    /// Expected: Should return true.
    @Test func testEventOnFirstDayOfMonthAppearsOnMonthSpread() {
        let date = makeDate(year: 2026, month: 6, day: 1)
        let event = DataModel.Event(startDate: date, endDate: date)

        let result = event.appearsOn(
            period: .month,
            date: date,
            calendar: testCalendar
        )
        #expect(result == true)
    }

    /// Conditions: Event on June 30 (last day of month), checking June month spread.
    /// Expected: Should return true.
    @Test func testEventOnLastDayOfMonthAppearsOnMonthSpread() {
        let lastDayOfJune = makeDate(year: 2026, month: 6, day: 30)
        let juneStart = makeDate(year: 2026, month: 6, day: 1)
        let event = DataModel.Event(startDate: lastDayOfJune, endDate: lastDayOfJune)

        let result = event.appearsOn(
            period: .month,
            date: juneStart,
            calendar: testCalendar
        )
        #expect(result == true)
    }

    /// Conditions: Event checking multiday spread (which has nil calendarComponent).
    /// Expected: Should return true (multiday filtering done by caller).
    @Test func testEventAlwaysAppearsOnMultidaySpread() {
        // Multiday spreads have nil calendarComponent, so appearsOn returns true
        // The actual filtering is done by the caller with the date range
        let event = DataModel.Event(
            startDate: makeDate(year: 2026, month: 6, day: 15),
            endDate: makeDate(year: 2026, month: 6, day: 15)
        )

        let result = event.appearsOn(
            period: .multiday,
            date: makeDate(year: 2026, month: 6, day: 1),
            calendar: testCalendar
        )
        #expect(result == true)
    }
}
