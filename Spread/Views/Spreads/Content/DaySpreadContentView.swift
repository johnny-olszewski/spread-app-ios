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
    var config: Config = .default

    @State private var calendarEventStore = CalendarEventStore()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var shouldShowTimelineCard: Bool {
        horizontalSizeClass.isRegular && !calendarEventStore.calendarEvents.isEmpty
    }

    // MARK: - Computed

    private var sections: [EntryList.Section] {
        let cal = context.calendar
        let base: [any Entry] = spreadDataModel.tasks + spreadDataModel.notes
        let eventEntries = calendarEventStore.calendarEvents.map { DataModel.Event(calendarEvent: $0) }

        return Self.makeSections(
            from: base + eventEntries,
            spreadDate: spreadDataModel.spread.date,
            calendar: cal
        )
    }

    private var configurationMap: [EntryType: EntryRowView.Configuration] {
        var map: [EntryType: EntryRowView.Configuration] = [
            .task: .standardTaskConfig(
                journalManager: context.journalManager,
                syncEngine: context.syncEngine,
                coordinator: context.coordinator
            ),
            .note: .standardNoteConfig(
                journalManager: context.journalManager,
                syncEngine: context.syncEngine,
                coordinator: context.coordinator
            )
        ]

        if !shouldShowTimelineCard {
            map[.event] = .standardEventConfig(journalManager: context.journalManager)
        }

        return map
    }

    private var onAddTask: (@MainActor (String, Date, Period) async throws -> Void) {
        let jm = context.journalManager
        let se = context.syncEngine
        return { @MainActor title, date, period in
            _ = try await jm.addTask(title: title, date: date, period: period)
            Task { @MainActor in await se?.syncNow() }
        }
    }

    // MARK: - Body

    var body: some View {
        Group {
            if shouldShowTimelineCard {
                regularLayout
            } else {
                compactLayout
            }
        }
        .task(id: spread.id) {
            await calendarEventStore.fetchCalendarEvents(
                spread: spread,
                service: context.eventKitService,
                calendar: context.journalManager.calendar
            )
        }
    }

    // MARK: - Layout variants

    /// Regular-width: full-height side-by-side layout with independent scrolls.
    ///
    /// Calendar events are surfaced in the timeline card only; the entry list
    /// receives an empty events array so it does not duplicate them.
    private var regularLayout: some View {
        HStack(alignment: .top, spacing: 0) {
            DayTimelineScrollView(
                generator: SpreadDayTimelineContentGenerator(),
                items: calendarEventStore.calendarEvents,
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
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .padding(.vertical, 12)

            entryList
        }
        .frame(maxHeight: .infinity)
    }

    /// Compact-width: a single scrollable entry list with calendar events in a dedicated section.
    private var compactLayout: some View {
        entryList
    }

    private var entryList: some View {
        EntryListView(
            sections: sections,
            configurationMap: configurationMap,
            onAddTask: onAddTask
        )
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
        var listCriteria: [UUID: DataModel.List] = [:]

        for entry in entries {
            if let task = entry as? DataModel.Task {
                let listID = task.list?.id
                listGroups[listID, default: []].append(entry)
                if let list = task.list { listCriteria[list.id] = list }
            } else {
                listGroups[nil, default: []].append(entry)
            }
        }

        var sections: [EntryList.Section] = []

        let sortedListIDs = listCriteria.keys.sorted {
            listCriteria[$0]!.sectionTitle < listCriteria[$1]!.sectionTitle
        }
        for listID in sortedListIDs {
            sections.append(EntryList.Section(
                id: listID.uuidString,
                criteria: listCriteria[listID],
                date: spreadDate,
                entries: sorted(listGroups[listID] ?? []),
                creationPeriod: .day,
                creationDate: spreadDate
            ))
        }

        if let noListEntries = listGroups[nil], !noListEntries.isEmpty {
            sections.append(EntryList.Section(
                id: sectionID,
                criteria: nil,
                date: spreadDate,
                entries: sorted(noListEntries),
                creationPeriod: .day,
                creationDate: spreadDate
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
