import SwiftUI

/// Root navigation container for the app.
///
/// Uses a single `NavigationSplitView` 3-column structure throughout — SwiftUI
/// handles compact collapse automatically. On iPad (regular), all three columns
/// can be visible simultaneously. On iPhone (compact), the columns collapse into
/// a navigation stack: sidebar → spread list → spread pager.
///
/// All navigation state is owned at this level so it survives size class
/// transitions without resetting.
struct RootNavigationView: View {

    let journalManager: JournalManager
    let authManager: AuthManager
    let dependencies: AppDependencies
    let syncEngine: SyncEngine?
    let appClock: AppClock
    let makeDebugMenuView: DebugMenuViewFactory?

    // MARK: - Root-owned Navigation State

    @State private var selectedContent: Content? = .spreads
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    /// Drives the content column list selection and NavigationSplitView column navigation.
    @State private var selectedColumnSpread: DataModel.Spread?
    /// Root-owned pager scroll position — lifted so it survives size class transitions.
    @State private var pagerSettledTargetID: String?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var spreadsNavigationState = SpreadsNavigationState()
    @State private var spreadsCoordinator = SpreadsCoordinator()

    init(
        journalManager: JournalManager,
        authManager: AuthManager,
        dependencies: AppDependencies,
        syncEngine: SyncEngine? = nil,
        appClock: AppClock,
        makeDebugMenuView: DebugMenuViewFactory? = nil
    ) {
        self.journalManager = journalManager
        self.authManager = authManager
        self.dependencies = dependencies
        self.syncEngine = syncEngine
        self.appClock = appClock
        self.makeDebugMenuView = makeDebugMenuView
    }

    // MARK: - Body

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarColumn
        } content: {
            contentColumn
        } detail: {
            detailColumn
        }
        // Content column selection → update coordinator + collapse to pager.
        // Guard prevents collapsing when the change originated from a pager swipe sync.
        // Only collapse on regular width — compact uses the navigation stack's back button instead.
        .onChange(of: selectedColumnSpread) { _, newValue in
            guard let spread = newValue else { return }
            guard spread.id != spreadsCoordinator.selectedSelection?.id else { return }
            spreadsCoordinator.selectedSelection = spread
            spreadsCoordinator.clearConvenienceNavigation()
            if horizontalSizeClass == .regular {
                columnVisibility = .detailOnly
            }
        }
        // Pager settle → sync content column list highlight without collapsing.
        .onChange(of: spreadsCoordinator.selectedSelection) { _, newValue in
            guard newValue?.id != selectedColumnSpread?.id else { return }
            selectedColumnSpread = newValue
        }
        .onChange(of: syncEngine?.status) { _, newValue in
            guard case .synced = newValue else { return }
            Task { @MainActor in await journalManager.reload() }
        }
        .sheet(item: Binding(
            get: { spreadsCoordinator.activeSheet },
            set: { spreadsCoordinator.activeSheet = $0 }
        )) { destination in
            spreadsSheetContent(for: destination)
        }
        .alert(item: Binding(
            get: { spreadsCoordinator.activeAlert },
            set: { spreadsCoordinator.activeAlert = $0 }
        )) { destination -> Alert in
            switch destination {
            case .deleteSpreadConfirmation(let spread):
                Alert(
                    title: Text("Delete Spread"),
                    message: Text(
                        "Only this spread will be deleted. Tasks and notes are preserved and moved to " +
                        "the nearest parent spread or Inbox. This action cannot be undone."
                    ),
                    primaryButton: .destructive(Text("Delete Spread")) {
                        deleteSpread(spread)
                    },
                    secondaryButton: .cancel {
                        spreadsCoordinator.dismissAlert()
                    }
                )
            case .deleteSpreadFailed(let message):
                Alert(
                    title: Text("Couldn't Delete Spread"),
                    message: Text(message),
                    dismissButton: .default(Text("OK")) {
                        spreadsCoordinator.dismissAlert()
                    }
                )
            case .discardChanges(let onSave, let onDiscard):
                Alert(
                    title: Text("Unsaved Changes"),
                    message: Text("Save your title changes before continuing?"),
                    primaryButton: .default(Text("Save")) {
                        Task { @MainActor in await onSave() }
                    },
                    secondaryButton: .destructive(Text("Discard")) {
                        Task { @MainActor in await onDiscard() }
                    }
                )
            case .deleteEntryConfirmation(let confirmAction):
                Alert(
                    title: Text("Confirm Delete"),
                    message: Text("Are you sure you want to delete this entry?"),
                    primaryButton: .destructive(Text("Delete")) {
                        Task { @MainActor in await confirmAction() }
                    },
                    secondaryButton: .cancel(Text("Cancel")) {
                        spreadsCoordinator.activeAlert = nil
                    }
                )
            }
        }
        .onAppear {
            if spreadsCoordinator.selectedSelection == nil {
                spreadsCoordinator.selectedSelection = journalManager.defaultNavigationSelection
                selectedColumnSpread = spreadsCoordinator.selectedSelection
            }
        }
        .onChange(of: spreadsNavigationState.pendingRequest?.id) { _, _ in
            handlePendingNavigationRequest()
        }
        .onChange(of: journalManager.dataVersion) { _, _ in
            resetSelectionIfNeeded()
        }
    }

    // MARK: - Sidebar Column

    private var sidebarColumn: some View {
        List(selection: $selectedContent) {
            ForEach(Content.allCases) { content in
                Label(content.title, systemImage: content.systemImage)
                    .tag(content as Content?)
            }
        }
        .navigationTitle("Spread")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                AuthButton(isSignedIn: authManager.state.isSignedIn) {
                    spreadsCoordinator.showAuth()
                }
            }
        }
    }

    // MARK: - Content Column

    @ViewBuilder
    private var contentColumn: some View {
        switch selectedContent ?? .spreads {
        case .spreads:
            SpreadNavigatorColumnView(
                items: pickerItems,
                selectedSpread: $selectedColumnSpread
            )
        case .entries:
            entriesBrowserView
        case .collections:
            CollectionsListView(
                collectionRepository: dependencies.collectionRepository,
                syncEngine: syncEngine
            )
        case .settings:
            SettingsView(
                journalManager: journalManager,
                settingsRepository: dependencies.settingsRepository,
                syncEngine: syncEngine
            )
        case .debug:
            debugMenuView
        }
    }

    /// Extracted to a separate property to help the type-checker with the trailing closure.
    private var entriesBrowserView: some View {
        EntriesBrowserView(
            journalManager: journalManager,
            listRepository: dependencies.listRepository,
            tagRepository: dependencies.tagRepository
        ) { taskID, selection in
            openTaskFromSearch(taskID: taskID, selection: selection)
        }
    }

    // MARK: - Detail Column

    @ViewBuilder
    private var detailColumn: some View {
        switch selectedContent ?? .spreads {
        case .spreads:
            spreadsDetailContent
        default:
            ContentUnavailableView("Select an item", systemImage: "sidebar.left")
        }
    }

    // MARK: - Spreads Detail

    @ViewBuilder
    private var spreadsDetailContent: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                if isSyncError { SyncErrorBanner() }
                SpreadContentPagerView(
                    coordinator: spreadsCoordinator,
                    syncEngine: syncEngine,
                    items: pickerItems,
                    currentSelection: currentSelection,
                    pagerSettledTargetID: $pagerSettledTargetID
                )
            }
            bottomInsetControls
        }
        .dotGridBackground(.paper, ignoresSafeAreaEdges: .all)
        .environment(spreadsCoordinator)
        .environment(journalManager)
        .localhostTemporalHarness(spreadDiagnostics: currentSpreadDiagnostics)
        .toolbar {
            // On regular width (iPad), show an explicit sidebar toggle since columnVisibility
            // is set to .detailOnly on spread selection and SwiftUI does not add one automatically.
            // On compact (iPhone), SwiftUI's NavigationSplitView injects its own back/sidebar button.
            if horizontalSizeClass == .regular {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation { columnVisibility = .automatic }
                    } label: {
                        Image(systemName: "sidebar.left")
                    }
                    .accessibilityLabel("Show spread list")
                }
            }
        }
    }

    // MARK: - Bottom Controls

    private var bottomInsetControls: some View {
        HStack(spacing: 12) {
            Spacer()
            Menu {
                Button(action: { spreadsCoordinator.showSpreadCreation() }) {
                    Label("Create Spread", systemImage: "book")
                }
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.CreateMenu.createSpread)

                Button(action: { spreadsCoordinator.showTaskCreation() }) {
                    Label("Create Task", systemImage: "circle.fill")
                }
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.CreateMenu.createTask)

                Button(action: { spreadsCoordinator.showNoteCreation() }) {
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
    }

    // MARK: - Computed Helpers

    /// The currently active spread selection, defaulting to the journal's default when unset.
    private var currentSelection: DataModel.Spread {
        spreadsCoordinator.selectedSelection ?? journalManager.defaultNavigationSelection
    }

    /// Picker items for the current selection's year — shared by the content column and pager.
    private var pickerItems: [SpreadPickerModel.Item] {
        journalManager.titleNavigatorModel.items(for: currentSelection)
    }

    private var spreadsCalendar: Calendar {
        journalManager.firstWeekday.configuredCalendar(from: journalManager.calendar)
    }

    private var isSyncError: Bool {
        guard let status = syncEngine?.status else { return false }
        if case .error = status { return true }
        return false
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

    // MARK: - Spreads Sheet Content

    @ViewBuilder
    private func spreadsSheetContent(for destination: SpreadsCoordinator.SheetDestination) -> some View {
        switch destination {
        case .spreadCreation(let prefill):
            SpreadCreationSheet(
                journalManager: journalManager,
                firstWeekday: journalManager.firstWeekday,
                initialPeriod: prefill?.period,
                initialDate: prefill?.date,
                onSpreadCreated: { result in
                    spreadsCoordinator.finishSpreadCreation(
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
                        spreadsCoordinator.finishSpreadDateEdit(updatedSpread)
                        Task { @MainActor in await syncEngine?.syncNow() }
                    }
                )
            } else {
                Color.clear
            }
        case .taskCreation:
            TaskCreationSheet(
                journalManager: journalManager,
                selectedSpread: currentSelection,
                onTaskCreated: { _ in
                    Task { @MainActor in await syncEngine?.syncNow() }
                }
            )
        case .noteCreation:
            NoteCreationSheet(
                journalManager: journalManager,
                selectedSpread: currentSelection,
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
                calendar: spreadsCalendar,
                today: journalManager.today,
                onClose: { spreadsCoordinator.dismiss() },
                onNavigate: { destination in
                    spreadsCoordinator.dismiss()
                    spreadsCoordinator.selectSpread(destination)
                },
                onTaskTap: nil
            )
        case .auth:
            AuthEntrySheet(authManager: authManager, isBlocking: false)
        }
    }

    // MARK: - Spread Actions

    private func deleteSpread(_ spread: DataModel.Spread) {
        spreadsCoordinator.dismissAlert()
        Task { @MainActor in
            do {
                try await journalManager.deleteSpread(spread)
                await syncEngine?.syncNow()
            } catch {
                spreadsCoordinator.showSpreadDeleteFailure(
                    message: "Failed to delete spread: \(error.localizedDescription)"
                )
            }
        }
    }

    // MARK: - Cross-tab Navigation

    private func openTaskFromSearch(taskID: UUID, selection: DataModel.Spread?) {
        selectedContent = .spreads
        let resolvedSelection = selection ?? fallbackSearchSelection()
        spreadsCoordinator.selectedSelection = resolvedSelection
        selectedColumnSpread = resolvedSelection
        if horizontalSizeClass == .regular {
            columnVisibility = .detailOnly
        }
        spreadsNavigationState.pendingRequest = SpreadsNavigationRequest(
            selection: resolvedSelection,
            taskID: taskID
        )
    }

    private func fallbackSearchSelection() -> DataModel.Spread {
        journalManager.bestSpread(for: journalManager.today)
            ?? journalManager.spreads.first
            ?? DataModel.Spread(period: .year, date: journalManager.today, calendar: journalManager.calendar)
    }

    // MARK: - Pending Navigation

    private func handlePendingNavigationRequest() {
        guard let request = spreadsNavigationState.pendingRequest else { return }

        spreadsCoordinator.selectedSelection = request.selection
        spreadsCoordinator.recenterToken += 1
        selectedColumnSpread = request.selection
        if horizontalSizeClass == .regular {
            columnVisibility = .detailOnly
        }

        guard let task = journalManager.tasks.first(where: { $0.id == request.taskID }) else {
            spreadsNavigationState.pendingRequest = nil
            return
        }

        Task { @MainActor in
            await Task.yield()
            spreadsCoordinator.showTaskDetail(task)
            spreadsNavigationState.pendingRequest = nil
        }
    }

    // MARK: - Selection Maintenance

    private func resetSelectionIfNeeded() {
        guard let spread = spreadsCoordinator.selectedSelection else { return }
        guard !journalManager.spreads.contains(where: { $0.id == spread.id }) else { return }

        let newSelection = journalManager.bestSpread(for: journalManager.today)
        spreadsCoordinator.selectedSelection = newSelection
        spreadsCoordinator.recenterToken += 1
        selectedColumnSpread = newSelection
    }

    // MARK: - Debug

    @ViewBuilder
    private var debugMenuView: some View {
        if let view = makeDebugMenuView?(
            dependencies, journalManager, authManager, syncEngine, appClock
        ) {
            view
        } else {
            Text("Debug tools unavailable")
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#Preview("Root navigation") {
    RootNavigationView(
        journalManager: .previewInstance,
        authManager: .makeForPreview(),
        dependencies: try! .makeForPreview(),
        appClock: .live()
    )
}
