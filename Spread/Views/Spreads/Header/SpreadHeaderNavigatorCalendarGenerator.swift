import SwiftUI
import JohnnyOFoundationUI

/// CalendarContentGenerator for the rooted spread header navigator's expanded-month calendar grid.
///
/// Day cells reflect the three-state visual treatment (today / created / uncreated) using style
/// constants shared with the multiday day card via `MultidayDayCardVisualState`. Peripheral
/// (out-of-month) dates are hidden by the caller via `showsPeripheralDates: false`.
struct SpreadHeaderNavigatorCalendarGenerator: CalendarContentGenerator {
    let model: SpreadHeaderNavigatorModel
    let monthRow: SpreadHeaderNavigatorModel.MonthRow
    let currentSpread: DataModel.Spread

    // MARK: - CalendarContentGenerator

    func headerView(context: MonthCalendarHeaderContext) -> some View {
        EmptyView().frame(height: 0)
    }

    func weekdayHeaderView(context: MonthCalendarWeekdayContext) -> some View {
        Text(context.symbol)
            .font(SpreadTheme.Typography.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
    }

    func dayCellView(context: MonthCalendarDayContext) -> some View {
        let targets = monthRow.targets(for: context.date, calendar: model.calendar)
        let visualState = dayVisualState(for: context, targets: targets)
        let isCurrent = model.isCurrent(date: context.date, currentSpread: currentSpread)

        return Text("\(model.calendar.component(.day, from: context.date))")
            .font(SpreadTheme.Typography.body)
            .foregroundStyle(foregroundColor(targets: targets, visualState: visualState))
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(cellFill(isCurrent: isCurrent, visualState: visualState))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(visualState.borderColor, style: visualState.borderStyle)
            )
    }

    func placeholderCellView(context: MonthCalendarPlaceholderContext) -> some View {
        Color.clear.frame(height: 40)
    }

    func weekBackgroundView(context: MonthCalendarWeekContext) -> some View {
        Color.clear
    }

    // MARK: - Helpers

    private func dayVisualState(
        for context: MonthCalendarDayContext,
        targets: [SpreadHeaderNavigatorModel.SelectionTarget]
    ) -> MultidayDayCardVisualState {
        if context.isToday { return .today }
        if model.mode == .traditional || !targets.isEmpty { return .created }
        return .uncreated
    }

    private func cellFill(isCurrent: Bool, visualState: MultidayDayCardVisualState) -> Color {
        if isCurrent { return Color.accentColor.opacity(0.16) }
        if visualState == .today { return visualState.fill }
        return Color.clear
    }

    private func foregroundColor(
        targets: [SpreadHeaderNavigatorModel.SelectionTarget],
        visualState: MultidayDayCardVisualState
    ) -> Color {
        if visualState == .today { return SpreadTheme.Accent.todayEmphasis }
        return targets.isEmpty ? .secondary : .primary
    }
}
