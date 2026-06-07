import SwiftUI
import JohnnyOFoundationCore

/// A self-contained scrollable day timeline that composes an optional all-day section
/// above a vertically-scrollable timed event grid.
///
/// Pass all items (all-day and timed) via `items`; the component uses
/// `generator.isAllDay(item:)` to split them internally. All-day items are
/// rendered via `generator.allDayItemView(item:)` in a pinned non-scrolling header;
/// timed items are rendered in a `DayTimelineView` inside a `ScrollView`.
///
/// The scrollable content height is determined by `containerRelativeFrame` with
/// `verticalCount`/`verticalSpan` — the grid becomes `verticalSpan/verticalCount`
/// times the scroll view's visible height, ensuring scrollable content on all
/// device sizes without manual height arithmetic.
///
/// On load and whenever the timed item count changes, the component
/// automatically scrolls to the first timed event. Pass a `scrollPosition`
/// binding to observe or override the scroll position from outside.
public struct DayTimelineScrollView<Provider: DayTimelineContentProvider>: View {

    // MARK: - Configuration

    public let generator: Provider

    /// All items for the day. All-day and timed items are separated internally
    /// via `provider.isAllDay(item:)`.
    public let items: [Provider.Item]

    /// The calendar day this timeline represents.
    public let date: Date

    /// The hour at the top of the visible window (0–24). Default `0` (midnight).
    public var visibleStartHour: Int = 0

    /// The hour at the bottom of the visible window (0–24). Default `24` (end of day).
    public var visibleEndHour: Int = 24

    /// Together, these control the scrollable content height relative to the
    /// scroll view's visible frame via `containerRelativeFrame(.vertical)`.
    /// Default `span: 3, count: 1` makes the grid 3× the visible card height.
    public var verticalCount: Int = 1
    public var verticalSpan: Int = 3

    public var calendar: Calendar = .current

    /// Corner radius forwarded to `DayTimelineView` for its clip shape. Default `0`.
    public var cornerRadius: CGFloat = 0

    /// Optional external scroll position. When `nil` the component manages
    /// scroll state internally.
    public var scrollPosition: Binding<ScrollPosition>?

    // MARK: - State

    @State private var internalScrollPosition = ScrollPosition()

    /// Measured height of the scrollable content area; used only by `scrollToFirstEvent`.
    @State private var scrollableHeight: CGFloat = 1000

    // MARK: - Init

    public init(
        generator: Provider,
        items: [Provider.Item],
        date: Date,
        visibleStartHour: Int = 0,
        visibleEndHour: Int = 24,
        verticalCount: Int = 1,
        verticalSpan: Int = 3,
        calendar: Calendar = .current,
        cornerRadius: CGFloat = 0,
        scrollPosition: Binding<ScrollPosition>? = nil
    ) {
        self.generator = generator
        self.items = items
        self.date = date
        self.visibleStartHour = visibleStartHour
        self.visibleEndHour = visibleEndHour
        self.verticalCount = verticalCount
        self.verticalSpan = verticalSpan
        self.calendar = calendar
        self.cornerRadius = cornerRadius
        self.scrollPosition = scrollPosition
    }

    // MARK: - Derived

    private var allDayItems: [Provider.Item] { items.filter { generator.isAllDay(item: $0) } }
    private var timedItems: [Provider.Item] { items.filter { !generator.isAllDay(item: $0) } }

    private var effectiveScrollPosition: Binding<ScrollPosition> {
        scrollPosition ?? $internalScrollPosition
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            if !allDayItems.isEmpty {
                DayTimelineAllDaySection(items: allDayItems) { generator.allDayItemView(item: $0) }
                Divider()
            }

            ScrollView {
                GeometryReader { proxy in
                    DayTimelineView(
                        provider: generator,
                        items: timedItems,
                        date: date,
                        visibleStartHour: visibleStartHour,
                        visibleEndHour: visibleEndHour,
                        height: proxy.size.height,
                        cornerRadius: cornerRadius,
                        calendar: calendar
                    )
                    .padding(8)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                        if $0 > 0 { scrollableHeight = $0 }
                    }
                }
                .containerRelativeFrame(.vertical, count: verticalCount, span: verticalSpan, spacing: 0)
            }
            .scrollIndicators(.hidden)
            .scrollPosition(effectiveScrollPosition)
            .onChange(of: timedItems.count) { _, _ in scrollToInitialPosition() }
        }
        .task { scrollToInitialPosition() }
    }

    // MARK: - Private

    /// Margin (in points) above the scroll target to keep the current-time line
    /// or first event from being flush against the top of the scroll view.
    private let scrollTopMargin: CGFloat = 60

    /// Scrolls to the appropriate initial position:
    /// - Today: current time minus `scrollTopMargin` so the red line is visible near the top.
    /// - Other dates: the start of the earliest timed event.
    private func scrollToInitialPosition() {
        let coordinateSpace = DayTimeCoordinateSpace(
            visibleStart: hourDate(visibleStartHour),
            visibleEnd: hourDate(visibleEndHour),
            totalHeight: scrollableHeight
        )

        let targetDate: Date
        if calendar.isDateInToday(date) {
            targetDate = Date()
        } else if let firstItem = timedItems.min(by: { generator.startDate(for: $0) < generator.startDate(for: $1) }) {
            targetDate = generator.startDate(for: firstItem)
        } else {
            return
        }

        let rawY = coordinateSpace.yOffset(for: targetDate)
        let targetY = max(rawY - scrollTopMargin, 0)
        effectiveScrollPosition.wrappedValue = ScrollPosition(y: targetY)
    }

    /// Converts an hour integer to a `Date` on the timeline's day.
    /// `hour == 24` is treated as midnight at the start of the following day.
    private func hourDate(_ hour: Int) -> Date {
        guard hour < 24 else {
            let startOfDay = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: date) ?? date
            return calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        }
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
    }
}
