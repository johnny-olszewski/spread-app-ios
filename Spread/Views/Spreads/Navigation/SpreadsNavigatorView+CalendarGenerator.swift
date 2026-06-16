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
        let calendar: Calendar
        let today: Date
        
        init(model: Model, calendar: Calendar, today: Date) {
            self.model = model
            self.calendar = calendar
            self.today = today
        }

        // MARK: Header

        func headerView(month: Date) -> some View {
            
            let monthYearString: String = {
                let formatter = DateFormatter()
                formatter.calendar = calendar
                formatter.timeZone = calendar.timeZone
                formatter.dateFormat = "MMMM yyyy"
                return formatter.string(from: month)
            }()
            
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

        // MARK: Weekday Header

        func weekdayHeaderView(weekday: Int) -> some View {
            Text(calendar.veryShortWeekdaySymbols[weekday - 1].prefix(1))
                .font(.caption2)
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
                .font(.subheadline)
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
