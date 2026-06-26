import SwiftUI

/// Visual state for a spread card — encodes whether the represented period is
/// today and whether a spread has been explicitly created for it.
enum SpreadCardStyle: Equatable {
    case created
    case uncreated
    case todayCreated
    case todayUncreated

    // MARK: - Initializers

    /// Derives the card style from raw today/created flags.
    init(isToday: Bool, isCreated: Bool) {
        switch (isToday, isCreated) {
        case (true, true): self = .todayCreated
        case (true, false): self = .todayUncreated
        case (false, true): self = .created
        case (false, false): self = .uncreated
        }
    }

    /// Derives the card style by comparing `date` to `today` and checking whether an explicit spread exists.
    init(for date: Date, today: Date, explicitDaySpread: DataModel.Spread?, calendar: Calendar) {
        self.init(
            isToday: calendar.isDate(date, inSameDayAs: today),
            isCreated: explicitDaySpread != nil
        )
    }

    // MARK: - Computed Properties

    var isToday: Bool {
        switch self {
        case .todayCreated, .todayUncreated: return true
        case .created, .uncreated: return false
        }
    }

    var isCreated: Bool {
        switch self {
        case .created, .todayCreated: return true
        case .uncreated, .todayUncreated: return false
        }
    }

    /// Shared today-fill color, hoisted to a single instance so `.todayCreated.fill` and
    /// `.todayUncreated.fill` compare equal — two separately-constructed dynamic `UIColor`
    /// closures are never `==` even when functionally identical.
    private static let todayFill: Color = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(Color.SpreadPalette.yellow300)
            : UIColor(Color.SpreadPalette.yellow100)
    }).opacity(0.2)

    var fill: Color {
        if isToday { return Self.todayFill }
        if isCreated { return Color.SpreadPalette.blue500.opacity(0.08) }
        return SpreadTheme.Paper.primary.opacity(0.6)
    }

    var borderColor: Color {
        switch self {
        case .todayCreated, .todayUncreated:
            return Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(Color.SpreadPalette.yellow200)
                    : UIColor(Color.SpreadPalette.yellow500)
            }).opacity(0.7)
        case .created:
            return Color.SpreadPalette.blue500.opacity(0.34)
        case .uncreated:
            return Color.secondary.opacity(0.24)
        }
    }

    var borderStyle: StrokeStyle {
        switch self {
        case .todayCreated:
            return StrokeStyle(lineWidth: 1.5)
        case .todayUncreated:
            return StrokeStyle(lineWidth: 1.5, dash: [4, 3])
        case .created:
            return StrokeStyle(lineWidth: 1)
        case .uncreated:
            return StrokeStyle(lineWidth: 1, dash: [4, 3])
        }
    }

    var primaryHeaderColor: Color {
        if isToday {
            return Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(Color.SpreadPalette.yellow200)
                    : UIColor(Color.SpreadPalette.yellow500)
            })
        }
        if isCreated { return Color.SpreadPalette.blue500.opacity(0.75) }
        return .primary
    }

    var secondaryHeaderColor: Color {
        if isToday {
            return Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(Color.SpreadPalette.yellow200)
                    : UIColor(Color.SpreadPalette.yellow500)
            }).opacity(0.8)
        }
        if isCreated { return Color.SpreadPalette.blue500.opacity(0.55) }
        return .secondary
    }

    var headerWeight: Font.Weight {
        isToday ? .semibold : .regular
    }
}
