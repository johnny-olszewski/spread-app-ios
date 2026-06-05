import Foundation

extension DataModel.Spread {

    /// Short label for use in parent-navigation toolbar buttons.
    ///
    /// - Year spread: `"YYYY"` (e.g. `"2026"`)
    /// - Month spread: `"MMM"` (e.g. `"Jun"`)
    /// - Multiday spread: `"d MMM – d MMM"` (e.g. `"3 Jun – 9 Jun"`)
    /// - Day spread: returns an empty string (day spreads are not parent targets).
    func parentNavigationLabel(calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = .current
        switch period {
        case .year:
            formatter.dateFormat = "yyyy"
            return formatter.string(from: date)
        case .month:
            formatter.dateFormat = "MMM"
            return formatter.string(from: date)
        case .multiday:
            guard let startDate, let endDate else { return "" }
            formatter.dateFormat = "d MMM"
            return "\(formatter.string(from: startDate)) – \(formatter.string(from: endDate))"
        case .day:
            return ""
        }
    }
}
