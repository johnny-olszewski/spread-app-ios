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

        // MARK: - Containing-Period Context

        /// Card sections for the open tasks of each containing broader-period spread,
        /// rendered below the day's own entry list — nearest horizon first: every multiday
        /// spread whose range contains this day, then the containing month, then the year.
        /// Spreads that don't exist or have no open tasks produce no card. [SPRD-309]
        ///
        /// Month/year resolve through the O(1) dictionary-keyed `spreadDataModel(for:period:)`;
        /// containing multiday spreads through a single scan of `spreads` — no per-entry
        /// work happens until a spread actually matches.
        func containingPeriodSections(orderedBy sortingOption: EntrySortOption) -> [EntryList.Section] {
            let journalManager = context.journalManager
            let calendar = journalManager.calendar
            let day = spread.date

            var dataModels: [SpreadDataModel] = Self.containingMultidaySpreads(
                for: day,
                in: journalManager.spreads,
                calendar: calendar
            ).compactMap { journalManager.spreadDataModel(for: $0.date, period: .multiday) }

            for period in [Period.month, .year] {
                if let dataModel = journalManager.spreadDataModel(for: day, period: period) {
                    dataModels.append(dataModel)
                }
            }

            let formatter = SpreadDisplayNameFormatter(
                calendar: calendar,
                today: journalManager.today,
                firstWeekday: journalManager.firstWeekday
            )
            return Self.makeContainingPeriodSections(
                from: dataModels,
                orderedBy: sortingOption,
                displayName: { formatter.display(for: $0).primary }
            )
        }

        /// The multiday spreads whose date range contains `day`, earliest-starting first.
        /// Start/end are already day-normalized by spread construction; the range is
        /// inclusive of its end day. [SPRD-309]
        static func containingMultidaySpreads(
            for day: Date,
            in spreads: [DataModel.Spread],
            calendar: Calendar
        ) -> [DataModel.Spread] {
            let normalizedDay = day.startOfDay(calendar: calendar)
            return spreads
                .filter { candidate in
                    guard candidate.period == .multiday,
                          let start = candidate.startDate, let end = candidate.endDate else { return false }
                    return start <= normalizedDay && normalizedDay <= end
                }
                .sorted { ($0.startDate ?? $0.date) < ($1.startDate ?? $1.date) }
        }

        /// Builds one `SectionStyle.card` section per data model holding its **open** tasks
        /// **assigned to that data model's own period** (no notes, events, completed/migrated/
        /// cancelled tasks, and no finer-grained tasks that merely roll up into this period's
        /// data model), ordered by `sortingOption`, titled via `displayName`, preserving the
        /// caller's data-model order. Data models with no such tasks are omitted. [SPRD-309]
        ///
        /// The period filter matters because a broader-period `SpreadDataModel.tasks`
        /// aggregates sub-period tasks (e.g. a month model includes day-assigned tasks whose
        /// day spread isn't created) — mirrors `YearSpreadContentView`'s `period`-filtered
        /// top section. So the multiday card shows only multiday-assigned tasks, etc.
        static func makeContainingPeriodSections(
            from dataModels: [SpreadDataModel],
            orderedBy sortingOption: EntrySortOption,
            displayName: (DataModel.Spread) -> String
        ) -> [EntryList.Section] {
            dataModels.compactMap { dataModel in
                let openTasks: [any Entry] = dataModel.tasks.filter {
                    $0.status == .open && $0.period == dataModel.spread.period
                }
                guard !openTasks.isEmpty else { return nil }
                return EntryList.Section(
                    id: "period-context-\(dataModel.spread.id)",
                    title: displayName(dataModel.spread),
                    date: dataModel.spread.date,
                    entries: openTasks.sorted(by: sortingOption.areInOrder),
                    creationPeriod: dataModel.spread.period,
                    creationDate: dataModel.spread.date,
                    style: .card(SpreadTheme.Accent.primary)
                )
            }
        }
    }
}

// MARK: - UserInterfaceSizeClass

private extension Optional where Wrapped == UserInterfaceSizeClass {
    /// `true` when the size class is `.regular` (wider layout context).
    var isRegular: Bool { self == .regular }
}
