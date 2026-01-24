import SwiftUI

/// Main spreads view for conventional mode.
///
/// Combines the spread hierarchy tab bar with the spread content area.
/// The tab bar provides navigation between spreads, and the content area
/// shows the selected spread's entries.
struct ConventionalSpreadsView: View {

    // MARK: - Properties

    /// The journal manager providing spread data.
    @Bindable var journalManager: JournalManager

    /// The currently selected spread.
    @State private var selectedSpread: DataModel.Spread?

    /// Whether the spread creation sheet is presented.
    @State private var isShowingCreationSheet = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Hierarchy tab bar
            SpreadHierarchyTabBar(
                spreads: journalManager.spreads,
                selectedSpread: $selectedSpread,
                calendar: journalManager.calendar,
                today: journalManager.today,
                onCreateTapped: {
                    isShowingCreationSheet = true
                }
            )

            Divider()

            // Content area
            spreadContent
        }
        .sheet(isPresented: $isShowingCreationSheet) {
            SpreadCreationSheet(
                journalManager: journalManager,
                firstWeekday: .sunday, // TODO: SPRD-20 - Get from user settings
                onSpreadCreated: { spread in
                    selectedSpread = spread
                }
            )
        }
        .onChange(of: journalManager.dataVersion) { _, _ in
            resetSelectionIfNeeded()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var spreadContent: some View {
        if let spread = selectedSpread {
            SpreadContentView(
                spread: spread,
                spreadDataModel: spreadDataModel(for: spread),
                calendar: journalManager.calendar,
                today: journalManager.today
            )
        } else {
            ContentUnavailableView {
                Label("No Spread Selected", systemImage: "book")
            } description: {
                Text("Select a spread from the bar above or create a new one.")
            }
        }
    }

    /// Returns the spread data model for the given spread.
    private func spreadDataModel(for spread: DataModel.Spread) -> SpreadDataModel? {
        let normalizedDate = spread.period.normalizeDate(spread.date, calendar: journalManager.calendar)
        return journalManager.dataModel[spread.period]?[normalizedDate]
    }

    private func resetSelectionIfNeeded() {
        if let selectedSpread, journalManager.spreads.contains(where: { $0.id == selectedSpread.id }) {
            return
        }

        let organizer = SpreadHierarchyOrganizer(
            spreads: journalManager.spreads,
            calendar: journalManager.calendar
        )
        selectedSpread = organizer.initialSelection(for: journalManager.today)
    }
}

/// Spread content view displaying header and entry list.
///
/// Shows the spread header with title and entry counts, followed by
/// the entry list grouped by period. Uses dot grid paper background
/// per visual design spec.
private struct SpreadContentView: View {
    let spread: DataModel.Spread
    let spreadDataModel: SpreadDataModel?
    let calendar: Calendar
    let today: Date

    var body: some View {
        VStack(spacing: 0) {
            // Header with title and counts
            SpreadHeaderView(
                spread: spread,
                calendar: calendar,
                taskCount: spreadDataModel?.tasks.count ?? 0,
                noteCount: spreadDataModel?.notes.count ?? 0
            )

            Divider()

            // Entry list grouped by period
            entryList
        }
        .dotGridBackground(.paper)
    }

    @ViewBuilder
    private var entryList: some View {
        if let dataModel = spreadDataModel {
            EntryListView(
                spreadDataModel: dataModel,
                calendar: calendar,
                today: today
            )
        } else {
            ContentUnavailableView {
                Label("No Data", systemImage: "tray")
            } description: {
                Text("Unable to load spread data.")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ConventionalSpreadsView(journalManager: .previewInstance)
}
