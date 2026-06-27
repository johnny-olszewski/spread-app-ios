import SwiftUI
import JohnnyOFoundationCore
import JohnnyOFoundationUI

/// `DayTimelineContentProvider` conformance that renders `CalendarEvent` items
/// using Apple Calendar–style event blocks: a colored left bar, tinted background,
/// title, time range, and optional location.
///
/// Concurrent events are rendered side-by-side using `context.columnIndex`
/// and `context.columnCount` from the foundation's column-partitioning algorithm.
struct SpreadDayTimelineContentGenerator: DayTimelineContentProvider {
    typealias Item = CalendarEvent

    // MARK: - DayTimelineContentProvider

    func startDate(for item: CalendarEvent) -> Date { item.startDate }

    func endDate(for item: CalendarEvent) -> Date { item.endDate }

    func isAllDay(item: CalendarEvent) -> Bool { item.isAllDay }

    @ViewBuilder
    func itemView(context: DayTimelineItemContext<CalendarEvent>) -> some View {
        GeometryReader { geo in
            let columnWidth = geo.size.width  // already width-fractioned by DayTimelineView
            SpreadDayTimelineEventBlock(event: context.item, availableHeight: context.height)
                .frame(width: columnWidth, height: context.height)
        }
    }

    @ViewBuilder
    func timeRulerLabel(hour: Int) -> some View {
        Text(formattedHour(hour))
            .font(SpreadTheme.Typography.caption)
            .foregroundStyle(.tertiary)
            .lineLimit(1)
    }

    // MARK: - All-day rendering

    /// Pill-shaped chip for an all-day event rendered in `DayTimelineAllDaySection`.
    @ViewBuilder
    func allDayItemView(item: CalendarEvent) -> some View {
        Text(item.title)
            .font(SpreadTheme.Typography.caption)
            .foregroundStyle(item.calendarColor)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(item.calendarColor.opacity(0.15))
            )
    }

    // MARK: - Private

    private func formattedHour(_ hour: Int) -> String {
        guard hour < 24 else { return "12AM" }
        let h = hour % 12 == 0 ? 12 : hour % 12
        let suffix = hour < 12 ? "AM" : "PM"
        return "\(h)\(suffix)"
    }
}

// MARK: - Timed event block

/// Apple Calendar–style event block: colored left bar, tinted background,
/// title (semibold), time range, and optional location.
private struct SpreadDayTimelineEventBlock: View {

    let event: CalendarEvent
    let availableHeight: CGFloat

    /// The event whose detail popover is currently presented, or `nil` when dismissed.
    /// Driving the popover with the event itself (rather than a `Bool`) keeps the
    /// presented content in sync if `event` changes while the popover is visible.
    @State private var presentedEvent: CalendarEvent?

    // MARK: - Time formatting

    /// Locale-aware time range string, e.g. "2:00 PM – 3:30 PM".
    private var timeRangeText: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        let start = formatter.string(from: event.startDate)
        let end = formatter.string(from: event.endDate)
        return "\(start) – \(end)"
    }

    // MARK: - Layout thresholds

    /// Height at which the time row is hidden (only title fits).
    private let hideTimeThreshold: CGFloat = 34
    /// Height at which the location row is also hidden.
    private let hideLocationThreshold: CGFloat = 52

    private var showTime: Bool { availableHeight >= hideTimeThreshold }
    private var showLocation: Bool {
        availableHeight >= hideLocationThreshold && event.location?.isEmpty == false
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            // Colored left bar
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(event.calendarColor)
                .frame(width: 3)

            // Text content
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(showTime ? 1 : 2)

                if showTime {
                    Text(timeRangeText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if showLocation, let location = event.location {
                    Text(location)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(event.calendarColor.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(event.calendarColor.opacity(0.3), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            presentedEvent = event
        }
        .popover(item: $presentedEvent, arrowEdge: .top) { event in
            EventDetailPopoverView(event: event)
        }
    }
}
