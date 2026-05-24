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
        let spread: DataModel.Spread
        switch currentSelection {
        case .conventional(let currentSpread):
            spread = currentSpread
        case .traditionalYear(let date):
            spread = DataModel.Spread(period: .year, date: date, calendar: journalManager.calendar)
        case .traditionalMonth(let date):
            spread = DataModel.Spread(period: .month, date: date, calendar: journalManager.calendar)
        case .traditionalDay(let date):
            spread = DataModel.Spread(period: .day, date: date, calendar: journalManager.calendar)
        }

        let headerConfiguration = SpreadHeaderConfiguration(
            spread: spread,
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

            contentArea
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .localhostTemporalHarness(spreadDiagnostics: currentSpreadDiagnostics)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                SpreadTitleNavigatorView(
                    stripModel: stripModel,
                    onRecommendedSpreadTapped: onRecommendedSpreadTapped,
                    recommendationProvider: recommendationProvider,
                    selection: selectionBinding
                )
            }
            ToolbarItem(placement: .topBarLeading) {
                if let syncEngine {
                    SyncIconButton(
                        status: syncEngine.status,
                        outboxCount: syncEngine.outboxCount,
                        onSyncNow: { Task { @MainActor in await syncEngine.syncNow() } }
                    )
                }
            }
            if journalManager.bujoMode == .conventional {
                ToolbarItem(placement: .primaryAction) {
                    favoritesMenu
                }
            }
            ToolbarItem(placement: .primaryAction) {
                AuthButton(isSignedIn: authManager.state.isSignedIn, action: { coordinator.showAuth() })
            }
            if let spread = currentConventionalSpread {
                ToolbarItem(placement: .primaryAction) {
                    spreadActionsMenu(for: spread)
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
            if journalManager.bujoMode == .conventional {
                resetConventionalSelectionIfNeeded()
            }
        }
        .onAppear {
            if coordinator.selectedSelection == nil {
                coordinator.selectedSelection = defaultSelection
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
        if !completeItems.isEmpty {
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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .dotGridBackground(.paper, ignoresSafeAreaEdges: .all)
        } else {
            ContentUnavailableView {
                Label("No Spread Selected", systemImage: "book")
            } description: {
                Text("Select a spread from the bar above.")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .dotGridBackground(.paper, ignoresSafeAreaEdges: .all)
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
                    Button(action: { coordinator.showSpreadCreation() }) {
                        Label("Create Spread", systemImage: "book")
                    }
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.CreateMenu.createSpread)
                }

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
                coordinator.clearPeekNavigationSource()
            }
        )
    }

    private var currentSelection: SpreadHeaderNavigatorModel.Selection {
        coordinator.selectedSelection ?? defaultSelection
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
            coordinator.showSpreadCreation(
                prefill: .init(period: recommendation.period, date: recommendation.date)
            )
        }
    }

    // MARK: - Spread Actions

    private var currentConventionalSpread: DataModel.Spread? {
        guard case .conventional(let spread) = currentSelection else { return nil }
        return spread
    }

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
        SpreadFavoritesMenuSupport.favoriteItemsForCurrentYear(
            mode: journalManager.bujoMode,
            items: completeItems
        )
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
        coordinator.clearPeekNavigationSource()
        coordinator.selectedSelection = item.selection
        coordinator.recenterToken += 1
    }

    // MARK: - Navigation

    private func navigateToToday() {
        coordinator.clearPeekNavigationSource()
        switch journalManager.bujoMode {
        case .conventional:
            guard let targetSpread = SpreadHierarchyOrganizer(
                spreads: journalManager.spreads,
                calendar: journalManager.calendar
            ).initialSelection(for: journalManager.today) else { return }

            if case .conventional(let current) = currentSelection, current.id == targetSpread.id {
                coordinator.recenterToken += 1
            } else {
                coordinator.selectedSelection = .conventional(targetSpread)
                coordinator.recenterToken += 1
            }

        case .traditional:
            let target = SpreadHeaderNavigatorModel.Selection.traditionalDay(
                Period.day.normalizeDate(journalManager.today, calendar: journalManager.calendar)
            )
            if target.stableID(calendar: journalManager.calendar)
                == currentSelection.stableID(calendar: journalManager.calendar) {
                coordinator.recenterToken += 1
            } else {
                coordinator.selectedSelection = target
                coordinator.recenterToken += 1
            }
        }
    }

    // MARK: - Conventional Helpers

    private func conventionalFallbackSpread() -> DataModel.Spread {
        conventionalFallbackSpreadIfAvailable()
            ?? DataModel.Spread(period: .year, date: journalManager.today, calendar: journalManager.calendar)
    }

    private func conventionalFallbackSpreadIfAvailable() -> DataModel.Spread? {
        SpreadSelectionFallbackSupport.fallbackSpread(
            spreads: journalManager.spreads,
            calendar: journalManager.calendar,
            today: journalManager.today
        )
    }

    private func resetConventionalSelectionIfNeeded() {
        guard case .conventional(let spread) = coordinator.selectedSelection else { return }
        if journalManager.spreads.contains(where: { $0.id == spread.id }) { return }

        coordinator.selectedSelection = SpreadSelectionFallbackSupport.replacementSelection(
            currentSelection: coordinator.selectedSelection,
            spreads: journalManager.spreads,
            calendar: journalManager.calendar,
            today: journalManager.today
        )
        coordinator.recenterToken += 1
    }

    // MARK: - Sheet Content

    @ViewBuilder
    private func sheetContent(for destination: SpreadsCoordinator.SheetDestination) -> some View {
        switch destination {
        case .spreadCreation(let prefill):
            if journalManager.bujoMode == .conventional {
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
        case .spreadDateEdit(let spread):
            if journalManager.bujoMode == .conventional, spread.period == .multiday {
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
            coordinator.selectedSelection = .conventional(spread)
        case .traditionalYear, .traditionalMonth, .traditionalDay:
            guard journalManager.bujoMode == .traditional else { return }
            coordinator.selectedSelection = request.selection
        }
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

enum SpreadFavoritesMenuSupport {
    static func favoriteItemsForCurrentYear(
        mode: BujoMode,
        items: [SpreadTitleNavigatorModel.Item]
    ) -> [SpreadTitleNavigatorModel.Item] {
        guard mode == .conventional else { return [] }
        return items.filter { item in
            guard case .conventional(let spread) = item.selection else { return false }
            return spread.isFavorite
        }
    }
}

enum SpreadSelectionFallbackSupport {
    static func fallbackSpread(
        spreads: [DataModel.Spread],
        calendar: Calendar,
        today: Date
    ) -> DataModel.Spread? {
        SpreadHierarchyOrganizer(spreads: spreads, calendar: calendar).initialSelection(for: today)
            ?? spreads.first
    }

    static func replacementSelection(
        currentSelection: SpreadHeaderNavigatorModel.Selection?,
        spreads: [DataModel.Spread],
        calendar: Calendar,
        today: Date
    ) -> SpreadHeaderNavigatorModel.Selection? {
        guard case .conventional(let spread) = currentSelection else {
            return currentSelection
        }
        guard !spreads.contains(where: { $0.id == spread.id }) else {
            return currentSelection
        }
        guard let fallback = fallbackSpread(spreads: spreads, calendar: calendar, today: today) else {
            return nil
        }
        return .conventional(fallback)
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
