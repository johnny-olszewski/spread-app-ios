import Foundation
import Testing
@testable import Spread

@Suite(.serialized)
struct OverdueCardViewTests {

    private static var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        return calendar
    }

    @MainActor
    private static func makeContext(
        today: Date,
        tasks: [DataModel.Task] = [],
        spreads: [DataModel.Spread] = []
    ) async throws -> SpreadPageContext {
        let manager = try await JournalManager(
            calendar: testCalendar,
            today: today,
            taskRepository: TestTaskRepository(tasks: tasks),
            spreadRepository: TestSpreadRepository(spreads: spreads)
        )
        return SpreadPageContext(
            journalManager: manager,
            coordinator: SpreadsCoordinator(),
            syncEngine: nil,
            eventKitService: nil,
            calendarEventService: MockCalendarEventService()
        )
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        testCalendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    // MARK: - Day

    /// Setup: a day spread whose date matches today (registered in the journal, so it resolves
    /// as `bestSpread`), with one overdue task.
    /// Expected: one "Overdue" section is produced.
    @MainActor @Test func daySpreadMatchingTodayShowsOverdueSection() async throws {
        let today = Self.date(2026, 1, 12)
        let overdueDate = Self.date(2026, 1, 10)
        let task = DataModel.Task(
            title: "Overdue",
            date: overdueDate,
            period: .day,
            status: .open,
            currentAssignments: [Assignment(period: .day, date: overdueDate, status: .open)]
        )
        let spread = DataModel.Spread(period: .day, date: today, calendar: Self.testCalendar)
        let context = try await Self.makeContext(today: today, tasks: [task], spreads: [spread])

        let sections = OverdueCardView.sections(for: spread, context: context)

        #expect(sections.count == 1)
        #expect(sections.first?.entries.map(\.id) == [task.id])
    }

    /// Setup: a day spread whose date does NOT match today.
    /// Expected: no sections, even though there is an overdue task elsewhere in the journal.
    @MainActor @Test func daySpreadNotMatchingTodayShowsNoSection() async throws {
        let today = Self.date(2026, 1, 12)
        let overdueDate = Self.date(2026, 1, 10)
        let task = DataModel.Task(
            title: "Overdue",
            date: overdueDate,
            period: .day,
            status: .open,
            currentAssignments: [Assignment(period: .day, date: overdueDate, status: .open)]
        )
        let context = try await Self.makeContext(today: today, tasks: [task])
        let otherDaySpread = DataModel.Spread(period: .day, date: overdueDate, calendar: Self.testCalendar)

        #expect(OverdueCardView.sections(for: otherDaySpread, context: context).isEmpty)
    }

    // MARK: - Month

    /// Setup: a month spread for the same month as today (registered, no day spread exists for
    /// today), with an overdue task assigned to an earlier month.
    /// Expected: the overdue section is shown, since the month spread is the most granular
    /// spread containing today.
    @MainActor @Test func monthSpreadContainingTodayShowsOverdueSection() async throws {
        let today = Self.date(2026, 2, 15)
        let overdueMonth = Self.date(2026, 1, 1)
        let task = DataModel.Task(
            title: "Overdue",
            date: overdueMonth,
            period: .month,
            status: .open,
            currentAssignments: [Assignment(period: .month, date: overdueMonth, status: .open)]
        )
        let thisMonthSpread = DataModel.Spread(period: .month, date: today, calendar: Self.testCalendar)
        let context = try await Self.makeContext(today: today, tasks: [task], spreads: [thisMonthSpread])

        let sections = OverdueCardView.sections(for: thisMonthSpread, context: context)

        #expect(sections.count == 1)
        #expect(sections.first?.entries.map(\.id) == [task.id])
    }

    /// Setup: a month spread for a month other than today's.
    /// Expected: no sections.
    @MainActor @Test func monthSpreadNotContainingTodayShowsNoSection() async throws {
        let today = Self.date(2026, 2, 15)
        let context = try await Self.makeContext(today: today)
        let otherMonthSpread = DataModel.Spread(period: .month, date: Self.date(2026, 1, 1), calendar: Self.testCalendar)

        #expect(OverdueCardView.sections(for: otherMonthSpread, context: context).isEmpty)
    }

    /// Setup: both a day spread for today and its parent month spread exist and are registered.
    /// Expected: the overdue section is shown only on the day spread (the more granular of the
    /// two) -- the month spread, despite also containing today, shows nothing.
    @MainActor @Test func daySpreadTakesPriorityOverParentMonthSpread() async throws {
        let today = Self.date(2026, 2, 15)
        let overdueDate = Self.date(2026, 2, 10)
        let task = DataModel.Task(
            title: "Overdue",
            date: overdueDate,
            period: .day,
            status: .open,
            currentAssignments: [Assignment(period: .day, date: overdueDate, status: .open)]
        )
        let daySpread = DataModel.Spread(period: .day, date: today, calendar: Self.testCalendar)
        let monthSpread = DataModel.Spread(period: .month, date: today, calendar: Self.testCalendar)
        let context = try await Self.makeContext(today: today, tasks: [task], spreads: [daySpread, monthSpread])

        #expect(!OverdueCardView.sections(for: daySpread, context: context).isEmpty)
        #expect(OverdueCardView.sections(for: monthSpread, context: context).isEmpty)
    }

    // MARK: - Year

    /// Setup: a year spread for the same year as today (registered, no day/multiday/month spread
    /// exists for today).
    /// Expected: the overdue section is shown.
    @MainActor @Test func yearSpreadContainingTodayShowsOverdueSection() async throws {
        let today = Self.date(2027, 1, 1)
        let lastYear = Self.date(2025, 1, 1)
        let task = DataModel.Task(
            title: "Overdue",
            date: lastYear,
            period: .year,
            status: .open,
            currentAssignments: [Assignment(period: .year, date: lastYear, status: .open)]
        )
        let thisYearSpread = DataModel.Spread(period: .year, date: today, calendar: Self.testCalendar)
        let context = try await Self.makeContext(today: today, tasks: [task], spreads: [thisYearSpread])

        let sections = OverdueCardView.sections(for: thisYearSpread, context: context)

        #expect(sections.count == 1)
        #expect(sections.first?.entries.map(\.id) == [task.id])
    }

    /// Setup: a year spread for a year other than today's.
    /// Expected: no sections.
    @MainActor @Test func yearSpreadNotContainingTodayShowsNoSection() async throws {
        let today = Self.date(2027, 1, 1)
        let context = try await Self.makeContext(today: today)
        let otherYearSpread = DataModel.Spread(period: .year, date: Self.date(2025, 1, 1), calendar: Self.testCalendar)

        #expect(OverdueCardView.sections(for: otherYearSpread, context: context).isEmpty)
    }

    /// Setup: both a month spread for today's month and its parent year spread exist and are
    /// registered.
    /// Expected: the overdue section is shown only on the month spread -- the year spread shows
    /// nothing despite also containing today.
    @MainActor @Test func monthSpreadTakesPriorityOverParentYearSpread() async throws {
        let today = Self.date(2026, 2, 15)
        let overdueMonth = Self.date(2026, 1, 1)
        let task = DataModel.Task(
            title: "Overdue",
            date: overdueMonth,
            period: .month,
            status: .open,
            currentAssignments: [Assignment(period: .month, date: overdueMonth, status: .open)]
        )
        let monthSpread = DataModel.Spread(period: .month, date: today, calendar: Self.testCalendar)
        let yearSpread = DataModel.Spread(period: .year, date: today, calendar: Self.testCalendar)
        let context = try await Self.makeContext(today: today, tasks: [task], spreads: [monthSpread, yearSpread])

        #expect(!OverdueCardView.sections(for: monthSpread, context: context).isEmpty)
        #expect(OverdueCardView.sections(for: yearSpread, context: context).isEmpty)
    }

    // MARK: - Multiday

    /// Setup: a multiday spread whose range contains today (today falls strictly inside the
    /// range), registered, with no day spread for today.
    /// Expected: the overdue section is shown.
    @MainActor @Test func multidaySpreadContainingTodayShowsOverdueSection() async throws {
        let today = Self.date(2026, 6, 3)
        let overdueDate = Self.date(2026, 5, 1)
        let task = DataModel.Task(
            title: "Overdue",
            date: overdueDate,
            period: .day,
            status: .open,
            currentAssignments: [Assignment(period: .day, date: overdueDate, status: .open)]
        )
        let multidaySpread = DataModel.Spread(
            startDate: Self.date(2026, 6, 1),
            endDate: Self.date(2026, 6, 7),
            calendar: Self.testCalendar
        )
        let context = try await Self.makeContext(today: today, tasks: [task], spreads: [multidaySpread])

        let sections = OverdueCardView.sections(for: multidaySpread, context: context)

        #expect(sections.count == 1)
        #expect(sections.first?.entries.map(\.id) == [task.id])
    }

    /// Setup: a multiday spread where today falls exactly on the range's start/end boundary,
    /// registered in both contexts.
    /// Expected: the overdue section is shown for both boundary dates (inclusive range).
    @MainActor @Test func multidaySpreadBoundaryDatesAreInclusive() async throws {
        let startBoundaryToday = Self.date(2026, 6, 1)
        let endBoundaryToday = Self.date(2026, 6, 7)
        let overdueDate = Self.date(2026, 5, 1)
        let task = DataModel.Task(
            title: "Overdue",
            date: overdueDate,
            period: .day,
            status: .open,
            currentAssignments: [Assignment(period: .day, date: overdueDate, status: .open)]
        )
        let multidaySpread = DataModel.Spread(
            startDate: Self.date(2026, 6, 1),
            endDate: Self.date(2026, 6, 7),
            calendar: Self.testCalendar
        )

        let startContext = try await Self.makeContext(today: startBoundaryToday, tasks: [task], spreads: [multidaySpread])
        let endContext = try await Self.makeContext(today: endBoundaryToday, tasks: [task], spreads: [multidaySpread])

        #expect(!OverdueCardView.sections(for: multidaySpread, context: startContext).isEmpty)
        #expect(!OverdueCardView.sections(for: multidaySpread, context: endContext).isEmpty)
    }

    /// Setup: a multiday spread whose range does not contain today.
    /// Expected: no sections.
    @MainActor @Test func multidaySpreadNotContainingTodayShowsNoSection() async throws {
        let today = Self.date(2026, 8, 1)
        let context = try await Self.makeContext(today: today)
        let multidaySpread = DataModel.Spread(
            startDate: Self.date(2026, 6, 1),
            endDate: Self.date(2026, 6, 7),
            calendar: Self.testCalendar
        )

        #expect(OverdueCardView.sections(for: multidaySpread, context: context).isEmpty)
    }

    /// Setup: a multiday spread containing today and its overlapping parent month spread both
    /// exist and are registered.
    /// Expected: the overdue section is shown only on the multiday spread (more granular per
    /// `bestSpread`'s priority cascade) -- the month spread shows nothing.
    @MainActor @Test func multidaySpreadTakesPriorityOverMonthSpread() async throws {
        let today = Self.date(2026, 6, 3)
        let overdueDate = Self.date(2026, 5, 1)
        let task = DataModel.Task(
            title: "Overdue",
            date: overdueDate,
            period: .day,
            status: .open,
            currentAssignments: [Assignment(period: .day, date: overdueDate, status: .open)]
        )
        let multidaySpread = DataModel.Spread(
            startDate: Self.date(2026, 6, 1),
            endDate: Self.date(2026, 6, 7),
            calendar: Self.testCalendar
        )
        let monthSpread = DataModel.Spread(period: .month, date: today, calendar: Self.testCalendar)
        let context = try await Self.makeContext(today: today, tasks: [task], spreads: [multidaySpread, monthSpread])

        #expect(!OverdueCardView.sections(for: multidaySpread, context: context).isEmpty)
        #expect(OverdueCardView.sections(for: monthSpread, context: context).isEmpty)
    }

    // MARK: - Empty overdue items

    /// Setup: a day spread matching today (registered, resolves as `bestSpread`), but there are
    /// no overdue tasks anywhere in the journal.
    /// Expected: no sections, even though the spread is the most granular match for today.
    @MainActor @Test func noOverdueItemsShowsNoSectionEvenWhenSpreadRepresentsToday() async throws {
        let today = Self.date(2026, 1, 12)
        let spread = DataModel.Spread(period: .day, date: today, calendar: Self.testCalendar)
        let context = try await Self.makeContext(today: today, spreads: [spread])

        #expect(OverdueCardView.sections(for: spread, context: context).isEmpty)
    }

    // MARK: - Read-only row configuration

    /// Setup: an overdue task's row configuration, as produced by the overdue card.
    /// Expected: the row is locked down -- no inline title editing, no context menu, and
    /// `onRowTap`/`onStatusIconTap` are both wired (read-only review surface).
    @MainActor @Test func rowConfigurationIsReadOnly() async throws {
        let today = Self.date(2026, 1, 12)
        let overdueDate = Self.date(2026, 1, 10)
        let task = DataModel.Task(
            title: "Overdue",
            date: overdueDate,
            period: .day,
            status: .open,
            currentAssignments: [Assignment(period: .day, date: overdueDate, status: .open)]
        )
        let spread = DataModel.Spread(period: .day, date: today, calendar: Self.testCalendar)
        let context = try await Self.makeContext(today: today, tasks: [task], spreads: [spread])

        let section = try #require(OverdueCardView.sections(for: spread, context: context).first)
        let configuration = try #require(section.configurationMap?[DataModel.Task.configurationKey])

        #expect(configuration.onTitleCommit == nil)
        #expect(configuration.actions.isEmpty)
        #expect(configuration.onRowTap != nil)
        #expect(configuration.onStatusIconTap != nil)
    }

    /// Setup: tapping the row (not the status icon) for a task whose source is a concrete spread.
    /// Expected: the coordinator navigates directly to that spread -- no alert, no confirmation.
    @MainActor @Test func rowTapOnSpreadSourcedTaskNavigatesDirectly() async throws {
        let today = Self.date(2026, 1, 12)
        let overdueDate = Self.date(2026, 1, 10)
        let sourceSpread = DataModel.Spread(period: .day, date: overdueDate, calendar: Self.testCalendar)
        let task = DataModel.Task(
            title: "Overdue",
            date: overdueDate,
            period: .day,
            status: .open,
            currentAssignments: [Assignment(period: .day, date: overdueDate, spreadID: sourceSpread.id, status: .open)]
        )
        let spread = DataModel.Spread(period: .day, date: today, calendar: Self.testCalendar)
        let context = try await Self.makeContext(today: today, tasks: [task], spreads: [spread, sourceSpread])

        let section = try #require(OverdueCardView.sections(for: spread, context: context).first)
        let configuration = try #require(section.configurationMap?[DataModel.Task.configurationKey])

        configuration.onRowTap?(task)

        #expect(context.coordinator.selectedSpread?.id == sourceSpread.id)
        #expect(context.coordinator.activeAlert == nil)
    }

    /// Setup: the configuration built by `sections(...)` for a custom `onStatusIconTap` closure.
    /// Expected: the exact closure passed in is wired to `onStatusIconTap` -- the status icon
    /// remains fully interactive (no built-in confirmation/alert at this layer); the calling
    /// view (`OverdueCardView.body`) owns the actual rotate + grace-period behavior.
    @MainActor @Test func statusIconTapUsesTheSuppliedClosure() async throws {
        let today = Self.date(2026, 1, 12)
        let overdueDate = Self.date(2026, 1, 10)
        let task = DataModel.Task(
            title: "Overdue",
            date: overdueDate,
            period: .day,
            status: .open,
            currentAssignments: [Assignment(period: .day, date: overdueDate, status: .open)]
        )
        let spread = DataModel.Spread(period: .day, date: today, calendar: Self.testCalendar)
        let context = try await Self.makeContext(today: today, tasks: [task], spreads: [spread])

        var tappedEntryIDs: [UUID] = []
        let section = try #require(
            OverdueCardView.sections(
                for: spread,
                context: context,
                onStatusIconTap: { entry in tappedEntryIDs.append(entry.id) }
            ).first
        )
        let configuration = try #require(section.configurationMap?[DataModel.Task.configurationKey])

        configuration.onStatusIconTap?(task)

        #expect(tappedEntryIDs == [task.id])
        #expect(context.coordinator.activeAlert == nil)
    }

    // MARK: - Grace period

    /// Setup: a task that has already left `overdueTaskItems` (status is `.complete`, so it's
    /// no longer open/overdue) but is still within its grace window, passed via `graceTaskIDs`.
    /// Expected: it still appears in the card's entries, using its live (complete) status, with
    /// the snapshotted source key from `graceSourceKeys` available for the chip.
    @MainActor @Test func graceTaskStillAppearsAfterLeavingOverdueTaskItems() async throws {
        let today = Self.date(2026, 1, 12)
        let overdueDate = Self.date(2026, 1, 10)
        let completedTask = DataModel.Task(
            title: "Just completed",
            date: overdueDate,
            period: .day,
            status: .complete,
            currentAssignments: [Assignment(period: .day, date: overdueDate, status: .complete)]
        )
        let spread = DataModel.Spread(period: .day, date: today, calendar: Self.testCalendar)
        let context = try await Self.makeContext(today: today, tasks: [completedTask], spreads: [spread])
        let snapshotKey = TaskReviewSourceKey(kind: .spread(id: spread.id, period: .day, date: overdueDate))

        let sections = OverdueCardView.sections(
            for: spread,
            context: context,
            graceTaskIDs: [completedTask.id],
            graceSourceKeys: [completedTask.id: snapshotKey]
        )

        let section = try #require(sections.first)
        #expect(section.entries.map(\.id) == [completedTask.id])
        #expect((section.entries.first as? DataModel.Task)?.status == .complete)

        let configuration = try #require(section.configurationMap?[DataModel.Task.configurationKey])
        let chips = configuration.getChips?(completedTask) ?? []
        #expect(chips.map(\.title) == [snapshotKey.title])
    }

    /// Setup: a grace-period task ID that no longer exists in `journalManager.tasks` at all
    /// (e.g. deleted).
    /// Expected: it's silently skipped rather than crashing or producing a placeholder entry.
    @MainActor @Test func graceTaskIDWithNoMatchingTaskIsSkipped() async throws {
        let today = Self.date(2026, 1, 12)
        let spread = DataModel.Spread(period: .day, date: today, calendar: Self.testCalendar)
        let context = try await Self.makeContext(today: today, spreads: [spread])

        let sections = OverdueCardView.sections(
            for: spread,
            context: context,
            graceTaskIDs: [UUID()]
        )

        #expect(sections.isEmpty)
    }

    /// Setup: a task that is both live-overdue (in `overdueTaskItems`) AND happens to also be
    /// listed in `graceTaskIDs` (e.g. a stale grace entry that never got cleared).
    /// Expected: it appears exactly once -- no duplicate row.
    @MainActor @Test func taskInBothLiveAndGraceListsAppearsOnce() async throws {
        let today = Self.date(2026, 1, 12)
        let overdueDate = Self.date(2026, 1, 10)
        let task = DataModel.Task(
            title: "Overdue",
            date: overdueDate,
            period: .day,
            status: .open,
            currentAssignments: [Assignment(period: .day, date: overdueDate, status: .open)]
        )
        let spread = DataModel.Spread(period: .day, date: today, calendar: Self.testCalendar)
        let context = try await Self.makeContext(today: today, tasks: [task], spreads: [spread])

        let sections = OverdueCardView.sections(
            for: spread,
            context: context,
            graceTaskIDs: [task.id]
        )

        #expect(sections.first?.entries.map(\.id) == [task.id])
    }

    /// Setup: three open overdue tasks with deliberately out-of-order `date`/`createdDate`
    /// (the array is constructed in scrambled `createdDate` order, mimicking
    /// `JournalManager.tasks`'s own createdDate-based sort, which is unrelated to task date).
    /// Expected: entries come back sorted strictly by date, ignoring `createdDate`/insertion order.
    @MainActor @Test func entriesAreSortedByDateNotInsertionOrder() async throws {
        let today = Self.date(2026, 1, 12)
        let earliest = Self.date(2026, 1, 5)
        let middle = Self.date(2026, 1, 8)
        let latest = Self.date(2026, 1, 10)

        // Constructed out of date order, with createdDate also scrambled relative to date,
        // so a createdDate-based sort would NOT happen to match the expected date order.
        let taskC = DataModel.Task(
            title: "C",
            date: latest,
            period: .day,
            status: .open,
            currentAssignments: [Assignment(period: .day, date: latest, status: .open)]
        )
        let taskA = DataModel.Task(
            title: "A",
            date: earliest,
            period: .day,
            status: .open,
            currentAssignments: [Assignment(period: .day, date: earliest, status: .open)]
        )
        let taskB = DataModel.Task(
            title: "B",
            date: middle,
            period: .day,
            status: .open,
            currentAssignments: [Assignment(period: .day, date: middle, status: .open)]
        )
        let spread = DataModel.Spread(period: .day, date: today, calendar: Self.testCalendar)
        let context = try await Self.makeContext(today: today, tasks: [taskC, taskA, taskB], spreads: [spread])

        let sections = OverdueCardView.sections(for: spread, context: context)

        #expect(sections.first?.entries.map(\.title) == ["A", "B", "C"])
    }

    /// Setup: a month-period overdue task with `date` set to the last day of January, alongside
    /// a day-period overdue task on January 15 -- a case where raw date comparison and the
    /// period-normalized "conventional" ordering disagree. Raw dates would put the month task
    /// (Jan 31) after the day task (Jan 15); period-normalized, the month task's date normalizes
    /// to Jan 1 (the start of its month), which sorts *before* Jan 15.
    /// Expected: entries follow the period-normalized order (month task first), matching how
    /// Year's month cards and Month's day sections already order mixed-period entries -- not raw
    /// date order.
    @MainActor @Test func entriesAreSortedByPeriodNormalizedDateNotRawDate() async throws {
        let today = Self.date(2026, 2, 15)
        let monthTaskDate = Self.date(2026, 1, 31)
        let dayTaskDate = Self.date(2026, 1, 15)

        let monthTask = DataModel.Task(
            title: "Month task",
            date: monthTaskDate,
            period: .month,
            status: .open,
            currentAssignments: [Assignment(period: .month, date: monthTaskDate, status: .open)]
        )
        let dayTask = DataModel.Task(
            title: "Day task",
            date: dayTaskDate,
            period: .day,
            status: .open,
            currentAssignments: [Assignment(period: .day, date: dayTaskDate, status: .open)]
        )
        let spread = DataModel.Spread(period: .day, date: today, calendar: Self.testCalendar)
        let context = try await Self.makeContext(today: today, tasks: [dayTask, monthTask], spreads: [spread])

        let sections = OverdueCardView.sections(for: spread, context: context)

        #expect(sections.first?.entries.map(\.title) == ["Month task", "Day task"])
    }

    /// Setup: a task in its grace period (status `.complete`, no longer live-overdue) whose date
    /// falls *earlier* than a live overdue task's date.
    /// Expected: the grace-period task keeps its date-correct position (first) rather than being
    /// appended after the live task -- completing a task must not move it to the end of the list.
    @MainActor @Test func graceTaskKeepsItsDateOrderedPositionRatherThanMovingToTheEnd() async throws {
        let today = Self.date(2026, 1, 12)
        let earlierDate = Self.date(2026, 1, 5)
        let laterDate = Self.date(2026, 1, 10)

        let justCompletedTask = DataModel.Task(
            title: "Just completed",
            date: earlierDate,
            period: .day,
            status: .complete,
            currentAssignments: [Assignment(period: .day, date: earlierDate, status: .complete)]
        )
        let stillOpenTask = DataModel.Task(
            title: "Still open",
            date: laterDate,
            period: .day,
            status: .open,
            currentAssignments: [Assignment(period: .day, date: laterDate, status: .open)]
        )
        let spread = DataModel.Spread(period: .day, date: today, calendar: Self.testCalendar)
        let context = try await Self.makeContext(
            today: today,
            tasks: [justCompletedTask, stillOpenTask],
            spreads: [spread]
        )

        let sections = OverdueCardView.sections(
            for: spread,
            context: context,
            graceTaskIDs: [justCompletedTask.id]
        )

        #expect(sections.first?.entries.map(\.title) == ["Just completed", "Still open"])
    }

    /// Setup: tapping the row for an Inbox-sourced overdue task (no spread assignment).
    /// Expected: an informational alert is shown -- there's nothing to navigate to.
    @MainActor @Test func rowTapOnInboxSourcedTaskShowsInformationalAlert() async throws {
        let today = Self.date(2026, 1, 12)
        let overdueDate = Self.date(2026, 1, 10)
        let task = DataModel.Task(
            title: "Overdue",
            date: overdueDate,
            period: .day,
            status: .open
        )
        let spread = DataModel.Spread(period: .day, date: today, calendar: Self.testCalendar)
        let context = try await Self.makeContext(today: today, tasks: [task], spreads: [spread])

        let section = try #require(OverdueCardView.sections(for: spread, context: context).first)
        let configuration = try #require(section.configurationMap?[DataModel.Task.configurationKey])

        configuration.onRowTap?(task)

        #expect(context.coordinator.selectedSpread == nil)
        guard case .alert(let model) = context.coordinator.activeAlert else {
            Issue.record("Expected an active alert")
            return
        }
        #expect(model.id == "overdueCardInboxNotice")
    }
}
