import SwiftUI
import JohnnyOFoundationCore
import JohnnyOFoundationUI

/// A card-styled task review surface rendered above `SpreadContentPagerView`, parameterized
/// by a `TaskReviewCollection` (which items it shows, and its card title/color).
///
/// Renders nothing when the collection has no live (or grace-period) tasks — empty-state
/// chrome belongs to the hosting panel, not the card. Renders one `EntryList.Section` inside
/// the existing `EntryListView` + `EntryList.Section.Style.card` mechanism — no new visual
/// chrome.
///
/// The status icon is fully interactive here, rotating status the same way it does everywhere
/// else. Since a status change would otherwise make a task vanish from the collection — and
/// therefore from this card — immediately under the user's finger, tapped tasks get a 5-second
/// grace period (`graceExpirations`) during which they keep showing here even though they're
/// no longer live items. Tapping again within that window (e.g. complete → cancelled) restarts
/// the 5 seconds.
struct TaskReviewCardView: View {

    let context: SpreadPageContext
    let collection: TaskReviewCollection

    /// Maps a task's ID to the wall-clock time its grace period ends. Presence in this
    /// dictionary, not the value, is what keeps a task showing — the `Task.sleep` in
    /// `handleStatusIconTap` re-checks its own captured expiration before removing the entry,
    /// so a later tap's fresh expiration isn't clobbered by an earlier tap's stale timer.
    @State private var graceExpirations: [UUID: Date] = [:]

    /// Snapshot of each grace-period task's source key, captured at the moment it was tapped —
    /// needed because once a task leaves the collection its source key isn't available from
    /// the live data anymore, but the chip should still show where it came from during the
    /// grace window.
    @State private var graceSourceKeys: [UUID: TaskReviewSourceKey] = [:]

    var body: some View {
        let sections = Self.sections(
            context: context,
            collection: collection,
            graceTaskIDs: Set(graceExpirations.keys),
            graceSourceKeys: graceSourceKeys,
            onStatusIconTap: { entry in
                guard let task = entry as? DataModel.Task else { return }
                handleStatusIconTap(task: task)
            }
        )
        if !sections.isEmpty {
            // Each section already carries its own `configurationMap`, so the list-level
            // map here is unused — passed empty rather than duplicating the section's.
            EntryListView(sections: sections, configurationMap: [:])
        }
    }

    // MARK: - Status Icon Handling

    /// Rotates `task`'s status through `EntryStatus.userEditableTaskStatuses` and, when the
    /// new status would drop it from this collection, keeps it showing in the card for a
    /// 5-second grace period rather than letting it vanish the instant it leaves the live items.
    private func handleStatusIconTap(task: DataModel.Task) {
        let newStatus = task.status.rotate(in: EntryStatus.userEditableTaskStatuses)

        if newStatus == .open {
            graceExpirations.removeValue(forKey: task.id)
            graceSourceKeys.removeValue(forKey: task.id)
        } else {
            // Snapshot the source key now, while the task is still a live item with a known
            // source — it won't be after `updateTaskStatus` commits.
            if let key = collection.items(in: context.journalManager).first(where: { $0.task.id == task.id })?.sourceKey {
                graceSourceKeys[task.id] = key
            }

            let expiration = Date().addingTimeInterval(5)
            graceExpirations[task.id] = expiration

            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                // Only remove if this is still the most recent tap's expiration — a later tap
                // (e.g. complete → cancelled) will have overwritten it with a fresh one.
                guard graceExpirations[task.id] == expiration else { return }
                graceExpirations.removeValue(forKey: task.id)
                graceSourceKeys.removeValue(forKey: task.id)
            }
        }

        Task { @MainActor in
            try? await context.journalManager.updateTaskStatus(task, newStatus: newStatus)
            await context.syncEngine?.syncNow()
        }
    }

    // MARK: - Section Building

    /// Builds the card's sections for `collection`, or `[]` when there are no live or
    /// grace-period tasks. Uses `bestSpread(for:today)` to derive the creation date/period for
    /// the section metadata. A `static` function so it's directly unit-testable without
    /// constructing the view.
    static func sections(
        context: SpreadPageContext,
        collection: TaskReviewCollection,
        graceTaskIDs: Set<UUID> = [],
        graceSourceKeys: [UUID: TaskReviewSourceKey] = [:],
        onStatusIconTap: @escaping (any Entry) -> Void = { _ in }
    ) -> [EntryList.Section] {
        let items = collection.items(in: context.journalManager)
        var sourceKeyByTaskID = Dictionary(uniqueKeysWithValues: items.map { ($0.task.id, $0.sourceKey) })
        var entries: [any Entry] = items.map { $0.task }

        let liveTaskIDs = Set(items.map { $0.task.id })
        for graceID in graceTaskIDs where !liveTaskIDs.contains(graceID) {
            guard let task = context.journalManager.tasks.first(where: { $0.id == graceID }) else { continue }
            entries.append(task)
            if let key = graceSourceKeys[graceID] {
                sourceKeyByTaskID[graceID] = key
            }
        }

        guard !entries.isEmpty else { return [] }

        // Sorted using the same period-aware convention as Year's month cards and Month's day
        // sections — never by status, insertion order, or `JournalManager.tasks`'s incidental
        // createdDate-based order. Left unsorted, a status change could reorder unrelated rows,
        // and grace-period tasks would always land at the end regardless of their actual date.
        let calendar = context.calendar
        entries.sort { $0.conventionalSortKey(calendar: calendar) < $1.conventionalSortKey(calendar: calendar) }

        let bestSpread = context.journalManager.bestSpread(for: context.journalManager.today)
        let creationDate = bestSpread?.date ?? context.journalManager.today
        let creationPeriod = bestSpread?.period ?? .day

        return [
            EntryList.Section(
                id: collection.sectionID,
                title: collection.title,
                date: creationDate,
                entries: entries,
                creationPeriod: creationPeriod,
                creationDate: creationDate,
                configurationMap: [
                    DataModel.Task.configurationKey: .readOnlyOverdueTaskConfig(
                        journalManager: context.journalManager,
                        coordinator: context.coordinator,
                        sourceKey: { entry in
                            guard let task = entry as? DataModel.Task else { return nil }
                            return sourceKeyByTaskID[task.id]
                        },
                        onStatusIconTap: onStatusIconTap,
                        getChips: { entry in
                            guard let task = entry as? DataModel.Task else { return [] }
                            return sourceKeyByTaskID[task.id].map { [$0] } ?? []
                        }
                    )
                ],
                style: .card(collection.cardColor)
            )
        ]
    }
}
