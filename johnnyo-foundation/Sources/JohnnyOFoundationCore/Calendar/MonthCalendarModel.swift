import Foundation

public enum MonthCalendarSlot: Identifiable, Hashable, Sendable {
    case day(date: Date, isPeripheral: Bool, isToday: Bool)
    case placeholder(date: Date, isLeading: Bool)

    public var date: Date {
        switch self {
        case .day(let date, _, _),
             .placeholder(let date, _):
            return date
        }
    }

    public var isDay: Bool {
        switch self {
        case .day:
            return true
        case .placeholder:
            return false
        }
    }

    public var isPeripheral: Bool {
        switch self {
        case .day(_, let isPeripheral, _):
            return isPeripheral
        case .placeholder:
            return true
        }
    }

    public var isToday: Bool {
        switch self {
        case .day(_, _, let isToday):
            return isToday
        case .placeholder:
            return false
        }
    }

    public var id: String {
        switch self {
        case .day(let date, _, _):
            return "day-\(date.timeIntervalSinceReferenceDate)"
        case .placeholder(let date, _):
            return "placeholder-\(date.timeIntervalSinceReferenceDate)"
        }
    }
}

public struct MonthCalendarWeek: Identifiable, Hashable, Sendable {
    public let index: Int
    public let slots: [MonthCalendarSlot]

    public var id: Int { index }

    public var startDate: Date {
        slots.first?.date ?? .distantPast
    }

    public init(index: Int, slots: [MonthCalendarSlot]) {
        self.index = index
        self.slots = slots
    }
}

public struct MonthCalendarModel: Hashable, Sendable {
    public let displayedMonth: Date
    public let weekdays: [Int]
    public let weeks: [MonthCalendarWeek]

    public init(
        displayedMonth: Date,
        weekdays: [Int],
        weeks: [MonthCalendarWeek]
    ) {
        self.displayedMonth = displayedMonth
        self.weekdays = weekdays
        self.weeks = weeks
    }
}
