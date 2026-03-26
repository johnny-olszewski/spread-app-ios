import Foundation

/// Display section for migration review rows grouped by source.
struct MigrationReviewSection: Identifiable {
    let sourceKey: TaskReviewSourceKey
    let sourceTitle: String
    let sourceDisplayName: String
    let destinationDisplayName: String
    let candidates: [MigrationCandidate]

    var id: String {
        sourceKey.id
    }
}

/// Result of submitting a batch migration review action.
struct MigrationSelectionOutcome {
    let migratedCount: Int
    let skippedCount: Int
    let remainingCount: Int
}

/// Groups migration candidates by source for the review sheet.
struct MigrationReviewGrouper {

    let calendar: Calendar

    func sections(
        for candidates: [MigrationCandidate],
        destination: DataModel.Spread
    ) -> [MigrationReviewSection] {
        let grouped = Dictionary(grouping: candidates, by: \.sourceKey)
        let destinationDisplayName = spreadDisplayName(
            period: destination.period,
            date: destination.date
        )

        return grouped.keys
            .sorted(by: sortSources(_:_:))
            .compactMap { sourceKey in
                guard let sectionCandidates = grouped[sourceKey] else { return nil }
                let first = sectionCandidates[0]
                return MigrationReviewSection(
                    sourceKey: sourceKey,
                    sourceTitle: sectionTitle(for: sourceKey, sourceSpread: first.sourceSpread),
                    sourceDisplayName: sourceDisplayName(for: sourceKey, sourceSpread: first.sourceSpread),
                    destinationDisplayName: destinationDisplayName,
                    candidates: sectionCandidates.sorted(by: candidateSort(_:_:))
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

    private func candidateSort(_ lhs: MigrationCandidate, _ rhs: MigrationCandidate) -> Bool {
        if lhs.task.date != rhs.task.date {
            return lhs.task.date < rhs.task.date
        }
        return lhs.task.createdDate < rhs.task.createdDate
    }

    private func sectionTitle(
        for sourceKey: TaskReviewSourceKey,
        sourceSpread: DataModel.Spread?
    ) -> String {
        "From \(sourceDisplayName(for: sourceKey, sourceSpread: sourceSpread))"
    }

    private func sourceDisplayName(
        for sourceKey: TaskReviewSourceKey,
        sourceSpread: DataModel.Spread?
    ) -> String {
        switch sourceKey.kind {
        case .inbox:
            return "Inbox"
        case .spread(_, let period, let date):
            return spreadDisplayName(period: period, date: sourceSpread?.date ?? date)
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

/// Matches the latest set of candidates against the user's selection before migration.
struct MigrationSelectionRevalidator {
    func revalidate(
        selected: [MigrationCandidate],
        against latest: [MigrationCandidate]
    ) -> (valid: [MigrationCandidate], skippedCount: Int) {
        let latestByTaskID = Dictionary(uniqueKeysWithValues: latest.map { ($0.task.id, $0) })
        let valid: [MigrationCandidate] = selected.compactMap { candidate in
            guard let latestCandidate = latestByTaskID[candidate.task.id],
                  latestCandidate.sourceKey == candidate.sourceKey,
                  latestCandidate.destination.id == candidate.destination.id else {
                return nil
            }
            return latestCandidate
        }
        return (valid, selected.count - valid.count)
    }
}
