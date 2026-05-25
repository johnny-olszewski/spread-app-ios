import SwiftUI
import JohnnyOFoundationUI
import JohnnyOFoundationCore

/// Month calendar view for a spread, with day-state computed from the journal.
///
/// Exists as a dedicated child view so that `journalManager` observation is isolated here,
/// preventing parent view re-evaluations from interfering with the parent's task/content lifecycle.
struct SpreadMonthCalendarView: View {
    enum Mode {
        case conventional
        case traditional
    }

    let monthDate: Date
    let mode: Mode
    let journalManager: JournalManager
    var calendarActionsByDate: [Date: MonthSpreadCalendarDayAction] = [:]
    var onViewDaySpread: ((DataModel.Spread) -> Void)? = nil
    var onRevealMonthDaySection: ((Date) -> Void)? = nil

    // MARK: - Calendar Delegate

    private struct CalendarDelegate: MonthCalendarActionDelegate {
        let calendar: Calendar
        let calendarActionsByDate: [Date: MonthSpreadCalendarDayAction]
        let onRevealSection: (Date) -> Void

        func monthCalendarDidTapDay(_ context: MonthCalendarDayContext) {
            let normalizedDate = Period.day.normalizeDate(context.date, calendar: calendar)
            guard case .revealSection(let sectionDate)? = calendarActionsByDate[normalizedDate] else {
                return
            }
            onRevealSection(sectionDate)
        }
    }

    // MARK: - Computed

    private var isConventional: Bool { mode == .conventional }

    private var calendar: Calendar {
        journalManager.firstWeekday.configuredCalendar(from: journalManager.calendar)
    }

    private var dayStateByDate: [Date: MonthDayState] {
        isConventional ? conventionalDayStateByDate() : traditionalDayStateByDate()
    }

    // MARK: - Body

    var body: some View {
        MonthCalendarView(
            displayedMonth: monthDate,
            calendar: calendar,
            today: journalManager.today,
            configuration: .init(showsPeripheralDates: true),
            contentGenerator: FullMonthCalendarContentGenerator(
                calendar: calendar,
                dayStateByDate: dayStateByDate,
                calendarActionsByDate: calendarActionsByDate,
                isConventional: isConventional,
                onViewDaySpread: onViewDaySpread
            ),
            actionDelegate: isConventional
                ? CalendarDelegate(
                    calendar: calendar,
                    calendarActionsByDate: calendarActionsByDate,
                    onRevealSection: { onRevealMonthDaySection?($0) }
                )
                : nil
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .accessibilityIdentifier("spreads.month.calendar")
    }

    // MARK: - Day State

    private func conventionalDayStateByDate() -> [Date: MonthDayState] {
        let monthStart = Period.month.normalizeDate(monthDate, calendar: calendar)
        let fallbackCounts = monthDayContentCounts(
            monthSpreadDataModel: journalManager.dataModel[.month]?[monthStart]
        )

        let explicitStates = journalManager.spreads.reduce(into: [Date: MonthDayState]()) { result, s in
            guard s.period == .day else { return }
            let normalizedDate = Period.day.normalizeDate(s.date, calendar: calendar)
            guard Period.month.normalizeDate(normalizedDate, calendar: calendar) == monthStart else { return }

            let explicitCount =
                (journalManager.dataModel[.day]?[normalizedDate]?.tasks.count ?? 0) +
                (journalManager.dataModel[.day]?[normalizedDate]?.notes.count ?? 0)
            let fallbackCount = fallbackCounts[normalizedDate] ?? 0
            result[normalizedDate] = MonthDayState(
                hasExplicitDaySpread: true,
                contentCount: max(explicitCount, fallbackCount)
            )
        }

        let fallbackStates = fallbackCounts.mapValues { MonthDayState(hasExplicitDaySpread: false, contentCount: $0) }

        return explicitStates.merging(fallbackStates) { explicit, fallback in
            MonthDayState(
                hasExplicitDaySpread: explicit.hasExplicitDaySpread,
                contentCount: max(explicit.contentCount, fallback.contentCount)
            )
        }
    }

    private func monthDayContentCounts(monthSpreadDataModel: SpreadDataModel?) -> [Date: Int] {
        guard let model = monthSpreadDataModel else { return [:] }
        let entries: [any Entry] =
            (model.tasks.filter { $0.period == .day } as [any Entry]) +
            (model.notes.filter { $0.period == .day } as [any Entry])
        return entries.reduce(into: [:]) { result, entry in
            let date = Period.day.normalizeDate(entryDate(for: entry), calendar: calendar)
            result[date, default: 0] += 1
        }
    }

    private func traditionalDayStateByDate() -> [Date: MonthDayState] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthDate) else {
            return [:]
        }

        var dates: [Date] = []
        var cursor = monthInterval.start
        while cursor < monthInterval.end {
            dates.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        let service = TraditionalSpreadService(calendar: calendar)
        let tasks = journalManager.tasks
        let notes = journalManager.notes
        let events = FeatureFlags.eventsEnabled ? journalManager.events : []

        return dates.reduce(into: [:]) { result, date in
            let model = service.virtualSpreadDataModel(
                period: .day,
                date: date,
                tasks: tasks,
                notes: notes,
                events: events
            )
            result[Period.day.normalizeDate(date, calendar: calendar)] = MonthDayState(
                hasExplicitDaySpread: true,
                contentCount: model.tasks.count + model.notes.count
            )
        }
    }

    private func entryDate(for entry: any Entry) -> Date {
        if let task = entry as? DataModel.Task { return task.date }
        if let note = entry as? DataModel.Note { return note.date }
        return entry.createdDate
    }
}
