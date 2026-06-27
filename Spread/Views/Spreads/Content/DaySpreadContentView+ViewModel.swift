import SwiftUI
import JohnnyOFoundationCore
import JohnnyOFoundationUI

extension DaySpreadContentView {

    /// View model for `DaySpreadContentView`.
    ///
    /// Owns the spread's entry data, derived `EntryList` sections, and the
    /// calendar events fetched for the spread's date.
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

        var shouldShowTimelineCard: Bool {
            horizontalSizeClass.isRegular && !calendarEvents.isEmpty
        }

        /// Card-styled sections for overdue tasks, shown above the standard entry list.
        ///
        /// Only populated when the spread represents today and there are overdue items.
        /// Each distinct source spread (or Inbox) produces one card section.
        var overdueSections: [EntryList.Section] {
            guard context.calendar.isDateInToday(spread.date) else { return [] }

            let overdueItems = context.journalManager.overdueTaskItems
            guard !overdueItems.isEmpty else { return [] }

            // Map task ID → source key so the chip closure can look up each task's origin.
            let sourceKeyByTaskID = Dictionary(uniqueKeysWithValues: overdueItems.map { ($0.task.id, $0.sourceKey) })
            let entries: [any Entry] = overdueItems.map { $0.task }

            return [
                EntryList.Section(
                    id: "overdue",
                    title: "Overdue",
                    date: spread.date,
                    entries: entries,
                    creationPeriod: .day,
                    creationDate: spread.date,
                    configurationMap: [
                        DataModel.Task.configurationKey: .standardTaskConfig(
                            journalManager: context.journalManager,
                            syncEngine: context.syncEngine,
                            coordinator: context.coordinator,
                            getChips: { entry in
                                guard let task = entry as? DataModel.Task,
                                      let key = sourceKeyByTaskID[task.id] else { return [] }
                                return [key]
                            }
                        )
                    ],
                    style: .card(.orange)
                )
            ]
        }

        var sections: [EntryList.Section] {
            let cal = context.calendar
            let live = context.journalManager.spreadDataModel(for: spread.date, period: spread.period) ?? spreadDataModel
            let base: [any Entry] = live.tasks + live.notes
            let eventEntries = calendarEvents.map { DataModel.Event(calendarEvent: $0) }

            return Self.makeSections(
                from: base + eventEntries,
                spreadDate: spread.date,
                calendar: cal,
                listConfigurationMap: entryConfigurationMap,
                unassignedConfigurationMap: entryConfigurationMap,
                eventConfigurationMap: eventConfigurationMap
            )
        }

        var entryConfigurationMap: EntryRowView.ConfigurationMap {
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
                )
            ]
        }

        var eventConfigurationMap: EntryRowView.ConfigurationMap {
            shouldShowTimelineCard
                ? [:]
                : [DataModel.Event.configurationKey: .standardEventConfig(journalManager: context.journalManager)]
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

        func toggleFavorite() async {
            try? await context.journalManager.updateSpreadFavorite(spread, isFavorite: !spread.isFavorite)
            await context.syncEngine?.syncNow()
        }

        func fetchCalendarEvents() async {
            calendarEvents = await context.calendarEventService.fetchEvents(
                for: spread,
                calendar: context.journalManager.calendar
            )
        }

        // MARK: - Section Grouping

        /// Groups day spread entries into named-list sections (alphabetical),
        /// with a trailing untitled section for entries with no list.
        static func makeSections(
            from entries: [any Entry],
            spreadDate: Date,
            calendar: Calendar,
            listConfigurationMap: EntryRowView.ConfigurationMap,
            unassignedConfigurationMap: EntryRowView.ConfigurationMap,
            eventConfigurationMap: EntryRowView.ConfigurationMap
        ) -> [EntryList.Section] {
            guard !entries.isEmpty else { return [] }

            let sectionID = String(spreadDate.timeIntervalSinceReferenceDate)
            let eventSectionID = "\(sectionID)-events"

            // Partition entries into three buckets: named-list, unassigned, and events.
            var listGroups: [UUID: [any Entry]] = [:]
            var listsByID: [UUID: DataModel.List] = [:]
            var unassignedEntries: [any Entry] = []
            var eventEntries: [any Entry] = []

            for entry in entries {
                if entry.entryType == .event {
                    eventEntries.append(entry)
                } else if let list = entry.assignedList {
                    listGroups[list.id, default: []].append(entry)
                    listsByID[list.id] = list
                } else {
                    unassignedEntries.append(entry)
                }
            }

            var sections: [EntryList.Section] = []

            // Named-list sections — sorted alphabetically by list name.
            let sortedListIDs = listsByID.keys.sorted { listsByID[$0]!.name < listsByID[$1]!.name }
            for listID in sortedListIDs {
                sections.append(EntryList.Section(
                    id: listID.uuidString,
                    title: listsByID[listID]?.name ?? "",
                    date: spreadDate,
                    entries: (listGroups[listID] ?? []).sortedByDate(),
                    creationPeriod: .day,
                    creationDate: spreadDate,
                    configurationMap: listConfigurationMap
                ))
            }

            // Unassigned entries trailing the named-list sections.
            if !unassignedEntries.isEmpty {
                sections.append(
                    EntryList.Section(
                        id: sectionID,
                        title: "No List",
                        titleStyle: .secondary,
                        date: spreadDate,
                        entries: unassignedEntries.sortedByDate(),
                        creationPeriod: .day,
                        creationDate: spreadDate,
                        configurationMap: unassignedConfigurationMap
                    )
                )
            }

            // Calendar events always appear last.
            if !eventEntries.isEmpty {
                sections.append(EntryList.Section(
                    id: eventSectionID,
                    title: "Events",
                    date: spreadDate,
                    entries: eventEntries.sortedByDate(),
                    creationPeriod: .day,
                    creationDate: spreadDate,
                    configurationMap: eventConfigurationMap
                ))
            }

            return sections
        }
    }
}

// MARK: - UserInterfaceSizeClass

private extension Optional where Wrapped == UserInterfaceSizeClass {
    /// `true` when the size class is `.regular` (wider layout context).
    var isRegular: Bool { self == .regular }
}

// MARK: - Entry sorting helpers

private extension Entry {
    /// The list this entry belongs to, or `nil` if it is unassigned or not list-eligible.
    var assignedList: DataModel.List? {
        if let task = self as? DataModel.Task { return task.list }
        if let note = self as? DataModel.Note { return note.list }
        return nil
    }
}

private extension [any Entry] {
    /// Returns the entries sorted chronologically by their `sortDate`.
    func sortedByDate() -> [any Entry] {
        sorted { $0.sortDate < $1.sortDate }
    }
}
