import Foundation
import Testing
@testable import Spread

/// Tests for the SPRD-307 `EntrySortOption` comparator chain. Every option resolves ties
/// through the full Default chain (`scheduledStart` nil-last → title → `createdDate`), so
/// each option's output must be identical for any input permutation.
/// See `Documentation/Specs/EntryListGrouping.md` — Sort Hardening: Deterministic Default Chain.
@Suite("Entry Sort Option Tests")
@MainActor
struct EntrySortOptionTests {

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

    // MARK: - Default Chain

    /// Conditions: A timed task scheduled between a timed event before it and a timed
    /// event after it, sorted with the Default comparator.
    /// Expected: Chronological interleaving across mixed types — event, task, event.
    @Test("Default interleaves timed tasks and events chronologically")
    func defaultInterleavesMixedTypes() {
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
        let sorted = entries.sorted(by: EntrySortOption.default.areInOrder)

        #expect(sorted.map(\.title) == ["Morning call", "Prep notes", "Afternoon call"])
    }

    /// Conditions: Two timed entries sharing the same instant, plus two untimed entries,
    /// sorted with the Default comparator.
    /// Expected: Timed entries precede all untimed ones; equal instants tie-break
    /// alphabetically by title; untimed entries order alphabetically by title.
    @Test("Default puts untimed last and tie-breaks equal instants by title")
    func defaultUntimedLastAndTitleTiebreak() {
        let day = makeDate(year: 2026, month: 7, day: 10)
        let instant = makeDate(year: 2026, month: 7, day: 10, hour: 9)
        let taskB = DataModel.Task(title: "Beta", scheduledTime: instant, date: day)
        let taskA = DataModel.Task(title: "Alpha", scheduledTime: instant, date: day)
        let untimedZ = DataModel.Task(title: "Zeta errand", date: day)
        let untimedM = DataModel.Task(title: "Mail package", date: day)

        let entries: [any Entry] = [untimedZ, taskB, untimedM, taskA]
        let sorted = entries.sorted(by: EntrySortOption.default.areInOrder)

        #expect(sorted.map(\.title) == ["Alpha", "Beta", "Mail package", "Zeta errand"])
    }

    /// Conditions: Two untimed tasks with identical titles but different creation dates,
    /// sorted with the Default comparator (the extreme-edge final tiebreaker).
    /// Expected: The earlier-created task sorts first.
    @Test("Default breaks identical-title ties by createdDate")
    func defaultCreatedDateTiebreak() {
        let day = makeDate(year: 2026, month: 7, day: 10)
        let older = DataModel.Task(
            title: "Duplicate",
            createdDate: makeDate(year: 2026, month: 7, day: 1),
            date: day
        )
        let newer = DataModel.Task(
            title: "Duplicate",
            createdDate: makeDate(year: 2026, month: 7, day: 5),
            date: day
        )

        let sorted = ([newer, older] as [any Entry]).sorted(by: EntrySortOption.default.areInOrder)

        #expect((sorted[0] as? DataModel.Task)?.id == older.id)
        #expect((sorted[1] as? DataModel.Task)?.id == newer.id)
    }

    /// Conditions: The same entry set sorted from two different input permutations, for
    /// every sort option.
    /// Expected: Identical output order regardless of input order — the chain is a total
    /// order with no dependence on `sorted(by:)` input position.
    @Test("Every option is deterministic under input permutation")
    func everyOptionIsDeterministic() {
        let day = makeDate(year: 2026, month: 7, day: 10)
        let entries: [any Entry] = [
            DataModel.Task(title: "Same", createdDate: makeDate(year: 2026, month: 7, day: 2), date: day),
            DataModel.Task(title: "Same", createdDate: makeDate(year: 2026, month: 7, day: 1), date: day),
            DataModel.Task(
                title: "Same",
                scheduledTime: makeDate(year: 2026, month: 7, day: 10, hour: 9),
                createdDate: makeDate(year: 2026, month: 7, day: 3),
                date: day
            ),
            DataModel.Note(title: "Same", date: day)
        ]

        for option in EntrySortOption.allCases {
            let forward = entries.sorted(by: option.areInOrder)
            let backward = entries.reversed().sorted(by: option.areInOrder)
            #expect(forward.map(\.id) == backward.map(\.id), "non-deterministic under \(option.rawValue)")
        }
    }

    // MARK: - Due Date

    /// Conditions: Tasks with due dates in non-chronological title order, a task whose
    /// assigned `date` is earlier than every due date but has no `dueDate`, and a note.
    /// Expected: Due-dated tasks first, soonest due date first; the no-due-date task and
    /// the note after all due-dated entries (the assigned date must not participate —
    /// regression against the old `sortDate` key).
    @Test("Due Date orders by the real dueDate with nil last")
    func dueDateUsesRealDueDateNilLast() {
        let earlyAssigned = makeDate(year: 2026, month: 7, day: 1)
        let later = DataModel.Task(title: "Alpha", dueDate: makeDate(year: 2026, month: 7, day: 20), date: earlyAssigned)
        let sooner = DataModel.Task(title: "Zulu", dueDate: makeDate(year: 2026, month: 7, day: 12), date: earlyAssigned)
        let noDueDate = DataModel.Task(title: "Aardvark", date: earlyAssigned)
        let note = DataModel.Note(title: "Idea", date: earlyAssigned)

        let entries: [any Entry] = [noDueDate, later, note, sooner]
        let sorted = entries.sorted(by: EntrySortOption.dueDate.areInOrder)

        #expect(sorted.map(\.title) == ["Zulu", "Alpha", "Aardvark", "Idea"])
    }

    /// Conditions: Two tasks sharing a due date — one with a scheduled time, one without.
    /// Expected: The tie falls through the full Default chain, so the timed task sorts
    /// first even though its title is alphabetically later.
    @Test("Due Date ties fall through the full Default chain")
    func dueDateTieFallsThroughChain() {
        let day = makeDate(year: 2026, month: 7, day: 10)
        let due = makeDate(year: 2026, month: 7, day: 15)
        let timed = DataModel.Task(
            title: "Zebra walk",
            dueDate: due,
            scheduledTime: makeDate(year: 2026, month: 7, day: 10, hour: 8),
            date: day
        )
        let untimed = DataModel.Task(title: "Apple run", dueDate: due, date: day)

        let sorted = ([untimed, timed] as [any Entry]).sorted(by: EntrySortOption.dueDate.areInOrder)

        #expect(sorted.map(\.title) == ["Zebra walk", "Apple run"])
    }

    // MARK: - Priority

    /// Conditions: Tasks with high/low/none priority, plus two same-priority tasks where
    /// one has a scheduled time.
    /// Expected: Higher priority first; the same-priority pair resolves through the
    /// Default chain (timed before untimed).
    @Test("Priority orders high first and ties fall through the Default chain")
    func priorityHighFirstWithChainTiebreak() {
        let day = makeDate(year: 2026, month: 7, day: 10)
        let high = DataModel.Task(title: "Urgent", priority: .high, date: day)
        let lowTimed = DataModel.Task(
            title: "Walk dog",
            priority: .low,
            scheduledTime: makeDate(year: 2026, month: 7, day: 10, hour: 7),
            date: day
        )
        let lowUntimed = DataModel.Task(title: "Buy milk", priority: .low, date: day)
        let none = DataModel.Task(title: "Someday", date: day)

        let entries: [any Entry] = [none, lowUntimed, high, lowTimed]
        let sorted = entries.sorted(by: EntrySortOption.priority.areInOrder)

        #expect(sorted.map(\.title) == ["Urgent", "Walk dog", "Buy milk", "Someday"])
    }

    // MARK: - Type

    /// Conditions: A note, an event, and two tasks (one timed, one untimed) sorted by Type.
    /// Expected: `EntryType` declaration order (task, event, note); the two tasks resolve
    /// through the Default chain (timed first).
    @Test("Type orders by entry type rank and ties fall through the Default chain")
    func typeRankWithChainTiebreak() {
        let day = makeDate(year: 2026, month: 7, day: 10)
        let note = DataModel.Note(title: "Idea", date: day)
        let event = makeTimedEvent(
            title: "Standup",
            start: makeDate(year: 2026, month: 7, day: 10, hour: 9),
            end: makeDate(year: 2026, month: 7, day: 10, hour: 10)
        )
        let timedTask = DataModel.Task(
            title: "Zebra walk",
            scheduledTime: makeDate(year: 2026, month: 7, day: 10, hour: 8),
            date: day
        )
        let untimedTask = DataModel.Task(title: "Apple run", date: day)

        let entries: [any Entry] = [note, untimedTask, event, timedTask]
        let sorted = entries.sorted(by: EntrySortOption.type.areInOrder)

        #expect(sorted.map(\.title) == ["Zebra walk", "Apple run", "Standup", "Idea"])
    }

    // MARK: - Timezone Invariance (regression)

    /// Conditions: A task scheduled between two events, all as absolute instants. The
    /// ordering is evaluated as-is and again conceptually "viewed" from a different
    /// timezone (instants are timezone-independent, so no conversion applies).
    /// Expected: The task stays between the two events — the defining SPRD-296 design
    /// scenario, ported from the SPRD-301 `.time` comparator to Default. This regression
    /// test pins the absolute-instant semantics so wall-clock (time-of-day)
    /// representations are never reintroduced.
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
        let comparator = EntrySortOption.default.areInOrder

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
