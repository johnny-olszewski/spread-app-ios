import SwiftUI
import JohnnyOFoundationCore
import JohnnyOFoundationUI

/// A card-styled overdue-task review surface, shared across every spread content view.
///
/// Renders nothing when `spread` does not represent today (per `Spread.contains(date:calendar:)`,
/// which is period-aware for day/month/year/multiday) or when there are no overdue tasks.
/// When applicable, renders one `EntryList.Section` per distinct source spread (or Inbox) inside
/// the existing `EntryListView` + `EntryList.Section.Style.card` mechanism — no new visual chrome.
struct OverdueCardView: View {

    let spread: DataModel.Spread
    let context: SpreadPageContext

    var body: some View {
        let sections = Self.sections(for: spread, context: context)
        if !sections.isEmpty {
            // Each section already carries its own `configurationMap`, so the list-level
            // map here is unused — passed empty rather than duplicating the section's.
            EntryListView(sections: sections, configurationMap: [:])
        }
    }

    // MARK: - Section Building

    /// Builds the overdue card's sections for `spread`, or `[]` when `spread` doesn't represent
    /// today or there are no overdue tasks. A `static` function so it's directly unit-testable
    /// without constructing the view.
    static func sections(for spread: DataModel.Spread, context: SpreadPageContext) -> [EntryList.Section] {
        guard spread.contains(date: context.journalManager.today, calendar: context.calendar) else { return [] }

        let overdueItems = context.journalManager.overdueTaskItems
        guard !overdueItems.isEmpty else { return [] }

        let sourceKeyByTaskID = sourceKeyByTaskID(for: spread, context: context)
        let entries: [any Entry] = overdueItems.map { $0.task }

        return [
            EntryList.Section(
                id: "overdue",
                title: "Overdue",
                date: spread.date,
                entries: entries,
                creationPeriod: spread.period,
                creationDate: spread.date,
                configurationMap: [
                    DataModel.Task.configurationKey: .readOnlyOverdueTaskConfig(
                        journalManager: context.journalManager,
                        coordinator: context.coordinator,
                        sourceKey: { entry in
                            guard let task = entry as? DataModel.Task else { return nil }
                            return sourceKeyByTaskID[task.id]
                        },
                        getChips: { entry in
                            guard let task = entry as? DataModel.Task else { return [] }
                            return sourceKeyByTaskID[task.id].map { [$0] } ?? []
                        }
                    )
                ],
                style: .card(.orange)
            )
        ]
    }

    /// Maps each overdue task's ID to its source key, so the chip closure can look up each
    /// task's origin (source spread or Inbox).
    private static func sourceKeyByTaskID(
        for spread: DataModel.Spread,
        context: SpreadPageContext
    ) -> [UUID: TaskReviewSourceKey] {
        Dictionary(uniqueKeysWithValues: context.journalManager.overdueTaskItems.map { ($0.task.id, $0.sourceKey) })
    }
}
