import SwiftUI
import JohnnyOFoundationCore
import JohnnyOFoundationUI

/// A card-styled overdue-task review surface, shared across every spread content view.
///
/// Renders nothing unless `spread` is the *most granular* spread containing today — per
/// `[DataModel.Spread].bestSpread(for:calendar:)`'s existing priority cascade (day > narrowest
/// multiday > month > year), the same logic already used by the Today button and default
/// navigation. Without this, a day spread and its parent month/year spread would all show the
/// card simultaneously, since each independently "contains" today. Also renders nothing when
/// there are no overdue (or grace-period, see below) tasks. When applicable, renders one
/// `EntryList.Section` per distinct source spread (or Inbox) inside the existing `EntryListView`
/// + `EntryList.Section.Style.card` mechanism — no new visual chrome.
///
/// The status icon is fully interactive here, rotating status the same way it does everywhere
/// else (open → complete → cancelled → open). Since marking a task complete/cancelled would
/// otherwise make it vanish from `overdueTaskItems` — and therefore from this card — immediately
/// under the user's finger, tapped tasks get a 5-second grace period (`graceExpirations`) during
/// which they keep showing here even though they're no longer "live" overdue items. Tapping
/// again within that window (e.g. complete → cancelled) restarts the 5 seconds.
struct OverdueCardView: View {

    let spread: DataModel.Spread
    let context: SpreadPageContext

    /// Maps a task's ID to the wall-clock time its grace period ends. Presence in this
    /// dictionary, not the value, is what keeps a task showing — the `Task.sleep` in
    /// `handleStatusIconTap` re-checks its own captured expiration before removing the entry,
    /// so a later tap's fresh expiration isn't clobbered by an earlier tap's stale timer.
    @State private var graceExpirations: [UUID: Date] = [:]

    /// Snapshot of each grace-period task's source key, captured at the moment it was tapped —
    /// needed because once a task leaves `overdueTaskItems` its source key isn't available from
    /// the live data anymore, but the chip should still show where it came from during the grace
    /// window.
    @State private var graceSourceKeys: [UUID: TaskReviewSourceKey] = [:]

    var body: some View {
        let sections = Self.sections(
            for: spread,
            context: context,
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

    /// Rotates `task`'s status (open → complete → cancelled → open) and, when it leaves `open`,
    /// keeps it showing in the card for a 5-second grace period rather than letting it vanish
    /// the instant it drops out of `overdueTaskItems`.
    private func handleStatusIconTap(task: DataModel.Task) {
        let newStatus = task.status.rotate(in: [.open, .complete, .cancelled])

        if newStatus == .open {
            graceExpirations.removeValue(forKey: task.id)
            graceSourceKeys.removeValue(forKey: task.id)
        } else {
            // Snapshot the source key now, while the task is still a live overdue item with a
            // known source — it won't be after `updateTaskStatus` commits.
            if let key = context.journalManager.overdueTaskItems.first(where: { $0.task.id == task.id })?.sourceKey {
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

    /// Builds the overdue card's sections for `spread`, or `[]` when `spread` isn't the most
    /// granular spread containing today, or there are no overdue/grace-period tasks. A `static`
    /// function so it's directly unit-testable without constructing the view.
    static func sections(
        for spread: DataModel.Spread,
        context: SpreadPageContext,
        graceTaskIDs: Set<UUID> = [],
        graceSourceKeys: [UUID: TaskReviewSourceKey] = [:],
        onStatusIconTap: @escaping (any Entry) -> Void = { _ in }
    ) -> [EntryList.Section] {
        guard spread.id == context.journalManager.bestSpread(for: context.journalManager.today)?.id else { return [] }

        let overdueItems = context.journalManager.overdueTaskItems
        var sourceKeyByTaskID = Dictionary(uniqueKeysWithValues: overdueItems.map { ($0.task.id, $0.sourceKey) })
        var entries: [any Entry] = overdueItems.map { $0.task }

        let liveTaskIDs = Set(overdueItems.map { $0.task.id })
        for graceID in graceTaskIDs where !liveTaskIDs.contains(graceID) {
            guard let task = context.journalManager.tasks.first(where: { $0.id == graceID }) else { continue }
            entries.append(task)
            if let key = graceSourceKeys[graceID] {
                sourceKeyByTaskID[graceID] = key
            }
        }

        guard !entries.isEmpty else { return [] }

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
                        onStatusIconTap: onStatusIconTap,
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
}
