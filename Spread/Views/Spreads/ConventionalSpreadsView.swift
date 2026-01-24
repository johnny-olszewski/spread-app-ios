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
            // TODO: SPRD-27 - Replace with SpreadContentView showing entries
            SpreadContentPlaceholderView(spread: spread, calendar: journalManager.calendar)
        } else {
            ContentUnavailableView {
                Label("No Spread Selected", systemImage: "book")
            } description: {
                Text("Select a spread from the bar above or create a new one.")
            }
        }
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

/// Placeholder for spread content until SPRD-27 is implemented.
private struct SpreadContentPlaceholderView: View {
    let spread: DataModel.Spread
    let calendar: Calendar

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: iconName)
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text(spreadTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadContent.title)

                Text("Spread content will appear here")
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

    private var spreadTitle: String {
        switch spread.period {
        case .year:
            return String(calendar.component(.year, from: spread.date))
        case .month:
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: spread.date)
        case .day:
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.dateStyle = .long
            return formatter.string(from: spread.date)
        case .multiday:
            guard let startDate = spread.startDate, let endDate = spread.endDate else {
                return "Multiday"
            }
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.dateFormat = "MMM d"
            let start = formatter.string(from: startDate)
            let end = formatter.string(from: endDate)
            return "\(start) - \(end)"
        }
    }
}

// MARK: - Preview

#Preview {
    ConventionalSpreadsView(journalManager: .previewInstance)
}
