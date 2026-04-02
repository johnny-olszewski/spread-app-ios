import SwiftUI

enum TraditionalNavigationDestination: Hashable {
    case month(Date)
    case day(Date)
}

private enum TraditionalSheetDestination: Identifiable {
    case inbox
    case auth
    case overdueReview

    var id: String {
        switch self {
        case .inbox: "inbox"
        case .auth: "auth"
        case .overdueReview: "overdueReview"
        }
    }
}

struct TraditionalSpreadsView: View {
    @Bindable var journalManager: JournalManager
    let authManager: AuthManager
    let syncEngine: SyncEngine?

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
        SpreadTitleNavigatorModel(headerModel: navigatorModel)
    }

    private var currentSelection: SpreadHeaderNavigatorModel.Selection {
        selectedSelection ?? .traditionalYear(defaultRootYearDate)
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
                headerNavigatorModel: navigatorModel,
                currentSpread: currentSpread,
                currentSelection: currentSelection,
                recenterToken: recenterToken,
                onSelect: { selectedSelection = $0 },
                onCreateSpreadTapped: nil,
                onCreateTaskTapped: nil,
                onCreateNoteTapped: nil
            )

            Divider()

            pagerContent
        }
        .overlay(alignment: .bottomLeading) {
            todayButton
                .padding(.leading, 16)
                .padding(.bottom, 20)
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
            case .overdueReview:
                OverdueReviewSheet(journalManager: journalManager, syncEngine: syncEngine)
            }
        }
        .onAppear {
            if selectedSelection == nil {
                selectedSelection = .traditionalYear(defaultRootYearDate)
            }
        }
    }

    @ViewBuilder
    private var pagerContent: some View {
        let items = stripModel.items(for: currentSelection)
        if !items.isEmpty {
            SpreadContentPagerView(
                model: stripModel,
                items: items,
                selectedID: currentSelection.stableID(calendar: journalManager.calendar),
                recenterToken: recenterToken,
                onSettledSelect: { selection in
                    selectedSelection = selection
                }
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
                navigatorModel: navigatorModel
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
                navigatorModel: navigatorModel
            )
        case .conventional:
            Color.clear
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            HStack(spacing: 16) {
                OverdueButton(overdueCount: journalManager.overdueTaskCount) {
                    activeSheet = .overdueReview
                }
                InboxButton(inboxCount: journalManager.inboxCount) {
                    activeSheet = .inbox
                }
                AuthButton(isSignedIn: authManager.state.isSignedIn) {
                    activeSheet = .auth
                }
            }
        }
    }

    private var todayButton: some View {
        Button("Today") {
            let target = SpreadHeaderNavigatorModel.Selection.traditionalDay(
                Period.day.normalizeDate(journalManager.today, calendar: journalManager.calendar)
            )
            if target.stableID(calendar: journalManager.calendar) == currentSelection.stableID(calendar: journalManager.calendar) {
                recenterToken += 1
            } else {
                selectedSelection = target
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .glassEffect(in: Capsule())
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadToolbar.todayButton)
    }
}
