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
/// Concurrent events (those whose time ranges overlap) are partitioned into
/// side-by-side columns. `DayTimelineItemContext.columnIndex` and `columnCount`
/// tell the provider where to render each item horizontally.
///
/// When `date` is today, a live red current-time indicator (line + circle) is
/// rendered and updated automatically every minute via `TimelineView`.
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

    /// Corner radius applied to the outer clip shape. Pass `0` for rectangular clipping (default).
    public var cornerRadius: CGFloat = 0

    /// Calendar used to resolve hour components for the visible window.
    public var calendar: Calendar = .current

    // MARK: - Layout constants

    private let rulerWidth: CGFloat = 44
    /// Minimum rendered height for any event block, regardless of duration.
    private let minimumEventHeight: CGFloat = 44
    /// Duration threshold below which the minimum height floor is applied, in seconds (30 min).
    private let minimumHeightThresholdSeconds: TimeInterval = 30 * 60
    /// Height of the current-time capsule indicator.
    private let currentTimeCapsuleHeight: CGFloat = 16

    // MARK: - Init

    public init(
        provider: Provider,
        items: [Provider.Item],
        date: Date,
        visibleStartHour: Int = 6,
        visibleEndHour: Int = 22,
        height: CGFloat = 240,
        cornerRadius: CGFloat = 0,
        calendar: Calendar = .current
    ) {
        self.provider = provider
        self.items = items
        self.date = date
        self.visibleStartHour = visibleStartHour
        self.visibleEndHour = visibleEndHour
        self.height = height
        self.cornerRadius = cornerRadius
        self.calendar = calendar
    }

    // MARK: - Body

    public var body: some View {
        TimelineView(.everyMinute) { timelineContext in
            HStack(spacing: 0) {
                rulerView
                eventZone
            }
            .frame(height: height)
            .overlay(alignment: .topLeading) {
                // Current-time indicator spans the full width (ruler + event zone),
                // rendered as an overlay so the circle is not clipped by the event zone.
                currentTimeIndicator(now: timelineContext.date)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
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

            // Timed item blocks (all-day items excluded)
            let contexts = layoutContexts
            ForEach(contexts, id: \.id) { context in
                GeometryReader { geo in
                    let columnWidth = geo.size.width / CGFloat(context.columnCount)
                    let xOffset = CGFloat(context.columnIndex) * columnWidth
                    provider.itemView(context: context)
                        .frame(width: columnWidth, height: max(context.height, 1))
                        .offset(x: xOffset)
                }
                .frame(height: max(context.height, 1))
                .offset(y: context.yOffset)
            }
        }
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
        .clipped()
    }

    // MARK: - Current time indicator

    @ViewBuilder
    private func currentTimeIndicator(now: Date) -> some View {
        let isToday = calendar.isDateInToday(date)
        let yOffset = coordinateSpace.yOffset(for: now)
        let withinWindow = now >= hourDate(visibleStartHour) && now <= hourDate(visibleEndHour)

        if isToday && withinWindow {
            ZStack(alignment: .topLeading) {
                // Horizontal line — starts at the ruler boundary and extends to the right
                Rectangle()
                    .fill(Color.red)
                    .frame(height: 1)
                    .padding(.leading, rulerWidth)

                // Time capsule centered vertically on the line, anchored to the ruler area.
                // Shows the current time (locale-aware) in a red pill, matching Apple Calendar.
                currentTimeCapsule(now: now)
                    .offset(y: -currentTimeCapsuleHeight / 2)
            }
            .offset(y: yOffset)
        }
    }

    /// Locale-aware short time string for `now`.
    private func formattedCurrentTime(_ now: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: now)
    }

    /// Red capsule containing the current time string, sized to fit within the ruler column.
    private func currentTimeCapsule(now: Date) -> some View {
        Text(formattedCurrentTime(now))
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .frame(height: currentTimeCapsuleHeight)
            .frame(maxWidth: rulerWidth)
            .background(Color.red)
            .clipShape(Capsule(style: .continuous))
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

    // MARK: - Column layout

    /// Delegates to `DayTimelineLayoutEngine` to compute column-partitioned layout contexts.
    private var layoutContexts: [DayTimelineItemContext<Provider.Item>] {
        DayTimelineLayoutEngine.layoutContexts(
            items: items,
            startDate: provider.startDate,
            endDate: provider.endDate,
            isAllDay: provider.isAllDay,
            coordinateSpace: coordinateSpace,
            minimumEventHeight: minimumEventHeight,
            minimumHeightThresholdSeconds: minimumHeightThresholdSeconds
        )
    }
}
