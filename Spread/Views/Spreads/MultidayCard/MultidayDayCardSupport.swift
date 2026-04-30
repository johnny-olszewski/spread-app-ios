import SwiftUI

enum MultidayDayCardVisualState: Equatable {
    case created
    case uncreated
    case todayCreated
    case todayUncreated

    var isToday: Bool {
        switch self {
        case .todayCreated, .todayUncreated:
            return true
        case .created, .uncreated:
            return false
        }
    }

    var isCreated: Bool {
        switch self {
        case .created, .todayCreated:
            return true
        case .uncreated, .todayUncreated:
            return false
        }
    }

    var fill: Color {
        if isToday {
            return SpreadTheme.Accent.todayEmphasis.opacity(0.08)
        }

        switch self {
        case .created:
            return SpreadTheme.Paper.primary.opacity(0.6)
        case .uncreated:
            return SpreadTheme.Paper.primary.opacity(0.25)
        case .todayCreated, .todayUncreated:
            return SpreadTheme.Accent.todayEmphasis.opacity(0.08)
        }
    }

    var borderColor: Color {
        if isToday {
            return SpreadTheme.Accent.todayEmphasisBorder
        }

        switch self {
        case .uncreated:
            return Color.secondary.opacity(0.28)
        case .created:
            return Color.secondary.opacity(0.12)
        case .todayCreated, .todayUncreated:
            return SpreadTheme.Accent.todayEmphasisBorder
        }
    }

    var borderStyle: StrokeStyle {
        switch self {
        case .todayCreated:
            return StrokeStyle(lineWidth: 1.5)
        case .todayUncreated:
            return StrokeStyle(lineWidth: 1.5, dash: [6, 4])
        case .uncreated:
            return StrokeStyle(lineWidth: 1, dash: [6, 4])
        case .created:
            return StrokeStyle(lineWidth: 1)
        }
    }

    var primaryHeaderColor: Color {
        isToday ? SpreadTheme.Accent.todayEmphasis : .primary
    }

    var secondaryHeaderColor: Color {
        isToday ? SpreadTheme.Accent.todayEmphasis.opacity(0.9) : .secondary
    }

    var headerWeight: Font.Weight {
        isToday ? .semibold : .regular
    }
}

enum SpreadSelectionVisualStyle {
    static var surfaceFill: Color {
        SpreadTheme.Accent.selectedSurface.opacity(0.3)
    }

    static var overlayFill: Color {
        SpreadTheme.Accent.selectedSurface.opacity(0.86)
    }

    static var overlayBorder: Color {
        SpreadTheme.Accent.selectedSurfaceBorder.opacity(0.96)
    }

    static var overlayMarker: Color {
        SpreadTheme.Accent.selectedSurfaceBorder.opacity(0.88)
    }

    static var overflowFill: Color {
        SpreadTheme.Accent.selectedSurface.opacity(0.9)
    }

    static var overflowForeground: Color {
        Color.black.opacity(0.72)
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
        isToday: Bool,
        isCreated: Bool
    ) -> MultidayDayCardVisualState {
        switch (isToday, isCreated) {
        case (true, true):
            return .todayCreated
        case (true, false):
            return .todayUncreated
        case (false, true):
            return .created
        case (false, false):
            return .uncreated
        }
    }

    static func visualState(
        for date: Date,
        today: Date,
        explicitDaySpread: DataModel.Spread?,
        calendar: Calendar
    ) -> MultidayDayCardVisualState {
        visualState(
            isToday: calendar.isDate(date, inSameDayAs: today),
            isCreated: explicitDaySpread != nil
        )
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
