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

    func isAllDay(item: CalendarEvent) -> Bool { item.isAllDay }

    @ViewBuilder
    func itemView(context: DayTimelineItemContext<CalendarEvent>) -> some View {
        SpreadDayTimelineEventBlock(event: context.item)
    }

    @ViewBuilder
    func timeRulerLabel(hour: Int) -> some View {
        Text(formattedHour(hour))
            .font(SpreadTheme.Typography.caption)
            .foregroundStyle(.tertiary)
            .lineLimit(1)
    }

    // MARK: - All-day rendering

    /// Compact chip for an all-day event rendered in `DayTimelineAllDaySection`.
    @ViewBuilder
    func allDayItemView(item: CalendarEvent) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(item.calendarColor)
                .frame(width: 3, height: 12)

            Text(item.title)
                .font(SpreadTheme.Typography.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
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

/// Visual block for a timed event in the day timeline grid.
private struct SpreadDayTimelineEventBlock: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(event.calendarColor)
                .frame(width: 3)

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
                .fill(event.calendarColor.opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(event.calendarColor.opacity(0.25), lineWidth: 0.5)
        )
    }
}
