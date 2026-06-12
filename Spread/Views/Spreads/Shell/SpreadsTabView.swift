import SwiftUI
import JohnnyOFoundationUI

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
    @State private var shouldShowSpreadsNavigatorSheet = false
    @State private var shouldShowSpreadsNavigatorColumn = false

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    /// Whether the calendar content pane is shown — inline on regular width,
    /// as a full-screen cover on compact width.
    private var isContentColumnVisible: Bool {
        shouldShowSpreadsNavigatorColumn || shouldShowSpreadsNavigatorSheet
    }
    /// The currently active spread selection, defaulting to the journal's default when unset.
    private var currentSelection: DataModel.Spread {
        spreadsCoordinator.selectedSpread ?? journalManager.defaultNavigationSelection
    }

    /// Spreads in the same year as the current selection — used by the spread pager.
    private var yearSpreads: [DataModel.Spread] {
        let year = spreadsCalendar.component(.year, from: currentSelection.startDate ?? currentSelection.date)
        return journalManager.spreads
            .filter { spreadsCalendar.component(.year, from: $0.startDate ?? $0.date) == year }
            .sorted { ($0.startDate ?? $0.date) < ($1.startDate ?? $1.date) }
    }

    private var spreadsCalendar: Calendar {
        journalManager.firstWeekday.configuredCalendar(from: journalManager.calendar)
    }

    /// `CalendarGenerator.Model` keyed by calendar year, built from `journalManager.spreads`.
    ///
    /// Computed here — in the parent's observation-tracking scope — so `SpreadsNavigatorView`
    /// receives an already-built model on every show, paying no per-render iteration cost.
    /// Only `.day` and `.multiday` spreads contribute; `.year` and `.month` are excluded,
    /// matching the navigator's display semantics.
    private var navigatorCalendarModels: [Int: SpreadsNavigatorView.CalendarGenerator.Model]

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
        
        // `spreadsCalendar` is a computed property on `self`, which isn't fully initialized
        // yet at this point in init. Inline the calendar construction from the already-assigned
        // `journalManager` instead.
        let calendar = journalManager.firstWeekday.configuredCalendar(from: journalManager.calendar)
        navigatorCalendarModels = {
            var result = [Int: SpreadsNavigatorView.CalendarGenerator.Model]()
            for spread in journalManager.spreads {
                switch spread.period {
                case .day:
                    let year = calendar.component(.year, from: spread.date)
                    let dayStart = spread.date.startOfDay(calendar: calendar)
                    result[year, default: SpreadsNavigatorView.CalendarGenerator.Model()][dayStart, default: []].append(spread)
                case .multiday:
                    guard let startDate = spread.startDate, let endDate = spread.endDate else { continue }
                    var date = startDate
                    while date <= endDate {
                        let year = calendar.component(.year, from: date)
                        let dayStart = date.startOfDay(calendar: calendar)
                        result[year, default: SpreadsNavigatorView.CalendarGenerator.Model()][dayStart, default: []].append(spread)
                        guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
                        date = next
                    }
                case .year, .month:
                    continue
                }
            }
            return result
        }()
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                if shouldShowSpreadsNavigatorColumn && horizontalSizeClass == .regular {
                    spreadsNavigatorView
                        .background(.ultraThinMaterial.opacity(0.65))
                        .clipShape(RoundedRectangle(cornerRadius: SpreadTheme.CornerRadius.card))
                        .padding(.horizontal, SpreadTheme.Spacing.medium)
                        .containerRelativeFrame(.horizontal, count: 10, span: 4, spacing: 0)
                        .transition(.move(edge: .leading))
                }

                SpreadContentPagerView(
                    coordinator: spreadsCoordinator,
                    syncEngine: syncEngine,
                    spreads: yearSpreads,
                    currentSelection: currentSelection
                )
                .environment(spreadsCoordinator)
                .environment(journalManager)
                .overlay(alignment: .bottom) {
                    bottomInsetControls
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            withAnimation {
                                switch horizontalSizeClass {
                                case .regular:
                                    shouldShowSpreadsNavigatorColumn.toggle()
                                default:
                                    shouldShowSpreadsNavigatorSheet.toggle()
                                }
                            }
                        } label: {
                            Image(systemName: isContentColumnVisible ? "chevron.left" : "calendar")
                        }
                        .accessibilityLabel(isContentColumnVisible ? "Hide spread list" : "Show spread list")
                    }

                    ToolbarItem(placement: .automatic) {
                        if let syncEngine {
                            SyncIconButton(
                                status: syncEngine.status,
                                outboxCount: syncEngine.outboxCount,
                                onSyncNow: { Task { @MainActor in await syncEngine.syncNow() } }
                            )
                        }
                    }

                    ToolbarItem(placement: .automatic) {
                        AuthButton(isSignedIn: authManager.state.isSignedIn) {
                            spreadsCoordinator.showAuth()
                        }
                    }
                }
            }
            .dotGridBackground(.paper, ignoresSafeAreaEdges: .all)
        }
        .fullScreenCover(isPresented: $shouldShowSpreadsNavigatorSheet) {
            spreadsNavigatorView
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { shouldShowSpreadsNavigatorSheet = false }
                    }
                }
        }
        .onChange(of: horizontalSizeClass) {
            shouldShowSpreadsNavigatorSheet = false
            shouldShowSpreadsNavigatorColumn = false
        }
        .sheet(item: $spreadsCoordinator.activeSheet) { destination in
            spreadsSheetContent(for: destination)
        }
        // TODO: Re-add alert
//        .modifier(AlertModelModifier(
//            model: activeAlertModel,
//            isPresented: Binding(
//                get: { spreadsCoordinator.activeAlert != nil },
//                set: { if !$0 { spreadsCoordinator.activeAlert = nil } }
//            )
//        ))
        .onChange(of: journalManager.dataVersion) { _, _ in
            resetSelectionIfNeeded()
        }
    }
    
    private var spreadsNavigatorView: some View {
        SpreadsNavigatorView(
            calendarModels: navigatorCalendarModels,
            selectedYear: $spreadsCoordinator.selectedYear,
            selectedSpread: $spreadsCoordinator.selectedSpread,
            today: journalManager.today,
            calendar: spreadsCalendar
        )
    }
    
    /// Re-resolves the selection when the current spread is removed from the journal
    /// (e.g. deleted via sync), falling back to the best spread for today.
    private func resetSelectionIfNeeded() {
        guard let spread = spreadsCoordinator.selectedSpread else { return }
        guard !journalManager.spreads.contains(where: { $0.id == spread.id }) else { return }

        let newSelection = journalManager.bestSpread(for: journalManager.today)
        spreadsCoordinator.selectedSpread = newSelection
        spreadsCoordinator.recenterToken += 1
    }

    // MARK: - Bottom Controls

    private var bottomInsetControls: some View {
        HStack(spacing: 12) {
            
            Spacer()
            
            Menu {
                Button {
                    spreadsCoordinator.activeSheet = .spreadCreation(nil)
                } label: {
                    Label("Create Spread", systemImage: "book")
                }
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.CreateMenu.createSpread)

                Button {
                    spreadsCoordinator.activeSheet = .taskCreation
                } label: {
                    Label("Create Task", systemImage: "circle.fill")
                }
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.CreateMenu.createTask)

                Button {
                    spreadsCoordinator.activeSheet = .noteCreation
                } label: {
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
        .padding(.all, SpreadTheme.Spacing.large)
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
