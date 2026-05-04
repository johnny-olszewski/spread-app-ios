import SwiftUI
import JohnnyOFoundationCore
import JohnnyOFoundationUI

/// `DayTimelineContentProvider` conformance that renders `CalendarEvent` items
/// using the event's calendar color and title.
struct SpreadDayTimelineProvider: DayTimelineContentProvider {
    typealias Item = CalendarEvent

    // MARK: - DayTimelineContentProvider

    func startDate(for item: CalendarEvent) -> Date { item.startDate }

    func endDate(for item: CalendarEvent) -> Date { item.endDate }

    @ViewBuilder
    func itemView(context: DayTimelineItemContext<CalendarEvent>) -> some View {
        SpreadDayTimelineEventBlock(event: context.item, isAllDay: context.item.isAllDay)
    }

    @ViewBuilder
    func timeRulerLabel(hour: Int) -> some View {
        Text(formattedHour(hour))
            .font(SpreadTheme.Typography.caption)
            .foregroundStyle(.tertiary)
            .lineLimit(1)
    }

    // MARK: - Private

    private func formattedHour(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let suffix = hour < 12 ? "AM" : "PM"
        return "\(h)\(suffix)"
    }
}

// MARK: - Event block

/// Visual block for a single event in the day timeline.
private struct SpreadDayTimelineEventBlock: View {
    let event: CalendarEvent
    let isAllDay: Bool

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(event.calendarColor)
                .frame(width: 3)
                .clipShape(
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                )

            Text(event.title)
                .font(SpreadTheme.Typography.caption)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(event.calendarColor.opacity(isAllDay ? 0.12 : 0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(event.calendarColor.opacity(0.25), lineWidth: 0.5)
        )
    }
}
