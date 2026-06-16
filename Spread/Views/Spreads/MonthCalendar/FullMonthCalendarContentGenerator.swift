import SwiftUI
import JohnnyOFoundationUI
import JohnnyOFoundationCore

/// Visual state of a day in the month calendar grid.
struct MonthDayState: Equatable {
    let hasExplicitDaySpread: Bool
    let contentCount: Int
}

/// Calendar content generator for the full month spread calendar view.
struct FullMonthCalendarContentGenerator: CalendarContentGenerator {
    let displayedMonth: Date
    let calendar: Calendar
    let today: Date
    let dayStateByDate: [Date: MonthDayState]
    let calendarActionsByDate: [Date: MonthSpreadCalendarDayAction]
    let isConventional: Bool
    let onViewDaySpread: ((DataModel.Spread) -> Void)?

    func headerView(month: Date) -> some View {
        EmptyView().frame(height: 0)
    }

    func weekdayHeaderView(weekday: Int) -> some View {
        Text(calendar.veryShortWeekdaySymbols[weekday - 1])
            .font(SpreadTheme.Typography.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
    }

    func dayCellView(date: Date) -> some View {
        let normalizedDate = Period.day.normalizeDate(date, calendar: calendar)
        let dayState = dayStateByDate[normalizedDate] ?? MonthDayState(hasExplicitDaySpread: false, contentCount: 0)
        let action = isConventional ? calendarActionsByDate[normalizedDate] : nil
        let isToday = calendar.isDate(date, inSameDayAs: today)
        let isPeripheral = !calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)
        let cardStyle = SpreadCardStyle(
            isToday: isToday,
            isCreated: isConventional ? dayState.hasExplicitDaySpread : true
        )
        return CalendarDayCellView(
            date: date,
            isPeripheral: isPeripheral,
            isToday: isToday,
            calendar: calendar,
            cardStyle: cardStyle,
            action: action,
            onViewDaySpread: onViewDaySpread
        )
    }

    func placeholderCellView(date: Date) -> some View {
        Color.clear.frame(maxWidth: .infinity, minHeight: 54)
    }

    func weekBackgroundView(week: MonthCalendarWeek) -> some View {
        Color.clear.frame(maxWidth: .infinity, minHeight: 0)
    }
}

// MARK: - Day Cell

private struct CalendarDayCellView: View {
    let date: Date
    let isPeripheral: Bool
    let isToday: Bool
    let calendar: Calendar
    let cardStyle: SpreadCardStyle
    let action: MonthSpreadCalendarDayAction?
    let onViewDaySpread: ((DataModel.Spread) -> Void)?

    private var foreground: Color {
        isPeripheral ? .secondary : .primary
    }

    private var cellFill: Color {
        if isPeripheral { return .clear }
        return (isToday || cardStyle.isCreated) ? cardStyle.fill : .clear
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            topRow
            dayNumber
            actionRow
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .topLeading)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(cellFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    isPeripheral ? Color.clear : cardStyle.borderColor,
                    style: cardStyle.borderStyle
                )
        )
        .padding(2)
    }

    @ViewBuilder
    private var topRow: some View {
        if isPeripheral {
            Text(shortMonth(for: date))
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else {
            Color.clear.frame(height: 12)
        }
    }

    private var dayNumber: some View {
        Text("\(calendar.component(.day, from: date))")
            .font(SpreadTheme.Typography.body)
            .fontWeight(isToday ? .semibold : .regular)
            .foregroundStyle(isToday ? SpreadTheme.Accent.todayCellBorder : foreground)
    }

    @ViewBuilder
    private var actionRow: some View {
        if case .revealSection? = action {
            Text("Assigned")
                .font(.system(size: 9, weight: .semibold, design: .default))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        } else if case .view(let spread)? = action {
            HStack {
                Spacer()
                Button {
                    onViewDaySpread?(spread)
                } label: {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SpreadTheme.Accent.todaySelectedEmphasis)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(.white.opacity(0.94)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open day spread")
            }
        } else {
            Spacer(minLength: 8)
        }
    }

    private func shortMonth(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "MMM"
        return formatter.string(from: date).uppercased()
    }
}
