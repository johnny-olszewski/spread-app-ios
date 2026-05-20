import SwiftUI

extension DaySpreadContentView {

    /// Owns entry list state and configuration map for `DaySpreadContentView`.
    ///
    /// Replaces the per-view `@State entryListViewModel` and `@State calendarEvents` properties,
    /// consolidating all data-configuration logic in one place. The view retains coordinator
    /// interactions and view-environment-dependent state (`horizontalSizeClass`,
    /// `timelineScrollPosition`).
    @Observable @MainActor
    final class ViewModel {
        private(set) var entryListViewModel = EntryListViewModel()
        private(set) var calendarEvents: [CalendarEvent] = []

        var allDayEvents: [CalendarEvent] { calendarEvents.filter { $0.isAllDay } }
        var timedEvents: [CalendarEvent] { calendarEvents.filter { !$0.isAllDay } }

        /// Full setup: entry list sections, calendar metadata, and configuration map.
        /// Called once when the spread-id changes.
        func configure(
            spread: DataModel.Spread,
            dataModel: SpreadDataModel,
            entryListConfiguration: EntryListConfiguration,
            showsTimelineCard: Bool,
            journalManager: JournalManager,
            syncEngine: SyncEngine?,
            onEditTask: @escaping (DataModel.Task) -> Void,
            onEditNote: @escaping (DataModel.Note) -> Void
        ) {
            setupEntryList(spread: spread, dataModel: dataModel, entryListConfiguration: entryListConfiguration, showsTimelineCard: showsTimelineCard, journalManager: journalManager)
            setupConfigurationMap(spread: spread, journalManager: journalManager, syncEngine: syncEngine, onEditTask: onEditTask, onEditNote: onEditNote)
        }

        /// Refreshes the entry list sections when entries or calendar events change.
        func refreshSections(
            spread: DataModel.Spread,
            dataModel: SpreadDataModel,
            entryListConfiguration: EntryListConfiguration,
            showsTimelineCard: Bool,
            journalManager: JournalManager
        ) {
            let cal = journalManager.calendar
            let grouper = EntryListGrouper(
                configuration: entryListConfiguration,
                period: dataModel.spread.period,
                spreadDate: dataModel.spread.date,
                spreadStartDate: dataModel.spread.startDate,
                spreadEndDate: dataModel.spread.endDate,
                calendar: cal
            )
            entryListViewModel.sections = grouper.group(allEntries(dataModel: dataModel, calendar: cal, showsTimelineCard: showsTimelineCard))
        }

        /// Fetches calendar events for the day spread. `eventKitService` is passed in
        /// because it lives in the view's SwiftUI environment.
        func fetchCalendarEvents(for spread: DataModel.Spread, service: (any EventKitService)?, journalManager: JournalManager) async {
            guard let service else { return }
            if service.authorizationStatus == .notDetermined {
                _ = await service.requestAuthorization()
            }
            guard service.authorizationStatus == .authorized else {
                calendarEvents = []
                return
            }
            let dayStart = spread.date.startOfDay(calendar: journalManager.calendar)
            guard let dayEnd = journalManager.calendar.date(byAdding: .day, value: 1, to: dayStart) else { return }
            calendarEvents = service.fetchEvents(from: dayStart, to: dayEnd)
        }

        // MARK: - Private

        private func allEntries(dataModel: SpreadDataModel, calendar: Calendar, showsTimelineCard: Bool) -> [any Entry] {
            let base = EntryListDisplaySupport.displayedEntries(for: dataModel, calendar: calendar)
            let eventEntries: [DataModel.Event] = showsTimelineCard ? [] : calendarEvents.map { DataModel.Event(calendarEvent: $0) }
            return base + eventEntries
        }

        private func setupEntryList(
            spread: DataModel.Spread,
            dataModel: SpreadDataModel,
            entryListConfiguration: EntryListConfiguration,
            showsTimelineCard: Bool,
            journalManager: JournalManager
        ) {
            let cal = journalManager.calendar
            let grouper = EntryListGrouper(
                configuration: entryListConfiguration,
                period: dataModel.spread.period,
                spreadDate: dataModel.spread.date,
                spreadStartDate: dataModel.spread.startDate,
                spreadEndDate: dataModel.spread.endDate,
                calendar: cal
            )
            entryListViewModel.sections = grouper.group(allEntries(dataModel: dataModel, calendar: cal, showsTimelineCard: showsTimelineCard))
            entryListViewModel.calendar = cal
            entryListViewModel.today = journalManager.today
        }

        private func setupConfigurationMap(
            spread: DataModel.Spread,
            journalManager: JournalManager,
            syncEngine: SyncEngine?,
            onEditTask: @escaping (DataModel.Task) -> Void,
            onEditNote: @escaping (DataModel.Note) -> Void
        ) {
            let calendar = journalManager.calendar
            let today = journalManager.today

            func effectiveStatus(for entry: any Entry) -> DataModel.Task.Status? {
                guard let task = entry as? DataModel.Task else { return nil }
                return task.status
            }

            let taskConfig = EntryRowView.Configuration(
                effectiveTaskStatus: { effectiveStatus(for: $0) },
                isGreyedOut: { entry in
                    guard let s = effectiveStatus(for: entry) else { return false }
                    return s == .complete || s == .migrated || s == .cancelled
                },
                hasStrikethrough: { entry in effectiveStatus(for: entry) == .cancelled },
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
                    if let task = entry as? DataModel.Task { onEditTask(task) }
                    else if let note = entry as? DataModel.Note { onEditNote(note) }
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

            let eventConfig = EntryRowView.Configuration(
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

            entryListViewModel.configurationMap = [.task: taskConfig, .note: noteConfig, .event: eventConfig]

            entryListViewModel.onAddTask = { @MainActor title, date, period in
                _ = try await journalManager.addTask(title: title, date: date, period: period)
                Task { @MainActor in await syncEngine?.syncNow() }
            }
        }
    }
}
