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
    let calendar: Calendar
    let dayStateByDate: [Date: MonthDayState]
    let calendarActionsByDate: [Date: MonthSpreadCalendarDayAction]
    let isConventional: Bool
    let onViewDaySpread: ((DataModel.Spread) -> Void)?

    func headerView(context: MonthCalendarHeaderContext) -> some View {
        EmptyView().frame(height: 0)
    }

    func weekdayHeaderView(context: MonthCalendarWeekdayContext) -> some View {
        Text(context.symbol)
            .font(SpreadTheme.Typography.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
    }

    func dayCellView(context: MonthCalendarDayContext) -> some View {
        let normalizedDate = Period.day.normalizeDate(context.date, calendar: calendar)
        let dayState = dayStateByDate[normalizedDate] ?? MonthDayState(hasExplicitDaySpread: false, contentCount: 0)
        let action = isConventional ? calendarActionsByDate[normalizedDate] : nil
        let visualState = MultidayDayCardSupport.visualState(
            isToday: context.isToday,
            isCreated: isConventional ? dayState.hasExplicitDaySpread : true
        )
        return CalendarDayCellView(
            context: context,
            calendar: calendar,
            visualState: visualState,
            action: action,
            onViewDaySpread: onViewDaySpread
        )
    }

    func placeholderCellView(context: MonthCalendarPlaceholderContext) -> some View {
        Color.clear.frame(maxWidth: .infinity, minHeight: 54)
    }

    func weekBackgroundView(context: MonthCalendarWeekContext) -> some View {
        Color.clear.frame(maxWidth: .infinity, minHeight: 0)
    }
}

// MARK: - Day Cell

private struct CalendarDayCellView: View {
    let context: MonthCalendarDayContext
    let calendar: Calendar
    let visualState: SpreadCardStyle
    let action: MonthSpreadCalendarDayAction?
    let onViewDaySpread: ((DataModel.Spread) -> Void)?

    private var foreground: Color {
        context.isPeripheral ? .secondary : .primary
    }

    private var cellFill: Color {
        if context.isPeripheral { return .clear }
        return (visualState.isToday || visualState.isCreated) ? visualState.fill : .clear
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
                    context.isPeripheral ? Color.clear : visualState.borderColor,
                    style: visualState.borderStyle
                )
        )
        .padding(2)
    }

    @ViewBuilder
    private var topRow: some View {
        if context.isPeripheral {
            Text(shortMonth(for: context.date))
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else {
            Color.clear.frame(height: 12)
        }
    }

    private var dayNumber: some View {
        Text("\(calendar.component(.day, from: context.date))")
            .font(SpreadTheme.Typography.body)
            .fontWeight(context.isToday ? .semibold : .regular)
            .foregroundStyle(context.isToday ? SpreadTheme.Accent.todayCellBorder : foreground)
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
