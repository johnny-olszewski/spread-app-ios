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
    /// Incremented each time the navigator opens. Used as the navigator's identity so every
    /// open recreates it — reseeding the calendar's initial scroll to today's month even if
    /// a still-animating removal kept the previous instance (and its scroll offset) alive.
    @State private var navigatorPresentationToken = 0

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

    /// Explicit month spreads keyed by year, then normalized month start date — used by
    /// the navigator's card-style month headers and "View month" buttons.
    private var navigatorMonthSpreads: [Int: [Date: DataModel.Spread]]

    /// Explicit year spreads keyed by year — drives the navigator's "View year" chip
    /// above January.
    private var navigatorExplicitYearSpreads: [Int: DataModel.Spread]

    /// Pre-built disambiguation rows (year → date → options) for dates covered by 2+
    /// spreads, so day-tap popovers present without any tap-time computation.
    private var navigatorDayDisambiguationOptions: [Int: [Date: [NavigatorDaySelectionPopoverContent.Option]]]

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
        navigatorMonthSpreads = built.monthSpreads
        navigatorExplicitYearSpreads = built.explicitYearSpreads
        navigatorDayDisambiguationOptions = built.dayDisambiguationOptions

        let defaultSelection = journalManager.defaultNavigationSelection
        initialSelectedSpreadID = defaultSelection.id
        let initialYear = calendar.component(.year, from: defaultSelection.startDate ?? defaultSelection.date)
        _cachedYearSpreads = State(initialValue: Self.buildYearSpreads(
            spreads: journalManager.spreads,
            year: initialYear,
            calendar: calendar
        ))
    }

    /// Returns spreads in `year` sorted by start/date ascending, breaking start-date ties
    /// so the broader container renders first — a multiday spread precedes a day spread that
    /// starts on the same date (the multiday contains the day). Without this tiebreak the sort
    /// key is start-date only, leaving same-start-date collisions in an undefined order
    /// (Swift's sort is not guaranteed stable). [SPRD-314]
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
            .sorted { lhs, rhs in
                let lhsStart = lhs.startDate ?? lhs.date
                let rhsStart = rhs.startDate ?? rhs.date
                if lhsStart != rhsStart { return lhsStart < rhsStart }
                return pagerPeriodTiebreak(lhs.period) < pagerPeriodTiebreak(rhs.period)
            }
    }

    /// Broader-container-first period rank for `buildYearSpreads`' same-start-date tiebreak
    /// only: `year → month → multiday → day`, so a multiday precedes a day it contains.
    /// Deliberately distinct from the global `year, month, day, multiday` rank
    /// (`JournalManager.spreadPeriodSortOrder` / `Period.sortOrder`), which is unchanged. [SPRD-314]
    private static func pagerPeriodTiebreak(_ period: Period) -> Int {
        switch period {
        case .year: 0
        case .month: 1
        case .multiday: 2
        case .day: 3
        }
    }

    /// Builds `navigatorCalendarModels` and `navigatorYearSpreads` in a single pass over
    /// `spreads`. A `static` function (rather than inline `init` logic) so it's directly
    /// unit-testable without constructing a full `JournalManager`/SwiftUI environment.
    static func buildNavigatorCalendarData(
        spreads: [DataModel.Spread],
        calendar: Calendar
    ) -> (
        models: [Int: SpreadsNavigatorView.CalendarGenerator.Model],
        yearSpreads: [Int: [DataModel.Spread]],
        monthSpreads: [Int: [Date: DataModel.Spread]],
        explicitYearSpreads: [Int: DataModel.Spread],
        dayDisambiguationOptions: [Int: [Date: [NavigatorDaySelectionPopoverContent.Option]]]
    ) {
        var models = [Int: SpreadsNavigatorView.CalendarGenerator.Model]()
        var yearSpreads = [Int: [DataModel.Spread]]()
        var monthSpreads = [Int: [Date: DataModel.Spread]]()
        var explicitYearSpreads = [Int: DataModel.Spread]()
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
            case .month:
                let year = calendar.component(.year, from: spread.date)
                let monthStart = Period.month.normalizeDate(spread.date, calendar: calendar)
                monthSpreads[year, default: [:]][monthStart] = spread
            case .year:
                explicitYearSpreads[calendar.component(.year, from: spread.date)] = spread
            }
        }

        // Pre-build disambiguation option rows for every date covered by 2+ spreads, so a
        // day tap presents the popover with zero label/formatter work at tap time.
        let dayFormatter = DateFormatter()
        dayFormatter.calendar = calendar
        dayFormatter.timeZone = calendar.timeZone
        dayFormatter.dateStyle = .medium
        let rangeFormatter = DateIntervalFormatter()
        rangeFormatter.calendar = calendar
        rangeFormatter.timeZone = calendar.timeZone
        rangeFormatter.dateStyle = .medium
        rangeFormatter.timeStyle = .none

        var dayDisambiguationOptions = [Int: [Date: [NavigatorDaySelectionPopoverContent.Option]]]()
        for (year, model) in models {
            for (date, covering) in model where covering.count >= 2 {
                let ordered = covering.sorted { lhs, rhs in
                    if lhs.period != rhs.period { return lhs.period == .day }
                    return (lhs.startDate ?? lhs.date) < (rhs.startDate ?? rhs.date)
                }
                dayDisambiguationOptions[year, default: [:]][date] = ordered.map { spread in
                    if spread.period == .day {
                        return .init(
                            spread: spread,
                            title: "Day spread",
                            subtitle: dayFormatter.string(from: spread.date),
                            icon: .sun
                        )
                    }
                    let rangeString = rangeFormatter.string(
                        from: spread.startDate ?? spread.date,
                        to: spread.endDate ?? spread.date
                    )
                    if let customName = spread.customName, !customName.isEmpty {
                        return .init(spread: spread, title: customName, subtitle: rangeString, icon: .rows)
                    }
                    return .init(spread: spread, title: rangeString, subtitle: "Multiday spread", icon: .rows)
                }
            }
        }

        return (
            models: models,
            yearSpreads: yearSpreads,
            monthSpreads: monthSpreads,
            explicitYearSpreads: explicitYearSpreads,
            dayDisambiguationOptions: dayDisambiguationOptions
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                if isNavigatorVisible && horizontalSizeClass == .regular {
                    spreadsNavigatorView
                        .id(navigatorPresentationToken)
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
                            setNavigatorVisible(!isNavigatorVisible)
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
            set: { setNavigatorVisible($0) }
        )) {
            spreadsNavigatorView
                .id(navigatorPresentationToken)
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
        let calendar = spreadsCalendar
        let today = journalManager.today
        let spreads = journalManager.spreads
        let firstWeekday = journalManager.firstWeekday
        let formatter = SpreadDisplayNameFormatter(calendar: calendar, today: today, firstWeekday: firstWeekday)
        let selectedPeriod = spreadsCoordinator.selectedSpread?.period

        var topInsetButtons: [SpreadButton.ViewModel] = []

        if let spread = spreads.first(where: { $0.period == .year && $0.contains(date: today, calendar: calendar) }) {
            topInsetButtons.append(SpreadButton.ViewModel(
                title: SpreadDisplayNameFormatter.canonicalTitle(for: spread, calendar: calendar),
                subtitle: "This year",
                style: selectedPeriod == .year ? .tonal : .plain,
                size: .small,
                action: {
                    spreadsCoordinator.navigate(to: spread, shouldRecenter: true, scrollsToToday: true)
                    withAnimation { isNavigatorVisible = false }
                }
            ))
        }

        if let spread = spreads.first(where: { $0.period == .month && $0.contains(date: today, calendar: calendar) }) {
            topInsetButtons.append(SpreadButton.ViewModel(
                title: SpreadDisplayNameFormatter.canonicalTitle(for: spread, calendar: calendar),
                subtitle: "This month",
                style: selectedPeriod == .month ? .tonal : .plain,
                size: .small,
                action: {
                    spreadsCoordinator.navigate(to: spread, shouldRecenter: true)
                    withAnimation { isNavigatorVisible = false }
                }
            ))
        }

        if let spread = spreads.first(where: { $0.period == .multiday && $0.contains(date: today, calendar: calendar) }) {
            let label = formatter.display(for: spread, allowsPersonalization: true).primary
            topInsetButtons.append(SpreadButton.ViewModel(
                title: label,
                style: selectedPeriod == .multiday ? .tonal : .plain,
                size: .small,
                action: {
                    spreadsCoordinator.navigate(to: spread, shouldRecenter: true, scrollsToToday: true)
                    withAnimation { isNavigatorVisible = false }
                }
            ))
        }

        if let spread = spreads.first(where: { $0.period == .day && $0.contains(date: today, calendar: calendar) }) {
            topInsetButtons.append(SpreadButton.ViewModel(
                title: "Today",
                style: selectedPeriod == .day ? .tonal : .plain,
                size: .small,
                action: {
                    spreadsCoordinator.navigate(to: spread, shouldRecenter: true)
                    withAnimation { isNavigatorVisible = false }
                }
            ))
        }

        return SpreadsNavigatorView(
            calendarModels: navigatorCalendarModels,
            yearSpreads: navigatorYearSpreads,
            selectedYear: $spreadsCoordinator.selectedYear,
            selectedSpread: Binding(
                get: { spreadsCoordinator.selectedSpread },
                set: {
                    guard let spread = $0 else { return }
                    spreadsCoordinator.navigate(to: spread)
                    // Every navigation out of the navigator collapses it, matching the
                    // context buttons. withAnimation overrides the tap path's
                    // animation-disabled transaction so the pane close still animates.
                    withAnimation { isNavigatorVisible = false }
                }
            ),
            coordinator: spreadsCoordinator,
            today: today,
            calendar: calendar,
            topInsetButtons: topInsetButtons,
            monthSpreads: navigatorMonthSpreads,
            explicitYearSpreads: navigatorExplicitYearSpreads,
            dayDisambiguationOptions: navigatorDayDisambiguationOptions
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

    /// Opens or closes the navigator in a single animated transaction.
    ///
    /// When opening, `navigatorPresentationToken` is bumped **in the same transaction** as
    /// `isNavigatorVisible` — not afterwards via `onChange` — so the regular-width column is
    /// inserted exactly once with its final `.id`. Bumping the token a beat later swapped the
    /// just-inserted view's identity mid-flight, tearing it down and re-inserting it, which
    /// collapsed the `.move(edge: .leading)` slide into SwiftUI's default opacity fade. The
    /// token still changes on every open, so the calendar re-runs its scroll-to-selection.
    private func setNavigatorVisible(_ visible: Bool) {
        withAnimation(SpreadTheme.Motion.spring) {
            if visible { navigatorPresentationToken += 1 }
            isNavigatorVisible = visible
        }
    }

    /// Re-resolves the selection when the current spread is removed from the journal
    /// (e.g. deleted via sync), falling back to the best spread for today.
    private func resetSelectionIfNeeded() {
        guard let spread = spreadsCoordinator.selectedSpread else { return }
        guard !journalManager.spreads.contains(where: { $0.id == spread.id }) else { return }

        guard let newSelection = journalManager.bestSpread(for: journalManager.today) else { return }
        spreadsCoordinator.navigate(to: newSelection)
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
