import SwiftUI
import JohnnyOFoundationCore

// MARK: - Display Configuration

/// Controls the scroll direction, scroll availability, and month-count behaviour of `CalendarView`.
///
/// Pass a non-default value to `CalendarView.init` to change how the calendar is presented:
///
/// ```swift
/// // Single-month pager with prev/next buttons (matches the native DatePicker .graphical style)
/// CalendarView(..., displayConfiguration: .singleMonthPager, ...)
///
/// // Horizontal multi-month scroll strip
/// CalendarView(..., displayConfiguration: .init(scrollDirection: .horizontal), ...)
/// ```
public struct CalendarViewDisplayConfiguration: Sendable {

    public enum ScrollDirection: Sendable {
        case vertical
        case horizontal
    }

    /// The axis along which months are laid out and (when `isScrollEnabled`) scrolled.
    /// Defaults to `.vertical`.
    public var scrollDirection: ScrollDirection

    /// Whether the user can scroll through months by dragging. When `false` the months list
    /// is rendered without a `ScrollView` wrapper (single-month mode) or inside a
    /// scroll-disabled `ScrollView` (multi-month mode). Defaults to `true`.
    public var isScrollEnabled: Bool

    /// When `true`, only one month is visible at a time. `CalendarView` renders its own
    /// navigation header with prev/next chevron buttons and suppresses the content
    /// generator's `headerView`. Defaults to `false`.
    public var isSingleMonth: Bool

    public init(
        scrollDirection: ScrollDirection = .vertical,
        isScrollEnabled: Bool = true,
        isSingleMonth: Bool = false
    ) {
        self.scrollDirection = scrollDirection
        self.isScrollEnabled = isScrollEnabled
        self.isSingleMonth = isSingleMonth
    }

    /// Multi-month vertical scrolling list — the original `CalendarView` behaviour.
    public static let `default` = CalendarViewDisplayConfiguration()

    /// Single-month pager: prev/next chevron buttons, no dragging, matches the
    /// feel of the native SwiftUI `DatePicker` in `.graphical` style.
    public static let singleMonthPager = CalendarViewDisplayConfiguration(
        scrollDirection: .horizontal,
        isScrollEnabled: false,
        isSingleMonth: true
    )
}

// MARK: - CalendarView

/// A calendar that renders one or more `MonthCalendarView` instances between `startDate`
/// and `endDate`, with layout and navigation controlled by `CalendarViewDisplayConfiguration`.
///
/// **Multi-month mode** (default): a scrolling list of months along the configured axis.
///
/// **Single-month mode** (`displayConfiguration.isSingleMonth == true`): one month visible
/// at a time, with a built-in navigation header containing prev/next chevron buttons and the
/// current month/year label. The content generator's `headerView` is suppressed in this mode —
/// `CalendarView` owns the full header chrome.
///
/// Foundation does not own any disambiguation UI for dates with multiple associated items.
/// The `onDateTapped` callback fires with the raw tapped date; the caller is responsible for
/// resolving what to present.
public struct CalendarView<
    Generator: CalendarContentGenerator,
    OverlayGenerator: MonthCalendarRowOverlayGenerator
>: View {

    private let months: [Date]
    private let startDate: Date
    private let endDate: Date
    private let calendar: Calendar
    private let today: Date
    private let configuration: MonthCalendarConfiguration
    private let displayConfiguration: CalendarViewDisplayConfiguration
    private let contentGenerator: Generator
    private let rowOverlayGenerator: OverlayGenerator
    private let initialScrollTarget: Date?
    private let onDateTapped: (Date) -> Void

    /// Multi-month: backs `.scrollPosition(id:anchor:)`, seeded from `initialScrollTarget`.
    @State private var scrollPosition: Date?

    /// Single-month: the month currently displayed.
    @State private var currentMonth: Date

    // MARK: - Init (without overlays)

    /// Creates a multi-month calendar without row overlays.
    public init(
        startDate: Date,
        endDate: Date,
        calendar: Calendar,
        today: Date = Date(),
        configuration: MonthCalendarConfiguration = .init(),
        displayConfiguration: CalendarViewDisplayConfiguration = .default,
        contentGenerator: Generator,
        initialScrollTarget: Date? = nil,
        onDateTapped: @escaping (Date) -> Void
    ) where OverlayGenerator == EmptyMonthCalendarRowOverlayGenerator {
        self.init(
            startDate: startDate,
            endDate: endDate,
            calendar: calendar,
            today: today,
            configuration: configuration,
            displayConfiguration: displayConfiguration,
            contentGenerator: contentGenerator,
            rowOverlayGenerator: EmptyMonthCalendarRowOverlayGenerator(),
            initialScrollTarget: initialScrollTarget,
            onDateTapped: onDateTapped
        )
    }

    /// Creates a multi-month calendar with row overlays.
    public init(
        startDate: Date,
        endDate: Date,
        calendar: Calendar,
        today: Date = Date(),
        configuration: MonthCalendarConfiguration = .init(),
        displayConfiguration: CalendarViewDisplayConfiguration = .default,
        contentGenerator: Generator,
        rowOverlayGenerator: OverlayGenerator,
        initialScrollTarget: Date? = nil,
        onDateTapped: @escaping (Date) -> Void
    ) {
        let months = monthDateRange(from: startDate, to: endDate, calendar: calendar)
        self.months = months
        self.startDate = startDate
        self.endDate = endDate
        self.calendar = calendar
        self.today = today
        self.configuration = configuration
        self.displayConfiguration = displayConfiguration
        self.contentGenerator = contentGenerator
        self.rowOverlayGenerator = rowOverlayGenerator
        self.initialScrollTarget = initialScrollTarget
        self.onDateTapped = onDateTapped
        self._scrollPosition = State(
            initialValue: resolvedCalendarScrollTarget(
                initialScrollTarget: initialScrollTarget,
                startDate: startDate,
                endDate: endDate,
                calendar: calendar,
                months: months
            )
        )
        self._currentMonth = State(
            initialValue: resolvedInitialMonth(
                from: initialScrollTarget,
                startDate: startDate,
                calendar: calendar,
                months: months
            )
        )
    }

    // MARK: - Body

    public var body: some View {
        if displayConfiguration.isSingleMonth {
            singleMonthBody
        } else {
            multiMonthBody
        }
    }

    // MARK: - Multi-month body

    private var multiMonthBody: some View {
        let delegate = DateTapDelegate(onDateTapped)
        let stack = Group {
            switch displayConfiguration.scrollDirection {
            case .vertical:
                LazyVStack(spacing: 0) { monthViews(delegate: delegate) }
            case .horizontal:
                LazyHStack(spacing: 0) {
                    monthViews(delegate: delegate)
                        .containerRelativeFrame(.horizontal)
                }
            }
        }
        return Group {
            if displayConfiguration.isScrollEnabled {
                ScrollView(displayConfiguration.scrollDirection == .vertical ? .vertical : .horizontal) {
                    stack
                }
                .scrollIndicators(.hidden)
                .scrollPosition(id: $scrollPosition, anchor: .center)
                .accessibilityIdentifier("johnnyo.foundation.calendarView")
            } else {
                stack
                    .accessibilityIdentifier("johnnyo.foundation.calendarView")
            }
        }
    }

    @ViewBuilder
    private func monthViews(delegate: DateTapDelegate) -> some View {
        ForEach(months, id: \.self) { month in
            MonthCalendarView(
                displayedMonth: month,
                calendar: calendar,
                today: today,
                configuration: configuration,
                contentGenerator: contentGenerator,
                rowOverlayGenerator: rowOverlayGenerator,
                actionDelegate: delegate
            )
            .id(month)
        }
    }

    // MARK: - Single-month body

    private var singleMonthBody: some View {
        let singleMonthConfig = MonthCalendarConfiguration(
            showsPeripheralDates: configuration.showsPeripheralDates,
            showsMonthHeader: false
        )
        let delegate = DateTapDelegate(onDateTapped)
        return VStack(spacing: 0) {
            singleMonthNavHeader
            MonthCalendarView(
                displayedMonth: currentMonth,
                calendar: calendar,
                today: today,
                configuration: singleMonthConfig,
                contentGenerator: contentGenerator,
                rowOverlayGenerator: rowOverlayGenerator,
                actionDelegate: delegate
            )
        }
        .accessibilityIdentifier("johnnyo.foundation.calendarView")
    }

    private var singleMonthNavHeader: some View {
        HStack(spacing: 0) {
            Button {
                moveToPreviousMonth()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(!canMoveToPreviousMonth)
            .accessibilityLabel("Previous month")

            Spacer()

            Text(monthYearLabel(for: currentMonth))
                .font(.headline)

            Spacer()

            Button {
                moveToNextMonth()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(!canMoveToNextMonth)
            .accessibilityLabel("Next month")
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Month navigation

    private var canMoveToPreviousMonth: Bool {
        guard let prev = calendar.date(byAdding: .month, value: -1, to: currentMonth) else { return false }
        return prev >= (months.first ?? startDate)
    }

    private var canMoveToNextMonth: Bool {
        guard let next = calendar.date(byAdding: .month, value: 1, to: currentMonth) else { return false }
        return next <= (months.last ?? endDate)
    }

    private func moveToPreviousMonth() {
        guard let prev = calendar.date(byAdding: .month, value: -1, to: currentMonth),
              prev >= (months.first ?? startDate) else { return }
        currentMonth = prev
    }

    private func moveToNextMonth() {
        guard let next = calendar.date(byAdding: .month, value: 1, to: currentMonth),
              next <= (months.last ?? endDate) else { return }
        currentMonth = next
    }

    private func monthYearLabel(for month: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: month)
    }
}

// MARK: - Initial Scroll Target

/// Normalizes `initialScrollTarget` to the first-of-month date used as each month's `id`,
/// returning `nil` when no target is set or it falls outside the rendered range.
func resolvedCalendarScrollTarget(
    initialScrollTarget: Date?,
    startDate: Date,
    endDate: Date,
    calendar: Calendar,
    months: [Date]
) -> Date? {
    guard let raw = initialScrollTarget,
          (startDate...endDate).contains(raw),
          let firstOfMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: raw)
          ),
          months.contains(firstOfMonth)
    else { return nil }
    return firstOfMonth
}

/// Resolves the initial visible month for single-month mode from `initialScrollTarget`,
/// falling back to the first month in the range when the target is absent or out of range.
func resolvedInitialMonth(
    from target: Date?,
    startDate: Date,
    calendar: Calendar,
    months: [Date]
) -> Date {
    guard let raw = target,
          let targetFirstOfMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: raw)
          ),
          months.contains(targetFirstOfMonth)
    else { return months.first ?? startDate }
    return targetFirstOfMonth
}

// MARK: - Month Range

/// Computes the first-of-month dates covering every calendar month from the month containing
/// `startDate` to the month containing `endDate`, in ascending order.
func monthDateRange(from startDate: Date, to endDate: Date, calendar: Calendar) -> [Date] {
    guard
        let firstMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: startDate)),
        let lastMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: endDate))
    else {
        return []
    }

    var dates: [Date] = []
    var current = firstMonth
    while current <= lastMonth {
        dates.append(current)
        guard let next = calendar.date(byAdding: .month, value: 1, to: current) else { break }
        current = next
    }
    return dates
}

// MARK: - Date Tap Delegate

/// Bridges `MonthCalendarActionDelegate` day-tap events to the `onDateTapped` closure.
private final class DateTapDelegate: MonthCalendarActionDelegate {

    let handler: (Date) -> Void

    init(_ handler: @escaping (Date) -> Void) {
        self.handler = handler
    }

    func monthCalendarDidTapDay(date: Date) {
        handler(date)
    }
}
