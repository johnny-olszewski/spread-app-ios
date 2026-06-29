import SwiftUI

extension MultidaySpreadContentView {

    /// View model for `MultidaySpreadContentView`.
    ///
    /// Owns the spread's entry data, derived per-day `EntryList` sections, and the
    /// calendar events fetched for the spread's date range.
    @Observable
    @MainActor
    final class ViewModel {

        let spread: DataModel.Spread
        let spreadDataModel: SpreadDataModel
        let context: SpreadPageContext
        let horizontalSizeClass: UserInterfaceSizeClass?

        var calendarEvents: [CalendarEvent] = []

        init(
            spread: DataModel.Spread,
            spreadDataModel: SpreadDataModel,
            context: SpreadPageContext,
            horizontalSizeClass: UserInterfaceSizeClass?
        ) {
            self.spread = spread
            self.spreadDataModel = spreadDataModel
            self.context = context
            self.horizontalSizeClass = horizontalSizeClass
        }

        // MARK: - Computed

        /// Groups/orders the spread's entries per `groupingOption`/`sortingOption`.
        ///
        /// `groupingOption` only subdivides the leading "This Range" section (multiday-assigned
        /// entries) — per-day cards are already a fixed, structural grouping by date, and the
        /// compact card layout has no room for a second nested grouping dimension inside it.
        /// `sortingOption` applies everywhere: within "This Range" and within every day card.
        func sections(groupedBy groupingOption: EntryGroupingOption, orderedBy sortingOption: EntrySortOption) -> [EntryList.Section] {
            let cal = context.calendar
            let live = context.journalManager.spreadDataModel(for: spread.date, period: spread.period) ?? spreadDataModel
            let base = live.displayedEntries(calendar: cal)
            let eventEntries: [DataModel.Event] = calendarEvents.map { DataModel.Event(calendarEvent: $0) }

            return Self.makeSections(
                from: base + eventEntries,
                spreadDate: spread.date,
                startDate: spread.startDate ?? spread.date,
                endDate: spread.endDate ?? spread.date,
                calendar: cal,
                groupingOption: groupingOption,
                sortingOption: sortingOption
            )
        }
        
        var columnCount: Int { horizontalSizeClass?.multidayColumnCount ?? 1 }
        
        var columns: [GridItem] {
            Array(
                repeating: GridItem(.flexible(), spacing: 16, alignment: .top),
                count: columnCount
            )
        }

        var configurationMap: EntryRowView.ConfigurationMap {
            [
                DataModel.Task.configurationKey: .standardTaskConfig(
                    journalManager: context.journalManager,
                    syncEngine: context.syncEngine,
                    coordinator: context.coordinator
                ),
                DataModel.Note.configurationKey: .standardNoteConfig(
                    journalManager: context.journalManager,
                    syncEngine: context.syncEngine,
                    coordinator: context.coordinator
                ),
                DataModel.Event.configurationKey: .standardEventConfig(journalManager: context.journalManager)
            ]
        }

        var onAddTask: (@MainActor (String, Date, Period, DataModel.List?, DataModel.Tag?) async throws -> Void) {
            let jm = context.journalManager
            let se = context.syncEngine
            return { @MainActor title, date, period, list, tag in
                _ = try await jm.addTask(title: title, date: date, period: period, list: list, tag: tag)
                Task { @MainActor in await se?.syncNow() }
            }
        }

        // MARK: - Actions

        func fetchCalendarEvents() async {
            calendarEvents = await context.calendarEventService.fetchEvents(
                for: spread,
                calendar: context.journalManager.calendar
            )
        }

        // MARK: - Day Card Helpers

        /// Returns the explicit day spread for the given date, if one exists.
        func explicitDaySpread(for date: Date) -> DataModel.Spread? {
            context.journalManager.spreadDataModel(for: date, period: .day)?.spread
        }

        /// The entry data for a given day spread, or `nil` if it has not been loaded.
        func dataModel(for daySpread: DataModel.Spread) -> SpreadDataModel? {
            let key = SpreadDataModelKey(spread: daySpread, calendar: context.calendar)
            return context.journalManager.dataModel[key: key]
        }

        /// The number of open tasks assigned to the given day spread.
        func openTaskCount(for daySpread: DataModel.Spread) -> Int {
            dataModel(for: daySpread)?.tasks.filter { $0.status == .open }.count ?? 0
        }

        /// Peek panel data for the given day spread, including calendar events overlapping that day.
        func peekData(for daySpread: DataModel.Spread) -> SpreadPeekPanelView.Data? {
            guard let dataModel = dataModel(for: daySpread) else { return nil }

            let calendar = context.calendar
            let dayStart = daySpread.date.startOfDay(calendar: calendar)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return nil }

            let dayEvents = calendarEvents.filter { $0.startDate < dayEnd && $0.endDate > dayStart }
            return SpreadPeekPanelView.Data(spread: daySpread, spreadDataModel: dataModel, calendarEvents: dayEvents)
        }

        /// The number of open, overdue tasks assigned to this multiday spread that fall within `section`.
        ///
        /// Only non-zero once the spread's range has fully passed (today is after `endDate`).
        func overdueCount(for section: EntryList.Section) -> Int {
            guard let endDate = spread.endDate else { return 0 }

            let calendar = context.calendar
            let todayStart = context.journalManager.today.startOfDay(calendar: calendar)
            guard todayStart > endDate.startOfDay(calendar: calendar) else { return 0 }

            return section.entries.reduce(into: 0) { count, entry in
                guard let task = entry as? DataModel.Task, task.status == .open else { return }
                let isAssigned = task.currentAssignments.contains { assignment in
                    assignment.status == .open &&
                    assignment.matches(spread: spread, calendar: calendar)
                }
                if isAssigned { count += 1 }
            }
        }

        // MARK: - Section Grouping

        /// Groups multiday spread entries into per-day sections.
        ///
        /// Multiday-assigned entries appear in one or more leading "This Range" sections —
        /// subdivided by `groupingOption` (e.g. one "This Range" card per list/tag/status/type),
        /// or a single "This Range" card when `groupingOption == .none`. Day-assigned entries are
        /// bucketed per day — that bucketing is fixed and not affected by `groupingOption`, since
        /// each day card already has no room for a second nested grouping dimension; `sortingOption`
        /// still orders entries within each day card. Every day in the range gets a section, even
        /// when empty.
        static func makeSections(
            from entries: [any Entry],
            spreadDate: Date,
            startDate: Date,
            endDate: Date,
            calendar: Calendar,
            groupingOption: EntryGroupingOption,
            sortingOption: EntrySortOption
        ) -> [EntryList.Section] {
            func entryPeriod(_ entry: any Entry) -> Period {
                if let task = entry as? DataModel.Task { return task.period ?? .day }
                if let note = entry as? DataModel.Note { return note.period }
                return .day
            }

            func ordered(_ entries: [any Entry]) -> [any Entry] {
                if let areInOrder = sortingOption.areInOrder {
                    return entries.sorted(by: areInOrder)
                }
                return entries.sorted { $0.sortDate < $1.sortDate }
            }

            let start = startDate.startOfDay(calendar: calendar)
            let end = endDate.startOfDay(calendar: calendar)

            let multidayEntries = entries.filter { entryPeriod($0) == .multiday }

            var dayGroups: [Date: [any Entry]] = [:]
            for entry in entries {
                guard entryPeriod(entry) == .day else { continue }
                let entryDay = entry.sortDate.startOfDay(calendar: calendar)
                dayGroups[entryDay, default: []].append(entry)
            }

            var sections: [EntryList.Section] = []

            if !multidayEntries.isEmpty {
                let grouped = EntryList.Section.grouped(
                    from: multidayEntries,
                    by: groupingOption.grouping(date: start, creationPeriod: .multiday, creationDate: spreadDate),
                    orderedBy: sortingOption.areInOrder
                )
                sections.append(contentsOf: grouped.map { section in
                    EntryList.Section(
                        id: "multiday-header-\(section.id)",
                        title: groupingOption == .none ? "This Range" : "This Range — \(section.title)",
                        date: section.date,
                        entries: section.entries,
                        creationPeriod: .multiday,
                        creationDate: spreadDate
                    )
                })
            }

            var current = start
            while current <= end {
                sections.append(EntryList.Section(
                    id: String(current.timeIntervalSinceReferenceDate),
                    title: "",
                    date: current,
                    entries: ordered(dayGroups[current] ?? []),
                    creationPeriod: .day,
                    creationDate: current
                ))
                guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
                current = next.startOfDay(calendar: calendar)
            }

            return sections
        }
    }
}
