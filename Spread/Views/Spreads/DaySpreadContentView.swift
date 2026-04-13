import SwiftUI

/// Renders the entry list for a day spread, with optional inline spread creation and navigation.
struct DaySpreadContentView: View {
    let spread: DataModel.Spread
    let spreadDataModel: SpreadDataModel?
    let journalManager: JournalManager
    let viewModel: SpreadsViewModel
    let syncEngine: SyncEngine?
    var entryListConfiguration: EntryListConfiguration = .init()
    var migrationConfiguration: EntryListMigrationConfiguration? = nil
    var onOpenMigratedTask: ((DataModel.Task) -> Void)? = nil
    var explicitDaySpreadForDate: ((Date) -> DataModel.Spread?)? = nil
    var onSelectSpread: ((DataModel.Spread) -> Void)? = nil
    var onCreateSpread: ((Date) -> Void)? = nil

    var body: some View {
        if let dataModel = spreadDataModel {
            EntryListView(
                spreadDataModel: dataModel,
                calendar: journalManager.calendar,
                today: journalManager.today,
                configuration: entryListConfiguration,
                onEdit: { entry in
                    if let task = entry as? DataModel.Task { viewModel.showTaskDetail(task) }
                    else if let note = entry as? DataModel.Note { viewModel.showNoteDetail(note) }
                },
                onOpenMigratedTask: onOpenMigratedTask,
                onDelete: { entry in
                    if let task = entry as? DataModel.Task {
                        Task { @MainActor in
                            try? await journalManager.deleteTask(task)
                            await syncEngine?.syncNow()
                        }
                    } else if let note = entry as? DataModel.Note {
                        Task { @MainActor in
                            try? await journalManager.deleteNote(note)
                            await syncEngine?.syncNow()
                        }
                    }
                },
                onComplete: { task in
                    Task { @MainActor in
                        let newStatus: DataModel.Task.Status = task.status == .complete ? .open : .complete
                        try? await journalManager.updateTaskStatus(task, newStatus: newStatus)
                        await syncEngine?.syncNow()
                    }
                },
                migrationConfiguration: migrationConfiguration,
                onTitleCommit: { @MainActor task, newTitle in
                    try? await journalManager.updateTaskTitle(task, newTitle: newTitle)
                    Task { @MainActor in await syncEngine?.syncNow() }
                },
                onReassignTask: { @MainActor task, date, period in
                    try? await journalManager.updateTaskDateAndPeriod(task, newDate: date, newPeriod: period)
                    await syncEngine?.syncNow()
                },
                onAddTask: { @MainActor title, date, period in
                    _ = try await journalManager.addTask(title: title, date: date, period: period)
                    Task { @MainActor in await syncEngine?.syncNow() }
                },
                explicitDaySpreadForDate: explicitDaySpreadForDate,
                onSelectSpread: onSelectSpread,
                onCreateSpread: onCreateSpread,
                onRefresh: {
                    guard let engine = syncEngine, engine.status.shouldTriggerSync else { return }
                    await engine.syncNow()
                },
                syncStatus: syncEngine?.status
            )
        } else {
            ContentUnavailableView {
                Label("No Data", systemImage: "tray")
            } description: {
                Text("Unable to load spread data.")
            }
        }
    }
}
