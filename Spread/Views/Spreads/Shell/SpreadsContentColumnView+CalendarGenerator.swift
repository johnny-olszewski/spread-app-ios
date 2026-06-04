import SwiftUI
import JohnnyOFoundationUI
import JohnnyOFoundationCore

// MARK: - Anchor Preference

/// Bubbles each day cell's bounds up so `SpreadsContentColumnView` can anchor
/// the disambiguation popover precisely on the tapped cell.
struct DateCellAnchorKey: PreferenceKey {
    static let defaultValue: [Date: Anchor<CGRect>] = [:]
    static func reduce(value: inout [Date: Anchor<CGRect>], nextValue: () -> [Date: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

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
            let isPeripheral = !context.isInDisplayedMonth
            let hasDaySpread = spreads.contains {
                $0.period == .day &&
                $0.contains(date: context.date, calendar: calendar)
            }
            let dayNumber = calendar.component(.day, from: context.date)
            let visualState = MultidayDayCardSupport.visualState(isToday: context.isToday, isCreated: hasDaySpread)

            let fillColor: Color = isPeripheral ? .clear
                : (visualState.isToday || visualState.isCreated) ? visualState.fill : .clear

            let strokeColor: Color = isPeripheral ? .clear
                : (!visualState.isToday && !hasDaySpread) ? .clear
                : visualState.borderColor

            let textColor: Color = isPeripheral ? Color.primary.opacity(0.2)
                : visualState.isToday ? SpreadTheme.Accent.todayCellBorder
                : hasDaySpread ? SpreadTheme.Accent.createdDayBorder
                : .secondary

            return Text("\(dayNumber)")
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
                .anchorPreference(key: DateCellAnchorKey.self, value: .bounds) { [context.date: $0] }
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

