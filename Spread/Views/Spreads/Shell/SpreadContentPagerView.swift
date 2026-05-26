import SwiftUI

/// Horizontally pages through spread content, assembling each page as a header and period-appropriate content view.
struct SpreadContentPagerView: View {
    private let liveRadius = 2

    @Environment(JournalManager.self) private var journalManager
    let coordinator: SpreadsCoordinator
    let syncEngine: SyncEngine?
    let model: SpreadTitleNavigatorModel
    let items: [SpreadTitleNavigatorModel.Item]
    let recenterToken: Int
    @Binding var selection: SpreadHeaderNavigatorModel.Selection

    @State private var pagerSettledTargetID: String?
    @State private var scrollPhase: ScrollPhase = .idle
    @State private var lastSequenceSignature: [String] = []

    private var sequenceSignature: [String] {
        items.map(\.id)
    }

    private var selectedSemanticID: String {
        selection.stableID(calendar: model.calendar)
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
        model.liveWindowIDs(items: items, anchorID: liveAnchorID, radius: liveRadius)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(items) { item in
                    Group {
                        if liveWindowIDs.contains(item.id) {
                            SpreadPageContentView(
                                item: item,
                                coordinator: coordinator,
                                syncEngine: syncEngine,
                                model: model
                            )
                        } else {
                            Color.clear
                                .accessibilityHidden(true)
                        }
                    }
                    .containerRelativeFrame(.horizontal)
                    .id(pagerID(for: item.id))
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
        .onChange(of: recenterToken) { _, _ in
            center(on: selectedSemanticID, animated: false)
        }
        .onChange(of: pagerSettledTargetID) { _, newValue in
            guard scrollPhase == .idle,
                  let semanticID = semanticID(from: newValue),
                  semanticID != selectedSemanticID else { return }
            guard let item = items.first(where: { $0.id == semanticID }) else { return }
            selection = item.selection
        }
        .onScrollPhaseChange { _, newPhase in
            scrollPhase = newPhase
            guard newPhase == .idle,
                  let currentVisibleID = semanticID(from: pagerSettledTargetID),
                  currentVisibleID != selectedSemanticID else {
                return
            }
            guard let item = items.first(where: { $0.id == currentVisibleID }) else { return }
            selection = item.selection
        }
        .alert(item: activeAlertBinding) { destination in
            switch destination {
            case .deleteSpreadConfirmation(let spread):
                return Alert(
                    title: Text("Delete Spread"),
                    message: Text(
                        "Only this spread will be deleted. Tasks and notes are preserved and moved to " +
                        "the nearest parent spread or Inbox. This action cannot be undone."
                    ),
                    primaryButton: .destructive(Text("Delete Spread")) {
                        deleteSpread(spread)
                    },
                    secondaryButton: .cancel {
                        coordinator.dismissAlert()
                    }
                )
            case .deleteSpreadFailed(let message):
                return Alert(
                    title: Text("Couldn't Delete Spread"),
                    message: Text(message),
                    dismissButton: .default(Text("OK")) {
                        coordinator.dismissAlert()
                    }
                )
            }
        }
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadContent.pager)
    }

    private var activeAlertBinding: Binding<SpreadsCoordinator.AlertDestination?> {
        Binding(
            get: { coordinator.activeAlert },
            set: { coordinator.activeAlert = $0 }
        )
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

    private func deleteSpread(_ spread: DataModel.Spread) {
        coordinator.dismissAlert()
        Task { @MainActor in
            do {
                try await journalManager.deleteSpread(spread)
                await syncEngine?.syncNow()
            } catch {
                coordinator.showSpreadDeleteFailure(
                    message: "Failed to delete spread: \(error.localizedDescription)"
                )
            }
        }
    }
}

// MARK: - Page Assembly

/// Assembles a single spread page: `SpreadHeaderView` followed by the period-appropriate content view.
private struct SpreadPageContentView: View {
    let item: SpreadTitleNavigatorModel.Item
    @Environment(JournalManager.self) private var journalManager
    let coordinator: SpreadsCoordinator
    let syncEngine: SyncEngine?
    let model: SpreadTitleNavigatorModel

    @Environment(\.eventKitService) private var eventKitService

    private var context: SpreadPageContext {
        SpreadPageContext(
            journalManager: journalManager,
            coordinator: coordinator,
            syncEngine: syncEngine,
            eventKitService: eventKitService
        )
    }

    var body: some View {
        switch journalManager.bujoMode {
        case .conventional:
            conventionalPage
        case .traditional:
            traditionalPage
        }
    }

    // MARK: - Conventional

    @ViewBuilder
    private var conventionalPage: some View {
        if case .conventional(let spread) = item.selection {
            let selectedID = coordinator.selectedSelection?.stableID(calendar: model.calendar)
            let isCurrentPage = item.id == selectedID
            let navState = isCurrentPage ? coordinator.convenienceNavigation : nil
            VStack(spacing: 0) {
                SpreadHeaderView(
                    state: navState,
                    onTap: navState != nil ? { coordinator.handleConvenienceNavButtonTapped() } : nil
                )
                conventionalContentView(for: spread)
            }
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private func conventionalContentView(for spread: DataModel.Spread) -> some View {
        if let dataModel = conventionalSpreadDataModel(for: spread) {
            switch spread.period {
            case .year:
                YearSpreadContentView(
                    spread: spread,
                    spreadDataModel: dataModel,
                    context: context
                )
            case .month:
                MonthSpreadContentView(
                    spread: spread,
                    spreadDataModel: dataModel,
                    context: context
                )
            case .day:
                DaySpreadContentView(
                    spread: spread,
                    spreadDataModel: dataModel,
                    context: context
                )
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

    // MARK: - Traditional

    @ViewBuilder
    private var traditionalPage: some View {
        switch item.selection {
        case .traditionalYear, .traditionalMonth, .traditionalDay:
            let spread = traditionalSpread(for: item.selection)
            traditionalContentView(for: spread, selection: item.selection)
        case .conventional:
            Color.clear
        }
    }

    @ViewBuilder
    private func traditionalContentView(
        for spread: DataModel.Spread,
        selection: SpreadHeaderNavigatorModel.Selection
    ) -> some View {
        let dataModel = traditionalSpreadDataModel(for: selection)

        switch spread.period {
        case .year:
            YearSpreadContentView(
                spread: spread,
                spreadDataModel: dataModel,
                context: context
            )
        case .month:
            MonthSpreadContentView(
                spread: spread,
                spreadDataModel: dataModel,
                context: context
            )
        case .day:
            DaySpreadContentView(
                spread: spread,
                spreadDataModel: dataModel,
                context: context
            )
        case .multiday:
            MultidaySpreadContentView(
                spread: spread,
                spreadDataModel: dataModel,
                context: context
            )
        }
    }

    // MARK: - Conventional Data Helpers

    private func conventionalSpreadDataModel(for spread: DataModel.Spread) -> SpreadDataModel? {
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

    // MARK: - Traditional Data Helpers

    private var traditionalService: TraditionalSpreadService {
        TraditionalSpreadService(calendar: journalManager.calendar)
    }

    private func traditionalSpread(for selection: SpreadHeaderNavigatorModel.Selection) -> DataModel.Spread {
        switch selection {
        case .traditionalYear(let yearDate):
            return DataModel.Spread(period: .year, date: yearDate, calendar: journalManager.calendar)
        case .traditionalMonth(let monthDate):
            return DataModel.Spread(period: .month, date: monthDate, calendar: journalManager.calendar)
        case .traditionalDay(let dayDate):
            return DataModel.Spread(period: .day, date: dayDate, calendar: journalManager.calendar)
        case .conventional:
            let calendar = journalManager.calendar
            let year = calendar.component(.year, from: journalManager.today)
            let yearDate = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
            return DataModel.Spread(period: .year, date: yearDate, calendar: calendar)
        }
    }

    private func traditionalSpreadDataModel(
        for selection: SpreadHeaderNavigatorModel.Selection
    ) -> SpreadDataModel {
        let spread = traditionalSpread(for: selection)
        return traditionalService.virtualSpreadDataModel(
            period: spread.period,
            date: spread.date,
            tasks: journalManager.tasks,
            notes: journalManager.notes,
            events: FeatureFlags.eventsEnabled ? journalManager.events : []
        )
    }
}
