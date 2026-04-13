import Foundation

enum MultidayDayCardVisualState: Equatable {
    case created
    case uncreated
    case today
}

enum MultidayDayCardAction: Equatable {
    case navigate(DataModel.Spread)
    case createDay(Date)

    var iconName: String {
        switch self {
        case .navigate:
            return "arrow.right"
        case .createDay:
            return "calendar.badge.plus"
        }
    }
}

enum MultidayDayCardSupport {
    static func visualState(
        for date: Date,
        today: Date,
        explicitDaySpread: DataModel.Spread?,
        calendar: Calendar
    ) -> MultidayDayCardVisualState {
        if calendar.isDate(date, inSameDayAs: today) {
            return .today
        }
        if explicitDaySpread == nil {
            return .uncreated
        }
        return .created
    }

    static func footerAction(
        for date: Date,
        explicitDaySpread: DataModel.Spread?
    ) -> MultidayDayCardAction {
        if let explicitDaySpread {
            return .navigate(explicitDaySpread)
        }
        return .createDay(date)
    }
}
