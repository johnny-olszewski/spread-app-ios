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

    /// Whether the inbox sheet is presented.
    @State private var isShowingInboxSheet = false

    /// Whether the auth sheet is presented.
    @State private var isShowingAuthSheet = false

    // MARK: - Private

    /// The current year date (normalized to Jan 1) for the root view.
    private var currentYearDate: Date {
        let calendar = journalManager.calendar
        let year = calendar.component(.year, from: journalManager.today)
        return calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
    }

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $navigationPath) {
            yearRoot
                .navigationDestination(for: TraditionalNavigationDestination.self) { destination in
                    destinationView(for: destination)
                }
                .navigationTitle("Spreads")
                .toolbar {
                    toolbarContent
                }
        }
        .sheet(isPresented: $isShowingInboxSheet) {
            InboxSheetView(journalManager: journalManager)
        }
        .sheet(isPresented: $isShowingAuthSheet) {
            AuthEntrySheet(authManager: authManager, isBlocking: false)
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
                }
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
                }
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
                yearDate: currentYearDate,
                onSelectMonth: { monthDate in
                    navigationPath.append(.month(monthDate))
                }
            )
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
                InboxButton(inboxCount: journalManager.inboxCount) {
                    isShowingInboxSheet = true
                }
                AuthButton(isSignedIn: authManager.state.isSignedIn) {
                    isShowingAuthSheet = true
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
