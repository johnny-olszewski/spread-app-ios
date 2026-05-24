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
    @Observable @MainActor
    final class ViewModel {
        private(set) var sections: [EntryList.Section] = []
        private(set) var configurationMap: [EntryType: EntryRowView.Configuration] = [:]
        private(set) var calendarEvents: [CalendarEvent] = []
        var onAddTask: (@MainActor (String, Date, Period) async throws -> Void)? = nil

        var allDayEvents: [CalendarEvent] { calendarEvents.filter { $0.isAllDay } }
        var timedEvents: [CalendarEvent] { calendarEvents.filter { !$0.isAllDay } }

        init() {}

        /// Full setup: sections, configuration map, and onAddTask.
        /// Called once when the spread-id changes.
        func configure(
            spread: DataModel.Spread,
            spreadDataModel: SpreadDataModel,
            journalManager: JournalManager,
            syncEngine: SyncEngine?,
            coordinator: SpreadsCoordinator
        ) {
            refreshSections(
                spread: spread,
                dataModel: spreadDataModel,
                journalManager: journalManager,
                showsTimelineCard: false
            )
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

        /// Refreshes entry list sections. Called when journal data or timeline card visibility changes.
        func refreshSections(
            spread: DataModel.Spread,
            dataModel: SpreadDataModel,
            journalManager: JournalManager,
            showsTimelineCard: Bool
        ) {
            let cal = journalManager.firstWeekday.configuredCalendar(from: journalManager.calendar)
            let groupsByList = journalManager.bujoMode == .conventional
            sections = Self.makeSections(
                from: allEntries(dataModel: dataModel, calendar: cal, showsTimelineCard: showsTimelineCard),
                spreadDate: dataModel.spread.date,
                calendar: cal,
                groupsByList: groupsByList
            )
        }

        /// Fetches calendar events for the day. `service` and `journalManager` are passed in
        /// because they live in the view's SwiftUI environment.
        func fetchCalendarEvents(
            spread: DataModel.Spread,
            service: (any EventKitService)?,
            journalManager: JournalManager
        ) async {
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

        private func allEntries(
            dataModel: SpreadDataModel,
            calendar: Calendar,
            showsTimelineCard: Bool
        ) -> [any Entry] {
            let base = EntryListDisplaySupport.displayedEntries(for: dataModel, calendar: calendar)
            let eventEntries: [DataModel.Event] = showsTimelineCard ? [] : calendarEvents.map { DataModel.Event(calendarEvent: $0) }
            return base + eventEntries
        }
    }
}
