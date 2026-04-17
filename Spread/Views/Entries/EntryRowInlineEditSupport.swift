import Foundation

enum EntryRowPrimaryInteraction: Equatable {
    case inlineEdit
    case fullEditSheet
}

enum EntryRowInlineMigrationOptionKind: String, CaseIterable {
    case today
    case tomorrow
    case nextMonth
    case nextMonthSameDay
}

struct EntryRowInlineMigrationOption: Identifiable, Equatable {
    let kind: EntryRowInlineMigrationOptionKind
    let label: String
    let date: Date
    let period: Period

    var id: String { kind.rawValue }
}

enum EntryRowInlineEditSupport {

    static func primaryInteraction(
        entryType: EntryType,
        taskStatus: DataModel.Task.Status?,
        canInlineEditTitle: Bool
    ) -> EntryRowPrimaryInteraction {
        guard entryType == .task, canInlineEditTitle, taskStatus == .open else {
            return .fullEditSheet
        }
        return .inlineEdit
    }

    static func migrationOptions(
        for task: DataModel.Task,
        today: Date,
        calendar: Calendar
    ) -> [EntryRowInlineMigrationOption] {
        guard task.status == .open else { return [] }

        let normalizedToday = Period.day.normalizeDate(today, calendar: calendar)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: normalizedToday)
        let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: normalizedToday)?
            .firstDayOfMonth(calendar: calendar)
        let sameDayNextMonth = calendar.date(byAdding: .month, value: 1, to: normalizedToday)

        let todayComponents = calendar.dateComponents([.day], from: normalizedToday)
        let sameDayComponents = sameDayNextMonth.map {
            calendar.dateComponents([.day], from: $0)
        }

        var options: [EntryRowInlineMigrationOption] = []

        if task.period != .day || !calendar.isDate(task.date, inSameDayAs: normalizedToday) {
            options.append(
                EntryRowInlineMigrationOption(
                    kind: .today,
                    label: "Today",
                    date: normalizedToday,
                    period: .day
                )
            )
        }

        if let tomorrow, (task.period != .day || !calendar.isDate(task.date, inSameDayAs: tomorrow)) {
            options.append(
                EntryRowInlineMigrationOption(
                    kind: .tomorrow,
                    label: "Tomorrow",
                    date: tomorrow,
                    period: .day
                )
            )
        }

        if let nextMonthStart,
           task.period != .month || !calendar.isDate(task.date, equalTo: nextMonthStart, toGranularity: .month) {
            options.append(
                EntryRowInlineMigrationOption(
                    kind: .nextMonth,
                    label: monthLabel(for: nextMonthStart, calendar: calendar),
                    date: nextMonthStart,
                    period: .month
                )
            )
        }

        if let sameDayNextMonth,
           todayComponents.day == sameDayComponents?.day,
           task.period != .day || !calendar.isDate(task.date, inSameDayAs: sameDayNextMonth) {
            options.append(
                EntryRowInlineMigrationOption(
                    kind: .nextMonthSameDay,
                    label: dayLabel(for: sameDayNextMonth, calendar: calendar),
                    date: sameDayNextMonth,
                    period: .day
                )
            )
        }

        return options
    }

    static func committedTitleDraft(
        draftTitle: String,
        originalTitle: String
    ) -> String? {
        let trimmed = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != originalTitle else {
            return nil
        }
        return trimmed
    }

    @MainActor
    static func performInlineAction(
        draftTitle: String,
        originalTitle: String,
        onCommit: @escaping (String) async -> Void,
        action: @escaping () async -> Void
    ) async {
        if let committedTitle = committedTitleDraft(draftTitle: draftTitle, originalTitle: originalTitle) {
            await onCommit(committedTitle)
        }
        await action()
    }

    private static func monthLabel(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }

    private static func dayLabel(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }
}
