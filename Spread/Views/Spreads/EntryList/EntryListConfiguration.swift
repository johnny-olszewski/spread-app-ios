import Foundation

struct EntryListConfiguration: Sendable {
    enum GroupingStyle: Sendable {
        case automatic
        case flat
        case byMonth
        case byDay
        case byDayIncludingEmptyDates
        case byList
    }

    var groupingStyle: GroupingStyle

    init(groupingStyle: GroupingStyle = .automatic) {
        self.groupingStyle = groupingStyle
    }
}
