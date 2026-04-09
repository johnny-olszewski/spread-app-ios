import SwiftUI

enum TraditionalNavigationDestination: Hashable {
    case month(Date)
    case day(Date)
}

private enum TraditionalSheetDestination: Identifiable {
    case inbox
    case auth

    var id: String {
        switch self {
        case .inbox: "inbox"
        case .auth: "auth"
        }
    }
}

struct TraditionalSpreadsView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Bindable var journalManager: JournalManager
    let authManager: AuthManager
    let syncEngine: SyncEngine?
    private let recommendationProvider: any SpreadTitleNavigatorRecommendationProviding = TodayMissingSpreadRecommendationProvider()

    @State private var selectedSelection: SpreadHeaderNavigatorModel.Selection?
    @State private var activeSheet: TraditionalSheetDestination?
    @State private var recenterToken = 0

    private var defaultRootYearDate: Date {
        let calendar = journalManager.calendar
        let year = calendar.component(.year, from: journalManager.today)
        return calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
    }

    private var navigatorModel: SpreadHeaderNavigatorModel {
        SpreadHeaderNavigatorModel(
            mode: .traditional,
            calendar: journalManager.calendar,
            today: journalManager.today,
            spreads: journalManager.spreads,
            tasks: journalManager.tasks,
            notes: journalManager.notes,
            events: FeatureFlags.eventsEnabled ? journalManager.events : []
        )
    }

    private var stripModel: SpreadTitleNavigatorModel {
        SpreadTitleNavigatorModel(
            headerModel: navigatorModel,
            overdueItems: journalManager.overdueTaskItems
        )
    }

    private var currentSelection: SpreadHeaderNavigatorModel.Selection {
        selectedSelection ?? .traditionalYear(defaultRootYearDate)
    }

    private var selectionBinding: Binding<SpreadHeaderNavigatorModel.Selection> {
        Binding(
            get: { currentSelection },
            set: {
                selectedSelection = $0
            }
        )
    }

    private var currentSpread: DataModel.Spread {
        switch currentSelection {
        case .traditionalYear(let yearDate):
            return DataModel.Spread(period: .year, date: yearDate, calendar: journalManager.calendar)
        case .traditionalMonth(let monthDate):
            return DataModel.Spread(period: .month, date: monthDate, calendar: journalManager.calendar)
        case .traditionalDay(let dayDate):
            return DataModel.Spread(period: .day, date: dayDate, calendar: journalManager.calendar)
        case .conventional:
            return DataModel.Spread(period: .year, date: defaultRootYearDate, calendar: journalManager.calendar)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SpreadTitleNavigatorView(
                stripModel: stripModel,
                recenterToken: recenterToken,
                onRecommendedSpreadTapped: nil,
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
            toolbarContent
        }
        .sheet(item: $activeSheet) { destination in
            switch destination {
            case .inbox:
                InboxSheetView(journalManager: journalManager)
            case .auth:
                AuthEntrySheet(authManager: authManager, isBlocking: false)
            }
        }
        .onAppear {
            if selectedSelection == nil {
                selectedSelection = .traditionalYear(defaultRootYearDate)
            }
        }
    }

    @ViewBuilder
    private var contentArea: some View {
        ZStack(alignment: overlayAlignment) {
            pagerContent
            spreadOverlayButtons
        }
    }

    private func navigateToToday() {
        let target = SpreadHeaderNavigatorModel.Selection.traditionalDay(
            Period.day.normalizeDate(journalManager.today, calendar: journalManager.calendar)
        )
        if target.stableID(calendar: journalManager.calendar) == currentSelection.stableID(calendar: journalManager.calendar) {
            recenterToken += 1
        } else {
            selectedSelection = target
        }
    }

    private var overlayAlignment: Alignment {
        horizontalSizeClass == .regular ? .topTrailing : .bottomLeading
    }

    private var spreadOverlayButtons: some View {
        Button("Today", action: navigateToToday)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .glassEffect(.clear, in: Capsule())
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 20)
            .accessibilityIdentifier(
                Definitions.AccessibilityIdentifiers.SpreadToolbar.todayButton
            )
    }

    @ViewBuilder
    private var pagerContent: some View {
        let items = stripModel.items(for: currentSelection)
        if !items.isEmpty {
            SpreadContentPagerView(
                model: stripModel,
                items: items,
                recenterToken: recenterToken,
                selection: selectionBinding
            ) { item in
                traditionalPage(for: item)
            }
        } else {
            ContentUnavailableView {
                Label("No Spread Selected", systemImage: "book")
            } description: {
                Text("Select a spread from the bar above.")
            }
        }
    }

    @ViewBuilder
    private func traditionalPage(for item: SpreadTitleNavigatorModel.Item) -> some View {
        switch item.selection {
        case .traditionalYear(let yearDate):
            TraditionalYearView(
                journalManager: journalManager,
                yearDate: yearDate,
                onSelectMonth: { selectedSelection = .traditionalMonth($0) },
                onSelectSelection: { selectedSelection = $0 },
                navigatorModel: navigatorModel
            )
        case .traditionalMonth(let monthDate):
            TraditionalMonthView(
                journalManager: journalManager,
                monthDate: monthDate,
                onSelectDay: { selectedSelection = .traditionalDay($0) },
                onBackToYear: {
                    selectedSelection = .traditionalYear(
                        Period.year.normalizeDate(monthDate, calendar: journalManager.calendar)
                    )
                },
                navigatorModel: navigatorModel,
                onSelectSelection: { selectedSelection = $0 }
            )
        case .traditionalDay(let dayDate):
            TraditionalDayView(
                journalManager: journalManager,
                syncEngine: syncEngine,
                dayDate: dayDate,
                onBackToMonth: {
                    selectedSelection = .traditionalMonth(
                        Period.month.normalizeDate(dayDate, calendar: journalManager.calendar)
                    )
                },
                navigatorModel: navigatorModel,
                onSelectSelection: { selectedSelection = $0 }
            )
        case .conventional:
            Color.clear
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            InboxButton(inboxCount: journalManager.inboxCount) {
                activeSheet = .inbox
            }
        }
        ToolbarSpacer(.fixed, placement: .primaryAction)
        ToolbarItem(placement: .primaryAction) {
            AuthButton(isSignedIn: authManager.state.isSignedIn) {
                activeSheet = .auth
            }
        }
    }
}
