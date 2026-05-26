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
        let base = EntryListDisplaySupport.displayedEntries(for: spreadDataModel, calendar: cal)
        let eventEntries: [DataModel.Event] = shouldShowTimelineCard
            ? []
            : calendarEventStore.calendarEvents.map { DataModel.Event(calendarEvent: $0) }
        return Self.makeSections(
            from: base + eventEntries,
            spreadDate: spreadDataModel.spread.date,
            calendar: cal,
            groupsByList: context.journalManager.bujoMode == .conventional
        )
    }

    private var configurationMap: [EntryType: EntryRowView.Configuration] {
        [
            .task: .standardTaskConfig(
                journalManager: context.journalManager,
                syncEngine: context.syncEngine,
                coordinator: context.coordinator
            ),
            .note: .standardNoteConfig(
                journalManager: context.journalManager,
                syncEngine: context.syncEngine,
                coordinator: context.coordinator
            ),
            .event: .standardEventConfig(journalManager: context.journalManager)
        ]
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

// MARK: - UserInterfaceSizeClass

private extension Optional where Wrapped == UserInterfaceSizeClass {
    /// `true` when the size class is `.regular` (wider layout context).
    var isRegular: Bool { self == .regular }
}
