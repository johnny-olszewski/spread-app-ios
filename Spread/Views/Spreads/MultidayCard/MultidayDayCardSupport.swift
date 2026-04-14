import SwiftUI

enum MultidayDayCardVisualState: Equatable {
    case created
    case uncreated
    case today

    var fill: Color {
        switch self {
        case .today:
            return SpreadTheme.Accent.todayEmphasis.opacity(0.08)
        case .created:
            return SpreadTheme.Paper.primary.opacity(0.6)
        case .uncreated:
            return SpreadTheme.Paper.primary.opacity(0.25)
        }
    }

    var borderColor: Color {
        switch self {
        case .today:
            return SpreadTheme.Accent.todayEmphasisBorder
        case .uncreated:
            return Color.secondary.opacity(0.28)
        case .created:
            return Color.secondary.opacity(0.12)
        }
    }

    var borderStyle: StrokeStyle {
        switch self {
        case .today:
            return StrokeStyle(lineWidth: 1.5)
        case .uncreated:
            return StrokeStyle(lineWidth: 1, dash: [6, 4])
        case .created:
            return StrokeStyle(lineWidth: 1)
        }
    }
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
