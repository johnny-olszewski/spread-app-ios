import Foundation

public struct MonthCalendarConfiguration: Hashable, Sendable {
    public var showsPeripheralDates: Bool

    public init(showsPeripheralDates: Bool = true) {
        self.showsPeripheralDates = showsPeripheralDates
    }
}
