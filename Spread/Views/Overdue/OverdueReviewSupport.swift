import Foundation

struct OverdueReviewSection: Identifiable {
    let sourceKey: TaskReviewSourceKey
    let title: String
    let items: [OverdueTaskItem]

    var id: String {
        sourceKey.id
    }
}

/// Groups overdue tasks by their current source assignment for review.
struct OverdueReviewGrouper {
    let calendar: Calendar

    func sections(for items: [OverdueTaskItem]) -> [OverdueReviewSection] {
        let grouped = Dictionary(grouping: items, by: \.sourceKey)
        return grouped.keys
            .sorted(by: sortSources(_:_:))
            .compactMap { sourceKey in
                guard let sectionItems = grouped[sourceKey] else { return nil }
                return OverdueReviewSection(
                    sourceKey: sourceKey,
                    title: title(for: sourceKey),
                    items: sectionItems.sorted(by: sortItems(_:_:))
                )
            }
    }

    private func sortSources(_ lhs: TaskReviewSourceKey, _ rhs: TaskReviewSourceKey) -> Bool {
        switch (lhs.kind, rhs.kind) {
        case (.inbox, .inbox):
            return false
        case (.inbox, _):
            return true
        case (_, .inbox):
            return false
        case (.spread(_, let lhsPeriod, let lhsDate), .spread(_, let rhsPeriod, let rhsDate)):
            let lhsNormalized = lhsPeriod.normalizeDate(lhsDate, calendar: calendar)
            let rhsNormalized = rhsPeriod.normalizeDate(rhsDate, calendar: calendar)
            if lhsNormalized != rhsNormalized {
                return lhsNormalized < rhsNormalized
            }
            return lhsPeriod.granularityRank < rhsPeriod.granularityRank
        }
    }

    private func sortItems(_ lhs: OverdueTaskItem, _ rhs: OverdueTaskItem) -> Bool {
        if lhs.task.date != rhs.task.date {
            return lhs.task.date < rhs.task.date
        }
        return lhs.task.createdDate < rhs.task.createdDate
    }

    private func title(for sourceKey: TaskReviewSourceKey) -> String {
        switch sourceKey.kind {
        case .inbox:
            return "From Inbox"
        case .spread(_, let period, let date):
            return "From \(spreadDisplayName(period: period, date: date))"
        }
    }

    private func spreadDisplayName(period: Period, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone

        switch period {
        case .year:
            return "\(calendar.component(.year, from: date))"
        case .month:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: date)
        case .day:
            formatter.dateFormat = "MMMM d, yyyy"
            return formatter.string(from: date)
        case .multiday:
            formatter.dateFormat = "MMMM d"
            return formatter.string(from: date) + "+"
        }
    }
}
