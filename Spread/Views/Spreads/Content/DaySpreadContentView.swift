import SwiftUI
import JohnnyOFoundationCore
import JohnnyOFoundationUI

/// Renders the entry list for a day spread, with optional inline spread creation and navigation.
///
/// In compact width the layout is a single scrollable entry list. Calendar events appear
/// in a dedicated section within the list.
///
/// In regular width the layout is horizontal when events are present:
/// - Leading: a full-height card containing a `ScrollView` with a full-day `DayTimelineView`.
///   All-day events are pinned at the top of the card (outside the scroll). The timed grid
///   scrolls independently so the first event is visible on load.
/// - Trailing: `EntryListView` with its own independent scroll. Calendar events are omitted
///   from the list because the timeline card already surfaces them.
struct DaySpreadContentView: View {

    let spread: DataModel.Spread
    let spreadDataModel: SpreadDataModel
    let context: SpreadPageContext
    let horizontalSizeClass: UserInterfaceSizeClass?
    var config: Config = .default

    @State private var calendarEvents: [CalendarEvent] = []

    private var shouldShowTimelineCard: Bool {
        horizontalSizeClass.isRegular && !calendarEvents.isEmpty
    }

    // MARK: - Computed

    /// Card-styled sections for overdue tasks, shown above the standard entry list.
    ///
    /// Only populated when the spread represents today and there are overdue items.
    /// Each distinct source spread (or Inbox) produces one card section.
    private var overdueSections: [EntryList.Section] {
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

    private var sections: [EntryList.Section] {
        let cal = context.calendar
        let base: [any Entry] = spreadDataModel.tasks + spreadDataModel.notes
        let eventEntries = calendarEvents.map { DataModel.Event(calendarEvent: $0) }

        return DaySpreadContentView.makeSections(
            from: base + eventEntries,
            spreadDate: spreadDataModel.spread.date,
            calendar: cal,
            listConfigurationMap: entryConfigurationMap,
            unassignedConfigurationMap: entryConfigurationMap,
            eventConfigurationMap: eventConfigurationMap,
            headerButtonViewModel: addTaskHeaderButtonViewModel
        )
    }

    private var entryConfigurationMap: EntryRowView.ConfigurationMap {
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

    private var eventConfigurationMap: EntryRowView.ConfigurationMap {
        shouldShowTimelineCard
            ? [:]
            : [DataModel.Event.configurationKey: .standardEventConfig(journalManager: context.journalManager)]
    }

    private var onAddTask: (@MainActor (String, Date, Period, DataModel.List?, DataModel.Tag?) async throws -> Void) {
        let jm = context.journalManager
        let se = context.syncEngine
        return { @MainActor title, date, period, list, tag in
            _ = try await jm.addTask(title: title, date: date, period: period, list: list, tag: tag)
            Task { @MainActor in await se?.syncNow() }
        }
    }

    private var addTaskHeaderButtonViewModel: SpreadButton.ViewModel {
        SpreadButton.ViewModel(
            title: "Add Task",
            systemImage: "plus",
            accessibilityIdentifier: Definitions.AccessibilityIdentifiers.SpreadContent.addTaskButton
        ) {
            context.coordinator.showTaskCreation()
        }
    }

    // MARK: - Body

    var body: some View {
        VStack {
            HStack {
                Capsule()
                    .stroke(SpreadTheme.DotGrid.defaultDots)
                    .frame(height: SpreadTheme.CornerRadius.xxlarge)
                    .padding(.leading, SpreadTheme.Spacing.large)
                    .padding(.vertical, SpreadTheme.Spacing.large)
                    .padding(.trailing, SpreadTheme.Spacing.medium)

                HStack(spacing: SpreadTheme.Spacing.medium) {
                    Button {
                        toggleFavorite()
                    } label: {
                        Image(systemName: spread.isFavorite ? "star.fill" : "star")
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .accessibilityLabel(spread.isFavorite ? "Remove from Favorites" : "Add to Favorites")
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadToolbar.favoriteToggle)

                    Button {
                        context.coordinator.showSpreadNameEdit(spread)
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Edit Spread")
                    .padding(SpreadTheme.Spacing.large)
                }
            }
            
            HStack(alignment: .top, spacing: SpreadTheme.Spacing.large) {
                if shouldShowTimelineCard {
                    DayTimelineScrollView(
                        generator: SpreadDayTimelineContentGenerator(),
                        items: calendarEvents,
                        date: spread.date,
                        visibleStartHour: 0,
                        visibleEndHour: 24,
                        verticalCount: config.wideTimelineRowCount,
                        verticalSpan: config.wideTimelineRowSpan,
                        calendar: context.journalManager.calendar
                    )
                    .containerRelativeFrame(
                        .horizontal,
                        count: config.wideTimelineColumnCount,
                        span: config.wideTimelineColumnSpan,
                        spacing: 0
                    )
                    .spreadCard()
                }

                EntryListView(
                    sections: overdueSections + sections,
                    configurationMap: entryConfigurationMap,
                    onAddTask: onAddTask,
                    availableLists: context.journalManager.lists,
                    availableTags: context.journalManager.tags
                )
            }
            .padding(.horizontal, SpreadTheme.Spacing.large)
            .task(id: spread.id) {
                calendarEvents = await context.calendarEventService.fetchEvents(
                    for: spread,
                    calendar: context.journalManager.calendar
                )
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func toggleFavorite() {
        Task { @MainActor in
            try? await context.journalManager.updateSpreadFavorite(spread, isFavorite: !spread.isFavorite)
            await context.syncEngine?.syncNow()
        }
    }
}

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

    // MARK: - Section Grouping

    /// Groups day spread entries into named-list sections (alphabetical),
    /// with a trailing untitled section for entries with no list.
    static func makeSections(
        from entries: [any Entry],
        spreadDate: Date,
        calendar: Calendar,
        listConfigurationMap: EntryRowView.ConfigurationMap,
        unassignedConfigurationMap: EntryRowView.ConfigurationMap,
        eventConfigurationMap: EntryRowView.ConfigurationMap,
        headerButtonViewModel: SpreadButton.ViewModel? = nil
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
                configurationMap: listConfigurationMap,
                headerButtonViewModel: headerButtonViewModel
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
                    configurationMap: unassignedConfigurationMap,
                    headerButtonViewModel: headerButtonViewModel
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

// MARK: - UserInterfaceSizeClass

private extension Optional where Wrapped == UserInterfaceSizeClass {
    /// `true` when the size class is `.regular` (wider layout context).
    var isRegular: Bool { self == .regular }
}

// MARK: - Entry sorting helpers

private extension Entry {
    /// The date used to chronologically order this entry within a section.
    var sortDate: Date {
        switch entryType {
        case .task:  return (self as? DataModel.Task)?.date ?? .now
        case .event: return (self as? DataModel.Event)?.startDate ?? .now
        case .note:  return (self as? DataModel.Note)?.date ?? .now
        }
    }

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
