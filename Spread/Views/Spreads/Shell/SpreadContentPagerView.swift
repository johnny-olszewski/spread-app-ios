import SwiftUI

/// Horizontally pages through spread content, assembling each page as a header and period-appropriate content view.
///
/// `spreads` and the `calendar`/`today`/`firstWeekday` triple are passed in from `SpreadsTabView`.
/// `spreads` is a `@State`-cached value in the parent so that intra-year scroll settles — which update
/// `coordinator.selectedSpread` — do not produce a new array and trigger a `@self changed` re-render
/// of this view. This view's struct value therefore remains stable between settles within the same year.
///
/// `coordinator.selectedSpread` is deliberately NOT read in this view's `body` scope: the title
/// derives from `settledSpreadID` (see `spreadDetailTitle`), per-page header state is isolated in
/// `SpreadPageHeaderView`, and external-navigation recentering reacts only to `coordinator.recenterToken`
/// (which changes only on explicit nav actions, not scroll settles). This breaks the
/// `coordinator.selectedSpread → body re-run → DaySpreadContentView @self changed` cascade that
/// fired on every swipe before SPRD-284.
///
/// `journalManager` is still read directly by `spreadDataModel(for:)`, called from `body` via
/// `contentView(for:)` — see that method's doc comment for how its cost is bounded.
struct SpreadContentPagerView: View {
    private let backgroundShape = UnevenRoundedRectangle(topLeadingRadius: SpreadTheme.CornerRadius.xxlarge, topTrailingRadius: SpreadTheme.CornerRadius.xxlarge)

    let coordinator: SpreadsCoordinator
    let syncEngine: SyncEngine?
    /// Pre-computed and cached by the parent so this view does not observe JournalManager during scrolling.
    let spreads: [DataModel.Spread]
    /// Pre-computed by the parent so `spreadDetailTitle` does not observe JournalManager during scrolling.
    let calendar: Calendar
    /// Pre-computed by the parent so `spreadDetailTitle` does not observe JournalManager during scrolling.
    let today: Date
    /// Pre-computed by the parent so `spreadDetailTitle` does not observe JournalManager during scrolling.
    let firstWeekday: FirstWeekday
    /// Seeded at construction (not just `.onAppear`) so the very first render's `spreadDataModel(for:)`
    /// window is already centered on the selected spread, rather than briefly showing the "No Data"
    /// placeholder before `.onAppear` fires. Stable across parent re-renders — only ever set once at init.
    @State private var settledSpreadID: UUID?

    /// Accessed in `body` only by `spreadDataModel(for:)`, scoped to the windowed set of spreads
    /// near `settledSpreadID` (see `Constants.spreadDataModelWindowRadius`).
    @Environment(JournalManager.self) private var journalManager
    @Environment(\.eventKitService) private var eventKitService
    @Environment(\.calendarEventService) private var calendarEventService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var scrollPhase: ScrollPhase = .idle
    @State private var isOverduePanelOpen: Bool = false
    @State private var overdueCardHeight: CGFloat = 0

    // MARK: - Init

    init(
        coordinator: SpreadsCoordinator,
        syncEngine: SyncEngine?,
        spreads: [DataModel.Spread],
        initialSelectedSpreadID: UUID,
        calendar: Calendar,
        today: Date,
        firstWeekday: FirstWeekday
    ) {
        self.coordinator = coordinator
        self.syncEngine = syncEngine
        self.spreads = spreads
        self.calendar = calendar
        self.today = today
        self.firstWeekday = firstWeekday
        _settledSpreadID = State(initialValue: initialSelectedSpreadID)
    }

    var body: some View {
        VStack(spacing: 0) {
            spreadDetailTitle
                .overlay(alignment: .trailing) {
                    OverduePanelToggleButton(
                        journalManager: journalManager,
                        isOpen: $isOverduePanelOpen
                    )
                    .padding(.trailing, SpreadTheme.Spacing.large)
                }

            if isSyncError { SyncErrorBanner() }

            ZStack(alignment: .top) {
                OverdueCardView(context: context)
                    .opacity(isOverduePanelOpen ? 1 : 0)
                    .padding(.horizontal, SpreadTheme.Spacing.large)
                    .padding(.bottom, SpreadTheme.Spacing.medium)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { overdueCardHeight = $0 }

                pager
                    .offset(y: isOverduePanelOpen ? overdueCardHeight : 0)
                    .animation(SpreadTheme.Motion.spring, value: isOverduePanelOpen)
                    .simultaneousGesture(TapGesture().onEnded {
                        if isOverduePanelOpen { isOverduePanelOpen = false }
                    })
            }
        }
        .onChange(of: journalManager.overdueTaskItems.isEmpty) { _, isEmpty in
            if isEmpty { isOverduePanelOpen = false }
        }
    }

    private var pager: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(spreads) { spread in
                    VStack(spacing: 0) {
                        SpreadPageHeaderView(spread: spread, coordinator: coordinator)
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
            // Only override the seeded settledSpreadID if the coordinator already has an explicit
            // selection (e.g. a deep-link drove the launch). When the coordinator has no selection
            // yet, the seeded value from init already shows the right page.
            if let id = coordinator.selectedSpread?.id { settledSpreadID = id }
        }
        // Recenter when externally-driven navigation fires (navigator tap, spread creation, deletion).
        // `coordinator.selectedSpread?.id` is read inside the handler closure, not as the `of:`
        // parameter, so it does not register a body-level @Observable dependency on selectedSpread.
        // All external navigation actions also increment recenterToken, so this replaces the prior
        // `onChange(of: selectedSpreadID)` without losing any recentering coverage.
        .onChange(of: coordinator.recenterToken) { _, _ in
            if let id = coordinator.selectedSpread?.id { center(on: id, animated: false) }
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

    /// Derives the display spread from `settledSpreadID` so that `coordinator.selectedSpread` is
    /// not read in body — keeping `coordinator.selectedSpread` changes from triggering a re-render.
    private var spreadDetailTitle: some View {
        let spread = spreads.first(where: { $0.id == settledSpreadID }) ?? spreads.first
        let config = spread.map {
            SpreadHeaderConfiguration(
                spread: $0,
                calendar: calendar,
                today: today,
                firstWeekday: firstWeekday,
                allowsPersonalization: true
            )
        }
        return VStack(spacing: 2) {
            Text(config?.title ?? "")
                .font(SpreadTheme.Typography.largeTitle(size: 17, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            if let subtitle = config?.subtitle {
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
              let settledSpreadID, settledSpreadID != coordinator.selectedSpread?.id,
              let spread = spreads.first(where: { $0.id == settledSpreadID }) else { return }
        coordinator.navigate(to: spread, shouldRecenter: false)
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
                    .equatable()
            case .month:
                MonthSpreadContentView(spread: spread, spreadDataModel: dataModel, context: context)
                    .equatable()
            case .day:
                DaySpreadContentView(
                    spread: spread,
                    spreadDataModel: dataModel,
                    context: context,
                    horizontalSizeClass: horizontalSizeClass
                )
                .equatable()
            case .multiday:
                MultidaySpreadContentView(
                    spread: spread,
                    spreadDataModel: dataModel,
                    context: context
                )
                .equatable()
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

// MARK: - OverduePanelToggleButton

/// Reads `journalManager.overdueTaskItems` in its own body scope so that changes to the overdue
/// list do not trigger a full `SpreadContentPagerView` body re-run — only this lightweight button
/// updates. Hidden when there are no overdue tasks.
private struct OverduePanelToggleButton: View {
    let journalManager: JournalManager
    @Binding var isOpen: Bool

    var body: some View {
        if !journalManager.overdueTaskItems.isEmpty {
            Button {
                withAnimation(SpreadTheme.Motion.spring) { isOpen.toggle() }
            } label: {
                SpreadTheme.Icon.clockCountdown.sized(SpreadTheme.IconSize.medium)
                    .iconTint(.yellow)
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
        }
    }
}

// MARK: - SpreadPageHeaderView

/// Per-page header that reads `coordinator.selectedSpread` and `coordinator.convenienceNavigation`
/// in its own body scope, isolated from `SpreadContentPagerView`.
///
/// Isolating these coordinator reads here prevents them from registering as body-level
/// `@Observable` dependencies on `SpreadContentPagerView`. When `coordinator.selectedSpread`
/// changes on a scroll settle, only this lightweight view re-renders — not the full pager body,
/// and not the sibling `DaySpreadContentView` / `MultidaySpreadContentView`.
private struct SpreadPageHeaderView: View {
    let spread: DataModel.Spread
    let coordinator: SpreadsCoordinator

    var body: some View {
        let isCurrentPage = spread.id == coordinator.selectedSpread?.id
        let navState = isCurrentPage ? coordinator.convenienceNavigation : nil
        SpreadHeaderView(
            state: navState,
            onTap: navState != nil ? { coordinator.handleConvenienceNavButtonTapped() } : nil
        )
    }
}
