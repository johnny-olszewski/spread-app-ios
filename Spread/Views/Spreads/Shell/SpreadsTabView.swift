import SwiftUI
import JohnnyOFoundationUI

/// Self-contained Spreads tab content.
///
/// Lays out the calendar content column (`SpreadsNavigatorView`) as a togglable
/// left pane alongside the spread detail pager as the right pane in a top-level `HStack`.
///
/// Owns all Spreads-specific navigation state — `spreadsCoordinator`, the selected
/// spread, pager scroll position, and year selection — so it survives size class
/// transitions without `RootNavigationView` needing to mirror or coordinate it.
///
/// A single `isNavigatorVisible` boolean tracks user intent. Presentation mode is
/// determined at render time: inline column on regular width, full-screen cover on compact.
/// Visibility is preserved across size class changes — rotating from portrait to landscape
/// while the navigator is open switches from cover to column automatically.
struct SpreadsTabView: View {

    let journalManager: JournalManager
    let authManager: AuthManager
    let syncEngine: SyncEngine?

    /// Shared cross-tab navigation state. `RootNavigationView` populates `pendingRequest`
    /// when a search result from another tab requests navigation to a spread/task here.
    let spreadsNavigationState: SpreadsNavigationState

    // MARK: - Spreads-owned Navigation State

    @State private var spreadsCoordinator = SpreadsCoordinator()
    /// Whether the navigator is shown. Presentation mode (inline column vs. full-screen cover)
    /// is determined at render time by `horizontalSizeClass` — this boolean encodes only intent.
    @State private var isNavigatorVisible = false

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// The currently active spread selection, defaulting to the journal's default when unset.
    private var currentSelection: DataModel.Spread {
        spreadsCoordinator.selectedSpread ?? journalManager.defaultNavigationSelection
    }

    /// Spreads in the same year as the current selection — used by the spread pager.
    ///
    /// Cached as `@State` so that intra-year scroll settles (which update
    /// `spreadsCoordinator.selectedSpread` via `syncSelectionFromSettledID`) do not produce
    /// a new array and re-render `SpreadContentPagerView`. Updated only when the selection
    /// crosses a calendar year boundary or when the spread collection grows/shrinks.
    @State private var cachedYearSpreads: [DataModel.Spread]

    private var spreadsCalendar: Calendar {
        journalManager.configuredCalendar
    }

    /// Calendar year derived from the current spread selection. Used as the `onChange` key
    /// for updating `cachedYearSpreads` only when the user actually crosses a year boundary.
    private var currentSelectionYear: Int {
        spreadsCalendar.component(.year, from: currentSelection.startDate ?? currentSelection.date)
    }

    /// Stable spread ID seeded from `journalManager.defaultNavigationSelection` at init time.
    /// Passed to `SpreadContentPagerView` as `initialSelectedSpreadID` so the pager's `@State`
    /// is seeded once without requiring `currentSelection` as a changing init param.
    private let initialSelectedSpreadID: UUID

    /// `CalendarGenerator.Model` keyed by calendar year, built from `journalManager.spreads`.
    ///
    /// Computed here — in the parent's observation-tracking scope — so `SpreadsNavigatorView`
    /// receives an already-built model on every show, paying no per-render iteration cost.
    /// Only `.day` and `.multiday` spreads contribute; `.year` and `.month` are excluded,
    /// matching the navigator's display semantics.
    private var navigatorCalendarModels: [Int: SpreadsNavigatorView.CalendarGenerator.Model]

    /// Unique `.day`/`.multiday` spreads per calendar year, built in the same pass as
    /// `navigatorCalendarModels`. `SpreadsNavigatorView` looks this up directly for
    /// `selectedYear` rather than deriving it by flat-mapping and deduping the model on every
    /// render — that walk is now paid once here, at the same lifecycle point as the model itself.
    private var navigatorYearSpreads: [Int: [DataModel.Spread]]

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
        let calendar = journalManager.configuredCalendar
        let built = Self.buildNavigatorCalendarData(spreads: journalManager.spreads, calendar: calendar)
        navigatorCalendarModels = built.models
        navigatorYearSpreads = built.yearSpreads

        let defaultSelection = journalManager.defaultNavigationSelection
        initialSelectedSpreadID = defaultSelection.id
        let initialYear = calendar.component(.year, from: defaultSelection.startDate ?? defaultSelection.date)
        _cachedYearSpreads = State(initialValue: Self.buildYearSpreads(
            spreads: journalManager.spreads,
            year: initialYear,
            calendar: calendar
        ))
    }

    /// Returns spreads in `year` sorted by start/date ascending.
    ///
    /// A `static` function so it can be called from both `init` and `onChange` handlers
    /// without capturing `self`, and tested directly without a full SwiftUI environment.
    static func buildYearSpreads(
        spreads: [DataModel.Spread],
        year: Int,
        calendar: Calendar
    ) -> [DataModel.Spread] {
        spreads
            .filter { calendar.component(.year, from: $0.startDate ?? $0.date) == year }
            .sorted { ($0.startDate ?? $0.date) < ($1.startDate ?? $1.date) }
    }

    /// Builds `navigatorCalendarModels` and `navigatorYearSpreads` in a single pass over
    /// `spreads`. A `static` function (rather than inline `init` logic) so it's directly
    /// unit-testable without constructing a full `JournalManager`/SwiftUI environment.
    static func buildNavigatorCalendarData(
        spreads: [DataModel.Spread],
        calendar: Calendar
    ) -> (models: [Int: SpreadsNavigatorView.CalendarGenerator.Model], yearSpreads: [Int: [DataModel.Spread]]) {
        var models = [Int: SpreadsNavigatorView.CalendarGenerator.Model]()
        var yearSpreads = [Int: [DataModel.Spread]]()
        var seenSpreadIDsByYear = [Int: Set<UUID>]()

        for spread in spreads {
            switch spread.period {
            case .day:
                let year = calendar.component(.year, from: spread.date)
                let dayStart = spread.date.startOfDay(calendar: calendar)
                models[year, default: SpreadsNavigatorView.CalendarGenerator.Model()][dayStart, default: []].append(spread)
                if seenSpreadIDsByYear[year, default: []].insert(spread.id).inserted {
                    yearSpreads[year, default: []].append(spread)
                }
            case .multiday:
                guard let startDate = spread.startDate, let endDate = spread.endDate else { continue }
                var date = startDate
                while date <= endDate {
                    let year = calendar.component(.year, from: date)
                    let dayStart = date.startOfDay(calendar: calendar)
                    models[year, default: SpreadsNavigatorView.CalendarGenerator.Model()][dayStart, default: []].append(spread)
                    if seenSpreadIDsByYear[year, default: []].insert(spread.id).inserted {
                        yearSpreads[year, default: []].append(spread)
                    }
                    guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
                    date = next
                }
            case .year, .month:
                continue
            }
        }

        return (models: models, yearSpreads: yearSpreads)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                if isNavigatorVisible && horizontalSizeClass == .regular {
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
                    spreads: cachedYearSpreads,
                    initialSelectedSpreadID: initialSelectedSpreadID,
                    calendar: journalManager.calendar,
                    today: journalManager.today,
                    firstWeekday: journalManager.firstWeekday
                )
                .environment(spreadsCoordinator)
                .environment(journalManager)
                .overlay(alignment: .bottom) {
                    bottomInsetControls
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            withAnimation { isNavigatorVisible.toggle() }
                        } label: {
                            (isNavigatorVisible ? SpreadTheme.Icon.caretLeft : SpreadTheme.Icon.calendar)
                                .sized(SpreadTheme.IconSize.medium)
                                .iconTint(.primary)
                                .frame(width: 44, height: 44)
                                .contentShape(Circle())
                        }
                        .accessibilityLabel(isNavigatorVisible ? "Hide spread list" : "Show spread list")
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
        .fullScreenCover(isPresented: Binding(
            get: { isNavigatorVisible && horizontalSizeClass != .regular },
            set: { isNavigatorVisible = $0 }
        )) {
            spreadsNavigatorView
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { isNavigatorVisible = false }
                    }
                }
        }
        .sheet(item: $spreadsCoordinator.activeSheet) { destination in
            spreadsSheetContent(for: destination)
        }
        .modifier(AlertModelModifier(
            model: activeAlertModel,
            isPresented: Binding(
                get: { spreadsCoordinator.activeAlert != nil },
                set: { if !$0 { spreadsCoordinator.activeAlert = nil } }
            )
        ))
        .onChange(of: journalManager.dataVersion) { _, _ in
            resetSelectionIfNeeded()
        }
        // Rebuild the pager's spread list when the user crosses a calendar year boundary.
        .onChange(of: currentSelectionYear) { _, newYear in
            cachedYearSpreads = Self.buildYearSpreads(
                spreads: journalManager.spreads,
                year: newYear,
                calendar: spreadsCalendar
            )
        }
        // Rebuild when spreads are added or removed so newly created spreads appear in the pager.
        .onChange(of: journalManager.spreads.count) { _, _ in
            cachedYearSpreads = Self.buildYearSpreads(
                spreads: journalManager.spreads,
                year: currentSelectionYear,
                calendar: spreadsCalendar
            )
        }
    }
    
    private var spreadsNavigatorView: some View {
        SpreadsNavigatorView(
            calendarModels: navigatorCalendarModels,
            yearSpreads: navigatorYearSpreads,
            selectedYear: $spreadsCoordinator.selectedYear,
            selectedSpread: Binding(
                get: { spreadsCoordinator.selectedSpread },
                set: { if let spread = $0 { spreadsCoordinator.navigate(to: spread) } }
            ),
            today: journalManager.today,
            calendar: spreadsCalendar
        )
    }
    
    /// The `AlertModel` to present for `spreadsCoordinator.activeAlert`, or `nil` when no
    /// alert is active. `AlertDestination` currently has only one case (`.alert(AlertModel)`),
    /// so this just unwraps it — kept as its own property so the modifier call site stays simple.
    private var activeAlertModel: AlertModel? {
        if case .alert(let model) = spreadsCoordinator.activeAlert {
            return model
        }
        return nil
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
                    Label {
                        Text("Create Spread")
                    } icon: {
                        SpreadTheme.Icon.book.sized(SpreadTheme.IconSize.medium)
                    }
                }
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.CreateMenu.createSpread)

                Button {
                    spreadsCoordinator.activeSheet = .taskCreation
                } label: {
                    Label {
                        Text("Create Task")
                    } icon: {
                        SpreadTheme.Icon.circleFilled.sized(SpreadTheme.IconSize.medium)
                    }
                }
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.CreateMenu.createTask)

                Button {
                    spreadsCoordinator.activeSheet = .noteCreation
                } label: {
                    Label {
                        Text("Create Note")
                    } icon: {
                        SpreadTheme.Icon.minus.sized(SpreadTheme.IconSize.medium)
                    }
                }
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.CreateMenu.createNote)
            } label: {
                SpreadTheme.Icon.plus.sized(SpreadTheme.IconSize.extraLarge)
                    .padding(8)
                    .iconTint(.white)
                    .glassEffect(.regular.tint(SpreadTheme.Accent.primary), in: Circle())
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
            SpreadNameEntrySheet(
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
            TaskEntrySheet(
                journalManager: journalManager,
                selectedSpread: currentSelection,
                onTaskCreated: { _ in
                    Task { @MainActor in await syncEngine?.syncNow() }
                }
            )
        case .noteCreation:
            NoteEntrySheet(
                journalManager: journalManager,
                selectedSpread: currentSelection,
                onNoteCreated: { _ in
                    Task { @MainActor in await syncEngine?.syncNow() }
                }
            )
        case .taskDetail(let task):
            TaskEntrySheet(
                task: task,
                journalManager: journalManager,
                onDelete: {
                    Task { @MainActor in await syncEngine?.syncNow() }
                }
            )
        case .noteDetail(let note):
            NoteEntrySheet(
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
