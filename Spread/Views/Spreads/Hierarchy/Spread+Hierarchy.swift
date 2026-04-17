import Foundation

// MARK: - Hierarchy Display

extension DataModel.Spread {

    /// Checks if this spread contains the given date.
    ///
    /// - Parameters:
    ///   - date: The date to check.
    ///   - calendar: The calendar for date calculations.
    /// - Returns: True if the date falls within this spread's range.
    func contains(date: Date, calendar: Calendar) -> Bool {
        switch period {
        case .year:
            return calendar.isDate(date, equalTo: self.date, toGranularity: .year)
        case .month:
            return calendar.isDate(date, equalTo: self.date, toGranularity: .month)
        case .day:
            return calendar.isDate(date, equalTo: self.date, toGranularity: .day)
        case .multiday:
            guard let startDate = startDate, let endDate = endDate else { return false }
            let normalizedDate = date.startOfDay(calendar: calendar)
            return normalizedDate >= startDate && normalizedDate <= endDate
        }
    }

    /// Returns a display label for this spread in the hierarchy.
    ///
    /// - Parameter calendar: The calendar for formatting.
    /// - Returns: A short label for display.
    func displayLabel(calendar: Calendar) -> String {
        switch period {
        case .year:
            return String(calendar.component(.year, from: date))
        case .month:
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.dateFormat = "MMM"
            return formatter.string(from: date)
        case .day:
            return String(calendar.component(.day, from: date))
        case .multiday:
            guard let startDate = startDate, let endDate = endDate else { return "" }
            let startMonth = calendar.component(.month, from: startDate)
            let endMonth = calendar.component(.month, from: endDate)
            let startDay = calendar.component(.day, from: startDate)
            let endDay = calendar.component(.day, from: endDate)

            if startMonth == endMonth {
                return "\(startDay)-\(endDay)"
            } else {
                let formatter = DateFormatter()
                formatter.calendar = calendar
                formatter.timeZone = calendar.timeZone
                formatter.dateFormat = "MMM"
                let startMonthName = formatter.string(from: startDate)
                let endMonthName = formatter.string(from: endDate)
                return "\(startMonthName) \(startDay)-\(endMonthName) \(endDay)"
            }
        }
    }
}
