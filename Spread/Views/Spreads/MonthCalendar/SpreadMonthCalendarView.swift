import SwiftUI
import JohnnyOFoundationUI

private struct SpreadMonthCalendarContentGenerator: CalendarContentGenerator {
    typealias HeaderContent = AnyView
    typealias WeekdayHeaderContent = AnyView
    typealias DayCellContent = AnyView
    typealias PlaceholderCellContent = AnyView
    typealias WeekBackgroundContent = AnyView

    let calendar: Calendar
    let entryCountsByDate: [Date: Int]

    func headerView(context: MonthCalendarHeaderContext) -> AnyView {
        AnyView(EmptyView().frame(height: 0))
    }

    func weekdayHeaderView(context: MonthCalendarWeekdayContext) -> AnyView {
        AnyView(
            Text(context.symbol)
                .font(SpreadTheme.Typography.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        )
    }

    func dayCellView(context: MonthCalendarDayContext) -> AnyView {
        let normalizedDate = Period.day.normalizeDate(context.date, calendar: calendar)
        let entryCount = entryCountsByDate[normalizedDate] ?? 0
        let monthSymbol = shortMonth(for: context.date)
        let foreground: Color = context.isPeripheral ? .secondary : .primary

        return AnyView(
            VStack(alignment: .leading, spacing: 4) {
                if context.isPeripheral {
                    Text(monthSymbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Color.clear
                        .frame(height: 12)
                }

                Text("\(calendar.component(.day, from: context.date))")
                    .font(SpreadTheme.Typography.body)
                    .fontWeight(context.isToday ? .bold : .regular)
                    .foregroundStyle(context.isToday ? SpreadTheme.Accent.todaySelectedEmphasis : foreground)

                if entryCount > 0 {
                    HStack(spacing: 3) {
                        ForEach(0..<min(entryCount, 3), id: \.self) { _ in
                            Circle()
                                .fill(SpreadTheme.Accent.todaySelectedEmphasis)
                                .frame(width: 4, height: 4)
                        }
                        if entryCount > 3 {
                            Text("+")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(height: 8)
                } else {
                    Spacer(minLength: 8)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .topLeading)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(context.isToday ? SpreadTheme.Accent.todaySelectedEmphasis.opacity(0.1) : Color.clear)
            )
        )
    }

    func placeholderCellView(context: MonthCalendarPlaceholderContext) -> AnyView {
        AnyView(
            Color.clear
                .frame(maxWidth: .infinity, minHeight: 54)
        )
    }

    func weekBackgroundView(context: MonthCalendarWeekContext) -> AnyView {
        AnyView(Color.clear.frame(maxWidth: .infinity, minHeight: 0))
    }

    private func shortMonth(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "MMM"
        return formatter.string(from: date).uppercased()
    }
}

struct SpreadMonthCalendarView: View {
    enum Mode {
        case conventional
        case traditional
    }

    let monthDate: Date
    let mode: Mode
    let journalManager: JournalManager

    private var calendar: Calendar {
        journalManager.firstWeekday.configuredCalendar(from: journalManager.calendar)
    }

    private var entryCountsByDate: [Date: Int] {
        switch mode {
        case .conventional:
            return SpreadMonthCalendarSupport.conventionalEntryCountsByDate(
                monthDate: monthDate,
                spreads: journalManager.spreads,
                dataModel: journalManager.dataModel,
                calendar: calendar
            )
        case .traditional:
            return SpreadMonthCalendarSupport.traditionalEntryCountsByDate(
                monthDate: monthDate,
                tasks: journalManager.tasks,
                notes: journalManager.notes,
                events: FeatureFlags.eventsEnabled ? journalManager.events : [],
                calendar: calendar
            )
        }
    }

    var body: some View {
        MonthCalendarView(
            displayedMonth: monthDate,
            calendar: calendar,
            today: journalManager.today,
            configuration: .init(showsPeripheralDates: true),
            contentGenerator: SpreadMonthCalendarContentGenerator(
                calendar: calendar,
                entryCountsByDate: entryCountsByDate
            )
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .accessibilityIdentifier("spreads.month.calendar")
    }
}
