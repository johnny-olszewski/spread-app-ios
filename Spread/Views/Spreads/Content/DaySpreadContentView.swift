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

    @State private var viewModel: ViewModel
    @Environment(SpreadsCoordinator.self) private var coordinator
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let config: Config

    private var autoMigrationFeedback: SpreadAutoMigrationFeedback? {
        guard let feedback = coordinator.autoMigrationFeedback,
              feedback.surfaceSpreadID == viewModel.spread.id,
              feedback.anchor == .spreadHeader else {
            return nil
        }
        return feedback
    }

    private var shouldShowTimelineCard: Bool {
        horizontalSizeClass.isRegular && !viewModel.calendarEvents.isEmpty
    }

    init(
        spread: DataModel.Spread,
        journalManager: JournalManager,
        syncEngine: SyncEngine?,
        groupsByList: Bool = true,
        eventKitService: (any EventKitService)?,
        onEditTask: @escaping (DataModel.Task) -> Void,
        onEditNote: @escaping (DataModel.Note) -> Void,
        config: Config = .default
    ) {
        self.config = config
        _viewModel = State(wrappedValue: ViewModel(
            spread: spread,
            journalManager: journalManager,
            syncEngine: syncEngine,
            groupsByList: groupsByList,
            eventKitService: eventKitService,
            onEditTask: onEditTask,
            onEditNote: onEditNote
        ))
    }


    // MARK: - Body

    var body: some View {
        Group {
            if viewModel.spreadDataModel != nil {
                if shouldShowTimelineCard {
                    regularLayout
                } else {
                    compactLayout
                }
            } else {
                ContentUnavailableView {
                    Label("No Data", systemImage: "tray")
                } description: {
                    Text("Unable to load spread data.")
                }
            }
        }
        .onChange(of: viewModel.calendarEvents) { _, _ in
            viewModel.refreshSections(showsTimelineCard: shouldShowTimelineCard)
        }
        .onChange(of: shouldShowTimelineCard) { _, _ in
            viewModel.refreshSections(showsTimelineCard: shouldShowTimelineCard)
        }
        .onChange(of: viewModel.spreadDataModel?.tasks.count ?? 0) { _, _ in
            viewModel.refreshSections(showsTimelineCard: shouldShowTimelineCard)
        }
        .onChange(of: viewModel.spreadDataModel?.notes.count ?? 0) { _, _ in
            viewModel.refreshSections(showsTimelineCard: shouldShowTimelineCard)
        }
    }

    // MARK: - Layout variants

    /// Regular-width: full-height side-by-side layout with independent scrolls.
    ///
    /// Calendar events are surfaced in the timeline card only; the entry list
    /// receives an empty events array so it does not duplicate them.
    private var regularLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let message = autoMigrationFeedback?.message {
                SpreadAutoMigrationCueView(message: message)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }

            HStack(alignment: .top, spacing: 0) {
                timelineCard
                EntryListView(
                    sections: viewModel.sections,
                    configurationMap: viewModel.configurationMap,
                    onAddTask: viewModel.onAddTask
                )
            }
            .frame(maxHeight: .infinity)
        }
    }

    /// Compact-width: a single scrollable entry list with calendar events in a dedicated section.
    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let message = autoMigrationFeedback?.message {
                SpreadAutoMigrationCueView(message: message)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }

            EntryListView(
                sections: viewModel.sections,
                configurationMap: viewModel.configurationMap,
                onAddTask: viewModel.onAddTask
            )
        }
    }

    // MARK: - Timeline card

    /// Full-height card for the wide layout. Scroll management, all-day section,
    /// and height sizing are all handled by `DayTimelineScrollView`.
    private var timelineCard: some View {
        return DayTimelineScrollView(
            generator: SpreadDayTimelineContentGenerator(),
            items: viewModel.calendarEvents,
            date: viewModel.spread.date,
            visibleStartHour: 0,
            visibleEndHour: 24,
            verticalCount: config.wideTimelineRowCount,
            verticalSpan: config.wideTimelineRowSpan,
            calendar: viewModel.calendar
        )
        .containerRelativeFrame(.horizontal, count: config.wideTimelineColumnCount, span: config.wideTimelineColumnSpan, spacing: 0)
        .spreadCard()
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 12)
    }
}

// MARK: - UserInterfaceSizeClass

private extension Optional where Wrapped == UserInterfaceSizeClass {
    /// `true` when the size class is `.regular` (wider layout context).
    var isRegular: Bool { self == .regular }
}
