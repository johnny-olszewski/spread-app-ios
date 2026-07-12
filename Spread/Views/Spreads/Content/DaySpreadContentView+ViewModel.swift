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


        /// Groups and orders the spread's regular (non-overdue) entries per the caller's
        /// current `EntryGroupingOption`/`EntrySortOption` picker selection.
        func sections(groupedBy groupingOption: EntryGroupingOption, orderedBy sortingOption: EntrySortOption) -> [EntryList.Section] {
            let live = context.journalManager.spreadDataModel(for: spread.date, period: spread.period) ?? spreadDataModel
            let base: [any Entry] = live.tasks + live.notes
            let eventEntries = calendarEvents.map { DataModel.Event(calendarEvent: $0) }

            return Self.makeSections(
                from: base + eventEntries,
                spreadDate: spread.date,
                groupingOption: groupingOption,
                sortingOption: sortingOption,
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

        /// The view-level configuration map passed to `EntryListView`, covering every type
        /// a section can contain. Time-sorted sections mix tasks/notes/events in one bucket
        /// and rely on this fallback (their sections carry no per-section map); grouped
        /// sections never contain events, so the extra event key is inert there. [SPRD-301]
        var listConfigurationMap: EntryRowView.ConfigurationMap {
            entryConfigurationMap.merging(eventConfigurationMap) { _, event in event }
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

        /// Groups/orders the spread's non-event entries per `groupingOption`/`sortingOption`,
        /// with calendar events always appearing last in their own fixed, ungrouped "Events"
        /// section — events have no list/tag/status assignment, so they sit outside the
        /// user-selectable grouping entirely, the same way overdue items sit outside it.
        ///
        /// `.time` sorting takes a different shape entirely: the fixed "Events" section
        /// dissolves and timed entries of every type interleave chronologically, with
        /// untimed entries in one "No time" section below — see `makeTimeSortedSections`.
        static func makeSections(
            from entries: [any Entry],
            spreadDate: Date,
            groupingOption: EntryGroupingOption,
            sortingOption: EntrySortOption,
            eventConfigurationMap: EntryRowView.ConfigurationMap
        ) -> [EntryList.Section] {
            guard !entries.isEmpty else { return [] }

            if sortingOption == .time {
                return makeTimeSortedSections(from: entries, spreadDate: spreadDate)
            }

            var regularEntries: [any Entry] = []
            var eventEntries: [any Entry] = []
            for entry in entries {
                if entry.entryType == .event {
                    eventEntries.append(entry)
                } else {
                    regularEntries.append(entry)
                }
            }

            var sections = EntryList.Section.grouped(
                from: regularEntries,
                by: groupingOption.grouping(date: spreadDate, creationPeriod: .day, creationDate: spreadDate),
                orderedBy: sortingOption.areInOrder
            )

            if !eventEntries.isEmpty {
                sections.append(EntryList.Section(
                    id: "\(spreadDate.timeIntervalSinceReferenceDate)-events",
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

        /// Builds the `.time`-sorted shape: one headerless chronological section of all
        /// timed entries (tasks by `scheduledTime`, `.timed` events by start time,
        /// interleaved — absolute instants, so the order is timezone-invariant), then one
        /// "No time" section (`.unnamed` style, per the SPRD-287 nil-bucket convention)
        /// holding everything untimed, ordered chronologically by `sortDate` with a title
        /// tiebreak. Sections carry no per-section configuration map — they mix entry
        /// types, so rows resolve through the view-level `listConfigurationMap`. [SPRD-301]
        static func makeTimeSortedSections(
            from entries: [any Entry],
            spreadDate: Date
        ) -> [EntryList.Section] {
            var timedEntries: [any Entry] = []
            var untimedEntries: [any Entry] = []
            for entry in entries {
                if entry.scheduledStart != nil {
                    timedEntries.append(entry)
                } else {
                    untimedEntries.append(entry)
                }
            }

            var sections: [EntryList.Section] = []
            if !timedEntries.isEmpty {
                sections.append(EntryList.Section(
                    id: "\(spreadDate.timeIntervalSinceReferenceDate)-timed",
                    title: "",
                    date: spreadDate,
                    entries: EntrySortOption.time.areInOrder.map { timedEntries.sorted(by: $0) } ?? timedEntries,
                    creationPeriod: .day,
                    creationDate: spreadDate
                ))
            }
            if !untimedEntries.isEmpty {
                sections.append(EntryList.Section(
                    id: "\(spreadDate.timeIntervalSinceReferenceDate)-untimed",
                    title: "No time",
                    date: spreadDate,
                    entries: EntrySortOption.dueDate.areInOrder.map { untimedEntries.sorted(by: $0) } ?? untimedEntries,
                    creationPeriod: .day,
                    creationDate: spreadDate,
                    headerStyle: .unnamed
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

private extension [any Entry] {
    /// Returns the entries sorted chronologically by their `sortDate`.
    func sortedByDate() -> [any Entry] {
        sorted { $0.sortDate < $1.sortDate }
    }
}
