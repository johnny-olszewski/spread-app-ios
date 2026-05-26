import SwiftUI

struct SpreadsView: View {
    @Bindable var journalManager: JournalManager
    let authManager: AuthManager
    let syncEngine: SyncEngine?
    let navigationState: SpreadsNavigationState

    @State private var coordinator = SpreadsCoordinator()

    private let recommendationProvider: any SpreadTitleNavigatorRecommendationProviding =
        TodayMissingSpreadRecommendationProvider()

    private var calendar: Calendar {
        journalManager.firstWeekday.configuredCalendar(from: journalManager.calendar)
    }

    private var stripModel: SpreadTitleNavigatorModel {
        journalManager.titleNavigatorModel
    }

    private var completeItems: [SpreadTitleNavigatorModel.Item] {
        stripModel.items(for: currentSelection)
    }

    private var currentSpreadDiagnostics: LocalhostTemporalHarnessSpreadDiagnostics {
        let headerConfiguration = SpreadHeaderConfiguration(
            spread: currentSelection,
            calendar: journalManager.calendar,
            today: journalManager.today,
            firstWeekday: journalManager.firstWeekday,
            allowsPersonalization: true
        )

        return LocalhostTemporalHarnessSpreadDiagnostics(
            selectionID: currentSelection.stableID(calendar: journalManager.calendar),
            title: headerConfiguration.title,
            subtitle: headerConfiguration.subtitle
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            if case .error = syncEngine?.status {
                SyncErrorBanner()
            }
            
            SpreadTitleNavigatorView(
                stripModel: stripModel,
                onRecommendedSpreadTapped: onRecommendedSpreadTapped,
                recommendationProvider: recommendationProvider,
                selection: selectionBinding
            )

            
            SpreadContentPagerView(
                coordinator: coordinator,
                syncEngine: syncEngine,
                model: stripModel,
                items: completeItems,
                recenterToken: coordinator.recenterToken,
                selection: selectionBinding
            )
            .environment(coordinator)
            .environment(journalManager)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .localhostTemporalHarness(spreadDiagnostics: currentSpreadDiagnostics)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                
                Button("Today", action: navigateToToday)
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadToolbar.todayButton)
            }
            
            ToolbarItemGroup(placement: .automatic) {
    
                if let syncEngine {
                    SyncIconButton(
                        status: syncEngine.status,
                        outboxCount: syncEngine.outboxCount,
                        onSyncNow: { Task { @MainActor in await syncEngine.syncNow() } }
                    )
                }
                
                favoritesMenu
                
                AuthButton(isSignedIn: authManager.state.isSignedIn, action: { coordinator.showAuth() })
                
                if let spread = currentConventionalSpread {
                    
                    Button {
                        toggleFavorite(for: spread)
                    } label: {
                        Label(
                            spread.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                            systemImage: spread.isFavorite ? "star.fill" : "star"
                        )
                    }
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadToolbar.favoriteToggle)

                    Button {
                        coordinator.showSpreadNameEdit(spread)
                    } label: {
                        Label("Edit Name", systemImage: "pencil")
                    }

                    if spread.period == .multiday {
                        Button {
                            coordinator.showSpreadDateEdit(spread)
                        } label: {
                            Label("Edit Dates", systemImage: "calendar")
                        }
                        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadToolbar.editDatesButton)
                    }

                    Button(role: .destructive) {
                        coordinator.showSpreadDeleteConfirmation(spread)
                    } label: {
                        Label("Delete Spread", systemImage: "trash")
                    }
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadToolbar.deleteSpreadButton)

                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomInsetControls
        }
        .sheet(item: $coordinator.activeSheet) { destination in
            sheetContent(for: destination)
        }
        .onChange(of: journalManager.dataVersion) { _, _ in
            resetSelectionIfNeeded()
        }
        .onAppear {
            if coordinator.selectedSelection == nil {
                coordinator.selectedSelection = journalManager.defaultNavigationSelection
            }
            handlePendingNavigationRequest()
        }
        .onChange(of: navigationState.pendingRequest?.id) { _, _ in
            handlePendingNavigationRequest()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var bottomInsetControls: some View {
        HStack(spacing: 12) {

            Spacer()

            Menu {
                Button(action: { coordinator.showSpreadCreation() }) {
                    Label("Create Spread", systemImage: "book")
                }
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.CreateMenu.createSpread)

                Button(action: { coordinator.showTaskCreation() }) {
                    Label("Create Task", systemImage: "circle.fill")
                }
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.CreateMenu.createTask)

                Button(action: { coordinator.showNoteCreation() }) {
                    Label("Create Note", systemImage: "minus")
                }
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.CreateMenu.createNote)
            } label: {
                Image(systemName: "plus")
                    .padding(8)
                    .font(.system(size: SpreadTheme.IconSize.extraLarge, weight: .semibold))
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
            set: {
                coordinator.selectedSelection = $0
                coordinator.clearConvenienceNavigation()
            }
        )
    }

    private var currentSelection: SpreadHeaderNavigatorModel.Selection {
        coordinator.selectedSelection ?? journalManager.defaultNavigationSelection
    }

    private var onRecommendedSpreadTapped: ((SpreadTitleNavigatorRecommendation) -> Void)? {
        { recommendation in
            coordinator.showSpreadCreation(
                prefill: .init(period: recommendation.period, date: recommendation.date)
            )
        }
    }

    // MARK: - Spread Actions

    private var currentConventionalSpread: DataModel.Spread? { currentSelection }

    private func spreadActionsMenu(for spread: DataModel.Spread) -> some View {
        Menu {
            Button {
                toggleFavorite(for: spread)
            } label: {
                Label(
                    spread.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                    systemImage: spread.isFavorite ? "star.fill" : "star"
                )
            }
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadToolbar.favoriteToggle)

            Button {
                coordinator.showSpreadNameEdit(spread)
            } label: {
                Label("Edit Name", systemImage: "pencil")
            }

            if spread.period == .multiday {
                Button {
                    coordinator.showSpreadDateEdit(spread)
                } label: {
                    Label("Edit Dates", systemImage: "calendar")
                }
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadToolbar.editDatesButton)
            }

            Button(role: .destructive) {
                coordinator.showSpreadDeleteConfirmation(spread)
            } label: {
                Label("Delete Spread", systemImage: "trash")
            }
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadToolbar.deleteSpreadButton)
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("Spread Actions")
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadToolbar.spreadActionsMenu)
    }

    private func toggleFavorite(for spread: DataModel.Spread) {
        Task { @MainActor in
            try? await journalManager.updateSpreadFavorite(spread, isFavorite: !spread.isFavorite)
            await syncEngine?.syncNow()
        }
    }

    // MARK: - Favorites

    private var favoriteItemsForCurrentYear: [SpreadTitleNavigatorModel.Item] {
        completeItems.filter { $0.selection.isFavorite }
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
                    Button {
                        selectFavorite(item)
                    } label: {
                        Label(
                            favoriteNameFormatter.display(for: item.selection).primary,
                            systemImage: "star.fill"
                        )
                    }
                }
            }
        } label: {
            Label("Favorites", systemImage: "star.circle")
        }
        .accessibilityLabel("Favorite Spreads")
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadToolbar.favoritesMenu)
    }

    private func selectFavorite(_ item: SpreadTitleNavigatorModel.Item) {
        coordinator.clearConvenienceNavigation()
        coordinator.selectedSelection = item.selection
        coordinator.recenterToken += 1
    }

    // MARK: - Navigation

    private func navigateToToday() {
        guard let selection = journalManager.todayNavigationSelection else { return }
        coordinator.navigate(to: selection)
    }

    // MARK: - Helpers

    private func resetSelectionIfNeeded() {
        guard let spread = coordinator.selectedSelection else { return }
        guard !journalManager.spreads.contains(where: { $0.id == spread.id }) else { return }

        coordinator.selectedSelection = journalManager.bestSpread(for: journalManager.today)
        coordinator.recenterToken += 1
    }

    // MARK: - Sheet Content

    @ViewBuilder
    private func sheetContent(for destination: SpreadsCoordinator.SheetDestination) -> some View {
        switch destination {
        case .spreadCreation(let prefill):
            SpreadCreationSheet(
                journalManager: journalManager,
                firstWeekday: journalManager.firstWeekday,
                initialPeriod: prefill?.period,
                initialDate: prefill?.date,
                onSpreadCreated: { result in
                    coordinator.finishSpreadCreation(
                        result,
                        currentSelection: currentSelection,
                        calendar: journalManager.calendar
                    )
                    Task { @MainActor in await syncEngine?.syncNow() }
                }
            )
        case .spreadNameEdit(let spread):
            SpreadNameEditSheet(
                journalManager: journalManager,
                spread: spread,
                onSaved: {
                    Task { @MainActor in await syncEngine?.syncNow() }
                }
            )
        case .spreadDateEdit(let spread):
            if spread.period == .multiday {
                SpreadCreationSheet(
                    journalManager: journalManager,
                    firstWeekday: journalManager.firstWeekday,
                    editingMultidaySpread: spread,
                    onSpreadDatesSaved: { updatedSpread in
                        coordinator.finishSpreadDateEdit(updatedSpread)
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
        case .peekData(let data):
            SpreadPeekPanelView(
                data: data,
                calendar: calendar,
                today: journalManager.today,
                onClose: { coordinator.dismiss() },
                onNavigate: { destination in
                    coordinator.dismiss()
                    if let source = currentConventionalSpread {
                        coordinator.navigateViaPeek(to: destination, from: source)
                    } else {
                        coordinator.selectSpread(destination)
                    }
                },
                onTaskTap: nil
            )
        case .auth:
            AuthEntrySheet(authManager: authManager, isBlocking: false)
        }
    }

    private var selectedSpreadForSheet: DataModel.Spread? { currentSelection }

    // MARK: - Pending Navigation

    private func handlePendingNavigationRequest() {
        guard let request = navigationState.pendingRequest else { return }

        coordinator.selectedSelection = request.selection
        coordinator.recenterToken += 1

        guard let task = journalManager.tasks.first(where: { $0.id == request.taskID }) else {
            navigationState.pendingRequest = nil
            return
        }

        Task { @MainActor in
            await Task.yield()
            coordinator.showTaskDetail(task)
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
