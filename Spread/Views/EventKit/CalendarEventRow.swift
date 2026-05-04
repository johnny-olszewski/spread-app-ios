import SwiftUI

/// A row displaying a single calendar event.
///
/// Shows a calendar color indicator, event title, time range (or "All Day"),
/// and the source calendar name.
struct CalendarEventRow: View {
    let event: CalendarEvent
    let calendar: Calendar

    var body: some View {
        HStack(spacing: SpreadTheme.Spacing.entryIconSpacing) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(event.calendarColor)
                .frame(width: 4, height: 18)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(SpreadTheme.Typography.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(timeLabel)
                    .font(SpreadTheme.Typography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
    }

    // MARK: - Private

    private var timeLabel: String {
        if event.isAllDay {
            return "All Day · \(event.calendarTitle)"
        }
        let start = formattedTime(event.startDate)
        let end = formattedTime(event.endDate)
        return "\(start)–\(end) · \(event.calendarTitle)"
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview("Timed event") {
    let calendar = Calendar.current
    let today = Date()
    let start = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: today)!
    let end = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: today)!
    let event = CalendarEvent(
        id: "preview-1",
        title: "Team Standup",
        startDate: start,
        endDate: end,
        isAllDay: false,
        calendarTitle: "Work",
        calendarColor: .blue
    )
    CalendarEventRow(event: event, calendar: calendar)
        .padding()
}

#Preview("All-day event") {
    let calendar = Calendar.current
    let today = Date()
    let event = CalendarEvent(
        id: "preview-2",
        title: "Team Off-Site",
        startDate: today,
        endDate: calendar.date(byAdding: .day, value: 1, to: today)!,
        isAllDay: true,
        calendarTitle: "Work",
        calendarColor: .green
    )
    CalendarEventRow(event: event, calendar: calendar)
        .padding()
}
