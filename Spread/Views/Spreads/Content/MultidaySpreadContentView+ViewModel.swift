import SwiftUI

extension MultidaySpreadContentView {

    /// Owns entry list state and configuration map for `MultidaySpreadContentView`.
    @Observable @MainActor
    final class ViewModel {
        private(set) var sections: [EntryList.Section] = []
        private(set) var configurationMap: [EntryType: EntryRowView.Configuration] = [:]
        private(set) var calendarEvents: [CalendarEvent] = []
        var onAddTask: (@MainActor (String, Date, Period) async throws -> Void)? = nil

        init() {}

        /// Full setup: entry list sections and configuration map.
        /// Called once when the spread-id changes.
        func configure(
            spread: DataModel.Spread,
            dataModel: SpreadDataModel,
            journalManager: JournalManager,
            syncEngine: SyncEngine?,
            coordinator: SpreadsCoordinator
        ) {
            refreshSections(spread: spread, dataModel: dataModel, journalManager: journalManager)
            configurationMap = [
                .task: .standardTaskConfig(journalManager: journalManager, syncEngine: syncEngine, coordinator: coordinator),
                .note: .standardNoteConfig(journalManager: journalManager, syncEngine: syncEngine, coordinator: coordinator),
                .event: .standardEventConfig(journalManager: journalManager)
            ]
            onAddTask = { @MainActor title, date, period in
                _ = try await journalManager.addTask(title: title, date: date, period: period)
                Task { @MainActor in await syncEngine?.syncNow() }
            }
        }

        /// Refreshes the entry list sections when entries or calendar events change.
        func refreshSections(
            spread: DataModel.Spread,
            dataModel: SpreadDataModel,
            journalManager: JournalManager
        ) {
            let cal = journalManager.firstWeekday.configuredCalendar(from: journalManager.calendar)
            let groupsByDay = journalManager.bujoMode == .conventional
            sections = Self.makeSections(
                from: allEntries(dataModel: dataModel, calendar: cal),
                spreadDate: dataModel.spread.date,
                startDate: dataModel.spread.startDate ?? dataModel.spread.date,
                endDate: dataModel.spread.endDate ?? dataModel.spread.date,
                calendar: cal,
                groupsByDay: groupsByDay
            )
        }

        /// Fetches calendar events for the multiday spread range.
        func fetchCalendarEvents(
            for spread: DataModel.Spread,
            service: (any EventKitService)?,
            journalManager: JournalManager
        ) async {
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
    }
}
