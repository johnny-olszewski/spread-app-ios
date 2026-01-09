import struct Foundation.Calendar
import struct Foundation.Date
import struct Foundation.DateComponents
import struct Foundation.TimeZone
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

    @Test func testEntryTypeCases() {
        let cases = EntryType.allCases
        #expect(cases.count == 3)
        #expect(cases.contains(.task))
        #expect(cases.contains(.event))
        #expect(cases.contains(.note))
    }

    @Test func testTaskImageName() {
        #expect(EntryType.task.imageName == "circle.fill")
    }

    @Test func testEventImageName() {
        #expect(EntryType.event.imageName == "circle")
    }

    @Test func testNoteImageName() {
        #expect(EntryType.note.imageName == "minus")
    }

    @Test func testTaskDisplayName() {
        #expect(EntryType.task.displayName == "Task")
    }

    @Test func testEventDisplayName() {
        #expect(EntryType.event.displayName == "Event")
    }

    @Test func testNoteDisplayName() {
        #expect(EntryType.note.displayName == "Note")
    }

    @Test func testEntryTypeRawValues() {
        #expect(EntryType.task.rawValue == "task")
        #expect(EntryType.event.rawValue == "event")
        #expect(EntryType.note.rawValue == "note")
    }

    @Test func testEntryTypeInitFromRawValue() {
        #expect(EntryType(rawValue: "task") == .task)
        #expect(EntryType(rawValue: "event") == .event)
        #expect(EntryType(rawValue: "note") == .note)
        #expect(EntryType(rawValue: "invalid") == nil)
    }

    // MARK: - Task Entry Protocol Tests

    @Test func testTaskConformsToEntry() {
        let createdDate = makeDate(year: 2026, month: 6, day: 1)
        let task = DataModel.Task(title: "Test Task", createdDate: createdDate)

        #expect(task.entryType == .task)
        #expect(task.title == "Test Task")
        #expect(task.createdDate == createdDate)
    }

    @Test func testTaskEntryType() {
        let task = DataModel.Task()
        #expect(task.entryType == .task)
    }

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

    @Test func testTaskStatusCases() {
        let cases = DataModel.Task.Status.allCases
        #expect(cases.count == 4)
        #expect(cases.contains(.open))
        #expect(cases.contains(.complete))
        #expect(cases.contains(.migrated))
        #expect(cases.contains(.cancelled))
    }

    @Test func testTaskStatusRawValues() {
        #expect(DataModel.Task.Status.open.rawValue == "open")
        #expect(DataModel.Task.Status.complete.rawValue == "complete")
        #expect(DataModel.Task.Status.migrated.rawValue == "migrated")
        #expect(DataModel.Task.Status.cancelled.rawValue == "cancelled")
    }

    @Test func testTaskDefaultValues() {
        let task = DataModel.Task()
        #expect(task.title == "")
        #expect(task.period == .day)
        #expect(task.status == .open)
        #expect(task.assignments.isEmpty)
    }

    // MARK: - Event Entry Protocol Tests

    @Test func testEventConformsToDateRangeEntry() {
        let event = DataModel.Event(title: "Test Event")

        #expect(event.entryType == .event)
        #expect(event.startDate <= event.endDate)
    }

    @Test func testEventEntryType() {
        let event = DataModel.Event()
        #expect(event.entryType == .event)
    }

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

    @Test func testEventTimingCases() {
        let cases = EventTiming.allCases
        #expect(cases.count == 4)
        #expect(cases.contains(.singleDay))
        #expect(cases.contains(.allDay))
        #expect(cases.contains(.timed))
        #expect(cases.contains(.multiDay))
    }

    @Test func testEventTimingDisplayNames() {
        #expect(EventTiming.singleDay.displayName == "Single Day")
        #expect(EventTiming.allDay.displayName == "All Day")
        #expect(EventTiming.timed.displayName == "Timed")
        #expect(EventTiming.multiDay.displayName == "Multi-Day")
    }

    @Test func testEventDefaultValues() {
        let event = DataModel.Event()
        #expect(event.title == "")
        #expect(event.timing == .singleDay)
        #expect(event.startTime == nil)
        #expect(event.endTime == nil)
    }

    // MARK: - Note Entry Protocol Tests

    @Test func testNoteConformsToAssignableEntry() {
        let note = DataModel.Note(title: "Test Note")

        #expect(note.entryType == .note)
        #expect(note.period == .day)
    }

    @Test func testNoteEntryType() {
        let note = DataModel.Note()
        #expect(note.entryType == .note)
    }

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

    @Test func testNoteStatusCases() {
        let cases = DataModel.Note.Status.allCases
        #expect(cases.count == 2)
        #expect(cases.contains(.active))
        #expect(cases.contains(.migrated))
    }

    @Test func testNoteStatusRawValues() {
        #expect(DataModel.Note.Status.active.rawValue == "active")
        #expect(DataModel.Note.Status.migrated.rawValue == "migrated")
    }

    @Test func testNoteDefaultValues() {
        let note = DataModel.Note()
        #expect(note.title == "")
        #expect(note.content == "")
        #expect(note.period == .day)
        #expect(note.status == .active)
        #expect(note.assignments.isEmpty)
    }

    @Test func testNoteCanHaveExtendedContent() {
        let longContent = String(repeating: "Lorem ipsum dolor sit amet. ", count: 100)
        let note = DataModel.Note(content: longContent)
        #expect(note.content == longContent)
    }

    // MARK: - Event appearsOn() Tests

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
