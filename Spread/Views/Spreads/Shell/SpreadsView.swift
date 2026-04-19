import SwiftUI

struct SpreadsView: View {
    @Bindable var journalManager: JournalManager
    let authManager: AuthManager
    let syncEngine: SyncEngine?
    let navigationState: SpreadsNavigationState

    @State private var viewModel = SpreadsViewModel()

    private let recommendationProvider: any SpreadTitleNavigatorRecommendationProviding =
        TodayMissingSpreadRecommendationProvider()

    private var stripModel: SpreadTitleNavigatorModel {
        journalManager.titleNavigatorModel
    }

    private var items: [SpreadTitleNavigatorModel.Item] {
        stripModel.items(for: currentSelection)
    }

    var body: some View {
        VStack(spacing: 0) {
            SpreadTitleNavigatorView(
                stripModel: stripModel,
                recenterToken: viewModel.recenterToken,
                onRecommendedSpreadTapped: onRecommendedSpreadTapped,
                recommendationProvider: recommendationProvider,
                selection: selectionBinding
            )

            Divider()

            if case .error = syncEngine?.status {
                SyncErrorBanner()
            }

            contentArea
        }
        .toolbar {
            if journalManager.bujoMode == .conventional {
                ToolbarItem(placement: .primaryAction) {
                    favoritesMenu
                }
            }
            ToolbarItem(placement: .primaryAction) {
                AuthButton(isSignedIn: authManager.state.isSignedIn, action: { viewModel.showAuth() })
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomInsetControls
        }
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

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        if !items.isEmpty {
            SpreadContentPagerView(
                journalManager: journalManager,
                viewModel: viewModel,
                syncEngine: syncEngine,
                model: stripModel,
                items: items,
                recenterToken: viewModel.recenterToken,
                selection: selectionBinding
            )
            .dotGridBackground(.paper, ignoresSafeAreaEdges: .bottom)
        } else {
            ContentUnavailableView {
                Label("No Spread Selected", systemImage: "book")
            } description: {
                Text("Select a spread from the bar above.")
            }
            .dotGridBackground(.paper, ignoresSafeAreaEdges: .bottom)
        }
    }

    @ViewBuilder
    private var bottomInsetControls: some View {
        HStack(spacing: 12) {
            Button(action: navigateToToday) {
                Text("Today")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .glassEffect(.clear, in: Capsule())
            }
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadToolbar.todayButton)

            Spacer()

            Menu {
                if journalManager.bujoMode == .conventional {
                    Button(action: { viewModel.showSpreadCreation() }) {
                        Label("Create Spread", systemImage: "book")
                    }
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.CreateMenu.createSpread)
                }

                Button(action: { viewModel.showTaskCreation() }) {
                    Label("Create Task", systemImage: "circle.fill")
                }
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.CreateMenu.createTask)

                Button(action: { viewModel.showNoteCreation() }) {
                    Label("Create Note", systemImage: "minus")
                }
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.CreateMenu.createNote)
            } label: {
                Image(systemName: "plus")
                    .padding(8)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .glassEffect(.regular.tint(SpreadTheme.Accent.todaySelectedEmphasis), in: Circle())
            }
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.CreateMenu.button)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Color.clear)
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

    private var onRecommendedSpreadTapped: ((SpreadTitleNavigatorRecommendation) -> Void)? {
        guard journalManager.bujoMode == .conventional else { return nil }
        return { recommendation in
            viewModel.showSpreadCreation(
                prefill: .init(period: recommendation.period, date: recommendation.date)
            )
        }
    }

    // MARK: - Favorites

    private var favoriteItemsForCurrentYear: [SpreadTitleNavigatorModel.Item] {
        guard journalManager.bujoMode == .conventional else { return [] }
        return items.filter { item in
            guard case .conventional(let spread) = item.selection else { return false }
            return spread.isFavorite
        }
    }

    private var favoriteNameFormatter: SpreadDisplayNameFormatter {
        SpreadDisplayNameFormatter(
            calendar: journalManager.calendar,
            today: journalManager.today,
            firstWeekday: journalManager.firstWeekday
        )
    }

    private var favoritesMenu: some View {
        Menu {
            if favoriteItemsForCurrentYear.isEmpty {
                Text("No favorites this year")
            } else {
                ForEach(favoriteItemsForCurrentYear) { item in
                    if case .conventional(let spread) = item.selection {
                        Button {
                            selectFavorite(item)
                        } label: {
                            Label(
                                favoriteNameFormatter.display(for: spread).primary,
                                systemImage: "star.fill"
                            )
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "star.circle")
        }
        .accessibilityLabel("Favorite Spreads")
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadToolbar.favoritesMenu)
    }

    private func selectFavorite(_ item: SpreadTitleNavigatorModel.Item) {
        viewModel.selectedSelection = item.selection
        viewModel.recenterToken += 1
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
        case .spreadNameEdit(let spread):
            if journalManager.bujoMode == .conventional {
                SpreadNameEditSheet(
                    journalManager: journalManager,
                    spread: spread,
                    onSaved: {
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
