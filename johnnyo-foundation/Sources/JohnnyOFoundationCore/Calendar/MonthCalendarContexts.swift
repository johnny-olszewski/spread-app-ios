import Foundation

public struct MonthCalendarHeaderContext: Sendable {
    public let displayedMonth: Date
    public let monthInterval: DateInterval
    public let calendar: Calendar
    public let configuration: MonthCalendarConfiguration
    public let weekCount: Int

    public init(
        displayedMonth: Date,
        monthInterval: DateInterval,
        calendar: Calendar,
        configuration: MonthCalendarConfiguration,
        weekCount: Int
    ) {
        self.displayedMonth = displayedMonth
        self.monthInterval = monthInterval
        self.calendar = calendar
        self.configuration = configuration
        self.weekCount = weekCount
    }
}

public struct MonthCalendarWeekdayContext: Identifiable, Sendable {
    public let weekday: Int
    public let symbol: String
    public let index: Int

    public var id: Int { index }

    public init(weekday: Int, symbol: String, index: Int) {
        self.weekday = weekday
        self.symbol = symbol
        self.index = index
    }
}

public struct MonthCalendarDayContext: Identifiable, Sendable {
    public let date: Date
    public let row: Int
    public let column: Int
    public let isInDisplayedMonth: Bool
    public let isPeripheral: Bool
    public let isToday: Bool

    public var id: String {
        "\(date.timeIntervalSinceReferenceDate)-\(row)-\(column)"
    }

    public init(
        date: Date,
        row: Int,
        column: Int,
        isInDisplayedMonth: Bool,
        isPeripheral: Bool,
        isToday: Bool
    ) {
        self.date = date
        self.row = row
        self.column = column
        self.isInDisplayedMonth = isInDisplayedMonth
        self.isPeripheral = isPeripheral
        self.isToday = isToday
    }
}

public struct MonthCalendarPlaceholderContext: Identifiable, Sendable {
    public let representedDate: Date
    public let row: Int
    public let column: Int
    public let isLeading: Bool
    public let isTrailing: Bool

    public var id: String {
        "\(representedDate.timeIntervalSinceReferenceDate)-\(row)-\(column)"
    }

    public init(
        representedDate: Date,
        row: Int,
        column: Int,
        isLeading: Bool,
        isTrailing: Bool
    ) {
        self.representedDate = representedDate
        self.row = row
        self.column = column
        self.isLeading = isLeading
        self.isTrailing = isTrailing
    }
}

public enum MonthCalendarSlotContext: Identifiable, Sendable {
    case day(MonthCalendarDayContext)
    case placeholder(MonthCalendarPlaceholderContext)

    public var id: String {
        switch self {
        case .day(let context):
            return "day-\(context.id)"
        case .placeholder(let context):
            return "placeholder-\(context.id)"
        }
    }
}

public struct MonthCalendarWeekContext: Identifiable, Sendable {
    public let index: Int
    public let slots: [MonthCalendarSlotContext]

    public var id: Int { index }

    public init(index: Int, slots: [MonthCalendarSlotContext]) {
        self.index = index
        self.slots = slots
    }
}

public struct MonthCalendarModel: Sendable {
    public let header: MonthCalendarHeaderContext
    public let weekdays: [MonthCalendarWeekdayContext]
    public let weeks: [MonthCalendarWeekContext]

    public init(
        header: MonthCalendarHeaderContext,
        weekdays: [MonthCalendarWeekdayContext],
        weeks: [MonthCalendarWeekContext]
    ) {
        self.header = header
        self.weekdays = weekdays
        self.weeks = weeks
    }
}
