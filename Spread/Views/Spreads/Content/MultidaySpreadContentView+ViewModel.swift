import SwiftUI

extension MultidaySpreadContentView {

    /// Owns fetched calendar events for `MultidaySpreadContentView`.
    @Observable @MainActor
    final class CalendarEventStore {
        private(set) var calendarEvents: [CalendarEvent] = []

        init() {}

        /// Fetches calendar events for the multiday spread range.
        func fetchCalendarEvents(
            for spread: DataModel.Spread,
            service: (any EventKitService)?,
            calendar: Calendar
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
            let start = startDate.startOfDay(calendar: calendar)
            guard let end = calendar.date(
                byAdding: .day,
                value: 1,
                to: endDate.startOfDay(calendar: calendar)
            ) else { return }
            calendarEvents = service.fetchEvents(from: start, to: end)
        }
    }

    // MARK: - Section Grouping

    /// Groups multiday spread entries into per-day sections.
    ///
    /// Multiday-assigned entries appear in a leading "This Range" section.
    /// Day-assigned entries are bucketed per day. Every day in the range gets a
    /// section, even when empty.
    static func makeSections(
        from entries: [any Entry],
        spreadDate: Date,
        startDate: Date,
        endDate: Date,
        calendar: Calendar
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
                criteria: EntryTitleSectionCriteria(sectionID: "multiday-header", sectionTitle: "This Range"),
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
                criteria: nil,
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
}
