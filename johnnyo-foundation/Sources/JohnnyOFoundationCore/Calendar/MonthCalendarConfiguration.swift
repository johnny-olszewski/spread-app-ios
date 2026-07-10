import Foundation

public struct MonthCalendarConfiguration: Hashable, Sendable {
    public var showsPeripheralDates: Bool
    /// When `false`, the month header produced by `CalendarContentGenerator.headerView` is
    /// suppressed. Use this when the containing view (e.g. `CalendarView` in single-month mode)
    /// renders its own navigation header in place of the generator's.
    public var showsMonthHeader: Bool

    public init(showsPeripheralDates: Bool = true, showsMonthHeader: Bool = true) {
        self.showsPeripheralDates = showsPeripheralDates
        self.showsMonthHeader = showsMonthHeader
    }
}
