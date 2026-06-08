import SwiftUI

/// Horizontally pages through spread content, assembling each page as a header and period-appropriate content view.
///
/// `items` and `currentSelection` are passed in from `SpreadsTabView` so the pager shell does not
/// read from `JournalManager` directly. Scroll-driven re-renders (from `scrollPhase` and
/// `pagerSettledTargetID` state changes) therefore only perform cheap lookups against already-
/// computed values — the year-spreads filtering stays in the parent.
///
/// `pagerSettledTargetID` is owned at the root level (`RootNavigationView`) and passed in as a
/// binding so its value survives size class transitions without resetting.
struct SpreadContentPagerView: View {
    private let backgroundShape = UnevenRoundedRectangle(topLeadingRadius: SpreadTheme.CornerRadius.xxlarge, topTrailingRadius: SpreadTheme.CornerRadius.xxlarge)

    let coordinator: SpreadsCoordinator
    let syncEngine: SyncEngine?
    /// Pre-computed by the parent so this view does not observe JournalManager during scrolling.
    let items: [DataModel.Spread]
    /// Pre-computed by the parent so this view does not observe Jo
    /// urnalManager during scrolling.
    let currentSelection: DataModel.Spread
    @State private var pagerSettledTargetID: String?

    /// Not accessed in `body` — stored here only for the `deleteSpread` action which fires
    /// outside of scroll-driven re-renders and therefore does not create a scroll-time observation.
    @Environment(JournalManager.self) private var journalManager

    @State private var scrollPhase: ScrollPhase = .idle
    @State private var lastSequenceSignature: [String] = []

    // MARK: - Pager State

    private var sequenceSignature: [String] {
        items.map { $0.stableID(calendar: .current) }
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
                ForEach(items) { spread in
                    SpreadPageContentView(
                        spread: spread,
                        coordinator: coordinator,
                        syncEngine: syncEngine
                    )
                    .containerRelativeFrame(.horizontal)
                    .id(pagerID(for: spread.stableID(calendar: .current)))
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
            guard let spread = items.first(where: { $0.stableID(calendar: .current) == semanticID }) else { return }
            coordinator.selectedSpread = spread
            coordinator.clearConvenienceNavigation()
        }
        .onScrollPhaseChange { _, newPhase in
            scrollPhase = newPhase
            guard newPhase == .idle,
                  let currentVisibleID = semanticID(from: pagerSettledTargetID),
                  currentVisibleID != selectedSemanticID else {
                return
            }
            guard let spread = items.first(where: { $0.stableID(calendar: .current) == currentVisibleID }) else { return }
            coordinator.selectedSpread = spread
            coordinator.clearConvenienceNavigation()
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
                .font(SpreadTheme.Typography.heading(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            if let subtitle = config.subtitle {
                Text(subtitle)
                    .font(.caption)
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

}

// MARK: - Page Assembly

/// Assembles a single spread page: `SpreadHeaderView` followed by the period-appropriate content view.
private struct SpreadPageContentView: View {
    let spread: DataModel.Spread
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
        let isCurrentPage = spread.stableID(calendar: .current) == coordinator.selectedSpread?.stableID(calendar: .current)
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
