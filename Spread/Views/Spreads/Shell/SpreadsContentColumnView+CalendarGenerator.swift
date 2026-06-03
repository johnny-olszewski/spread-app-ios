import SwiftUI
import JohnnyOFoundationUI
import JohnnyOFoundationCore

// MARK: - Calendar Generator

extension SpreadsContentColumnView {

    /// A `CalendarContentGenerator` that renders month headers and day cells.
    ///
    /// Only day and multiday spreads are considered for cell state — month and year
    /// spreads are intentionally excluded since the user cannot navigate to them
    /// directly from this view.
    struct CalendarGenerator: CalendarContentGenerator {

        let spreads: [DataModel.Spread]
        let calendar: Calendar

        // MARK: Header

        func headerView(context: MonthCalendarHeaderContext) -> some View {
            MonthHeaderView(context: context)
        }

        // MARK: Weekday Header

        func weekdayHeaderView(context: MonthCalendarWeekdayContext) -> some View {
            Text(context.symbol.prefix(1))
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }

        // MARK: Day Cell

        func dayCellView(context: MonthCalendarDayContext) -> some View {
            let hasDaySpread = spreads.contains {
                $0.period == .day &&
                $0.contains(date: context.date, calendar: calendar)
            }
            return DayCellView(context: context, calendar: calendar, hasDaySpread: hasDaySpread)
        }

        // MARK: Placeholder Cell

        func placeholderCellView(context: MonthCalendarPlaceholderContext) -> some View {
            Color.clear
        }

        // MARK: Week Background

        /// Must return a sized view (not EmptyView) so the row overlay layer has geometry to render against.
        func weekBackgroundView(context: MonthCalendarWeekContext) -> some View {
            Color.clear
        }
    }
}

// MARK: - Row Overlay Generator

extension SpreadsContentColumnView {

    /// Renders a thin bar across week rows for multiday spreads, making multi-day
    /// spans visually continuous across cells and row breaks.
    struct RowOverlayGenerator: MonthCalendarRowOverlayGenerator {

        private static let laneHeight: CGFloat = 3
        private static let laneHorizontalPadding: CGFloat = 4
        private static let laneBottomPadding: CGFloat = 4

        let overlays: [MonthCalendarLogicalRowOverlay<UUID, Bool>]
        let maximumVisibleLaneCount: Int

        init(spreads: [DataModel.Spread], calendar: Calendar) {
            self.maximumVisibleLaneCount = 2
            self.overlays = spreads
                .filter { $0.period == .multiday }
                .map { spread in
                    MonthCalendarLogicalRowOverlay(
                        id: spread.id,
                        startDate: spread.startDate ?? spread.date,
                        endDate: spread.endDate ?? spread.date,
                        payload: true
                    )
                }
        }

        func rowOverlayView(
            context: MonthCalendarPackedRowOverlayRenderContext<UUID, Bool>
        ) -> some View {
            Capsule(style: .circular)
                .fill(SpreadTheme.Accent.todaySelectedEmphasis.opacity(0.4))
                .frame(height: Self.laneHeight)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.horizontal, Self.laneHorizontalPadding)
                .padding(.bottom, Self.laneBottomPadding)
        }

        func overflowView(
            context: MonthCalendarRowOverlayOverflowRenderContext<UUID, Bool>
        ) -> some View {
            EmptyView()
        }
    }
}

// MARK: - Month Header View

private struct MonthHeaderView: View {

    let context: MonthCalendarHeaderContext

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.calendar = context.calendar
        formatter.timeZone = context.calendar.timeZone
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: context.displayedMonth)
    }

    var body: some View {
        HStack {
            Text(monthYearString)
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 4)
    }
}

// MARK: - Day Cell View

private struct DayCellView: View {

    let context: MonthCalendarDayContext
    let calendar: Calendar
    /// True only when a `.day`-period spread explicitly covers this date.
    /// Multiday spans are shown via the row overlay bar and do not affect cell styling.
    let hasDaySpread: Bool

    private var dayNumber: Int {
        calendar.component(.day, from: context.date)
    }

    private var isPeripheral: Bool { !context.isInDisplayedMonth }

    /// Resolved card style — mirrors `MultidayDayCardSupport.visualState` so styling stays
    /// consistent with the month calendar and multiday grid.
    private var visualState: SpreadCardStyle {
        MultidayDayCardSupport.visualState(isToday: context.isToday, isCreated: hasDaySpread)
    }

    /// Subtle fill: today gets a tinted wash; created days get a near-invisible primary tint;
    /// everything else is clear. Peripheral dates are always clear.
    private var fillColor: Color {
        if isPeripheral { return .clear }
        return (visualState.isToday || visualState.isCreated) ? visualState.fill : .clear
    }

    /// Stroke is intentionally more visible than the fill, giving the rectangle its definition.
    /// No stroke is rendered for plain (non-today, non-created) cells or peripheral dates.
    private var strokeColor: Color {
        if isPeripheral { return .clear }
        if !visualState.isToday && !hasDaySpread { return .clear }
        return visualState.borderColor
    }

    private var textColor: Color {
        if isPeripheral { return Color.primary.opacity(0.2) }
        if visualState.isToday { return SpreadTheme.Accent.todayCellBorder }
        return hasDaySpread ? SpreadTheme.Accent.createdDayBorder : .secondary
    }

    var body: some View {
        Text("\(dayNumber)")
            .font(.subheadline)
            .fontWeight(visualState.headerWeight)
            .foregroundStyle(textColor)
            .lineLimit(1)
            .padding(4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: SpreadTheme.CornerRadius.badge, style: .continuous)
                    .fill(fillColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SpreadTheme.CornerRadius.badge, style: .continuous)
                    .strokeBorder(strokeColor, style: visualState.borderStyle)
            )
            .aspectRatio(1, contentMode: .fit)
            .padding(2)
    }
}
