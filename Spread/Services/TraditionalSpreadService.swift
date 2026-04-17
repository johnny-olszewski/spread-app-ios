import Foundation

/// Service for generating virtual spreads and mapping entries in traditional mode.
///
/// Traditional mode differs from conventional mode in several ways:
/// - All year/month/day spreads are available for navigation regardless of created spread records
/// - Entries appear only on their preferred date/period (no migration history)
/// - Migration updates an entry's preferred date/period rather than creating assignment chains
/// - Virtual spread data models are generated on-the-fly from entries
///
/// This service does NOT create or mutate Spread records. It generates ephemeral
/// `SpreadDataModel` instances for display purposes only.
struct TraditionalSpreadService {

    // MARK: - Properties

    /// The calendar used for date calculations.
    let calendar: Calendar

    // MARK: - Virtual Spread Data Model

    /// Generates a virtual `SpreadDataModel` for a given period and date.
    ///
    /// Filters entries to include only those whose preferred date/period matches
    /// the requested spread. No assignment history is consulted — only the entry's
    /// `date` and `period` fields.
    ///
    /// - Parameters:
    ///   - period: The period of the virtual spread (year, month, or day).
    ///   - date: The date of the virtual spread (will be normalized).
    ///   - tasks: All tasks to filter.
    ///   - notes: All notes to filter.
    ///   - events: All events to filter.
    /// - Returns: A `SpreadDataModel` containing entries that belong on this virtual spread.
    func virtualSpreadDataModel(
        period: Period,
        date: Date,
        tasks: [DataModel.Task],
        notes: [DataModel.Note],
        events: [DataModel.Event]
    ) -> SpreadDataModel {
        let normalizedDate = period.normalizeDate(date, calendar: calendar)
        let virtualSpread = DataModel.Spread(period: period, date: normalizedDate, calendar: calendar)

        // Filter tasks by preferred date/period
        let matchingTasks = tasks.filter { task in
            taskBelongsOnSpread(task, period: period, normalizedDate: normalizedDate)
        }

        // Filter notes by preferred date/period
        let matchingNotes = notes.filter { note in
            noteBelongsOnSpread(note, period: period, normalizedDate: normalizedDate)
        }

        // Events use computed visibility (same as conventional)
        let matchingEvents = events.filter { event in
            event.appearsOn(period: period, date: normalizedDate, calendar: calendar)
        }

        return SpreadDataModel(
            spread: virtualSpread,
            tasks: matchingTasks,
            notes: matchingNotes,
            events: matchingEvents
        )
    }

    // MARK: - Entry Matching

    /// Determines if a task belongs on a virtual spread based on its preferred date/period.
    ///
    /// In traditional mode, a task appears on a spread only when:
    /// - The task's preferred period matches the spread's period exactly, AND
    /// - The task's preferred date normalizes to the spread's date for that period
    ///
    /// - Parameters:
    ///   - task: The task to check.
    ///   - period: The spread's period.
    ///   - normalizedDate: The spread's normalized date.
    /// - Returns: `true` if the task belongs on this spread.
    func taskBelongsOnSpread(
        _ task: DataModel.Task,
        period: Period,
        normalizedDate: Date
    ) -> Bool {
        entryBelongsOnSpread(
            preferredDate: task.date,
            preferredPeriod: task.period,
            spreadPeriod: period,
            spreadNormalizedDate: normalizedDate
        )
    }

    /// Determines if a note belongs on a virtual spread based on its preferred date/period.
    ///
    /// Uses the same matching logic as tasks.
    ///
    /// - Parameters:
    ///   - note: The note to check.
    ///   - period: The spread's period.
    ///   - normalizedDate: The spread's normalized date.
    /// - Returns: `true` if the note belongs on this spread.
    func noteBelongsOnSpread(
        _ note: DataModel.Note,
        period: Period,
        normalizedDate: Date
    ) -> Bool {
        entryBelongsOnSpread(
            preferredDate: note.date,
            preferredPeriod: note.period,
            spreadPeriod: period,
            spreadNormalizedDate: normalizedDate
        )
    }

    /// Core matching logic: determines if an entry's preferred date/period places it on a spread.
    ///
    /// Rules:
    /// - The entry's preferred period must match the spread period exactly.
    /// - The entry's preferred date must normalize to the spread's normalized date.
    private func entryBelongsOnSpread(
        preferredDate: Date,
        preferredPeriod: Period,
        spreadPeriod: Period,
        spreadNormalizedDate: Date
    ) -> Bool {
        // Multiday spreads are not used in traditional mode navigation
        guard spreadPeriod != .multiday, preferredPeriod != .multiday else { return false }
        guard preferredPeriod == spreadPeriod else { return false }

        // Normalize the entry's date to the spread's period for comparison
        let entryDateAtSpreadPeriod = spreadPeriod.normalizeDate(preferredDate, calendar: calendar)
        return entryDateAtSpreadPeriod == spreadNormalizedDate
    }

    // MARK: - Traditional Migration

    /// Computes the migration result for traditional mode.
    ///
    /// In traditional mode, migration updates the entry's preferred date/period.
    /// Then, conventional reassignment logic applies to determine the actual spread assignment.
    ///
    /// This method returns the new preferred date/period and the best matching
    /// conventional spread (if any) for assignment.
    ///
    /// - Parameters:
    ///   - newDate: The new preferred date for the entry.
    ///   - newPeriod: The new preferred period for the entry.
    ///   - createdSpreads: The actually-created conventional spreads.
    /// - Returns: The best matching conventional spread, or `nil` if the entry should go to Inbox.
    func findConventionalSpread(
        forPreferredDate newDate: Date,
        preferredPeriod newPeriod: Period,
        in createdSpreads: [DataModel.Spread]
    ) -> DataModel.Spread? {
        let conventionalService = ConventionalSpreadService(calendar: calendar)

        // Reuse the conventional algorithm: search from preferred period up to year
        return conventionalService.findBestSpread(
            preferredDate: newDate,
            preferredPeriod: newPeriod,
            in: createdSpreads
        )
    }

    // MARK: - Virtual Spread Generation

    /// Generates a list of year spreads that contain entries.
    ///
    /// Returns the distinct years from all entries' preferred dates.
    ///
    /// - Parameters:
    ///   - tasks: All tasks.
    ///   - notes: All notes.
    ///   - events: All events.
    /// - Returns: Sorted list of year dates (normalized to Jan 1).
    func yearsWithEntries(
        tasks: [DataModel.Task],
        notes: [DataModel.Note],
        events: [DataModel.Event]
    ) -> [Date] {
        var years: Set<Date> = []

        for task in tasks {
            let yearDate = Period.year.normalizeDate(task.date, calendar: calendar)
            years.insert(yearDate)
        }

        for note in notes {
            let yearDate = Period.year.normalizeDate(note.date, calendar: calendar)
            years.insert(yearDate)
        }

        for event in events {
            let yearDate = Period.year.normalizeDate(event.startDate, calendar: calendar)
            years.insert(yearDate)
        }

        return years.sorted()
    }

    /// Generates month dates for a given year that contain entries.
    ///
    /// - Parameters:
    ///   - yearDate: The normalized year date (Jan 1).
    ///   - tasks: All tasks.
    ///   - notes: All notes.
    ///   - events: All events.
    /// - Returns: Sorted list of month dates within the year.
    func monthsWithEntries(
        inYear yearDate: Date,
        tasks: [DataModel.Task],
        notes: [DataModel.Note],
        events: [DataModel.Event]
    ) -> [Date] {
        var months: Set<Date> = []

        let year = calendar.component(.year, from: yearDate)

        for task in tasks {
            let taskYear = calendar.component(.year, from: task.date)
            if taskYear == year {
                let monthDate = Period.month.normalizeDate(task.date, calendar: calendar)
                months.insert(monthDate)
            }
        }

        for note in notes {
            let noteYear = calendar.component(.year, from: note.date)
            if noteYear == year {
                let monthDate = Period.month.normalizeDate(note.date, calendar: calendar)
                months.insert(monthDate)
            }
        }

        for event in events {
            let eventYear = calendar.component(.year, from: event.startDate)
            if eventYear == year {
                let monthDate = Period.month.normalizeDate(event.startDate, calendar: calendar)
                months.insert(monthDate)
            }
        }

        return months.sorted()
    }

    /// Generates day dates for a given month that contain entries.
    ///
    /// - Parameters:
    ///   - monthDate: The normalized month date (1st of month).
    ///   - tasks: All tasks.
    ///   - notes: All notes.
    ///   - events: All events.
    /// - Returns: Sorted list of day dates within the month.
    func daysWithEntries(
        inMonth monthDate: Date,
        tasks: [DataModel.Task],
        notes: [DataModel.Note],
        events: [DataModel.Event]
    ) -> [Date] {
        var days: Set<Date> = []

        let year = calendar.component(.year, from: monthDate)
        let month = calendar.component(.month, from: monthDate)

        for task in tasks {
            if task.period == .day {
                let taskYear = calendar.component(.year, from: task.date)
                let taskMonth = calendar.component(.month, from: task.date)
                if taskYear == year && taskMonth == month {
                    let dayDate = Period.day.normalizeDate(task.date, calendar: calendar)
                    days.insert(dayDate)
                }
            }
        }

        for note in notes {
            if note.period == .day {
                let noteYear = calendar.component(.year, from: note.date)
                let noteMonth = calendar.component(.month, from: note.date)
                if noteYear == year && noteMonth == month {
                    let dayDate = Period.day.normalizeDate(note.date, calendar: calendar)
                    days.insert(dayDate)
                }
            }
        }

        for event in events {
            let eventYear = calendar.component(.year, from: event.startDate)
            let eventMonth = calendar.component(.month, from: event.startDate)
            if eventYear == year && eventMonth == month {
                let dayDate = Period.day.normalizeDate(event.startDate, calendar: calendar)
                days.insert(dayDate)
            }
        }

        return days.sorted()
    }
}
