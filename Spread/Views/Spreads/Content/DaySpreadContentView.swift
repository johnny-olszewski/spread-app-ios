import SwiftUI
import JohnnyOFoundationCore
import JohnnyOFoundationUI

/// Renders the entry list for a day spread, with optional inline spread creation and navigation.
///
/// Calendar events are ordinary entries in the list in both size classes — they flow through
/// the same grouping/sorting pipeline as tasks and notes, so timed work lines up
/// chronologically under Default sort. [SPRD-308]
///
/// In compact width the layout is a single scrollable entry list.
///
/// In regular width the layout is horizontal when events are present:
/// - Leading: a full-height card containing a `ScrollView` with a full-day `DayTimelineView`.
///   All-day events are pinned at the top of the card (outside the scroll). The timed grid
///   scrolls independently so the first event is visible on load.
/// - Trailing: `EntryListView` with its own independent scroll, complementing the timeline
///   card rather than replaced by it.
struct DaySpreadContentView: View {

    @State private var viewModel: ViewModel
    var config: Config = .default

    /// Stored for `Equatable` comparison without accessing `@State`.
    /// See `DaySpreadContentView+Equatable.swift`.
    let spreadID: UUID
    let storedHorizontalSizeClass: UserInterfaceSizeClass?

    @AppStorage("entryGrouping.day") private var groupingOption: EntryGroupingOption = .list
    @AppStorage("entrySorting.day") private var sortingOption: EntrySortOption = .default

    init(
        spread: DataModel.Spread,
        spreadDataModel: SpreadDataModel,
        context: SpreadPageContext,
        horizontalSizeClass: UserInterfaceSizeClass?,
        config: Config = .default
    ) {
        spreadID = spread.id
        storedHorizontalSizeClass = horizontalSizeClass
        _viewModel = State(wrappedValue: ViewModel(
            spread: spread,
            spreadDataModel: spreadDataModel,
            context: context,
            horizontalSizeClass: horizontalSizeClass
        ))
        self.config = config
    }

    // MARK: - Body

    var body: some View {
        VStack {
            HStack {
                Capsule()
                    .stroke(SpreadTheme.DotGrid.defaultDots)
                    .frame(height: SpreadTheme.CornerRadius.xxlarge)
                    .padding(.vertical, SpreadTheme.Spacing.large)
                    .padding(.trailing, SpreadTheme.Spacing.medium)

                HStack(spacing: SpreadTheme.Spacing.medium) {
                    EntryListOptionsPicker(
                        grouping: groupingOption,
                        sorting: sortingOption,
                        onGroupingSelected: { groupingOption = $0 },
                        onSortingSelected: { sortingOption = $0 }
                    )
                    .padding(SpreadTheme.Spacing.large)

                    SpreadButton(
                        icon: viewModel.spread.isFavorite ? .starFilled : .star,
                        style: .glass,
                        accessibilityIdentifier: Definitions.AccessibilityIdentifiers.SpreadToolbar.favoriteToggle
                    ) {
                        Task { await viewModel.toggleFavorite() }
                    }
                    .accessibilityLabel(viewModel.spread.isFavorite ? "Remove from Favorites" : "Add to Favorites")

                    SpreadButton(icon: .pencil, style: .glass) {
                        viewModel.context.coordinator.showSpreadNameEdit(viewModel.spread)
                    }
                    .accessibilityLabel("Edit Spread")
                    .padding(SpreadTheme.Spacing.large)
                }
            }
            .padding(.horizontal, SpreadTheme.Spacing.large)

            HStack(alignment: .top, spacing: SpreadTheme.Spacing.large) {
                if viewModel.shouldShowTimelineCard {
                    DayTimelineScrollView(
                        generator: SpreadDayTimelineContentGenerator(),
                        items: viewModel.calendarEvents,
                        date: viewModel.spread.date,
                        visibleStartHour: 0,
                        visibleEndHour: 24,
                        verticalCount: config.wideTimelineRowCount,
                        verticalSpan: config.wideTimelineRowSpan,
                        calendar: viewModel.context.journalManager.calendar
                    )
                    .containerRelativeFrame(
                        .horizontal,
                        count: config.wideTimelineColumnCount,
                        span: config.wideTimelineColumnSpan,
                        spacing: 0
                    )
                    .spreadCard()
                }

                VStack(spacing: SpreadTheme.Spacing.medium) {
                    EntryListView(
                        sections: viewModel.sections(groupedBy: groupingOption, orderedBy: sortingOption),
                        configurationMap: viewModel.listConfigurationMap,
                        emptyStateMessage: "Nothing planned for this day yet. Add a task or note with the + button."
                    ) { section in
                        // Section ids are list names only when grouping by list — other groupings
                        // (tag/status/none) have no notion of a corresponding list to preselect.
                        let sectionList = groupingOption == .list
                            ? viewModel.context.journalManager.lists.first { $0.name == section.id }
                            : nil
                        QuickAddButton(
                            coordinator: viewModel.context.coordinator,
                            anchorID: section.id,
                            date: viewModel.spread.date,
                            period: viewModel.spread.period,
                            availableLists: viewModel.context.journalManager.lists,
                            availableTags: viewModel.context.journalManager.tags,
                            preselectedList: sectionList,
                            accessibilityIdentifier: Definitions.AccessibilityIdentifiers.SpreadContent.addTaskButton,
                            onAddTask: viewModel.onAddTask
                        )
                    }

                    // Open tasks from the containing multiday/month/year spreads, in
                    // per-period cards below the day's own entries. A separate list keeps
                    // the day's entries and the broader-horizon context as distinct units
                    // with independent inputs (and its own empty behavior: absent, not an
                    // empty state). [SPRD-309]
                    let periodSections = viewModel.containingPeriodSections(orderedBy: sortingOption)
                    if !periodSections.isEmpty {
                        EntryListView(
                            sections: periodSections,
                            configurationMap: viewModel.listConfigurationMap
                        )
                    }
                }
            }
            .padding(.horizontal, SpreadTheme.Spacing.large)
            .task(id: viewModel.spread.id) {
                await viewModel.fetchCalendarEvents()
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
}
