import Foundation

extension DataModel.Task {
    /// Computes the day-granularity migration candidates for this task: today, tomorrow,
    /// next month (1st), and next month (same day) — whichever of those don't match the
    /// task's current assignment, since migrating "to where it already is" isn't a candidate.
    ///
    /// Only open tasks have migration candidates; returns an empty array otherwise.
    ///
    /// Day-granularity only by design — there's a single call site today. Not generalized to
    /// month/year migration; revisit only if that becomes an actual scoped task.
    func migrationOptions(
        today: Date,
        calendar: Calendar
    ) -> [EntryRowView.Configuration.Action.MigrationOption] {
        guard status == .open else { return [] }

        // No preferred date means the task has no current position, so no candidate should be
        // excluded as "already there" — .distantPast never matches a real comparison below.
        let taskCurrentDate = date ?? .distantPast

        let normalizedToday = Period.day.normalizeDate(today, calendar: calendar)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: normalizedToday)
        let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: normalizedToday)?
            .firstDayOfMonth(calendar: calendar)
        let sameDayNextMonth = calendar.date(byAdding: .month, value: 1, to: normalizedToday)

        let todayComponents = calendar.dateComponents([.day], from: normalizedToday)
        let sameDayComponents = sameDayNextMonth.map { calendar.dateComponents([.day], from: $0) }

        var options: [EntryRowView.Configuration.Action.MigrationOption] = []

        if period != .day || !calendar.isDate(taskCurrentDate, inSameDayAs: normalizedToday) {
            options.append(.init(kind: .today, label: "Today", date: normalizedToday, period: .day))
        }

        if let tomorrow, (period != .day || !calendar.isDate(taskCurrentDate, inSameDayAs: tomorrow)) {
            options.append(.init(kind: .tomorrow, label: "Tomorrow", date: tomorrow, period: .day))
        }

        if let nextMonthStart,
           period != .month || !calendar.isDate(taskCurrentDate, equalTo: nextMonthStart, toGranularity: .month) {
            options.append(.init(
                kind: .nextMonth,
                label: Self.migrationMonthLabel(for: nextMonthStart, calendar: calendar),
                date: nextMonthStart,
                period: .month
            ))
        }

        if let sameDayNextMonth,
           todayComponents.day == sameDayComponents?.day,
           period != .day || !calendar.isDate(taskCurrentDate, inSameDayAs: sameDayNextMonth) {
            options.append(.init(
                kind: .nextMonthSameDay,
                label: Self.migrationDayLabel(for: sameDayNextMonth, calendar: calendar),
                date: sameDayNextMonth,
                period: .day
            ))
        }

        return options
    }

    private static func migrationMonthLabel(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }

    private static func migrationDayLabel(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }
}
