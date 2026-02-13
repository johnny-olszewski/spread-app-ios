#if DEBUG
import Foundation

/// Predefined mock data sets for debug testing.
///
/// Each data set represents a specific testing scenario:
/// - `empty`: Clears all data for testing empty states
/// - `baseline`: Standard year/month/day spreads for today
/// - `multiday`: Multiday ranges including preset and custom
/// - `boundary`: Month and year transition dates
/// - `highVolume`: Large data set for performance testing
/// - `inboxNextYear`: Current year spreads with tasks dated in the following year
enum MockDataSet: String, CaseIterable {
    /// Clears all data (empty state).
    case empty

    /// Baseline year/month/day spreads for today with sample entries.
    case baseline

    /// Multiday ranges including preset-based and custom ranges.
    case multiday

    /// Spreads at month and year boundaries for edge case testing.
    case boundary

    /// Large data set for performance testing.
    case highVolume

    /// Current year spreads with next year tasks for inbox testing.
    case inboxNextYear

    // MARK: - Display

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
        case .highVolume:
            return "High Volume"
        case .inboxNextYear:
            return "Inbox (Next Year Tasks)"
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
        case .highVolume:
            return "50+ spreads and 100+ tasks for performance testing."
        case .inboxNextYear:
            return "Current year spreads only, with tasks dated next year to populate the Inbox."
        }
    }

    // MARK: - Data Generation

    /// Container for generated mock data.
    struct GeneratedData {
        let spreads: [DataModel.Spread]
        let tasks: [DataModel.Task]
        let events: [DataModel.Event]
        let notes: [DataModel.Note]
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

        case .highVolume:
            return generateHighVolumeData(calendar: calendar, today: today)
        case .inboxNextYear:
            return generateInboxNextYearData(calendar: calendar, today: today)
        }
    }

    // MARK: - Private Generators

    private func generateBaselineData(calendar: Calendar, today: Date) -> GeneratedData {
        var spreads: [DataModel.Spread] = []
        var tasks: [DataModel.Task] = []
        var events: [DataModel.Event] = []
        var notes: [DataModel.Note] = []

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

        // Sample tasks with assignments to the day spread
        let normalizedDay = Period.day.normalizeDate(today, calendar: calendar)
        tasks.append(DataModel.Task(
            title: "Review project timeline",
            date: today,
            period: .day,
            assignments: [TaskAssignment(period: .day, date: normalizedDay, status: .open)]
        ))
        tasks.append(DataModel.Task(
            title: "Send weekly status update",
            date: today,
            period: .day,
            assignments: [TaskAssignment(period: .day, date: normalizedDay, status: .open)]
        ))
        tasks.append(DataModel.Task(
            title: "Schedule team meeting",
            date: today,
            period: .day,
            assignments: [TaskAssignment(period: .day, date: normalizedDay, status: .complete)]
        ))

        // Sample event for today
        events.append(DataModel.Event(
            title: "Team standup",
            timing: .timed,
            startDate: today,
            endDate: today
        ))

        // Sample note with assignment
        notes.append(DataModel.Note(
            title: "Meeting notes",
            content: "Discussed project timeline and milestones.",
            date: today,
            period: .day,
            assignments: [NoteAssignment(period: .day, date: normalizedDay, status: .active)]
        ))

        return GeneratedData(spreads: spreads, tasks: tasks, events: events, notes: notes)
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
            assignments: [TaskAssignment(period: .day, date: normalizedDay, status: .open)]
        ))

        if let dayInFuture = calendar.date(byAdding: .day, value: 3, to: today) {
            let normalizedFuture = Period.day.normalizeDate(dayInFuture, calendar: calendar)
            tasks.append(DataModel.Task(
                title: "Mid-week review",
                date: dayInFuture,
                period: .day,
                assignments: [TaskAssignment(period: .day, date: normalizedFuture, status: .open)]
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
                assignments: [TaskAssignment(period: .day, date: normalizedLast, status: .open)]
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
                assignments: [TaskAssignment(period: .day, date: normalizedFirst, status: .open)]
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
                assignments: [TaskAssignment(period: .day, date: normalizedFeb29, status: .open)]
            ))

            // Note assigned to Feb 29
            notes.append(DataModel.Note(
                title: "Leap day note",
                date: feb29,
                period: .day,
                assignments: [NoteAssignment(period: .day, date: normalizedFeb29, status: .active)]
            ))
        }

        return GeneratedData(spreads: spreads, tasks: tasks, events: events, notes: notes)
    }

    private func generateHighVolumeData(calendar: Calendar, today: Date) -> GeneratedData {
        var spreads: [DataModel.Spread] = []
        var tasks: [DataModel.Task] = []
        var events: [DataModel.Event] = []
        var notes: [DataModel.Note] = []

        // Create year spreads for current and next 2 years (3 total)
        for yearOffset in 0...2 {
            if let yearDate = calendar.date(byAdding: .year, value: yearOffset, to: today) {
                spreads.append(DataModel.Spread(period: .year, date: yearDate, calendar: calendar))
            }
        }

        // Create month spreads for current year (12 months)
        if let startOfYear = today.firstDayOfYear(calendar: calendar) {
            for monthOffset in 0...11 {
                if let monthDate = calendar.date(byAdding: .month, value: monthOffset, to: startOfYear) {
                    spreads.append(DataModel.Spread(period: .month, date: monthDate, calendar: calendar))
                }
            }
        }

        // Create day spreads for next 60 days (fills out to ~75 total spreads)
        for dayOffset in 0...59 {
            if let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: today) {
                spreads.append(DataModel.Spread(period: .day, date: dayDate, calendar: calendar))
            }
        }

        // Create 100+ tasks spread across the days
        let taskTitles = [
            "Review document", "Send email", "Update report", "Schedule meeting",
            "Call client", "Fix bug", "Write tests", "Code review", "Deploy feature",
            "Update documentation", "Team sync", "One-on-one", "Sprint planning",
            "Retrospective", "Design review", "Research topic", "Prepare presentation",
            "Follow up", "Submit request", "Archive files"
        ]

        for i in 0..<110 {
            let dayOffset = i % 60
            if let taskDate = calendar.date(byAdding: .day, value: dayOffset, to: today) {
                let normalizedDate = Period.day.normalizeDate(taskDate, calendar: calendar)
                let title = taskTitles[i % taskTitles.count]
                let status: DataModel.Task.Status = i % 5 == 0 ? .complete : .open

                tasks.append(DataModel.Task(
                    title: "\(title) #\(i + 1)",
                    date: taskDate,
                    period: .day,
                    status: status,
                    assignments: [TaskAssignment(period: .day, date: normalizedDate, status: status == .complete ? .complete : .open)]
                ))
            }
        }

        // Create 20 events spread across the period
        for i in 0..<20 {
            let dayOffset = i * 3
            if let eventDate = calendar.date(byAdding: .day, value: dayOffset, to: today) {
                events.append(DataModel.Event(
                    title: "Event #\(i + 1)",
                    timing: i % 2 == 0 ? .allDay : .timed,
                    startDate: eventDate,
                    endDate: eventDate
                ))
            }
        }

        // Create 15 notes
        for i in 0..<15 {
            let dayOffset = i * 4
            if let noteDate = calendar.date(byAdding: .day, value: dayOffset, to: today) {
                let normalizedDate = Period.day.normalizeDate(noteDate, calendar: calendar)
                notes.append(DataModel.Note(
                    title: "Note #\(i + 1)",
                    content: "Sample content for note \(i + 1).",
                    date: noteDate,
                    period: .day,
                    assignments: [NoteAssignment(period: .day, date: normalizedDate, status: .active)]
                ))
            }
        }

        return GeneratedData(spreads: spreads, tasks: tasks, events: events, notes: notes)
    }

    private func generateInboxNextYearData(calendar: Calendar, today: Date) -> GeneratedData {
        var spreads: [DataModel.Spread] = []
        var tasks: [DataModel.Task] = []
        var events: [DataModel.Event] = []
        var notes: [DataModel.Note] = []

        // Create only current year spreads (no next-year spreads).
        spreads.append(DataModel.Spread(period: .year, date: today, calendar: calendar))
        spreads.append(DataModel.Spread(period: .month, date: today, calendar: calendar))
        spreads.append(DataModel.Spread(period: .day, date: today, calendar: calendar))

        guard let startOfCurrentYear = today.firstDayOfYear(calendar: calendar),
              let startOfNextYear = calendar.date(byAdding: .year, value: 1, to: startOfCurrentYear) else {
            return GeneratedData(spreads: spreads, tasks: tasks, events: events, notes: notes)
        }

        let nextYearTaskSpecs: [(String, Period, Int)] = [
            ("File 1099s", .day, 0),
            ("Plan Q1 roadmap", .day, 14),
            ("Renew licenses", .day, 60),
            ("Next year budget review", .month, 90),
            ("Next year goals", .year, 0)
        ]

        for (title, period, dayOffset) in nextYearTaskSpecs {
            guard let taskDate = calendar.date(byAdding: .day, value: dayOffset, to: startOfNextYear) else {
                continue
            }

            tasks.append(DataModel.Task(
                title: title,
                date: taskDate,
                period: period
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
