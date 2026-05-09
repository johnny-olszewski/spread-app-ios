import Foundation

enum SpreadAutoMigrationRevealAnchor: Equatable {
    case spreadHeader
    case yearMonth(Date)
    case monthDay(Date)
}

struct SpreadAutoMigrationFeedback: Identifiable {
    let id = UUID()
    let surfaceSpreadID: UUID
    let destinationSpread: DataModel.Spread
    let summary: SpreadAutoMigrationSummary
    let anchor: SpreadAutoMigrationRevealAnchor

    var message: String {
        let taskPart = summary.taskCount > 0 ? "\(summary.taskCount) task\(summary.taskCount == 1 ? "" : "s")" : nil
        let notePart = summary.noteCount > 0 ? "\(summary.noteCount) note\(summary.noteCount == 1 ? "" : "s")" : nil

        let movedEntries = [taskPart, notePart]
            .compactMap { $0 }
            .joined(separator: taskPart != nil && notePart != nil ? " and " : "")

        let subject = movedEntries.isEmpty ? "Entries" : movedEntries
        return "\(subject) moved automatically"
    }
}

enum SpreadAutoMigrationFeedbackSupport {
    enum RevealBehavior: Equatable {
        case local(surfaceSpreadID: UUID, anchor: SpreadAutoMigrationRevealAnchor)
        case navigate(surfaceSpreadID: UUID, anchor: SpreadAutoMigrationRevealAnchor)
    }

    static func revealBehavior(
        currentSelection: SpreadHeaderNavigatorModel.Selection,
        creationResult: SpreadCreationOperationResult,
        calendar: Calendar
    ) -> RevealBehavior {
        let destination = creationResult.spread
        let destinationSurface = destination.id

        guard let currentSpread = conventionalSpread(from: currentSelection) else {
            return .navigate(surfaceSpreadID: destinationSurface, anchor: .spreadHeader)
        }

        switch (currentSpread.period, destination.period) {
        case (.year, .month)
        where calendar.isDate(currentSpread.date, equalTo: destination.date, toGranularity: .year):
            return .local(
                surfaceSpreadID: currentSpread.id,
                anchor: .yearMonth(Period.month.normalizeDate(destination.date, calendar: calendar))
            )

        case (.month, .day)
        where calendar.isDate(currentSpread.date, equalTo: destination.date, toGranularity: .month):
            return .local(
                surfaceSpreadID: currentSpread.id,
                anchor: .monthDay(Period.day.normalizeDate(destination.date, calendar: calendar))
            )

        default:
            return .navigate(surfaceSpreadID: destinationSurface, anchor: .spreadHeader)
        }
    }

    static func feedback(
        currentSelection: SpreadHeaderNavigatorModel.Selection,
        creationResult: SpreadCreationOperationResult,
        calendar: Calendar
    ) -> SpreadAutoMigrationFeedback? {
        guard let summary = creationResult.autoMigrationSummary, summary.totalCount > 0 else {
            return nil
        }

        let behavior = revealBehavior(
            currentSelection: currentSelection,
            creationResult: creationResult,
            calendar: calendar
        )

        switch behavior {
        case .local(let surfaceSpreadID, let anchor), .navigate(let surfaceSpreadID, let anchor):
            return SpreadAutoMigrationFeedback(
                surfaceSpreadID: surfaceSpreadID,
                destinationSpread: creationResult.spread,
                summary: summary,
                anchor: anchor
            )
        }
    }

    private static func conventionalSpread(
        from selection: SpreadHeaderNavigatorModel.Selection
    ) -> DataModel.Spread? {
        guard case .conventional(let spread) = selection else { return nil }
        return spread
    }
}
