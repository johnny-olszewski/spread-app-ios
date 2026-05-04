import SwiftUI
import JohnnyOFoundationCore

/// A fixed-height day timeline that renders a time ruler and proportionally
/// positioned event blocks for a given provider and item list.
///
/// The visible time window is configurable (default 6 AM–10 PM). Pass
/// `visibleStartHour: 0, visibleEndHour: 24` for a full-day view. Items that
/// start before or end after the window are clamped so they remain partially
/// visible at the edges.
///
/// All-day items (those for which `provider.isAllDay(item:)` returns `true`)
/// are excluded from the timed grid. They are typically rendered separately via
/// `DayTimelineAllDaySection` above this view.
///
/// Overlapping timed items are rendered in start-time order with escalating
/// leading offsets so later-starting events remain partially visible.
public struct DayTimelineView<Provider: DayTimelineContentProvider>: View {

    // MARK: - Configuration

    /// The provider that supplies rendering for items and ruler labels.
    public let provider: Provider

    /// Items to display. All-day items (per `provider.isAllDay`) are excluded
    /// from the timed grid automatically.
    public let items: [Provider.Item]

    /// The calendar day this timeline represents.
    public let date: Date

    /// The hour at the top of the visible window (0–24). Default `6` (6 AM).
    public var visibleStartHour: Int = 6

    /// The hour at the bottom of the visible window (0–24). Pass `24` for
    /// midnight at the end of the day. Default `22` (10 PM).
    public var visibleEndHour: Int = 22

    /// Total height of the rendered view, in points. Default `240`.
    public var height: CGFloat = 240

    /// Calendar used to resolve hour components for the visible window.
    public var calendar: Calendar = .current

    // MARK: - Layout constants

    private let rulerWidth: CGFloat = 44
    private let overlapStep: CGFloat = 12

    // MARK: - Init

    public init(
        provider: Provider,
        items: [Provider.Item],
        date: Date,
        visibleStartHour: Int = 6,
        visibleEndHour: Int = 22,
        height: CGFloat = 240,
        calendar: Calendar = .current
    ) {
        self.provider = provider
        self.items = items
        self.date = date
        self.visibleStartHour = visibleStartHour
        self.visibleEndHour = visibleEndHour
        self.height = height
        self.calendar = calendar
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: 0) {
            rulerView
            eventZone
        }
        .frame(height: height)
        .clipped()
    }

    // MARK: - Subviews

    private var rulerView: some View {
        ZStack(alignment: .topLeading) {
            ForEach(visibleHours, id: \.self) { hour in
                provider.timeRulerLabel(hour: hour)
                    .offset(y: labelYOffset(for: hour))
            }
        }
        .frame(width: rulerWidth, height: height, alignment: .topLeading)
        .clipped()
    }

    private var eventZone: some View {
        ZStack(alignment: .topLeading) {
            // Hour divider lines
            ForEach(visibleHours, id: \.self) { hour in
                Divider()
                    .offset(y: coordinateSpace.yOffset(for: hourDate(hour)))
            }

            // Timed item blocks (all-day items are excluded)
            ForEach(layoutContexts, id: \.id) { context in
                provider.itemView(context: context)
                    .frame(height: max(context.height, 1))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, context.overlapOffset)
                    .offset(y: context.yOffset)
            }
        }
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
        .clipped()
    }

    // MARK: - Coordinate space

    private var coordinateSpace: DayTimeCoordinateSpace {
        DayTimeCoordinateSpace(
            visibleStart: hourDate(visibleStartHour),
            visibleEnd: hourDate(visibleEndHour),
            totalHeight: height
        )
    }

    // MARK: - Layout helpers

    private var visibleHours: [Int] {
        Array(visibleStartHour...visibleEndHour)
    }

    /// Converts an hour integer to a `Date` on the timeline's day.
    ///
    /// `hour == 24` is treated as midnight at the start of the following day
    /// rather than an invalid component, enabling a full-day window of 0–24.
    private func hourDate(_ hour: Int) -> Date {
        guard hour < 24 else {
            let startOfDay = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: date) ?? date
            return calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        }
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
    }

    /// Y offset that vertically centers a ruler label on its hour line.
    private func labelYOffset(for hour: Int) -> CGFloat {
        let y = coordinateSpace.yOffset(for: hourDate(hour))
        return max(y - 8, 0)
    }

    /// Computes `DayTimelineItemContext` values for timed items (all-day excluded),
    /// sorted by start time with overlap offsets applied.
    private var layoutContexts: [DayTimelineItemContext<Provider.Item>] {
        let timedItems = items.filter { !provider.isAllDay(item: $0) }
        let sorted = timedItems.sorted { provider.startDate(for: $0) < provider.startDate(for: $1) }
        var contexts: [DayTimelineItemContext<Provider.Item>] = []

        for item in sorted {
            let start = provider.startDate(for: item)
            let end = provider.endDate(for: item)
            let yOff = coordinateSpace.yOffset(for: start)
            let h = coordinateSpace.height(from: start, to: end)

            let overlapDepth = contexts.filter { prior in
                let priorStart = provider.startDate(for: prior.item)
                let priorEnd = provider.endDate(for: prior.item)
                return priorStart < end && priorEnd > start
            }.count

            let context = DayTimelineItemContext(
                item: item,
                yOffset: yOff,
                height: h,
                overlapOffset: CGFloat(overlapDepth) * overlapStep,
                coordinateSpace: coordinateSpace
            )
            contexts.append(context)
        }

        return contexts
    }
}
