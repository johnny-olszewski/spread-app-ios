import Foundation

/// Static helpers for formatting date components displayed in multiday section headers.
enum EntryListMultidaySupport {
    static func weekdayText(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    static func shortMonthText(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }

    static func dayNumberText(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}
