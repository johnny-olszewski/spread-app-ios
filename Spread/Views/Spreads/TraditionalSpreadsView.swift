import SwiftUI

/// Navigation destination for traditional mode drill-in.
///
/// Represents each level of the year → month → day hierarchy.
/// Conforms to `Hashable` for use with `NavigationPath`.
enum TraditionalNavigationDestination: Hashable {
    /// Month view for a given month date.
    case month(Date)
    /// Day view for a given day date.
    case day(Date)
}

private enum TraditionalSheetDestination: Identifiable {
    case inbox
    case auth
    case overdueReview

    var id: String {
        switch self {
        case .inbox:
            "inbox"
        case .auth:
            "auth"
        case .overdueReview:
            "overdueReview"
        }
    }
}

/// Main spreads view for traditional mode with year → month → day navigation.
///
/// Provides iOS Calendar-style drill-in navigation using `NavigationStack`
/// with a programmatic path. The year view is the root, tapping a month
/// pushes the month view, and tapping a day pushes the day view.
///
/// This view manages its own `NavigationStack` — callers should NOT wrap
/// it in an additional stack.
///
/// On iPad (regular width), toolbar items for inbox and auth appear in this view.
struct TraditionalSpreadsView: View {

    // MARK: - Properties

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// The journal manager providing spread data.
    @Bindable var journalManager: JournalManager

    /// The auth manager for handling authentication.
    let authManager: AuthManager

    /// The sync engine for data synchronization.
    let syncEngine: SyncEngine?

    /// Navigation path for drill-in stack.
    @State private var navigationPath: [TraditionalNavigationDestination] = []

    /// The currently selected root year for traditional navigation.
    @State private var selectedRootYearDate: Date = Date()

    /// Active root-level sheet destination for compact spread navigation.
    @State private var activeSheet: TraditionalSheetDestination?

    // MARK: - Private

    /// The current year date (normalized to Jan 1) default for the root view.
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

    private var currentSpread: DataModel.Spread {
        if case .day(let dayDate) = navigationPath.last {
            return DataModel.Spread(period: .day, date: dayDate, calendar: journalManager.calendar)
        }
        if case .month(let monthDate) = navigationPath.last {
            return DataModel.Spread(period: .month, date: monthDate, calendar: journalManager.calendar)
        }
        return DataModel.Spread(period: .year, date: selectedRootYearDate, calendar: journalManager.calendar)
    }

    private var currentSelection: SpreadHeaderNavigatorModel.Selection {
        if case .day(let dayDate) = navigationPath.last {
            return .traditionalDay(dayDate)
        }
        if case .month(let monthDate) = navigationPath.last {
            return .traditionalMonth(monthDate)
        }
        return .traditionalYear(selectedRootYearDate)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $navigationPath) {
            traditionalChrome {
                yearRoot
            }
                .navigationDestination(for: TraditionalNavigationDestination.self) { destination in
                    traditionalChrome {
                        destinationView(for: destination)
                    }
                }
                .navigationTitle("Spreads")
                .toolbar {
                    toolbarContent
                }
        }
        .sheet(item: $activeSheet) { destination in
            switch destination {
            case .inbox:
                InboxSheetView(journalManager: journalManager)
            case .auth:
                AuthEntrySheet(authManager: authManager, isBlocking: false)
            case .overdueReview:
                OverdueReviewSheet(
                    journalManager: journalManager,
                    syncEngine: syncEngine
                )
            }
        }
        .onAppear {
            if navigationPath.isEmpty {
                selectedRootYearDate = defaultRootYearDate
            }
        }
    }

    // MARK: - Navigation Destinations

    @ViewBuilder
    private func destinationView(for destination: TraditionalNavigationDestination) -> some View {
        switch destination {
        case .month(let monthDate):
            TraditionalMonthView(
                journalManager: journalManager,
                monthDate: monthDate,
                onSelectDay: { dayDate in
                    navigationPath.append(.day(dayDate))
                },
                onBackToYear: {
                    navigationPath.removeLast()
                },
                navigatorModel: navigatorModel
            )
            .navigationBarBackButtonHidden(true)
            .navigationTitle("")
            .toolbar(.hidden, for: .tabBar)
        case .day(let dayDate):
            TraditionalDayView(
                journalManager: journalManager,
                syncEngine: syncEngine,
                dayDate: dayDate,
                onBackToMonth: {
                    navigationPath.removeLast()
                },
                navigatorModel: navigatorModel
            )
            .navigationBarBackButtonHidden(true)
            .navigationTitle("")
            .toolbar(.hidden, for: .tabBar)
        }
    }

    // MARK: - Root Year View

    private var yearRoot: some View {
        VStack(spacing: 0) {
            // Sync status banner
            if let syncEngine {
                SyncStatusBanner(syncEngine: syncEngine)
            }

            TraditionalYearView(
                journalManager: journalManager,
                yearDate: selectedRootYearDate,
                onSelectMonth: { monthDate in
                    navigationPath.append(.month(monthDate))
                },
                navigatorModel: navigatorModel
            )
        }
    }

    @ViewBuilder
    private func traditionalChrome<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            SpreadTitleNavigatorView(
                stripModel: stripModel,
                headerNavigatorModel: navigatorModel,
                currentSpread: currentSpread,
                currentSelection: currentSelection,
                onSelect: { handleNavigatorSelection($0) },
                onCreateSpreadTapped: nil,
                onCreateTaskTapped: nil,
                onCreateNoteTapped: nil
            )

            Divider()

            content()
        }
    }

    private func handleNavigatorSelection(_ selection: SpreadHeaderNavigatorModel.Selection) {
        switch selection {
        case .traditionalYear(let yearDate):
            selectedRootYearDate = Period.year.normalizeDate(yearDate, calendar: journalManager.calendar)
            navigationPath = []
        case .traditionalMonth(let monthDate):
            let normalizedMonth = Period.month.normalizeDate(monthDate, calendar: journalManager.calendar)
            selectedRootYearDate = Period.year.normalizeDate(monthDate, calendar: journalManager.calendar)
            navigationPath = [.month(normalizedMonth)]
        case .traditionalDay(let dayDate):
            let normalizedDay = Period.day.normalizeDate(dayDate, calendar: journalManager.calendar)
            let monthDate = Period.month.normalizeDate(dayDate, calendar: journalManager.calendar)
            selectedRootYearDate = Period.year.normalizeDate(dayDate, calendar: journalManager.calendar)
            navigationPath = [.month(monthDate), .day(normalizedDay)]
        case .conventional:
            break
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if let syncEngine {
            ToolbarItem(placement: .navigationBarLeading) {
                SyncStatusView(syncEngine: syncEngine)
            }
        }
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
}

// MARK: - Preview

#Preview {
    TraditionalSpreadsView(
        journalManager: .previewInstance,
        authManager: .makeForPreview(),
        syncEngine: nil
    )
}
