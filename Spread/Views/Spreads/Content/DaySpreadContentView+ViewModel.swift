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

    /// Owns fetched calendar events for `DaySpreadContentView`.
    @Observable @MainActor
    final class CalendarEventStore {
        private(set) var calendarEvents: [CalendarEvent] = []

        var allDayEvents: [CalendarEvent] { calendarEvents.filter { $0.isAllDay } }
        var timedEvents: [CalendarEvent] { calendarEvents.filter { !$0.isAllDay } }

        init() {}

        /// Fetches calendar events for the spread day.
        func fetchCalendarEvents(
            spread: DataModel.Spread,
            service: (any EventKitService)?,
            calendar: Calendar
        ) async {
            guard let service else { return }
            if service.authorizationStatus == .notDetermined {
                _ = await service.requestAuthorization()
            }
            guard service.authorizationStatus == .authorized else {
                calendarEvents = []
                return
            }
            let dayStart = spread.date.startOfDay(calendar: calendar)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return }
            calendarEvents = service.fetchEvents(from: dayStart, to: dayEnd)
        }
    }

    // MARK: - Section Grouping

    /// Groups day spread entries into named-list sections (alphabetical),
    /// with a trailing untitled section for entries with no list.
    static func makeSections(
        from entries: [any Entry],
        spreadDate: Date,
        calendar: Calendar
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
}
