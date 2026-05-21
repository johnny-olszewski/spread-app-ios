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
    let config: Config
    @State private var vm: ViewModel

    init(
        spread: DataModel.Spread,
        journalManager: JournalManager,
        syncEngine: SyncEngine?,
        entryListConfiguration: EntryListConfiguration = .init(),
        eventKitService: (any EventKitService)?,
        onEditTask: @escaping (DataModel.Task) -> Void,
        onEditNote: @escaping (DataModel.Note) -> Void,
        config: Config = .default
    ) {
        self.config = config
        _vm = State(wrappedValue: ViewModel(
            spread: spread,
            journalManager: journalManager,
            syncEngine: syncEngine,
            entryListConfiguration: entryListConfiguration,
            eventKitService: eventKitService,
            onEditTask: onEditTask,
            onEditNote: onEditNote
        ))
    }

    @Environment(SpreadsCoordinator.self) private var coordinator
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Tracks the scroll position of the timeline card so we can programmatically
    /// jump to the first event on load.
    @State private var timelineScrollPosition = ScrollPosition()

    // MARK: - Derived

    private var autoMigrationFeedback: SpreadAutoMigrationFeedback? {
        guard let feedback = coordinator.autoMigrationFeedback,
              feedback.surfaceSpreadID == vm.spread.id,
              feedback.anchor == .spreadHeader else {
            return nil
        }
        return feedback
    }

    private var shouldShowTimelineCard: Bool {
        horizontalSizeClass.isRegular && !vm.calendarEvents.isEmpty
    }

    // MARK: - Body

    var body: some View {
        Group {
            if vm.spreadDataModel != nil {
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
        .onChange(of: vm.calendarEvents) { _, _ in
            vm.refreshSections(showsTimelineCard: shouldShowTimelineCard)
        }
        .onChange(of: shouldShowTimelineCard) { _, _ in
            vm.refreshSections(showsTimelineCard: shouldShowTimelineCard)
        }
        .onChange(of: vm.spreadDataModel?.tasks.count ?? 0) { _, _ in
            vm.refreshSections(showsTimelineCard: shouldShowTimelineCard)
        }
        .onChange(of: vm.spreadDataModel?.notes.count ?? 0) { _, _ in
            vm.refreshSections(showsTimelineCard: shouldShowTimelineCard)
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
                EntryListView(viewModel: vm.entryListViewModel)
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

            EntryListView(viewModel: vm.entryListViewModel)
        }
    }

    // MARK: - Timeline card

    /// Full-height card for the wide layout.
    ///
    /// Structure (top to bottom):
    /// 1. All-day events header — non-scrolling, pinned above the timed grid.
    /// 2. Divider — only present when all-day events exist.
    /// 3. Timed event grid — full-day `DayTimelineView` inside a `ScrollView`.
    ///    On load the scroll position jumps to the start of the first timed event.
    private var timelineCard: some View {
        let provider = SpreadDayTimelineProvider()

        return VStack(spacing: 0) {
            if !vm.allDayEvents.isEmpty {
                DayTimelineAllDaySection(items: vm.allDayEvents) { event in
                    provider.allDayItemView(item: event)
                }
                Divider()
            }

            ScrollView {
                DayTimelineView(
                    provider: provider,
                    items: vm.calendarEvents,
                    date: vm.spread.date,
                    visibleStartHour: 0,
                    visibleEndHour: 24,
                    height: config.wideTimelineHeight,
                    calendar: vm.calendar
                )
                .scrollIndicators(.hidden)
                .padding(8)
            }
            .scrollPosition($timelineScrollPosition)
            .onChange(of: vm.calendarEvents.count) { _, _ in
                scrollToFirstEvent()
            }
        }
        .containerRelativeFrame(.horizontal, count: config.wideTimelineColumnCount, span: config.wideTimelineColumnSpan, spacing: 0)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color(uiColor: .separator).opacity(0.5), lineWidth: 0.5)
        )
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 12)
    }

    // MARK: - Private

    /// Scrolls the timeline card so the first timed event's start time is near the
    /// top of the visible area. No-ops when there are no timed events.
    private func scrollToFirstEvent() {
        guard let firstEvent = vm.timedEvents.min(by: { $0.startDate < $1.startDate }) else { return }

        let cal = vm.calendar
        let startOfDay = vm.spread.date.startOfDay(calendar: cal)
        guard let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        let coordinateSpace = DayTimeCoordinateSpace(
            visibleStart: startOfDay,
            visibleEnd: endOfDay,
            totalHeight: config.wideTimelineHeight
        )
        // +8 for the padding around the DayTimelineView inside the ScrollView
        let targetY = coordinateSpace.yOffset(for: firstEvent.startDate) + 8
        timelineScrollPosition = ScrollPosition(y: targetY)
    }
}

// MARK: - UserInterfaceSizeClass

private extension Optional where Wrapped == UserInterfaceSizeClass {
    /// `true` when the size class is `.regular` (wider layout context).
    var isRegular: Bool { self == .regular }
}
