import SwiftUI

extension DaySpreadContentView {

    /// Layout and sizing constants for `DaySpreadContentView`.
    struct Config {
        /// Divides the available container width into `wideTimelineColumnCount` equal parts
        /// and sizes the timeline card to `wideTimelineColumnSpan` of them.
        let wideTimelineColumnCount: Int
        let wideTimelineColumnSpan: Int

        /// Divides the available container height into `wideTimelineRowCount` equal parts
        /// and sizes the scrollable timeline content to `wideTimelineRowSpan` of them.
        ///
        /// A span larger than the count makes the content taller than the visible card,
        /// keeping the timeline scrollable across all device sizes.
        let wideTimelineRowCount: Int
        let wideTimelineRowSpan: Int

        init(
            wideTimelineColumnCount: Int = 10,
            wideTimelineColumnSpan: Int = 4,
            wideTimelineRowCount: Int = 1,
            wideTimelineRowSpan: Int = 3
        ) {
            self.wideTimelineColumnCount = wideTimelineColumnCount
            self.wideTimelineColumnSpan = wideTimelineColumnSpan
            self.wideTimelineRowCount = wideTimelineRowCount
            self.wideTimelineRowSpan = wideTimelineRowSpan
        }

        static let `default` = Config()
    }

    /// Owns entry list state, calendar events, and configuration map for `DaySpreadContentView`.
    ///
    /// Fully initialized at creation time — no deferred configuration step. The calendar
    /// event fetch is kicked off immediately via a stored `Task`.
    @Observable @MainActor
    final class ViewModel {
        let spread: DataModel.Spread
        private let journalManager: JournalManager
        private let syncEngine: SyncEngine?
        private let groupsByList: Bool

        private(set) var sections: [EntryList.Section] = []
        private(set) var configurationMap: [EntryType: EntryRowView.Configuration] = [:]
        private(set) var calendarEvents: [CalendarEvent] = []
        var onAddTask: (@MainActor (String, Date, Period) async throws -> Void)?

        @ObservationIgnored private var fetchTask: Task<Void, Never>?

        /// Always-fresh spread data derived from the live `journalManager.dataModel`.
        var spreadDataModel: SpreadDataModel? {
            let normalizedDate = spread.period.normalizeDate(spread.date, calendar: journalManager.calendar)
            return journalManager.dataModel[spread.period]?[normalizedDate]
        }

        var calendar: Calendar { journalManager.calendar }

        var allDayEvents: [CalendarEvent] { calendarEvents.filter { $0.isAllDay } }
        var timedEvents: [CalendarEvent] { calendarEvents.filter { !$0.isAllDay } }

        init(
            spread: DataModel.Spread,
            journalManager: JournalManager,
            syncEngine: SyncEngine?,
            groupsByList: Bool = true,
            eventKitService: (any EventKitService)?,
            onEditTask: @escaping (DataModel.Task) -> Void,
            onEditNote: @escaping (DataModel.Note) -> Void
        ) {
            self.spread = spread
            self.journalManager = journalManager
            self.syncEngine = syncEngine
            self.groupsByList = groupsByList

            setupConfigurationMap(onEditTask: onEditTask, onEditNote: onEditNote)
            refreshSections(showsTimelineCard: false)

            let capturedService = eventKitService
            fetchTask = Task { [weak self] in
                await self?.fetchCalendarEvents(service: capturedService)
            }
        }

        /// Refreshes entry list sections. Called from the view when calendar events,
        /// timeline card visibility, or task/note counts change.
        func refreshSections(showsTimelineCard: Bool) {
            guard let dataModel = spreadDataModel else { return }
            let cal = journalManager.calendar
            sections = Self.makeSections(
                from: allEntries(dataModel: dataModel, calendar: cal, showsTimelineCard: showsTimelineCard),
                spreadDate: dataModel.spread.date,
                calendar: cal,
                groupsByList: groupsByList
            )
        }

        // MARK: - Section Grouping

        /// Groups day spread entries into sections.
        ///
        /// When `groupsByList` is true, entries are bucketed into named-list sections (alphabetical)
        /// with a trailing untitled section for entries with no list. When false, all entries appear
        /// in a single flat section — used in traditional mode.
        static func makeSections(
            from entries: [any Entry],
            spreadDate: Date,
            calendar: Calendar,
            groupsByList: Bool
        ) -> [EntryList.Section] {
            guard !entries.isEmpty else { return [] }

            let sectionID = String(spreadDate.timeIntervalSinceReferenceDate)

            func entryDate(_ entry: any Entry) -> Date {
                switch entry.entryType {
                case .task: return (entry as? DataModel.Task)?.date ?? .now
                case .event: return (entry as? DataModel.Event)?.startDate ?? .now
                case .note: return (entry as? DataModel.Note)?.date ?? .now
                }
            }

            func sorted(_ entries: [any Entry]) -> [any Entry] {
                entries.sorted { entryDate($0) < entryDate($1) }
            }

            guard groupsByList else {
                return [EntryList.Section(
                    id: sectionID,
                    title: "",
                    date: spreadDate,
                    entries: sorted(entries),
                    creationPeriod: .day,
                    creationDate: spreadDate
                )]
            }

            var listGroups: [UUID?: [any Entry]] = [:]
            var listNames: [UUID: String] = [:]

            for entry in entries {
                if let task = entry as? DataModel.Task {
                    let listID = task.list?.id
                    listGroups[listID, default: []].append(entry)
                    if let list = task.list { listNames[list.id] = list.name }
                } else {
                    listGroups[nil, default: []].append(entry)
                }
            }

            var sections: [EntryList.Section] = []

            let sortedListIDs = listNames.keys.sorted { listNames[$0]! < listNames[$1]! }
            for listID in sortedListIDs {
                sections.append(EntryList.Section(
                    id: listID.uuidString,
                    title: listNames[listID] ?? "",
                    date: spreadDate,
                    entries: sorted(listGroups[listID] ?? []),
                    creationPeriod: .day,
                    creationDate: spreadDate
                ))
            }

            if let noListEntries = listGroups[nil], !noListEntries.isEmpty {
                sections.append(EntryList.Section(
                    id: sectionID,
                    title: "",
                    date: spreadDate,
                    entries: sorted(noListEntries),
                    creationPeriod: .day,
                    creationDate: spreadDate
                ))
            }

            return sections
        }

        // MARK: - Private

        private func allEntries(dataModel: SpreadDataModel, calendar: Calendar, showsTimelineCard: Bool) -> [any Entry] {
            let base = EntryListDisplaySupport.displayedEntries(for: dataModel, calendar: calendar)
            let eventEntries: [DataModel.Event] = showsTimelineCard ? [] : calendarEvents.map { DataModel.Event(calendarEvent: $0) }
            return base + eventEntries
        }

        private func fetchCalendarEvents(service: (any EventKitService)?) async {
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

        private func setupConfigurationMap(
            onEditTask: @escaping (DataModel.Task) -> Void,
            onEditNote: @escaping (DataModel.Note) -> Void
        ) {
            let journalManager = self.journalManager
            let syncEngine = self.syncEngine
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

            configurationMap = [.task: taskConfig, .note: noteConfig, .event: eventConfig]

            onAddTask = { @MainActor title, date, period in
                _ = try await journalManager.addTask(title: title, date: date, period: period)
                Task { @MainActor in await syncEngine?.syncNow() }
            }
        }
    }
}
