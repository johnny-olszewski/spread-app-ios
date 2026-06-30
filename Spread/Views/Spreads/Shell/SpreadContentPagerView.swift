import SwiftUI

/// Horizontally pages through spread content, assembling each page as a header and period-appropriate content view.
///
/// `spreads`, `currentSelection`, and the `calendar`/`today`/`firstWeekday` triple are passed in
/// from `SpreadsTabView` so `spreadDetailTitle` does not observe `JournalManager` directly.
/// Scroll-driven re-renders (from `scrollPhase` and `settledSpreadID` state changes) therefore
/// only perform cheap lookups against already-computed values for the title — the year-spreads
/// filtering stays in the parent. `journalManager` is still read directly by `spreadDataModel(for:)`,
/// called from `body` via `contentView(for:)` — see that method's doc comment for how its cost is bounded.
struct SpreadContentPagerView: View {
    private let backgroundShape = UnevenRoundedRectangle(topLeadingRadius: SpreadTheme.CornerRadius.xxlarge, topTrailingRadius: SpreadTheme.CornerRadius.xxlarge)

    let coordinator: SpreadsCoordinator
    let syncEngine: SyncEngine?
    /// Pre-computed by the parent so this view does not observe JournalManager during scrolling.
    let spreads: [DataModel.Spread]
    /// Pre-computed by the parent so this view does not observe JournalManager during scrolling.
    let currentSelection: DataModel.Spread
    /// Pre-computed by the parent so `spreadDetailTitle` does not observe JournalManager during scrolling.
    let calendar: Calendar
    /// Pre-computed by the parent so `spreadDetailTitle` does not observe JournalManager during scrolling.
    let today: Date
    /// Pre-computed by the parent so `spreadDetailTitle` does not observe JournalManager during scrolling.
    let firstWeekday: FirstWeekday
    /// Seeded from `currentSelection.id` at construction (not just `.onAppear`) so the very
    /// first render's `spreadDataModel(for:)` window is already centered on the selected
    /// spread, rather than briefly showing the "No Data" placeholder before `.onAppear` runs.
    @State private var settledSpreadID: UUID?

    /// Accessed in `body` only by `spreadDataModel(for:)`, scoped to the windowed set of spreads
    /// near `settledSpreadID` (see `Constants.spreadDataModelWindowRadius`). `spreadDetailTitle`
    /// does not read this — see the `calendar`/`today`/`firstWeekday` properties above.
    @Environment(JournalManager.self) private var journalManager
    @Environment(\.eventKitService) private var eventKitService
    @Environment(\.calendarEventService) private var calendarEventService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var scrollPhase: ScrollPhase = .idle

    // MARK: - Init

    init(
        coordinator: SpreadsCoordinator,
        syncEngine: SyncEngine?,
        spreads: [DataModel.Spread],
        currentSelection: DataModel.Spread,
        calendar: Calendar,
        today: Date,
        firstWeekday: FirstWeekday
    ) {
        self.coordinator = coordinator
        self.syncEngine = syncEngine
        self.spreads = spreads
        self.currentSelection = currentSelection
        self.calendar = calendar
        self.today = today
        self.firstWeekday = firstWeekday
        _settledSpreadID = State(initialValue: currentSelection.id)
    }

    // MARK: - Pager State

    /// `DataModel.Spread.id` is used directly for pager identity — both the `ForEach`'s `.id()` and
    /// `settledSpreadID` are `UUID`. There is no need for a separate string-based "stable ID"; the
    /// model's own identity is already stable and unique.
    private var selectedSpreadID: UUID {
        currentSelection.id
    }

    var body: some View {
        VStack(spacing: 0) {
            spreadDetailTitle

            if isSyncError { SyncErrorBanner() }

            pager
        }
    }

    private var pager: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(spreads) { spread in
                    let isCurrentPage = spread.id == coordinator.selectedSpread?.id
                    let navState = isCurrentPage ? coordinator.convenienceNavigation : nil
                    VStack(spacing: 0) {
                        SpreadHeaderView(
                            state: navState,
                            onTap: navState != nil ? { coordinator.handleConvenienceNavButtonTapped() } : nil
                        )
                        contentView(for: spread)
                    }
                    .containerRelativeFrame(.horizontal)
                    .id(spread.id)
                    .background {
                        self.backgroundShape
                            .fill(.background.opacity(0.6))
                    }
                    .clipShape(self.backgroundShape)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $settledSpreadID)
        .onAppear {
            settledSpreadID = selectedSpreadID
        }
        // Recenter whenever the externally-driven selection changes (e.g. tab/title navigation).
        .onChange(of: selectedSpreadID) { _, newValue in
            guard newValue != settledSpreadID else { return }
            center(on: newValue, animated: false)
        }
        .onChange(of: coordinator.recenterToken) { _, _ in
            center(on: selectedSpreadID, animated: false)
        }
        // These two handlers cover the two possible orderings of "settled ID changed" vs.
        // "scroll phase became idle" — see `syncSelectionFromSettledID` for why both are needed.
        .onChange(of: settledSpreadID) { _, _ in
            syncSelectionFromSettledID()
        }
        .onScrollPhaseChange { _, newPhase in
            scrollPhase = newPhase
            syncSelectionFromSettledID()
        }
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadContent.pager)
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Detail Title

    private var spreadDetailTitle: some View {
        let config = SpreadHeaderConfiguration(
            spread: currentSelection,
            calendar: calendar,
            today: today,
            firstWeekday: firstWeekday,
            allowsPersonalization: true
        )
        return VStack(spacing: 2) {
            Text(config.title)
                .font(SpreadTheme.Typography.largeTitle(size: 17, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            if let subtitle = config.subtitle {
                Text(subtitle)
                    .font(SpreadTheme.Typography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private var isSyncError: Bool {
        guard let status = syncEngine?.status else { return false }
        if case .error = status { return true }
        return false
    }

    /// Pushes the pager's settled position back to the coordinator once scrolling is idle,
    /// so the rest of the app reflects whatever page the user landed on.
    ///
    /// Called from two places because SwiftUI does not guarantee which happens first:
    /// - `settledSpreadID` changing while `scrollPhase` is already `.idle` (e.g. the binding
    ///   update arrives after the phase already settled), and
    /// - `scrollPhase` becoming `.idle` after `settledSpreadID` already changed mid-drag.
    /// Both call this same check; the `scrollPhase == .idle` guard makes mid-scroll updates a no-op.
    private func syncSelectionFromSettledID() {
        guard scrollPhase == .idle,
              let settledSpreadID, settledSpreadID != selectedSpreadID,
              let spread = spreads.first(where: { $0.id == settledSpreadID }) else { return }
        coordinator.selectedSpread = spread
        coordinator.clearConvenienceNavigation()
    }

    private func center(on id: UUID, animated: Bool) {
        guard settledSpreadID != id else { return }
        if animated {
            withAnimation(.easeInOut(duration: 0.38)) {
                settledSpreadID = id
            }
        } else {
            settledSpreadID = id
        }
    }

    // MARK: - Page Content

    private var context: SpreadPageContext {
        SpreadPageContext(
            journalManager: journalManager,
            coordinator: coordinator,
            syncEngine: syncEngine,
            eventKitService: eventKitService,
            calendarEventService: calendarEventService
        )
    }

    /// How many pages on either side of `settledSpreadID` get a computed `SpreadDataModel`.
    /// Tune this in one place if the window needs to widen (e.g. for faster multi-page flicks)
    /// or narrow further.
    private enum Constants {
        static let spreadDataModelWindowRadius = 1
    }

    @ViewBuilder
    private func contentView(for spread: DataModel.Spread) -> some View {
        if let dataModel = spreadDataModel(for: spread) {
            switch spread.period {
            case .year:
                YearSpreadContentView(spread: spread, spreadDataModel: dataModel, context: context)
            case .month:
                MonthSpreadContentView(spread: spread, spreadDataModel: dataModel, context: context)
            case .day:
                DaySpreadContentView(
                    spread: spread,
                    spreadDataModel: dataModel,
                    context: context,
                    horizontalSizeClass: horizontalSizeClass
                )
            case .multiday:
                MultidaySpreadContentView(
                    spread: spread,
                    spreadDataModel: dataModel,
                    context: context,
                    horizontalSizeClass: horizontalSizeClass
                )
            }
        } else {
            ContentUnavailableView {
                Label {
                    Text("No Data")
                } icon: {
                    SpreadTheme.Icon.tray.sized(SpreadTheme.IconSize.large)
                }
            } description: {
                Text("Unable to load spread data.")
            }
        }
    }

    /// Whether `spread` falls within `Constants.spreadDataModelWindowRadius` pages of
    /// `settledSpreadID` in `spreads`. Spreads outside the window skip the `JournalManager`
    /// dictionary lookup entirely and render the "No Data" placeholder until the window moves
    /// to include them, bounding per-render work to a small constant regardless of how many
    /// spreads are loaded into the pager.
    static func isWithinDataModelWindow(
        spread: DataModel.Spread,
        spreads: [DataModel.Spread],
        settledSpreadID: UUID?,
        radius: Int
    ) -> Bool {
        guard let settledSpreadID,
              let settledIndex = spreads.firstIndex(where: { $0.id == settledSpreadID }),
              let index = spreads.firstIndex(where: { $0.id == spread.id }) else { return false }
        return abs(index - settledIndex) <= radius
    }

    private func spreadDataModel(for spread: DataModel.Spread) -> SpreadDataModel? {
        guard Self.isWithinDataModelWindow(
            spread: spread,
            spreads: spreads,
            settledSpreadID: settledSpreadID,
            radius: Constants.spreadDataModelWindowRadius
        ) else { return nil }
        let normalizedDate = spread.period.normalizeDate(spread.date, calendar: journalManager.calendar)
        return journalManager.dataModel[spread.period]?[normalizedDate]
    }
}
