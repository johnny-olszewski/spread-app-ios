import SwiftUI

/// Popover content showing additional details for a tapped `CalendarEvent`:
/// title, date/time range (or "All day"), location, and source calendar.
///
/// Presented from `SpreadDayTimelineContentGenerator`'s event blocks via
/// `.popover(item:)` when an event is tapped.
struct EventDetailPopoverView: View {

    let event: CalendarEvent
    var calendar: Calendar = .current

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: SpreadTheme.Spacing.standard) {
            Text(event.title)
                .font(SpreadTheme.Typography.headline)
                .lineLimit(2)

            VStack(alignment: .leading, spacing: SpreadTheme.Spacing.small) {
                detailRow(systemImage: "clock", text: formattedDateTimeRange)

                if let location = event.location, !location.isEmpty {
                    detailRow(systemImage: "mappin.and.ellipse", text: location)
                }

                detailRow(systemImage: "calendar.circle.fill", text: event.calendarTitle, tint: event.calendarColor)
            }
        }
        .padding(SpreadTheme.Spacing.large)
        .frame(minWidth: 240, alignment: .leading)
        .presentationCompactAdaptation(.popover)
    }

    // MARK: - Subviews

    @ViewBuilder
    private func detailRow(systemImage: String, text: String, tint: Color = .secondary) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: SpreadTheme.Spacing.medium) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: SpreadTheme.IconSize.small, alignment: .center)

            Text(text)
                .font(SpreadTheme.Typography.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    // MARK: - Formatting

    /// Locale-aware date and time range, e.g. "Tue, Jun 9 · 2:00 – 3:30 PM" or "Tue, Jun 9 · All day".
    private var formattedDateTimeRange: String {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = calendar
        dateFormatter.setLocalizedDateFormatFromTemplate("EEE, MMM d")
        let datePart = dateFormatter.string(from: event.startDate)

        guard !event.isAllDay else {
            return "\(datePart) · All day"
        }

        let timeFormatter = DateFormatter()
        timeFormatter.calendar = calendar
        timeFormatter.timeStyle = .short
        timeFormatter.dateStyle = .none
        let start = timeFormatter.string(from: event.startDate)
        let end = timeFormatter.string(from: event.endDate)

        return "\(datePart) · \(start) – \(end)"
    }
}

// MARK: - Previews

#Preview("Timed event with location") {
    Color.clear
        .popover(isPresented: .constant(true)) {
            EventDetailPopoverView(
                event: CalendarEvent(
                    id: "1",
                    title: "Design Review",
                    startDate: .now,
                    endDate: .now.addingTimeInterval(60 * 60),
                    isAllDay: false,
                    calendarTitle: "Work",
                    calendarColor: .blue,
                    location: "Conference Room B"
                )
            )
        }
}

#Preview("All-day event without location") {
    Color.clear
        .popover(isPresented: .constant(true)) {
            EventDetailPopoverView(
                event: CalendarEvent(
                    id: "2",
                    title: "Company Holiday",
                    startDate: .now,
                    endDate: .now.addingTimeInterval(60 * 60 * 24),
                    isAllDay: true,
                    calendarTitle: "Holidays",
                    calendarColor: .green,
                    location: nil
                )
            )
        }
}
