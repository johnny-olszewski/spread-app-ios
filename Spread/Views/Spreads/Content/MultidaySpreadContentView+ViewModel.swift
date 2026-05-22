import SwiftUI

extension MultidaySpreadContentView {

    /// Owns entry list state and configuration map for `MultidaySpreadContentView`.
    @Observable @MainActor
    final class ViewModel {
        private(set) var sections: [EntryList.Section] = []
        private(set) var configurationMap: [EntryType: EntryRowView.Configuration] = [:]
        private(set) var calendarEvents: [CalendarEvent] = []
        var onAddTask: (@MainActor (String, Date, Period) async throws -> Void)?

        /// Full setup: entry list sections and configuration map.
        /// Called once when the spread-id changes.
        func configure(
            spread: DataModel.Spread,
            dataModel: SpreadDataModel,
            groupsByDay: Bool,
            journalManager: JournalManager,
            syncEngine: SyncEngine?,
            coordinator: SpreadsCoordinator
        ) {
            refreshSections(spread: spread, dataModel: dataModel, groupsByDay: groupsByDay, journalManager: journalManager)
            setupConfigurationMap(journalManager: journalManager, syncEngine: syncEngine, coordinator: coordinator)
        }

        /// Refreshes the entry list sections when entries or calendar events change.
        func refreshSections(
            spread: DataModel.Spread,
            dataModel: SpreadDataModel,
            groupsByDay: Bool,
            journalManager: JournalManager
        ) {
            let cal = journalManager.calendar
            sections = Self.makeSections(
                from: allEntries(dataModel: dataModel, calendar: cal),
                spreadDate: dataModel.spread.date,
                startDate: dataModel.spread.startDate ?? dataModel.spread.date,
                endDate: dataModel.spread.endDate ?? dataModel.spread.date,
                calendar: cal,
                groupsByDay: groupsByDay
            )
        }

        /// Fetches calendar events for the multiday spread range. `service` is passed in
        /// because it lives in the view's SwiftUI environment.
        func fetchCalendarEvents(for spread: DataModel.Spread, service: (any EventKitService)?, journalManager: JournalManager) async {
            guard let service,
                  let startDate = spread.startDate,
                  let endDate = spread.endDate else { return }
            if service.authorizationStatus == .notDetermined {
                _ = await service.requestAuthorization()
            }
            guard service.authorizationStatus == .authorized else {
                calendarEvents = []
                return
            }
            let cal = journalManager.calendar
            let start = startDate.startOfDay(calendar: cal)
            guard let end = cal.date(byAdding: .day, value: 1, to: endDate.startOfDay(calendar: cal)) else { return }
            calendarEvents = service.fetchEvents(from: start, to: end)
        }

        // MARK: - Section Grouping

        /// Groups multiday spread entries into per-day sections.
        ///
        /// When `groupsByDay` is true, multiday-assigned entries appear in a leading "This Range"
        /// section and day-assigned entries are bucketed per day. Every day in the range gets a
        /// section, even when empty. When false, all entries appear in a single flat section —
        /// used in traditional mode.
        static func makeSections(
            from entries: [any Entry],
            spreadDate: Date,
            startDate: Date,
            endDate: Date,
            calendar: Calendar,
            groupsByDay: Bool
        ) -> [EntryList.Section] {
            let sectionID = String(spreadDate.timeIntervalSinceReferenceDate)

            func entryDate(_ entry: any Entry) -> Date {
                switch entry.entryType {
                case .task: return (entry as? DataModel.Task)?.date ?? .now
                case .event: return (entry as? DataModel.Event)?.startDate ?? .now
                case .note: return (entry as? DataModel.Note)?.date ?? .now
                }
            }

            func entryPeriod(_ entry: any Entry) -> Period {
                if let task = entry as? DataModel.Task { return task.period }
                if let note = entry as? DataModel.Note { return note.period }
                return .day
            }

            func sorted(_ entries: [any Entry]) -> [any Entry] {
                entries.sorted { entryDate($0) < entryDate($1) }
            }

            guard groupsByDay else {
                return [EntryList.Section(
                    id: sectionID,
                    title: "",
                    date: startDate,
                    entries: sorted(entries),
                    creationPeriod: .day,
                    creationDate: spreadDate
                )]
            }

            let start = startDate.startOfDay(calendar: calendar)
            let end = endDate.startOfDay(calendar: calendar)

            let multidayEntries = sorted(entries.filter { entryPeriod($0) == .multiday })

            var dayGroups: [Date: [any Entry]] = [:]
            for entry in entries {
                guard entryPeriod(entry) == .day else { continue }
                let entryDay = entryDate(entry).startOfDay(calendar: calendar)
                dayGroups[entryDay, default: []].append(entry)
            }

            var sections: [EntryList.Section] = []

            if !multidayEntries.isEmpty {
                sections.append(EntryList.Section(
                    id: "multiday-header",
                    title: "This Range",
                    date: start,
                    entries: multidayEntries,
                    creationPeriod: .multiday,
                    creationDate: spreadDate
                ))
            }

            var current = start
            while current <= end {
                sections.append(EntryList.Section(
                    id: String(current.timeIntervalSinceReferenceDate),
                    title: "",
                    date: current,
                    entries: sorted(dayGroups[current] ?? []),
                    creationPeriod: .day,
                    creationDate: current
                ))
                guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
                current = next.startOfDay(calendar: calendar)
            }

            return sections
        }

        // MARK: - Private

        private func allEntries(dataModel: SpreadDataModel, calendar: Calendar) -> [any Entry] {
            let base = EntryListDisplaySupport.displayedEntries(for: dataModel, calendar: calendar)
            let eventEntries: [DataModel.Event] = calendarEvents.map { DataModel.Event(calendarEvent: $0) }
            return base + eventEntries
        }

        private func setupConfigurationMap(
            journalManager: JournalManager,
            syncEngine: SyncEngine?,
            coordinator: SpreadsCoordinator
        ) {
            let calendar = journalManager.calendar
            let today = journalManager.today

            let taskConfig = EntryRowView.Configuration(
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
                    else if let note = entry as? DataModel.Note { coordinator.showNoteDetail(note) }
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

            let noteConfig = EntryRowView.Configuration(
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

            configurationMap = [.task: taskConfig, .note: noteConfig, .event: eventConfig]

            onAddTask = { @MainActor title, date, period in
                _ = try await journalManager.addTask(title: title, date: date, period: period)
                Task { @MainActor in await syncEngine?.syncNow() }
            }
        }
    }
}
