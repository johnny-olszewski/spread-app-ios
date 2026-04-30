import SwiftUI
import JohnnyOFoundationUI

/// CalendarContentGenerator for the rooted spread header navigator's expanded-month calendar grid.
///
/// Day cells reflect the three-state visual treatment (today / created / uncreated) using style
/// constants shared with the multiday day card via `MultidayDayCardVisualState`. Peripheral
/// (out-of-month) dates are hidden by the caller via `showsPeripheralDates: false`.
struct SpreadHeaderNavigatorCalendarGenerator: CalendarContentGenerator {
    private enum Layout {
        static let cellAspectRatio: CGFloat = 0.82
        static let cellCornerRadius: CGFloat = 8
        static let cellPadding: CGFloat = 3
        static let cellTopPadding: CGFloat = 6
        static let cellHorizontalPadding: CGFloat = 7
        static let laneReservationHeight: CGFloat = 16
        static let minimumCellHeight: CGFloat = 52
    }

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
        let visualState = Self.visualState(
            isToday: context.isToday,
            mode: model.mode,
            hasExplicitDayTarget: Self.hasExplicitDayTarget(targets)
        )
        let isSelected = model.isCurrent(date: context.date, currentSpread: currentSpread)

        return VStack(alignment: .leading, spacing: 0) {
            Text("\(model.calendar.component(.day, from: context.date))")
                .font(SpreadTheme.Typography.body)
                .foregroundStyle(foregroundColor(targets: targets, visualState: visualState))
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: Layout.laneReservationHeight)
        }
            .padding(.horizontal, Layout.cellHorizontalPadding)
            .padding(.top, Layout.cellTopPadding)
            .frame(maxWidth: .infinity, minHeight: Layout.minimumCellHeight, alignment: .topLeading)
            .aspectRatio(Layout.cellAspectRatio, contentMode: .fit)
            .background(
                RoundedRectangle(cornerRadius: Layout.cellCornerRadius, style: .continuous)
                    .fill(cellFill(isSelected: isSelected, visualState: visualState))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Layout.cellCornerRadius, style: .continuous)
                    .strokeBorder(visualState.borderColor, style: visualState.borderStyle)
            )
            .padding(Layout.cellPadding)
    }

    func placeholderCellView(context: MonthCalendarPlaceholderContext) -> some View {
        Color.clear
            .frame(maxWidth: .infinity, minHeight: Layout.minimumCellHeight)
            .aspectRatio(Layout.cellAspectRatio, contentMode: .fit)
            .padding(Layout.cellPadding)
    }

    func weekBackgroundView(context: MonthCalendarWeekContext) -> some View {
        Color.clear
    }

    // MARK: - Helpers

    static func hasExplicitDayTarget(
        _ targets: [SpreadHeaderNavigatorModel.SelectionTarget]
    ) -> Bool {
        targets.contains(where: { !$0.isMultiday })
    }

    static func visualState(
        isToday: Bool,
        mode: SpreadHeaderNavigatorModel.Mode,
        hasExplicitDayTarget: Bool
    ) -> MultidayDayCardVisualState {
        MultidayDayCardSupport.visualState(
            isToday: isToday,
            isCreated: mode == .traditional || hasExplicitDayTarget
        )
    }

    private func cellFill(isSelected: Bool, visualState: MultidayDayCardVisualState) -> Color {
        if isSelected { return SpreadSelectionVisualStyle.surfaceFill }
        if visualState.isToday { return visualState.fill }
        return Color.clear
    }

    private func foregroundColor(
        targets: [SpreadHeaderNavigatorModel.SelectionTarget],
        visualState: MultidayDayCardVisualState
    ) -> Color {
        if visualState.isToday { return SpreadTheme.Accent.todayEmphasis }
        return targets.isEmpty ? .secondary : .primary
    }
}
