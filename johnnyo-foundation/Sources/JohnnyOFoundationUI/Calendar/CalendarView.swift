import SwiftUI
import JohnnyOFoundationCore

/// A vertically scrolling calendar that renders one `MonthCalendarView` per calendar month
/// between `startDate` and `endDate`, inclusive of both boundary months.
///
/// The same `contentGenerator` instance serves all months — it is called per-cell across the
/// entire range. Month construction is deferred via `LazyVStack`, so off-screen months are
/// not instantiated until scrolled into view.
///
/// Foundation does not own any disambiguation UI for dates with multiple associated items.
/// The `onDateTapped` callback fires with the raw tapped date; the caller is responsible for
/// resolving what to present.
public struct CalendarView<
    Generator: CalendarContentGenerator,
    OverlayGenerator: MonthCalendarRowOverlayGenerator
>: View {

    private let months: [Date]
    private let calendar: Calendar
    private let today: Date
    private let configuration: MonthCalendarConfiguration
    private let contentGenerator: Generator
    private let rowOverlayGenerator: OverlayGenerator
    private let initialScrollTarget: Date?
    private let onDateTapped: (Date) -> Void

    // MARK: - Init (without overlays)

    /// Creates a multi-month calendar without row overlays.
    ///
    /// - Parameters:
    ///   - startDate: The start of the date range. The month containing this date is included.
    ///   - endDate: The end of the date range. The month containing this date is included.
    ///   - calendar: The calendar used for month boundary calculations.
    ///   - today: The current date, used to mark today's cell in each month. Defaults to `Date()`.
    ///   - configuration: Layout configuration forwarded to each `MonthCalendarView`.
    ///   - contentGenerator: The generator that supplies views for each calendar slot.
    ///   - initialScrollTarget: When non-nil, the calendar scrolls to the month containing this
    ///     date on first appear. The date is normalized to the first of its month for lookup.
    ///   - onDateTapped: Called when the user taps a date cell, receiving the tapped `Date`.
    public init(
        startDate: Date,
        endDate: Date,
        calendar: Calendar,
        today: Date = Date(),
        configuration: MonthCalendarConfiguration = .init(),
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
            contentGenerator: contentGenerator,
            rowOverlayGenerator: EmptyMonthCalendarRowOverlayGenerator(),
            initialScrollTarget: initialScrollTarget,
            onDateTapped: onDateTapped
        )
    }

    /// Creates a multi-month calendar with row overlays.
    ///
    /// - Parameters:
    ///   - startDate: The start of the date range. The month containing this date is included.
    ///   - endDate: The end of the date range. The month containing this date is included.
    ///   - calendar: The calendar used for month boundary calculations.
    ///   - today: The current date, used to mark today's cell in each month. Defaults to `Date()`.
    ///   - configuration: Layout configuration forwarded to each `MonthCalendarView`.
    ///   - contentGenerator: The generator that supplies views for each calendar slot.
    ///   - rowOverlayGenerator: The generator that supplies row-bounded overlay decorations.
    ///   - initialScrollTarget: When non-nil, the calendar scrolls to the month containing this
    ///     date on first appear. The date is normalized to the first of its month for lookup.
    ///   - onDateTapped: Called when the user taps a date cell, receiving the tapped `Date`.
    public init(
        startDate: Date,
        endDate: Date,
        calendar: Calendar,
        today: Date = Date(),
        configuration: MonthCalendarConfiguration = .init(),
        contentGenerator: Generator,
        rowOverlayGenerator: OverlayGenerator,
        initialScrollTarget: Date? = nil,
        onDateTapped: @escaping (Date) -> Void
    ) {
        self.months = monthDateRange(from: startDate, to: endDate, calendar: calendar)
        self.calendar = calendar
        self.today = today
        self.configuration = configuration
        self.contentGenerator = contentGenerator
        self.rowOverlayGenerator = rowOverlayGenerator
        self.initialScrollTarget = initialScrollTarget
        self.onDateTapped = onDateTapped
    }

    // MARK: - Body

    public var body: some View {
        let delegate = DateTapDelegate(onDateTapped)
        let scrollTarget = resolvedScrollTarget
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
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
            }
            .onAppear {
                guard let target = scrollTarget else { return }
                // Defer one run-loop iteration so LazyVStack has established geometry
                // for items beyond the initial visible window before scrollTo fires.
                DispatchQueue.main.async {
                    proxy.scrollTo(target, anchor: .top)
                }
            }
        }
        .accessibilityIdentifier("johnnyo.foundation.calendarView")
    }

    /// Normalizes `initialScrollTarget` to the first-of-month date used as each month's ID,
    /// returning `nil` when no target is set or the target falls outside the rendered range.
    private var resolvedScrollTarget: Date? {
        guard let raw = initialScrollTarget,
              let firstOfMonth = calendar.date(
                from: calendar.dateComponents([.year, .month], from: raw)
              ),
              months.contains(firstOfMonth)
        else { return nil }
        return firstOfMonth
    }
}

// MARK: - Month Range

/// Computes the first-of-month dates covering every calendar month from the month containing
/// `startDate` to the month containing `endDate`, in ascending order.
///
/// Exposed at internal access so package tests can verify the computation via
/// `@testable import JohnnyOFoundationUI`.
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

    func monthCalendarDidTapDay(_ context: MonthCalendarDayContext) {
        handler(context.date)
    }
}
