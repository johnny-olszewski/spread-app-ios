import Foundation

struct EntryListConfiguration: Sendable {
    enum GroupingStyle: Sendable {
        case automatic
        case flat
        case byMonth
        case byDay
        case byDayIncludingEmptyDates
    }

    var groupingStyle: GroupingStyle
    var showsMigrationHistory: Bool

    init(
        groupingStyle: GroupingStyle = .automatic,
        showsMigrationHistory: Bool = true
    ) {
        self.groupingStyle = groupingStyle
        self.showsMigrationHistory = showsMigrationHistory
    }
}
