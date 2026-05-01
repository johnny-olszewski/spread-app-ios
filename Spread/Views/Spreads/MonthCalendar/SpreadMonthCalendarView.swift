import SwiftUI
import JohnnyOFoundationUI

private struct SpreadMonthCalendarContentGenerator: CalendarContentGenerator {
    typealias HeaderContent = AnyView
    typealias WeekdayHeaderContent = AnyView
    typealias DayCellContent = AnyView
    typealias PlaceholderCellContent = AnyView
    typealias WeekBackgroundContent = AnyView

    let calendar: Calendar
    let dayStateByDate: [Date: SpreadMonthCalendarDayState]
    let mode: SpreadMonthCalendarView.Mode

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
        let dayState = dayStateByDate[normalizedDate] ?? .init(hasExplicitDaySpread: false, contentCount: 0)
        let visualState = dayVisualState(for: context, dayState: dayState)
        let foreground: Color = context.isPeripheral ? .secondary : .primary

        return AnyView(
            VStack(alignment: .leading, spacing: 4) {
                if context.isPeripheral {
                    Text(shortMonth(for: context.date))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Color.clear
                        .frame(height: 12)
                }

                Text("\(calendar.component(.day, from: context.date))")
                    .font(SpreadTheme.Typography.body)
                    .fontWeight(context.isToday ? .semibold : .regular)
                    .foregroundStyle(context.isToday ? SpreadTheme.Accent.todayEmphasis : foreground)

                if dayState.contentCount > 0 {
                    HStack(spacing: 3) {
                        ForEach(0..<min(dayState.contentCount, 3), id: \.self) { _ in
                            Circle()
                                .fill(SpreadTheme.Accent.todaySelectedEmphasis)
                                .frame(width: 4, height: 4)
                        }
                        if dayState.contentCount > 3 {
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
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(cellFill(visualState: visualState, isPeripheral: context.isPeripheral))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        context.isPeripheral ? Color.clear : visualState.borderColor,
                        style: visualState.borderStyle
                    )
            )
            .padding(2)
        )
    }

    private func dayVisualState(
        for context: MonthCalendarDayContext,
        dayState: SpreadMonthCalendarDayState
    ) -> MultidayDayCardVisualState {
        switch mode {
        case .conventional:
            return MultidayDayCardSupport.visualState(
                isToday: context.isToday,
                isCreated: dayState.hasExplicitDaySpread
            )
        case .traditional:
            return MultidayDayCardSupport.visualState(
                isToday: context.isToday,
                isCreated: true
            )
        }
    }

    private func cellFill(
        visualState: MultidayDayCardVisualState,
        isPeripheral: Bool
    ) -> Color {
        if isPeripheral { return Color.clear }
        if visualState.isToday { return visualState.fill }
        return visualState.isCreated ? Color.primary.opacity(0.04) : Color.clear
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

    private var dayStateByDate: [Date: SpreadMonthCalendarDayState] {
        switch mode {
        case .conventional:
            let monthStart = Period.month.normalizeDate(monthDate, calendar: calendar)
            return SpreadMonthCalendarSupport.conventionalDayStateByDate(
                monthDate: monthDate,
                spreads: journalManager.spreads,
                dataModel: journalManager.dataModel,
                monthSpreadDataModel: journalManager.dataModel[.month]?[monthStart],
                calendar: calendar
            )
        case .traditional:
            return SpreadMonthCalendarSupport.traditionalDayStateByDate(
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
                dayStateByDate: dayStateByDate,
                mode: mode
            )
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .accessibilityIdentifier("spreads.month.calendar")
    }
}
