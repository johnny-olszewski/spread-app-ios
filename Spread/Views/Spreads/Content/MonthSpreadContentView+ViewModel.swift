import SwiftUI

extension MonthSpreadContentView {

    /// Owns the entry row configuration map for `MonthSpreadContentView`.
    @Observable @MainActor
    final class ViewModel {
        private(set) var configurationMap: [EntryType: EntryRowView.Configuration] = [:]

        /// Rebuilds the configuration map. Called once per spread-id change.
        func configure(
            journalManager: JournalManager,
            syncEngine: SyncEngine?,
            onEditTask: @escaping (DataModel.Task) -> Void,
            onEditNote: @escaping (DataModel.Note) -> Void
        ) {
            let cal = journalManager.firstWeekday.configuredCalendar(from: journalManager.calendar)
            let today = journalManager.today

            let taskConfig = EntryRowView.Configuration(
                effectiveTaskStatus: { $0.displayTaskStatus },
                isGreyedOut: { entry in
                    guard let s = entry.displayTaskStatus else { return false }
                    return s == .complete || s == .migrated || s == .cancelled
                },
                hasStrikethrough: { entry in entry.displayTaskStatus == .cancelled },
                dueDateLabel: { entry in (entry as? DataModel.Task)?.dueDateLabel(calendar: cal) },
                isDueDateHighlighted: { entry in
                    (entry as? DataModel.Task)?.isDueDateHighlighted(today: today, calendar: cal) ?? false
                },
                onComplete: { entry in
                    guard let task = entry as? DataModel.Task else { return }
                    Task { @MainActor in
                        let newStatus: DataModel.Task.Status = task.status == .complete ? .open : .complete
                        try? await journalManager.updateTaskStatus(task, newStatus: newStatus)
                        await syncEngine?.syncNow()
                    }
                },
                onEdit: { entry in
                    if let task = entry as? DataModel.Task { onEditTask(task) }
                },
                onDelete: { entry in
                    guard let task = entry as? DataModel.Task else { return }
                    Task { @MainActor in
                        try? await journalManager.deleteTask(task)
                        await syncEngine?.syncNow()
                    }
                },
                onTitleCommit: { @MainActor entry, newTitle in
                    guard let task = entry as? DataModel.Task else { return }
                    try? await journalManager.updateTaskTitle(task, newTitle: newTitle)
                    Task { @MainActor in await syncEngine?.syncNow() }
                },
                inlineActionConfiguration: { entry in
                    guard let task = entry as? DataModel.Task, task.status == .open else { return nil }
                    let options = EntryRowInlineEditSupport.migrationOptions(for: task, today: today, calendar: cal)
                    return EntryRowInlineActionConfiguration(
                        migrationOptions: options,
                        onEditSheet: { onEditTask(task) },
                        onMigrationSelected: { option in
                            try? await journalManager.updateTaskDateAndPeriod(task, newDate: option.date, newPeriod: option.period)
                            await syncEngine?.syncNow()
                        }
                    )
                }
            )

            let noteConfig = EntryRowView.Configuration(
                isGreyedOut: { entry in (entry as? DataModel.Note)?.status == .migrated },
                onEdit: { entry in
                    if let note = entry as? DataModel.Note { onEditNote(note) }
                },
                onDelete: { entry in
                    guard let note = entry as? DataModel.Note else { return }
                    Task { @MainActor in
                        try? await journalManager.deleteNote(note)
                        await syncEngine?.syncNow()
                    }
                }
            )

            configurationMap = [.task: taskConfig, .note: noteConfig]
        }
    }
}
