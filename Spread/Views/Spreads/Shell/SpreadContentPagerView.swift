import SwiftUI

/// Horizontally pages through spread content, assembling each page as a header and period-appropriate content view.
///
/// `items` and `currentSelection` are passed in from `RootNavigationView` so the pager shell does not
/// read from `JournalManager` directly. Scroll-driven re-renders (from `scrollPhase` and
/// `pagerSettledTargetID` state changes) therefore only perform cheap lookups against already-
/// computed values — the expensive `titleNavigatorModel` rebuild stays in the parent.
///
/// `pagerSettledTargetID` is owned at the root level (`RootNavigationView`) and passed in as a
/// binding so its value survives size class transitions without resetting.
struct SpreadContentPagerView: View {
    private let liveRadius = 2
    private let backgroundShape = UnevenRoundedRectangle(topLeadingRadius: SpreadTheme.CornerRadius.xxlarge,topTrailingRadius: SpreadTheme.CornerRadius.xxlarge)

    let coordinator: SpreadsCoordinator
    let syncEngine: SyncEngine?
    /// Pre-computed by the parent so this view does not observe JournalManager during scrolling.
    let items: [SpreadPickerModel.Item]
    /// Pre-computed by the parent so this view does not observe JournalManager during scrolling.
    let currentSelection: DataModel.Spread
    /// Root-owned scroll position binding — lifted so it survives size class transitions.
    @Binding var pagerSettledTargetID: String?

    /// Not accessed in `body` — stored here only for the `deleteSpread` action which fires
    /// outside of scroll-driven re-renders and therefore does not create a scroll-time observation.
    @Environment(JournalManager.self) private var journalManager

    @State private var scrollPhase: ScrollPhase = .idle
    @State private var lastSequenceSignature: [String] = []

    // MARK: - Pager State

    private var sequenceSignature: [String] {
        items.map(\.id)
    }

    /// Stable ID derived directly from the spread's UUID — no calendar or JournalManager needed.
    private var selectedSemanticID: String {
        currentSelection.stableID(calendar: .current)
    }

    private func pagerID(for semanticID: String) -> String {
        "pager.\(semanticID)"
    }

    private func semanticID(from pagerID: String?) -> String? {
        guard let pagerID else { return nil }
        return pagerID.replacingOccurrences(of: "pager.", with: "")
    }

    private var liveAnchorID: String {
        guard let visibleSemanticID = semanticID(from: pagerSettledTargetID),
              items.contains(where: { $0.id == visibleSemanticID }) else {
            return selectedSemanticID
        }
        if visibleSemanticID != selectedSemanticID && scrollPhase == .idle {
            return selectedSemanticID
        }
        return visibleSemanticID
    }

    private var liveWindowIDs: Set<String> {
        liveWindow(items: items, anchorID: liveAnchorID, radius: liveRadius)
    }

    // MARK: - Parent Spread Navigation

    /// Parent spread entries for the current selection, used to build the leading toolbar buttons.
    private var parentSpreadEntries: [(period: Period, spread: DataModel.Spread?)] {
        journalManager.parentSpreads(for: currentSelection)
    }

    /// Toolbar button label for a parent entry.
    ///
    /// Uses the spread's own `parentNavigationLabel` when the spread exists, otherwise
    /// derives the expected label from the current selection's reference date.
    private func parentButtonLabel(period: Period, spread: DataModel.Spread?) -> String {
        if let spread {
            return spread.parentNavigationLabel(calendar: journalManager.calendar)
        }
        let formatter = DateFormatter()
        formatter.calendar = journalManager.calendar
        formatter.locale = .current
        let referenceDate = currentSelection.period == .multiday
            ? (currentSelection.startDate ?? currentSelection.date)
            : currentSelection.date
        switch period {
        case .year:
            formatter.dateFormat = "yyyy"
            return formatter.string(from: referenceDate)
        case .month:
            formatter.dateFormat = "MMM"
            return formatter.string(from: referenceDate)
        case .day, .multiday:
            return ""
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(items) { item in
                    SpreadPageContentView(
                        item: item,
                        coordinator: coordinator,
                        syncEngine: syncEngine
                    )
                    .containerRelativeFrame(.horizontal)
                    .id(pagerID(for: item.id))
                    .background {
//                        DotGridView(configuration: .paper)
//                            .clipShape(
//                                UnevenRoundedRectangle(
//                                    topLeadingRadius: 48,
//                                    bottomLeadingRadius: 48,
//                                    bottomTrailingRadius: 48,
//                                    topTrailingRadius: 48
//                                )
//                            )
                        self.backgroundShape
                        .fill(.background.opacity(0.6))
                    }
                    .clipShape(self.backgroundShape)
                }
            }
            .scrollTargetLayout()
        }
        .scrollClipDisabled()
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $pagerSettledTargetID)
        .onAppear {
            pagerSettledTargetID = pagerID(for: selectedSemanticID)
            lastSequenceSignature = sequenceSignature
        }
        .task(id: sequenceSignature) {
            let isSameSequence = lastSequenceSignature == sequenceSignature
            lastSequenceSignature = sequenceSignature
            center(on: selectedSemanticID, animated: isSameSequence)
        }
        .onChange(of: selectedSemanticID) { _, newValue in
            guard pagerID(for: newValue) != pagerSettledTargetID else { return }
            center(on: newValue, animated: false)
        }
        .onChange(of: coordinator.recenterToken) { _, _ in
            center(on: selectedSemanticID, animated: false)
        }
        .onChange(of: pagerSettledTargetID) { _, newValue in
            guard scrollPhase == .idle,
                  let semanticID = semanticID(from: newValue),
                  semanticID != selectedSemanticID else { return }
            guard let item = items.first(where: { $0.id == semanticID }) else { return }
            coordinator.selectedSelection = item.selection
            coordinator.clearConvenienceNavigation()
        }
        .onScrollPhaseChange { _, newPhase in
            scrollPhase = newPhase
            guard newPhase == .idle,
                  let currentVisibleID = semanticID(from: pagerSettledTargetID),
                  currentVisibleID != selectedSemanticID else {
                return
            }
            guard let item = items.first(where: { $0.id == currentVisibleID }) else { return }
            coordinator.selectedSelection = item.selection
            coordinator.clearConvenienceNavigation()
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarLeading) {
                ForEach(parentSpreadEntries, id: \.period) { entry in
                    Button(parentButtonLabel(period: entry.period, spread: entry.spread)) {
                        coordinator.selectedSelection = entry.spread
                    }
                    .disabled(entry.spread == nil)
                    .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: .leading)))
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: parentSpreadEntries.map(\.period))
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadContent.pager)
    }

    private func center(on id: String, animated: Bool) {
        let targetID = pagerID(for: id)
        guard pagerSettledTargetID != targetID else { return }
        if animated {
            withAnimation(.easeInOut(duration: 0.38)) {
                pagerSettledTargetID = targetID
            }
        } else {
            pagerSettledTargetID = targetID
        }
    }

    /// Returns the set of item IDs within `radius` positions of `anchorID`.
    /// Pure array logic — no model state accessed.
    private func liveWindow(
        items: [SpreadPickerModel.Item],
        anchorID: String,
        radius: Int
    ) -> Set<String> {
        guard let anchorIndex = items.firstIndex(where: { $0.id == anchorID }) else {
            return Set(items.prefix(radius * 2 + 1).map(\.id))
        }
        let lower = max(0, anchorIndex - radius)
        let upper = min(items.count - 1, anchorIndex + radius)
        return Set(items[lower...upper].map(\.id))
    }
}

// MARK: - Page Assembly

/// Assembles a single spread page: `SpreadHeaderView` followed by the period-appropriate content view.
private struct SpreadPageContentView: View {
    let item: SpreadPickerModel.Item
    @Environment(JournalManager.self) private var journalManager
    let coordinator: SpreadsCoordinator
    let syncEngine: SyncEngine?

    @Environment(\.eventKitService) private var eventKitService
    @Environment(\.calendarEventService) private var calendarEventService

    private var context: SpreadPageContext {
        SpreadPageContext(
            journalManager: journalManager,
            coordinator: coordinator,
            syncEngine: syncEngine,
            eventKitService: eventKitService,
            calendarEventService: calendarEventService
        )
    }

    var body: some View {
        let spread = item.selection
        let isCurrentPage = item.id == coordinator.selectedSelection?.stableID(calendar: .current)
        let navState = isCurrentPage ? coordinator.convenienceNavigation : nil
        VStack(spacing: 0) {
            SpreadHeaderView(
                state: navState,
                onTap: navState != nil ? { coordinator.handleConvenienceNavButtonTapped() } : nil
            )
            contentView(for: spread)
        }
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
                DaySpreadContentView(spread: spread, spreadDataModel: dataModel, context: context)
            case .multiday:
                MultidaySpreadContentView(
                    spread: spread,
                    spreadDataModel: dataModel,
                    context: context,
                    explicitDaySpreadForDate: { date in explicitDaySpread(for: date) }
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

    // MARK: - Data Helpers

    private func spreadDataModel(for spread: DataModel.Spread) -> SpreadDataModel? {
        let normalizedDate = spread.period.normalizeDate(spread.date, calendar: journalManager.calendar)
        return journalManager.dataModel[spread.period]?[normalizedDate]
    }

    private func explicitDaySpread(for date: Date) -> DataModel.Spread? {
        let normalizedDate = Period.day.normalizeDate(date, calendar: journalManager.calendar)
        return journalManager.spreads.first { spread in
            spread.period == .day &&
            journalManager.calendar.isDate(
                Period.day.normalizeDate(spread.date, calendar: journalManager.calendar),
                inSameDayAs: normalizedDate
            )
        }
    }
}
