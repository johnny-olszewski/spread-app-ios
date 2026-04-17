import Foundation

public struct MonthCalendarConfiguration: Sendable {
    public var showsPeripheralDates: Bool

    public init(showsPeripheralDates: Bool = true) {
        self.showsPeripheralDates = showsPeripheralDates
    }
}
