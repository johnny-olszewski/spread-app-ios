import SwiftUI

extension EntryRowView {

    /// A type-level configuration describing how entries of one type are displayed and what actions they support.
    ///
    /// One configuration per entry type is stored in `EntryListViewModel.configurationMap`. At render time
    /// `EntryRowView` calls each closure with the specific entry to derive per-row values. All business logic —
    /// date formatting, persistence callbacks — lives in closures built at the call site.
    struct Configuration {

        // MARK: - Context-dependent display derivations

        /// Returns the effective task status for display purposes.
        var effectiveTaskStatus: ((any Entry) -> DataModel.Task.Status?)?

        /// Returns whether the row should render greyed out.
        var isGreyedOut: ((any Entry) -> Bool)?

        /// Returns whether the row title should use strikethrough styling.
        var hasStrikethrough: ((any Entry) -> Bool)?

        /// Returns the formatted due date label (tasks only).
        var dueDateLabel: ((any Entry) -> String?)?

        /// Returns whether the due date label should use urgent styling.
        var isDueDateHighlighted: ((any Entry) -> Bool)?

        /// Returns whether the event has already ended (events only).
        var isEventPast: ((any Entry) -> Bool)?

        /// Returns the subtitle shown below the title (e.g. event time range + calendar name).
        var subtitle: ((any Entry) -> String?)?

        // MARK: - Action callbacks

        var onComplete: ((any Entry) -> Void)?
        var onEdit: ((any Entry) -> Void)?
        var onDelete: ((any Entry) -> Void)?
        var onTitleCommit: (@MainActor (any Entry, String) async -> Void)?
        var inlineActionConfiguration: ((any Entry) -> EntryRowInlineActionConfiguration?)?
    }
}

// MARK: - Standard configurations

extension EntryRowView.Configuration {

    /// Standard task row configuration shared across all spread periods.
    @MainActor
    static func standardTaskConfig(
        journalManager: JournalManager,
        syncEngine: SyncEngine?,
        coordinator: SpreadsCoordinator
    ) -> EntryRowView.Configuration {
        let calendar = journalManager.firstWeekday.configuredCalendar(from: journalManager.calendar)
        let today = journalManager.today
        return EntryRowView.Configuration(
            effectiveTaskStatus: { $0.displayTaskStatus },
            isGreyedOut: { entry in
                guard let s = entry.displayTaskStatus else { return false }
                return s == .complete || s == .migrated || s == .cancelled
            },
            hasStrikethrough: { entry in entry.displayTaskStatus == .cancelled },
            dueDateLabel: { entry in (entry as? DataModel.Task)?.dueDateLabel(calendar: calendar) },
            isDueDateHighlighted: { entry in
                (entry as? DataModel.Task)?.isDueDateHighlighted(today: today, calendar: calendar) ?? false
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
                if let task = entry as? DataModel.Task { coordinator.showTaskDetail(task) }
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
                let options = EntryRowInlineEditSupport.migrationOptions(for: task, today: today, calendar: calendar)
                return EntryRowInlineActionConfiguration(
                    migrationOptions: options,
                    onEditSheet: { coordinator.showTaskDetail(task) },
                    onMigrationSelected: { option in
                        try? await journalManager.updateTaskDateAndPeriod(task, newDate: option.date, newPeriod: option.period)
                        await syncEngine?.syncNow()
                    }
                )
            }
        )
    }

    /// Standard note row configuration shared across all spread periods.
    @MainActor
    static func standardNoteConfig(
        journalManager: JournalManager,
        syncEngine: SyncEngine?,
        coordinator: SpreadsCoordinator
    ) -> EntryRowView.Configuration {
        return EntryRowView.Configuration(
            isGreyedOut: { entry in (entry as? DataModel.Note)?.status == .migrated },
            onEdit: { entry in
                if let note = entry as? DataModel.Note { coordinator.showNoteDetail(note) }
            },
            onDelete: { entry in
                guard let note = entry as? DataModel.Note else { return }
                Task { @MainActor in
                    try? await journalManager.deleteNote(note)
                    await syncEngine?.syncNow()
                }
            }
        )
    }

    /// Standard calendar event row configuration shared across periods that surface calendar events.
    @MainActor
    static func standardEventConfig(journalManager: JournalManager) -> EntryRowView.Configuration {
        let calendar = journalManager.firstWeekday.configuredCalendar(from: journalManager.calendar)
        let today = journalManager.today
        return EntryRowView.Configuration(
            isGreyedOut: { entry in
                guard let event = entry as? DataModel.Event else { return false }
                return (event.calendarEvent?.endDate ?? event.endDate) < today
            },
            isEventPast: { entry in
                guard let event = entry as? DataModel.Event else { return false }
                return (event.calendarEvent?.endDate ?? event.endDate) < today
            },
            subtitle: { entry in
                guard let event = entry as? DataModel.Event,
                      let calEvent = event.calendarEvent else { return nil }
                if calEvent.isAllDay {
                    return "All Day · \(calEvent.calendarTitle)"
                } else {
                    let fmt = DateFormatter()
                    fmt.calendar = calendar
                    fmt.timeZone = calendar.timeZone
                    fmt.timeStyle = .short
                    fmt.dateStyle = .none
                    return "\(fmt.string(from: calEvent.startDate))–\(fmt.string(from: calEvent.endDate)) · \(calEvent.calendarTitle)"
                }
            }
        )
    }
}
