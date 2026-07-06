#if DEBUG
import Foundation

/// Predefined mock data sets for debug testing.
///
/// Each data set represents a specific testing scenario:
/// - `empty`: Clears all data for testing empty states
/// - `baseline`: Standard year/month/day spreads for today
/// - `multiday`: Multiday ranges including preset and custom
/// - `boundary`: Month and year transition dates
/// - `scenario*`: hidden localhost UI-test fixtures for deterministic scenario coverage
enum MockDataSet: String, CaseIterable {
    /// Clears all data (empty state).
    case empty

    /// Baseline year/month/day spreads for today with sample entries.
    case baseline

    /// Multiday ranges including preset-based and custom ranges.
    case multiday

    /// Spreads at month and year boundaries for edge case testing.
    case boundary

    /// Hidden scenario fixture: direct assignment to an existing spread.
    case scenarioAssignmentExistingSpread

    /// Hidden scenario fixture: task creation falls back to Inbox.
    case scenarioAssignmentInboxFallback

    /// Hidden scenario fixture: Inbox task becomes eligible when a spread is created.
    case scenarioInboxResolution

    /// Hidden scenario fixture: month-bounded migration.
    case scenarioMigrationMonthBound

    /// Hidden scenario fixture: day migration supersedes month prompt once created.
    case scenarioMigrationDayUpgrade

    /// Hidden scenario fixture: finer day spread already exists, so month prompt is suppressed.
    case scenarioMigrationDaySuperseded

    /// Hidden scenario fixture: task reassignment and migrated history.
    case scenarioReassignment

    /// Hidden scenario fixture: global overdue review by assignment period.
    case scenarioOverdueReview

    /// Hidden scenario fixture: overdue fallback for Inbox tasks.
    case scenarioOverdueInbox

    /// Hidden scenario fixture: overdue remains available in traditional mode while migration stays absent.
    case scenarioTraditionalOverdue

    /// Hidden scenario fixture: notes excluded from migration/overdue review.
    case scenarioNoteExclusions

    /// Hidden scenario fixture: multiday spreads show empty days with adaptive section layout.
    case scenarioMultidayLayout

    /// Hidden scenario fixture: iPad header spread navigator across conventional and traditional flows.
    case scenarioSpreadNavigator

    // MARK: - Display

    static var debugMenuCases: [MockDataSet] {
        allCases.filter(\.isVisibleInDebugMenu)
    }

    var isScenarioFixture: Bool {
        !isVisibleInDebugMenu
    }

    var isVisibleInDebugMenu: Bool {
        switch self {
        case .empty, .baseline, .multiday, .boundary:
            return true
        case .scenarioAssignmentExistingSpread,
                .scenarioAssignmentInboxFallback,
                .scenarioInboxResolution,
                .scenarioMigrationMonthBound,
                .scenarioMigrationDayUpgrade,
                .scenarioMigrationDaySuperseded,
                .scenarioReassignment,
                .scenarioOverdueReview,
                .scenarioOverdueInbox,
                .scenarioTraditionalOverdue,
                .scenarioNoteExclusions,
                .scenarioMultidayLayout,
                .scenarioSpreadNavigator:
            return false
        }
    }

    /// The display name shown in the Debug menu.
    var displayName: String {
        switch self {
        case .empty:
            return "Empty"
        case .baseline:
            return "Baseline"
        case .multiday:
            return "Multiday Ranges"
        case .boundary:
            return "Boundary Dates"
        case .scenarioAssignmentExistingSpread:
            return "Scenario: Assignment Existing Spread"
        case .scenarioAssignmentInboxFallback:
            return "Scenario: Assignment Inbox Fallback"
        case .scenarioInboxResolution:
            return "Scenario: Inbox Resolution"
        case .scenarioMigrationMonthBound:
            return "Scenario: Migration Month Bound"
        case .scenarioMigrationDayUpgrade:
            return "Scenario: Migration Day Upgrade"
        case .scenarioMigrationDaySuperseded:
            return "Scenario: Migration Day Superseded"
        case .scenarioReassignment:
            return "Scenario: Reassignment"
        case .scenarioOverdueReview:
            return "Scenario: Overdue Review"
        case .scenarioOverdueInbox:
            return "Scenario: Overdue Inbox"
        case .scenarioTraditionalOverdue:
            return "Scenario: Traditional Overdue"
        case .scenarioNoteExclusions:
            return "Scenario: Note Exclusions"
        case .scenarioMultidayLayout:
            return "Scenario: Multiday Layout"
        case .scenarioSpreadNavigator:
            return "Scenario: Spread Navigator"
        }
    }

    /// A description of what this data set contains.
    var description: String {
        switch self {
        case .empty:
            return "Clears all spreads, tasks, events, and notes."
        case .baseline:
            return "Year, month, and day spreads for today with sample entries."
        case .multiday:
            return "Multiday spreads using This Week, Next Week presets and custom ranges."
        case .boundary:
            return "Spreads across month and year boundaries for edge case testing."
        case .scenarioAssignmentExistingSpread:
            return "Hidden UI-test fixture for direct assignment to an existing spread."
        case .scenarioAssignmentInboxFallback:
            return "Hidden UI-test fixture for task creation routing to Inbox."
        case .scenarioInboxResolution:
            return "Hidden UI-test fixture for Inbox tasks that become migratable after spread creation."
        case .scenarioMigrationMonthBound:
            return "Hidden UI-test fixture for desired-assignment-bounded migration."
        case .scenarioMigrationDayUpgrade:
            return "Hidden UI-test fixture for most-granular valid destination migration behavior."
        case .scenarioMigrationDaySuperseded:
            return "Hidden UI-test fixture where an existing day spread suppresses the month migration prompt."
        case .scenarioReassignment:
            return "Hidden UI-test fixture for edit-time reassignment and migrated history."
        case .scenarioOverdueReview:
            return "Hidden UI-test fixture for overdue review by assignment granularity."
        case .scenarioOverdueInbox:
            return "Hidden UI-test fixture for Inbox overdue fallback."
        case .scenarioTraditionalOverdue:
            return "Hidden UI-test fixture for overdue access in traditional mode without migration UI."
        case .scenarioNoteExclusions:
            return "Hidden UI-test fixture for note exclusion assertions."
        case .scenarioMultidayLayout:
            return "Hidden UI-test fixture for multiday empty-day layout and task-only sections."
        case .scenarioSpreadNavigator:
            return "Hidden UI-test fixture for the iPad header spread navigator."
        }
    }

    // MARK: - Data Generation

    /// Container for generated mock data.
    struct GeneratedData {
        let spreads: [DataModel.Spread]
        let tasks: [DataModel.Task]
        let events: [DataModel.Event]
        let notes: [DataModel.Note]
        let lists: [DataModel.List]
        let tags: [DataModel.Tag]

        init(
            spreads: [DataModel.Spread],
            tasks: [DataModel.Task],
            events: [DataModel.Event],
            notes: [DataModel.Note],
            lists: [DataModel.List] = [],
            tags: [DataModel.Tag] = []
        ) {
            self.spreads = spreads
            self.tasks = tasks
            self.events = events
            self.notes = notes
            self.lists = lists
            self.tags = tags
        }
    }

    /// Generates the mock data for this data set.
    ///
    /// - Parameters:
    ///   - calendar: The calendar to use for date calculations.
    ///   - today: The reference date (typically the current date).
    /// - Returns: The generated spreads, tasks, events, and notes.
    func generateData(calendar: Calendar, today: Date) -> GeneratedData {
        switch self {
        case .empty:
            return GeneratedData(spreads: [], tasks: [], events: [], notes: [])

        case .baseline:
            return generateBaselineData(calendar: calendar, today: today)

        case .multiday:
            return generateMultidayData(calendar: calendar, today: today)

        case .boundary:
            return generateBoundaryData(calendar: calendar, today: today)

        case .scenarioAssignmentExistingSpread:
            return generateScenarioAssignmentExistingSpread(calendar: calendar, today: today)
        case .scenarioAssignmentInboxFallback:
            return generateScenarioAssignmentInboxFallback(calendar: calendar, today: today)
        case .scenarioInboxResolution:
            return generateScenarioInboxResolution(calendar: calendar, today: today)
        case .scenarioMigrationMonthBound:
            return generateScenarioMigrationMonthBound(calendar: calendar, today: today)
        case .scenarioMigrationDayUpgrade:
            return generateScenarioMigrationDayUpgrade(calendar: calendar, today: today)
        case .scenarioMigrationDaySuperseded:
            return generateScenarioMigrationDaySuperseded(calendar: calendar, today: today)
        case .scenarioReassignment:
            return generateScenarioReassignment(calendar: calendar, today: today)
        case .scenarioOverdueReview:
            return generateScenarioOverdueReview(calendar: calendar, today: today)
        case .scenarioOverdueInbox:
            return generateScenarioOverdueInbox(calendar: calendar, today: today)
        case .scenarioTraditionalOverdue:
            return generateScenarioTraditionalOverdue(calendar: calendar, today: today)
        case .scenarioNoteExclusions:
            return generateScenarioNoteExclusions(calendar: calendar, today: today)
        case .scenarioMultidayLayout:
            return generateScenarioMultidayLayout(calendar: calendar, today: today)
        case .scenarioSpreadNavigator:
            return generateScenarioSpreadNavigator(calendar: calendar, today: today)
        }
    }

    // MARK: - Private Generators

    private func generateBaselineData(calendar: Calendar, today: Date) -> GeneratedData {
        var spreads: [DataModel.Spread] = []
        var tasks: [DataModel.Task] = []
        var events: [DataModel.Event] = []
        var notes: [DataModel.Note] = []
        var lists: [DataModel.List] = []
        var tags: [DataModel.Tag] = []

        let workList = DataModel.List(name: "Work")
        let personalList = DataModel.List(name: "Personal")
        let errandsList = DataModel.List(name: "Errands")
        let healthList = DataModel.List(name: "Health")
        lists.append(contentsOf: [errandsList, healthList, personalList, workList])

        let focusTag = DataModel.Tag(name: "Focus")
        let planningTag = DataModel.Tag(name: "Planning")
        let homeTag = DataModel.Tag(name: "Home")
        let waitingTag = DataModel.Tag(name: "Waiting")
        let urgentTag = DataModel.Tag(name: "Urgent")
        tags.append(contentsOf: [focusTag, homeTag, planningTag, urgentTag, waitingTag])

        // Create year spread for current year
        let yearSpread = DataModel.Spread(period: .year, date: today, calendar: calendar)
        spreads.append(yearSpread)

        // Create month spread for current month
        let monthSpread = DataModel.Spread(period: .month, date: today, calendar: calendar)
        spreads.append(monthSpread)

        // Create day spread for today
        let daySpread = DataModel.Spread(period: .day, date: today, calendar: calendar)
        spreads.append(daySpread)

        // Create day spread for tomorrow
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) {
            let tomorrowSpread = DataModel.Spread(period: .day, date: tomorrow, calendar: calendar)
            spreads.append(tomorrowSpread)
        }

        // Create "This Week" multiday spread
        if let thisWeekSpread = DataModel.Spread(
            preset: .thisWeek,
            today: today,
            calendar: calendar,
            firstWeekday: .sunday
        ) {
            spreads.append(thisWeekSpread)
        }

        let normalizedDay = Period.day.normalizeDate(today, calendar: calendar)
        let normalizedMonth = Period.month.normalizeDate(today, calendar: calendar)
        let normalizedYear = Period.year.normalizeDate(today, calendar: calendar)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let normalizedTomorrow = Period.day.normalizeDate(tomorrow, calendar: calendar)

        func time(dayOffset: Int = 0, hour: Int, minute: Int = 0) -> Date {
            let day = calendar.date(byAdding: .day, value: dayOffset, to: today) ?? today
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }

        tasks.append(DataModel.Task(
            title: "Review project timeline",
            body: "Check milestone dates and confirm the next delivery window.",
            priority: .high,
            date: time(hour: 9),
            period: .day,
            currentAssignments: [Assignment(period: .day, date: normalizedDay, status: .open)],
            list: workList,
            tags: [planningTag, focusTag]
        ))
        tasks.append(DataModel.Task(
            title: "Send weekly status update",
            body: "Include blockers, shipped work, and decisions needed.",
            priority: .medium,
            date: time(hour: 16),
            period: .day,
            currentAssignments: [Assignment(period: .day, date: normalizedDay, status: .open)],
            list: workList,
            tags: [waitingTag]
        ))
        tasks.append(DataModel.Task(
            title: "Schedule team meeting",
            date: time(hour: 11),
            period: .day,
            status: .complete,
            currentAssignments: [Assignment(period: .day, date: normalizedDay, status: .complete)],
            list: workList,
            tags: [planningTag]
        ))
        tasks.append(DataModel.Task(
            title: "Pick up groceries",
            priority: .medium,
            date: time(hour: 17, minute: 30),
            period: .day,
            currentAssignments: [Assignment(period: .day, date: normalizedDay, status: .open)],
            list: errandsList,
            tags: [homeTag]
        ))
        tasks.append(DataModel.Task(
            title: "Book dentist appointment",
            date: time(hour: 13),
            period: .day,
            currentAssignments: [Assignment(period: .day, date: normalizedDay, status: .open)],
            list: personalList,
            tags: [waitingTag]
        ))
        tasks.append(DataModel.Task(
            title: "Call insurance about claim",
            priority: .low,
            date: time(hour: 10),
            period: .day,
            currentAssignments: [Assignment(period: .day, date: normalizedDay, status: .open)]
            // No list/tags — exercises the "No list"/"No tag" fallback buckets for .list and .tag grouping.
        ))
        tasks.append(DataModel.Task(
            title: "Cancel unused subscription",
            priority: .low,
            date: time(hour: 8),
            period: .day,
            status: .cancelled,
            currentAssignments: [Assignment(period: .day, date: normalizedDay, status: .cancelled)],
            list: personalList,
            tags: [waitingTag]
        ))
        tasks.append(DataModel.Task(
            title: "Morning workout",
            priority: .medium,
            date: time(hour: 6, minute: 30),
            period: .day,
            currentAssignments: [Assignment(period: .day, date: normalizedDay, status: .open)],
            list: healthList,
            tags: [focusTag, urgentTag]
        ))
        tasks.append(DataModel.Task(
            title: "Take vitamins",
            date: time(hour: 7),
            period: .day,
            currentAssignments: [Assignment(period: .day, date: normalizedDay, status: .open)],
            list: healthList
            // No tags — exercises the "No tag" fallback bucket for .tag grouping.
        ))
        tasks.append(DataModel.Task(
            title: "Plan weekend meals",
            date: tomorrow,
            period: .day,
            currentAssignments: [Assignment(period: .day, date: normalizedTomorrow, status: .open)],
            list: personalList,
            tags: [homeTag, planningTag]
        ))
        tasks.append(DataModel.Task(
            title: "Draft monthly budget",
            priority: .low,
            date: today,
            period: .month,
            currentAssignments: [Assignment(period: .month, date: normalizedMonth, status: .open)],
            list: personalList,
            tags: [planningTag]
        ))
        tasks.append(DataModel.Task(
            title: "Define yearly learning theme",
            date: today,
            period: .year,
            currentAssignments: [Assignment(period: .year, date: normalizedYear, status: .open)],
            tags: [focusTag]
        ))
        if let thisWeekSpread = DataModel.Spread(preset: .thisWeek, today: today, calendar: calendar, firstWeekday: .sunday) {
            let normalizedMultiday = Period.multiday.normalizeDate(thisWeekSpread.date, calendar: calendar)
            tasks.append(DataModel.Task(
                title: "Plan the week",
                date: today,
                period: .multiday,
                currentAssignments: [Assignment(period: .multiday, date: normalizedMultiday, status: .open)],
                list: workList,
                tags: [planningTag]
            ))
        }

        events.append(DataModel.Event(
            title: "Team standup",
            timing: .timed,
            startDate: today,
            endDate: today,
            startTime: time(hour: 9, minute: 30),
            endTime: time(hour: 9, minute: 50)
        ))
        events.append(DataModel.Event(
            title: "Design review",
            timing: .timed,
            startDate: today,
            endDate: today,
            startTime: time(hour: 14),
            endTime: time(hour: 15)
        ))
        events.append(DataModel.Event(
            title: "Focus block",
            timing: .timed,
            startDate: today,
            endDate: today,
            startTime: time(hour: 10),
            endTime: time(hour: 12)
        ))
        events.append(DataModel.Event(
            title: "Renew library books",
            timing: .allDay,
            startDate: today,
            endDate: today
        ))
        events.append(DataModel.Event(
            title: "Long weekend trip",
            timing: .multiDay,
            startDate: today,
            endDate: calendar.date(byAdding: .day, value: 2, to: today) ?? today
        ))
        events.append(DataModel.Event(
            title: "Coffee with Sam",
            timing: .timed,
            startDate: tomorrow,
            endDate: tomorrow,
            startTime: time(dayOffset: 1, hour: 8, minute: 30),
            endTime: time(dayOffset: 1, hour: 9, minute: 15)
        ))

        notes.append(DataModel.Note(
            title: "Meeting notes",
            content: "Discussed project timeline and milestones.",
            date: today,
            period: .day,
            currentAssignments: [Assignment(period: .day, date: normalizedDay, status: .active)],
            list: workList,
            tags: [planningTag]
        ))
        notes.append(DataModel.Note(
            title: "Ideas for next sprint",
            content: "Explore a tighter day spread toolbar, faster list switching, and clearer tag chips.",
            date: today,
            period: .day,
            currentAssignments: [Assignment(period: .day, date: normalizedDay, status: .active)],
            list: workList,
            tags: [focusTag]
        ))
        notes.append(DataModel.Note(
            title: "Home project notes",
            content: "Measure the hallway shelf before buying brackets.",
            date: today,
            period: .day,
            currentAssignments: [Assignment(period: .day, date: normalizedDay, status: .active)],
            list: personalList,
            tags: [homeTag]
        ))
        notes.append(DataModel.Note(
            title: "Quick reminder",
            content: "Call back the plumber about the quote.",
            date: today,
            period: .day,
            currentAssignments: [Assignment(period: .day, date: normalizedDay, status: .active)]
            // No list/tags — exercises the nil-bucket fallback for notes too.
        ))
        notes.append(DataModel.Note(
            title: "Monthly reflection",
            content: "Keep planning lightweight. Use lists for context, tags for intent.",
            date: today,
            period: .month,
            currentAssignments: [Assignment(period: .month, date: normalizedMonth, status: .active)],
            tags: [planningTag]
        ))

        return GeneratedData(spreads: spreads, tasks: tasks, events: events, notes: notes, lists: lists, tags: tags)
    }

    private func generateMultidayData(calendar: Calendar, today: Date) -> GeneratedData {
        var spreads: [DataModel.Spread] = []
        var tasks: [DataModel.Task] = []
        var events: [DataModel.Event] = []
        var notes: [DataModel.Note] = []

        // Create baseline spreads first
        spreads.append(DataModel.Spread(period: .year, date: today, calendar: calendar))
        spreads.append(DataModel.Spread(period: .month, date: today, calendar: calendar))
        spreads.append(DataModel.Spread(period: .day, date: today, calendar: calendar))

        // Create "This Week" multiday spread using preset
        if let thisWeekSpread = DataModel.Spread(
            preset: .thisWeek,
            today: today,
            calendar: calendar,
            firstWeekday: .sunday
        ) {
            spreads.append(thisWeekSpread)
        }

        // Create "Next Week" multiday spread using preset
        if let nextWeekSpread = DataModel.Spread(
            preset: .nextWeek,
            today: today,
            calendar: calendar,
            firstWeekday: .sunday
        ) {
            spreads.append(nextWeekSpread)
        }

        // Create custom multiday spread (5-day range starting from today)
        if let endDate = calendar.date(byAdding: .day, value: 4, to: today) {
            let customMultiday = DataModel.Spread(
                startDate: today,
                endDate: endDate,
                calendar: calendar
            )
            spreads.append(customMultiday)
        }

        // Add tasks that fall within multiday ranges
        let normalizedDay = Period.day.normalizeDate(today, calendar: calendar)
        tasks.append(DataModel.Task(
            title: "Weekly planning",
            date: today,
            period: .day,
            currentAssignments: [Assignment(period: .day, date: normalizedDay, status: .open)]
        ))

        if let dayInFuture = calendar.date(byAdding: .day, value: 3, to: today) {
            let normalizedFuture = Period.day.normalizeDate(dayInFuture, calendar: calendar)
            tasks.append(DataModel.Task(
                title: "Mid-week review",
                date: dayInFuture,
                period: .day,
                currentAssignments: [Assignment(period: .day, date: normalizedFuture, status: .open)]
            ))
        }

        // Multi-day event that spans the week
        if let eventEnd = calendar.date(byAdding: .day, value: 2, to: today) {
            events.append(DataModel.Event(
                title: "Team offsite",
                timing: .multiDay,
                startDate: today,
                endDate: eventEnd
            ))
        }

        return GeneratedData(spreads: spreads, tasks: tasks, events: events, notes: notes)
    }

    private func generateBoundaryData(calendar: Calendar, today: Date) -> GeneratedData {
        var spreads: [DataModel.Spread] = []
        var tasks: [DataModel.Task] = []
        var events: [DataModel.Event] = []
        var notes: [DataModel.Note] = []

        // Current year spread
        spreads.append(DataModel.Spread(period: .year, date: today, calendar: calendar))

        // Next year spread (for year boundary testing)
        if let nextYear = calendar.date(byAdding: .year, value: 1, to: today) {
            spreads.append(DataModel.Spread(period: .year, date: nextYear, calendar: calendar))
        }

        // Current month spread
        spreads.append(DataModel.Spread(period: .month, date: today, calendar: calendar))

        // Next month spread (for month boundary testing)
        if let nextMonth = calendar.date(byAdding: .month, value: 1, to: today) {
            spreads.append(DataModel.Spread(period: .month, date: nextMonth, calendar: calendar))
        }

        // Last day of current month
        if let lastDayOfMonth = lastDayOfMonth(for: today, calendar: calendar) {
            spreads.append(DataModel.Spread(period: .day, date: lastDayOfMonth, calendar: calendar))

            // Task on last day of month
            let normalizedLast = Period.day.normalizeDate(lastDayOfMonth, calendar: calendar)
            tasks.append(DataModel.Task(
                title: "End of month review",
                date: lastDayOfMonth,
                period: .day,
                currentAssignments: [Assignment(period: .day, date: normalizedLast, status: .open)]
            ))
        }

        // First day of next month
        if let nextMonth = calendar.date(byAdding: .month, value: 1, to: today),
           let firstDayNextMonth = nextMonth.firstDayOfMonth(calendar: calendar) {
            spreads.append(DataModel.Spread(period: .day, date: firstDayNextMonth, calendar: calendar))

            // Task on first day of next month
            let normalizedFirst = Period.day.normalizeDate(firstDayNextMonth, calendar: calendar)
            tasks.append(DataModel.Task(
                title: "Start of month planning",
                date: firstDayNextMonth,
                period: .day,
                currentAssignments: [Assignment(period: .day, date: normalizedFirst, status: .open)]
            ))
        }

        // Last day of year (Dec 31)
        if let lastDayOfYear = lastDayOfYear(for: today, calendar: calendar) {
            spreads.append(DataModel.Spread(period: .day, date: lastDayOfYear, calendar: calendar))
        }

        // First day of next year (Jan 1)
        if let nextYear = calendar.date(byAdding: .year, value: 1, to: today),
           let firstDayNextYear = nextYear.firstDayOfYear(calendar: calendar) {
            spreads.append(DataModel.Spread(period: .day, date: firstDayNextYear, calendar: calendar))
        }

        // Event spanning month boundary
        if let lastDay = lastDayOfMonth(for: today, calendar: calendar),
           let firstDayNext = calendar.date(byAdding: .day, value: 1, to: lastDay) {
            events.append(DataModel.Event(
                title: "Month-end celebration",
                timing: .multiDay,
                startDate: lastDay,
                endDate: firstDayNext
            ))
        }

        // Leap day scenarios (next leap year: 2028)
        let leapYear = nextLeapYear(after: calendar.component(.year, from: today))
        if let feb28 = calendar.date(from: DateComponents(year: leapYear, month: 2, day: 28)),
           let feb29 = calendar.date(from: DateComponents(year: leapYear, month: 2, day: 29)),
           let mar1 = calendar.date(from: DateComponents(year: leapYear, month: 3, day: 1)) {

            // February month spread for the leap year
            spreads.append(DataModel.Spread(period: .month, date: feb29, calendar: calendar))

            // Day spreads: Feb 28, Feb 29, Mar 1
            spreads.append(DataModel.Spread(period: .day, date: feb28, calendar: calendar))
            spreads.append(DataModel.Spread(period: .day, date: feb29, calendar: calendar))
            spreads.append(DataModel.Spread(period: .day, date: mar1, calendar: calendar))

            // Multiday spanning Feb 28 – Mar 1
            spreads.append(DataModel.Spread(startDate: feb28, endDate: mar1, calendar: calendar))

            // Task assigned to Feb 29
            let normalizedFeb29 = Period.day.normalizeDate(feb29, calendar: calendar)
            tasks.append(DataModel.Task(
                title: "Leap day task",
                date: feb29,
                period: .day,
                currentAssignments: [Assignment(period: .day, date: normalizedFeb29, status: .open)]
            ))

            // Note assigned to Feb 29
            notes.append(DataModel.Note(
                title: "Leap day note",
                date: feb29,
                period: .day,
                currentAssignments: [Assignment(period: .day, date: normalizedFeb29, status: .active)]
            ))
        }

        return GeneratedData(spreads: spreads, tasks: tasks, events: events, notes: notes)
    }

    // MARK: - Date Helpers

    private func lastDayOfMonth(for date: Date, calendar: Calendar) -> Date? {
        guard let startOfMonth = date.firstDayOfMonth(calendar: calendar),
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth),
              let lastDay = calendar.date(byAdding: .day, value: -1, to: nextMonth) else {
            return nil
        }
        return lastDay
    }

    private func nextLeapYear(after year: Int) -> Int {
        var candidate = year + 1
        while !isLeapYear(candidate) {
            candidate += 1
        }
        return candidate
    }

    private func isLeapYear(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    private func lastDayOfYear(for date: Date, calendar: Calendar) -> Date? {
        guard let startOfYear = date.firstDayOfYear(calendar: calendar),
              let nextYear = calendar.date(byAdding: .year, value: 1, to: startOfYear),
              let lastDay = calendar.date(byAdding: .day, value: -1, to: nextYear) else {
            return nil
        }
        return lastDay
    }
}
#endif
