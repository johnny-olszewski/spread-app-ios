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
                sortingOption: sortingOption
            )
        }

        /// The view-level configuration map passed to `EntryListView`, covering every type
        /// any section can contain. Events flow through the same grouping pipeline as tasks
        /// and notes in both size classes, so their configuration is always present — the
        /// regular-width timeline card complements the list rather than replacing event
        /// rows. [SPRD-308]
        var listConfigurationMap: EntryRowView.ConfigurationMap {
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

        /// Groups/orders every entry — tasks, notes, and calendar events — per
        /// `groupingOption`/`sortingOption`, with no special casing by type: events land in
        /// the "No list"/"No tag" bucket under list/tag grouping, their own bucket under
        /// status/type grouping, and interleave chronologically with timed tasks under
        /// Default sort. [SPRD-308]
        static func makeSections(
            from entries: [any Entry],
            spreadDate: Date,
            groupingOption: EntryGroupingOption,
            sortingOption: EntrySortOption
        ) -> [EntryList.Section] {
            guard !entries.isEmpty else { return [] }

            return EntryList.Section.grouped(
                from: entries,
                by: groupingOption.grouping(date: spreadDate, creationPeriod: .day, creationDate: spreadDate),
                orderedBy: sortingOption.areInOrder
            )
        }
    }
}

// MARK: - UserInterfaceSizeClass

private extension Optional where Wrapped == UserInterfaceSizeClass {
    /// `true` when the size class is `.regular` (wider layout context).
    var isRegular: Bool { self == .regular }
}
