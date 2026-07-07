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

extension SpreadsNavigatorView {

    /// A `CalendarContentGenerator` that renders month headers and day cells.
    ///
    /// Only day and multiday spreads are considered for cell state — month and year
    /// spreads are intentionally excluded since the user cannot navigate to them
    /// directly from this view.
    struct CalendarGenerator: CalendarContentGenerator {

        typealias Model = [Date: [DataModel.Spread]]

        let model: Model
        /// Explicit month spreads for the displayed year, keyed by normalized month start.
        let monthSpreads: [Date: DataModel.Spread]
        let calendar: Calendar
        let today: Date
        /// Invoked when a month header's "View month" button is tapped.
        let onViewMonth: (DataModel.Spread) -> Void

        init(
            model: Model,
            monthSpreads: [Date: DataModel.Spread] = [:],
            calendar: Calendar,
            today: Date,
            onViewMonth: @escaping (DataModel.Spread) -> Void = { _ in }
        ) {
            self.model = model
            self.monthSpreads = monthSpreads
            self.calendar = calendar
            self.today = today
            self.onViewMonth = onViewMonth
        }

        // MARK: Header

        /// Card-style month header: `SpreadCardStyle` fill/stroke communicates whether an
        /// explicit month spread exists (with today-month emphasis), and a "View month"
        /// button navigates to it when it does. The chip itself is not a tap target.
        func headerView(month: Date) -> some View {

            let monthYearString: String = {
                let formatter = DateFormatter()
                formatter.calendar = calendar
                formatter.timeZone = calendar.timeZone
                formatter.dateFormat = "MMMM yyyy"
                return formatter.string(from: month)
            }()

            let monthStart = Period.month.normalizeDate(month, calendar: calendar)
            let monthSpread = monthSpreads[monthStart]
            let cardStyle = SpreadCardStyle(
                isToday: calendar.isDate(month, equalTo: today, toGranularity: .month),
                isCreated: monthSpread != nil
            )

            HStack(spacing: SpreadTheme.Spacing.small) {
                Text(monthYearString)
                    .font(SpreadTheme.Typography.headline)
                    .foregroundStyle(cardStyle.textColor)

                Spacer()

                if let monthSpread {
                    SpreadButton("View month", style: .plain, size: .small) {
                        onViewMonth(monthSpread)
                    }
                }
            }
            .padding(.horizontal, SpreadTheme.Spacing.standard)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: SpreadTheme.CornerRadius.card, style: .continuous)
                    .fill(cardStyle.spreadNavigatorFillColor)
                    .strokeBorder(cardStyle.spreadNavigatorStrokeColor, style: cardStyle.borderStyle)
            )
            .padding(.horizontal, SpreadTheme.Spacing.large)
            .padding(.top, SpreadTheme.Spacing.large)
            .padding(.bottom, SpreadTheme.Spacing.small)
        }

        // MARK: Weekday Header

        func weekdayHeaderView(weekday: Int) -> some View {
            Text(calendar.veryShortWeekdaySymbols[weekday - 1].prefix(1))
                .font(SpreadTheme.Typography.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }

        // MARK: Day Cell

        func dayCellView(date: Date) -> some View {

            let isToday = calendar.isDate(date, inSameDayAs: today)
            
            let spreads: [DataModel.Spread] = model[date.startOfDay(calendar: calendar)]?.filter {
                $0.period == .day &&
                $0.contains(date: date, calendar: calendar)
            } ?? []
            
            let dayNumber = calendar.component(.day, from: date)

            let cardStyle = SpreadCardStyle(isToday: isToday, isCreated: !spreads.isEmpty)
            let fillColor: Color = cardStyle.spreadNavigatorFillColor
            let strokeColor: Color = cardStyle.spreadNavigatorStrokeColor
            let textColor: Color = cardStyle.textColor

            return Text("\(dayNumber)")
                .font(SpreadTheme.Typography.subheadline)
                .fontWeight(cardStyle.headerWeight)
                .foregroundStyle(textColor)
                .lineLimit(1)
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: SpreadTheme.CornerRadius.badge, style: .continuous)
                        .fill(fillColor)
                        .strokeBorder(strokeColor, style: cardStyle.borderStyle)
                )
                .aspectRatio(1, contentMode: .fit)
                .padding(2)
        }

        // MARK: Placeholder Cell

        func placeholderCellView(date: Date) -> some View {
            Color.clear
        }

        // MARK: Week Background

        /// Must return a sized view (not EmptyView) so the row overlay layer has geometry to render against.
        func weekBackgroundView(week: MonthCalendarWeek) -> some View {
            Color.clear
        }
    }
}

fileprivate extension SpreadCardStyle {
    var spreadNavigatorFillColor: Color {
        switch self {
        case .created, .todayCreated, .todayUncreated:
            return self.fill
        case .uncreated:
            return .clear
        }
    }
    
    var spreadNavigatorStrokeColor: Color {
        switch self {
        case .created, .todayCreated, .todayUncreated:
            return self.borderColor
        case .uncreated:
            return .clear
        }
    }
    
    var textColor: Color {
        switch self {
        case .created, .todayCreated, .todayUncreated:
            return .primary
        case .uncreated:
            return .secondary
        }
    }
}

// MARK: - Row Overlay Generator

extension SpreadsNavigatorView {

    /// Renders each multiday spread as a continuous low-opacity accent band running behind
    /// the covered day cells (rounded caps at range ends) — the same range vocabulary as the
    /// entry sheet's assignment calendar highlight. The overlay layer sits behind the day
    /// cell layer, so cells stay fully legible on top. When two spreads overlap, the
    /// existing lane packing splits the row height and the bands stack as offset
    /// translucent strips.
    struct RowOverlayGenerator: MonthCalendarRowOverlayGenerator {

        private static let bandPadding: CGFloat = 2

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
                .fill(SpreadTheme.Accent.primary.opacity(SpreadTheme.Opacity.cardFill))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(Self.bandPadding)
        }

        func overflowView(
            context: MonthCalendarRowOverlayOverflowRenderContext<UUID, Bool>
        ) -> some View {
            EmptyView()
        }
    }
}
