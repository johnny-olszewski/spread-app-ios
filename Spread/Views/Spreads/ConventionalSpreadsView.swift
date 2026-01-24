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
                calendar: journalManager.calendar
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

/// Spread content view displaying header and entry list placeholder.
///
/// Shows the spread header with title and entry counts, followed by
/// a placeholder for the entry list (to be implemented in SPRD-28).
/// Uses dot grid paper background per visual design spec.
private struct SpreadContentView: View {
    let spread: DataModel.Spread
    let spreadDataModel: SpreadDataModel?
    let calendar: Calendar

    var body: some View {
        VStack(spacing: 0) {
            // Header with title and counts
            SpreadHeaderView(
                spread: spread,
                calendar: calendar,
                taskCount: spreadDataModel?.tasks.count ?? 0,
                eventCount: spreadDataModel?.events.count ?? 0,
                noteCount: spreadDataModel?.notes.count ?? 0
            )

            Divider()

            // TODO: SPRD-28 - Replace with entry list grouped by period
            entryListPlaceholder
        }
        .dotGridBackground(.paper)
    }

    @ViewBuilder
    private var entryListPlaceholder: some View {
        VStack {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: iconName)
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text("Entry list coming soon")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var iconName: String {
        switch spread.period {
        case .year: return "calendar"
        case .month: return "calendar.badge.clock"
        case .day: return "sun.max"
        case .multiday: return "calendar.day.timeline.left"
        }
    }
}

// MARK: - Preview

#Preview {
    ConventionalSpreadsView(journalManager: .previewInstance)
}
