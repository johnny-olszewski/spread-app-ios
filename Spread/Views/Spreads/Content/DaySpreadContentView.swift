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
    let syncEngine: SyncEngine?
    var config: Config = .default

    @State private var viewModel = ViewModel()
    @Environment(JournalManager.self) private var journalManager
    @Environment(SpreadsCoordinator.self) private var coordinator
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.eventKitService) private var eventKitService

    private var shouldShowTimelineCard: Bool {
        horizontalSizeClass.isRegular && !viewModel.calendarEvents.isEmpty
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
            viewModel.configure(
                spread: spread,
                spreadDataModel: spreadDataModel,
                journalManager: journalManager,
                syncEngine: syncEngine,
                coordinator: coordinator
            )
            await viewModel.fetchCalendarEvents(spread: spread, service: eventKitService, journalManager: journalManager)
        }
        .onChange(of: journalManager.dataVersion) { _, _ in
            viewModel.refreshSections(
                spread: spread,
                dataModel: spreadDataModel,
                journalManager: journalManager,
                showsTimelineCard: shouldShowTimelineCard
            )
        }
        .onChange(of: viewModel.calendarEvents) { _, _ in
            viewModel.refreshSections(
                spread: spread,
                dataModel: spreadDataModel,
                journalManager: journalManager,
                showsTimelineCard: shouldShowTimelineCard
            )
        }
        .onChange(of: shouldShowTimelineCard) { _, _ in
            viewModel.refreshSections(
                spread: spread,
                dataModel: spreadDataModel,
                journalManager: journalManager,
                showsTimelineCard: shouldShowTimelineCard
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
                    items: viewModel.calendarEvents,
                    date: spread.date,
                    visibleStartHour: 0,
                    visibleEndHour: 24,
                    verticalCount: config.wideTimelineRowCount,
                    verticalSpan: config.wideTimelineRowSpan,
                    calendar: journalManager.calendar
                )
                .containerRelativeFrame(.horizontal, count: config.wideTimelineColumnCount, span: config.wideTimelineColumnSpan, spacing: 0)
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
            sections: viewModel.sections,
            configurationMap: viewModel.configurationMap,
            onAddTask: viewModel.onAddTask
        )
    }

}

// MARK: - UserInterfaceSizeClass

private extension Optional where Wrapped == UserInterfaceSizeClass {
    /// `true` when the size class is `.regular` (wider layout context).
    var isRegular: Bool { self == .regular }
}
