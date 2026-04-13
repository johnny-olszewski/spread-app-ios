import Foundation

/// Generates calendar grid cells for a month, including leading and trailing empty cells.
enum CalendarGridHelper {
    /// Returns an array of optional dates for a calendar grid.
    ///
    /// Leading `nil` values represent empty cells before the first day.
    /// Trailing `nil` values fill the last row to 7 columns.
    static func cells(for monthDate: Date, calendar: Calendar) -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: monthDate) else {
            return []
        }

        let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate))!
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)

        var leadingEmpty = firstWeekday - calendar.firstWeekday
        if leadingEmpty < 0 { leadingEmpty += 7 }

        var cells: [Date?] = Array(repeating: nil, count: leadingEmpty)

        for day in range {
            if let date = calendar.date(bySetting: .day, value: day, of: firstDayOfMonth) {
                cells.append(date)
            }
        }

        let remainder = cells.count % 7
        if remainder > 0 {
            cells.append(contentsOf: Array(repeating: nil as Date?, count: 7 - remainder))
        }

        return cells
    }
}
