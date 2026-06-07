import SwiftUI

/// Self-contained Spreads tab content.
///
/// Lays out the calendar content column (`SpreadsContentColumnView`) as a togglable
/// left pane alongside the spread detail pager as the right pane in a top-level `HStack`.
///
/// Owns all Spreads-specific navigation state — `spreadsCoordinator`, the selected
/// spread, pager scroll position, and year selection — so it survives size class
/// transitions without `RootNavigationView` needing to mirror or coordinate it.
///
/// On regular width, a single leading toolbar button toggles `isContentColumnVisible`,
/// sliding the left pane in/out inline. On compact width, the same toggle presents the
/// left pane as a `.fullScreenCover` instead.
struct SpreadsTabView: View {

    let journalManager: JournalManager
    let authManager: AuthManager
    let syncEngine: SyncEngine?

    /// Shared cross-tab navigation state. `RootNavigationView` populates `pendingRequest`
    /// when a search result from another tab requests navigation to a spread/task here.
    let spreadsNavigationState: SpreadsNavigationState

    // MARK: - Spreads-owned Navigation State

    @State private var spreadsCoordinator = SpreadsCoordinator()
    @State private var selectedSpread: DataModel.Spread?
    /// Lifted so it survives size class transitions, mirroring the prior root-owned approach.
    @State private var pagerSettledTargetID: String?
    /// Year displayed in the content column's calendar — owned here so it persists
    /// across pane show/hide and size class transitions; the picker UI lives in
    /// `SpreadsContentColumnView` itself.
    @State private var selectedYear: Int
    /// Whether the calendar content pane is shown — inline on regular width,
    /// as a full-screen cover on compact width.
    @State private var isContentColumnVisible = false

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: - Init

    init(
        journalManager: JournalManager,
        authManager: AuthManager,
        syncEngine: SyncEngine?,
        spreadsNavigationState: SpreadsNavigationState
    ) {
        self.journalManager = journalManager
        self.authManager = authManager
        self.syncEngine = syncEngine
        self.spreadsNavigationState = spreadsNavigationState
        let calendar = journalManager.firstWeekday.configuredCalendar(from: journalManager.calendar)
        _selectedYear = State(initialValue: calendar.component(.year, from: journalManager.today))
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            if horizontalSizeClass == .regular && isContentColumnVisible {
                contentColumn
                    .frame(minWidth: 320, idealWidth: 360, maxWidth: 420)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
            detailContent
        }
        .animation(.easeInOut(duration: 0.25), value: isContentColumnVisible)
        .fullScreenCover(isPresented: compactCoverBinding) {
            NavigationStack {
                contentColumn
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { isContentColumnVisible = false }
                        }
                    }
            }
        }
        .sheet(item: Binding(
            get: { spreadsCoordinator.activeSheet },
            set: { spreadsCoordinator.activeSheet = $0 }
        )) { destination in
            spreadsSheetContent(for: destination)
        }
        .modifier(AlertModelModifier(
            model: activeAlertModel,
            isPresented: Binding(
                get: { spreadsCoordinator.activeAlert != nil },
                set: { if !$0 { spreadsCoordinator.activeAlert = nil } }
            )
        ))
        .onAppear {
            if spreadsCoordinator.selectedSelection == nil {
                spreadsCoordinator.selectedSelection = journalManager.defaultNavigationSelection
                selectedSpread = spreadsCoordinator.selectedSelection
            }
        }
        // Content column selection → update coordinator and hide the pane.
        // Guard prevents redundant updates when the change originated from a pager swipe sync.
        .onChange(of: selectedSpread) { _, newValue in
            guard let spread = newValue else { return }
            guard spread.id != spreadsCoordinator.selectedSelection?.id else { return }
            spreadsCoordinator.selectedSelection = spread
            spreadsCoordinator.clearConvenienceNavigation()
            hideContentColumn()
        }
        // Pager settle → sync content column highlight without forcing the pane to hide.
        .onChange(of: spreadsCoordinator.selectedSelection) { _, newValue in
            guard newValue?.id != selectedSpread?.id else { return }
            selectedSpread = newValue
        }
        .onChange(of: spreadsNavigationState.pendingRequest?.id) { _, _ in
            handlePendingNavigationRequest()
        }
        .onChange(of: journalManager.dataVersion) { _, _ in
            resetSelectionIfNeeded()
        }
    }

    // MARK: - Content Column (Left Pane)

    private var contentColumn: some View {
        SpreadsContentColumnView(
            spreads: journalManager.spreads,
            selectedYear: $selectedYear,
            today: journalManager.today,
            calendar: spreadsCalendar,
            selectedSpread: $selectedSpread
        )
    }

    // MARK: - Detail Content (Right Pane)

    @ViewBuilder
    private var detailContent: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                spreadDetailTitle
                if isSyncError { SyncErrorBanner() }
                SpreadContentPagerView(
                    coordinator: spreadsCoordinator,
                    syncEngine: syncEngine,
                    items: pickerItems,
                    currentSelection: currentSelection,
                    pagerSettledTargetID: $pagerSettledTargetID
                )
                .ignoresSafeArea(edges: .bottom)
            }
            bottomInsetControls
        }
        .dotGridBackground(.paper, ignoresSafeAreaEdges: .all)
        .environment(spreadsCoordinator)
        .environment(journalManager)
        .localhostTemporalHarness(spreadDiagnostics: currentSpreadDiagnostics)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isContentColumnVisible.toggle()
                    }
                } label: {
                    Image(systemName: isContentColumnVisible ? "chevron.left" : "calendar")
                }
                .accessibilityLabel(isContentColumnVisible ? "Hide spread list" : "Show spread list")
                .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: .leading)))
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                let todayTarget = journalManager.todayNavigationSelection ?? journalManager.defaultNavigationSelection
                let isOnToday = currentSelection.id == journalManager.todayNavigationSelection?.id
                if !isOnToday {
                    Button {
                        spreadsCoordinator.navigate(to: todayTarget)
                    } label: {
                        Label("Today", systemImage: "calendar")
                    }
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadToolbar.todayButton)
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
                }

                if let syncEngine {
                    SyncIconButton(
                        status: syncEngine.status,
                        outboxCount: syncEngine.outboxCount,
                        onSyncNow: { Task { @MainActor in await syncEngine.syncNow() } }
                    )
                }
                AuthButton(isSignedIn: authManager.state.isSignedIn) {
                    spreadsCoordinator.showAuth()
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: currentSelection.id)
    }

    /// In-content title header for the detail pane — shows the current spread's title
    /// and optional subtitle, updating dynamically as the selection changes.
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
        .animation(.easeInOut(duration: 0.15), value: currentSelection.id)
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

    // MARK: - Pane Visibility

    /// Drives `.fullScreenCover` on compact width only — on regular width the pane
    /// renders inline in the `HStack`, so the cover must stay dismissed there even
    /// while `isContentColumnVisible` is `true`.
    private var compactCoverBinding: Binding<Bool> {
        Binding(
            get: { horizontalSizeClass == .compact && isContentColumnVisible },
            set: { newValue in
                if !newValue { isContentColumnVisible = false }
            }
        )
    }

    /// Hides the content column — collapses the inline pane on regular width and
    /// dismisses the full-screen cover on compact width (both driven by the same flag).
    private func hideContentColumn() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isContentColumnVisible = false
        }
    }

    // MARK: - Computed Helpers

    /// The currently active spread selection, defaulting to the journal's default when unset.
    private var currentSelection: DataModel.Spread {
        spreadsCoordinator.selectedSelection ?? journalManager.defaultNavigationSelection
    }

    /// Picker items for the current selection's year — used by the spread pager.
    private var pickerItems: [SpreadPickerModel.Item] {
        journalManager.titleNavigatorModel.items(for: currentSelection)
    }

    /// Extracts the `AlertModel` from the active alert destination for generic rendering.
    private var activeAlertModel: AlertModel? {
        guard case .alert(let model) = spreadsCoordinator.activeAlert else { return nil }
        return model
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

    // MARK: - Pending Navigation

    /// Reacts to a cross-tab navigation request populated by `RootNavigationView`
    /// (e.g. tapping a search result while on the Entries tab): selects the target
    /// spread, hides the content column, and opens the requested task detail.
    private func handlePendingNavigationRequest() {
        guard let request = spreadsNavigationState.pendingRequest else { return }

        spreadsCoordinator.selectedSelection = request.selection
        spreadsCoordinator.recenterToken += 1
        selectedSpread = request.selection
        hideContentColumn()

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

    /// Re-resolves the selection when the current spread is removed from the journal
    /// (e.g. deleted via sync), falling back to the best spread for today.
    private func resetSelectionIfNeeded() {
        guard let spread = spreadsCoordinator.selectedSelection else { return }
        guard !journalManager.spreads.contains(where: { $0.id == spread.id }) else { return }

        let newSelection = journalManager.bestSpread(for: journalManager.today)
        spreadsCoordinator.selectedSelection = newSelection
        spreadsCoordinator.recenterToken += 1
        selectedSpread = newSelection
    }
}

// MARK: - Preview

#Preview("Spreads tab") {
    SpreadsTabView(
        journalManager: .previewInstance,
        authManager: .makeForPreview(),
        syncEngine: nil,
        spreadsNavigationState: SpreadsNavigationState()
    )
}
