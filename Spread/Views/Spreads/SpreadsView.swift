import SwiftUI

struct SpreadsView: View {
    @Bindable var journalManager: JournalManager
    let authManager: AuthManager
    let syncEngine: SyncEngine?
    let navigationState: SpreadsNavigationState

    @State private var viewModel = SpreadsViewModel()

    private let recommendationProvider: any SpreadTitleNavigatorRecommendationProviding =
        TodayMissingSpreadRecommendationProvider()

    var body: some View {
        SharedSpreadsShellView(
            selection: selectionBinding,
            journalManager: journalManager,
            viewModel: viewModel,
            syncEngine: syncEngine,
            stripModel: journalManager.titleNavigatorModel,
            recenterToken: viewModel.recenterToken,
            recommendationProvider: recommendationProvider,
            onRecommendedSpreadTapped: onRecommendedSpreadTapped,
            authManager: authManager,
            onAuth: { viewModel.showAuth() },
            syncStatus: syncEngine?.status,
            controls: shellControls
        )
        .sheet(item: $viewModel.activeSheet) { destination in
            sheetContent(for: destination)
        }
        .onChange(of: journalManager.dataVersion) { _, _ in
            if journalManager.bujoMode == .conventional {
                resetConventionalSelectionIfNeeded()
            }
        }
        .onAppear {
            if viewModel.selectedSelection == nil {
                viewModel.selectedSelection = defaultSelection
            }
            handlePendingNavigationRequest()
        }
        .onChange(of: navigationState.pendingRequest?.id) { _, _ in
            handlePendingNavigationRequest()
        }
    }

    // MARK: - Selection

    private var selectionBinding: Binding<SpreadHeaderNavigatorModel.Selection> {
        Binding(
            get: { currentSelection },
            set: { viewModel.selectedSelection = $0 }
        )
    }

    private var currentSelection: SpreadHeaderNavigatorModel.Selection {
        viewModel.selectedSelection ?? defaultSelection
    }

    private var defaultSelection: SpreadHeaderNavigatorModel.Selection {
        switch journalManager.bujoMode {
        case .conventional:
            return .conventional(conventionalFallbackSpread())
        case .traditional:
            return .traditionalYear(defaultTraditionalYearDate)
        }
    }

    private var defaultTraditionalYearDate: Date {
        let calendar = journalManager.calendar
        let year = calendar.component(.year, from: journalManager.today)
        return calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
    }

    // MARK: - Shell Controls

    private var shellControls: SharedSpreadsShellControlConfiguration {
        SharedSpreadsShellControlConfiguration(
            showsTodayButton: true,
            onToday: navigateToToday,
            onCreateSpread: journalManager.bujoMode == .conventional
                ? { viewModel.showSpreadCreation() }
                : nil,
            onCreateTask: { viewModel.showTaskCreation() },
            onCreateNote: { viewModel.showNoteCreation() }
        )
    }

    private var onRecommendedSpreadTapped: ((SpreadTitleNavigatorRecommendation) -> Void)? {
        guard journalManager.bujoMode == .conventional else { return nil }
        return { recommendation in
            viewModel.showSpreadCreation(
                prefill: .init(period: recommendation.period, date: recommendation.date)
            )
        }
    }

    // MARK: - Navigation

    private func navigateToToday() {
        switch journalManager.bujoMode {
        case .conventional:
            guard let targetSpread = SpreadHierarchyOrganizer(
                spreads: journalManager.spreads,
                calendar: journalManager.calendar
            ).initialSelection(for: journalManager.today) else { return }

            if case .conventional(let current) = currentSelection, current.id == targetSpread.id {
                viewModel.recenterToken += 1
            } else {
                viewModel.selectedSelection = .conventional(targetSpread)
            }

        case .traditional:
            let target = SpreadHeaderNavigatorModel.Selection.traditionalDay(
                Period.day.normalizeDate(journalManager.today, calendar: journalManager.calendar)
            )
            if target.stableID(calendar: journalManager.calendar)
                == currentSelection.stableID(calendar: journalManager.calendar) {
                viewModel.recenterToken += 1
            } else {
                viewModel.selectedSelection = target
            }
        }
    }

    // MARK: - Conventional Helpers

    private func conventionalFallbackSpread() -> DataModel.Spread {
        SpreadHierarchyOrganizer(
            spreads: journalManager.spreads,
            calendar: journalManager.calendar
        ).initialSelection(for: journalManager.today)
        ?? journalManager.spreads.first
        ?? DataModel.Spread(period: .year, date: journalManager.today, calendar: journalManager.calendar)
    }

    private func resetConventionalSelectionIfNeeded() {
        guard case .conventional(let spread) = viewModel.selectedSelection else { return }
        if journalManager.spreads.contains(where: { $0.id == spread.id }) { return }

        let organizer = SpreadHierarchyOrganizer(
            spreads: journalManager.spreads,
            calendar: journalManager.calendar
        )
        if let newSelection = organizer.initialSelection(for: journalManager.today) {
            viewModel.selectedSelection = .conventional(newSelection)
        }
    }

    // MARK: - Sheet Content

    @ViewBuilder
    private func sheetContent(for destination: SpreadsViewModel.SheetDestination) -> some View {
        switch destination {
        case .spreadCreation(let prefill):
            if journalManager.bujoMode == .conventional {
                SpreadCreationSheet(
                    journalManager: journalManager,
                    firstWeekday: journalManager.firstWeekday,
                    initialPeriod: prefill?.period,
                    initialDate: prefill?.date,
                    onSpreadCreated: { spread in
                        viewModel.selectedSelection = .conventional(spread)
                        Task { @MainActor in await syncEngine?.syncNow() }
                    }
                )
            } else {
                Color.clear
            }
        case .taskCreation:
            TaskCreationSheet(
                journalManager: journalManager,
                selectedSpread: selectedSpreadForSheet,
                onTaskCreated: { _ in
                    Task { @MainActor in await syncEngine?.syncNow() }
                }
            )
        case .noteCreation:
            NoteCreationSheet(
                journalManager: journalManager,
                selectedSpread: selectedSpreadForSheet,
                onNoteCreated: { _ in
                    Task { @MainActor in await syncEngine?.syncNow() }
                }
            )
        case .taskDetail(let task):
            TaskDetailSheet(
                task: task,
                journalManager: journalManager,
                onDelete: {
                    Task { @MainActor in await syncEngine?.syncNow() }
                }
            )
        case .noteDetail(let note):
            NoteDetailSheet(
                note: note,
                journalManager: journalManager,
                onDelete: {
                    Task { @MainActor in await syncEngine?.syncNow() }
                }
            )
        case .auth:
            AuthEntrySheet(authManager: authManager, isBlocking: false)
        }
    }

    private var selectedSpreadForSheet: DataModel.Spread? {
        switch currentSelection {
        case .conventional(let spread):
            return spread
        case .traditionalYear(let date):
            return DataModel.Spread(period: .year, date: date, calendar: journalManager.calendar)
        case .traditionalMonth(let date):
            return DataModel.Spread(period: .month, date: date, calendar: journalManager.calendar)
        case .traditionalDay(let date):
            return DataModel.Spread(period: .day, date: date, calendar: journalManager.calendar)
        }
    }

    // MARK: - Pending Navigation

    private func handlePendingNavigationRequest() {
        guard let request = navigationState.pendingRequest else { return }

        switch request.selection {
        case .conventional(let spread):
            guard journalManager.bujoMode == .conventional else { return }
            viewModel.selectedSelection = .conventional(spread)
        case .traditionalYear, .traditionalMonth, .traditionalDay:
            guard journalManager.bujoMode == .traditional else { return }
            viewModel.selectedSelection = request.selection
        }

        guard let task = journalManager.tasks.first(where: { $0.id == request.taskID }) else {
            navigationState.pendingRequest = nil
            return
        }

        Task { @MainActor in
            await Task.yield()
            viewModel.showTaskDetail(task)
            navigationState.pendingRequest = nil
        }
    }
}

#Preview {
    SpreadsView(
        journalManager: .previewInstance,
        authManager: .makeForPreview(),
        syncEngine: nil,
        navigationState: SpreadsNavigationState()
    )
}
