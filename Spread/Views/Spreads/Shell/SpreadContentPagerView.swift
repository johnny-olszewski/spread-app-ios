import SwiftUI

/// Horizontally pages through spread content, assembling each page as a header and period-appropriate content view.
///
/// `spreads` and `currentSelection` are passed in from `SpreadsTabView` so the pager shell does not
/// read from `JournalManager` directly. Scroll-driven re-renders (from `scrollPhase` and
/// `settledSpreadID` state changes) therefore only perform cheap lookups against already-
/// computed values — the year-spreads filtering stays in the parent.
struct SpreadContentPagerView: View {
    private let backgroundShape = UnevenRoundedRectangle(topLeadingRadius: SpreadTheme.CornerRadius.xxlarge, topTrailingRadius: SpreadTheme.CornerRadius.xxlarge)

    let coordinator: SpreadsCoordinator
    let syncEngine: SyncEngine?
    /// Pre-computed by the parent so this view does not observe JournalManager during scrolling.
    let spreads: [DataModel.Spread]
    /// Pre-computed by the parent so this view does not observe JournalManager during scrolling.
    let currentSelection: DataModel.Spread
    @State private var settledSpreadID: UUID?

    /// Not accessed in `body` — stored here only for the `deleteSpread` action which fires
    /// outside of scroll-driven re-renders and therefore does not create a scroll-time observation.
    @Environment(JournalManager.self) private var journalManager
    @Environment(\.eventKitService) private var eventKitService
    @Environment(\.calendarEventService) private var calendarEventService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var scrollPhase: ScrollPhase = .idle

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
            calendar: journalManager.calendar,
            today: journalManager.today,
            firstWeekday: journalManager.firstWeekday,
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
                Label("No Data", systemImage: "tray")
            } description: {
                Text("Unable to load spread data.")
            }
        }
    }

    private func spreadDataModel(for spread: DataModel.Spread) -> SpreadDataModel? {
        let normalizedDate = spread.period.normalizeDate(spread.date, calendar: journalManager.calendar)
        return journalManager.dataModel[spread.period]?[normalizedDate]
    }
}
