import SwiftUI

/// Hierarchical tab bar for navigating spreads in conventional mode.
///
/// Displays spreads organized by year → month → day hierarchy with:
/// - Progressive disclosure (tap year to show months, tap month to show days)
/// - Sticky leading tabs for selected year and month
/// - Horizontally scrollable children
/// - Trailing "+" button for creating new spreads
///
/// Used on both iPad and iPhone inside the spreads view.
struct SpreadHierarchyTabBar: View {

    // MARK: - Properties

    /// The spreads to display in the hierarchy.
    let spreads: [DataModel.Spread]

    /// The currently selected spread.
    @Binding var selectedSpread: DataModel.Spread?

    /// The calendar for date calculations.
    let calendar: Calendar

    /// The reference date for initial selection (typically today).
    let today: Date

    /// Callback when the create button is tapped.
    var onCreateTapped: (() -> Void)?

    /// The expanded year in the hierarchy (shows its months).
    @State private var expandedYear: DataModel.Spread?

    /// The expanded month in the hierarchy (shows its days).
    @State private var expandedMonth: DataModel.Spread?

    /// The hierarchy organizer for the current spreads.
    private var organizer: SpreadHierarchyOrganizer {
        SpreadHierarchyOrganizer(spreads: spreads, calendar: calendar)
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            // Sticky leading section (selected year and month)
            stickyLeadingSection

            // Scrollable children section
            scrollableSection

            // Trailing create button
            createButton
        }
        .frame(height: SpreadHierarchyDesign.barHeight)
        .background(Color(.systemBackground))
        .onAppear {
            initializeSelection()
        }
    }

    // MARK: - Sticky Leading Section

    @ViewBuilder
    private var stickyLeadingSection: some View {
        HStack(spacing: SpreadHierarchyDesign.itemSpacing) {
            // Year tab (if expanded)
            if let year = expandedYear {
                tabItem(for: year, font: SpreadHierarchyDesign.yearFont) {
                    handleYearTap(year)
                }
            }

            // Month tab (if expanded)
            if let month = expandedMonth {
                tabItem(for: month, font: SpreadHierarchyDesign.monthFont) {
                    handleMonthTap(month)
                }
            }
        }
        .padding(.leading, SpreadHierarchyDesign.horizontalPadding)
    }

    // MARK: - Scrollable Section

    @ViewBuilder
    private var scrollableSection: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SpreadHierarchyDesign.itemSpacing) {
                    scrollableContent
                }
                .padding(.horizontal, SpreadHierarchyDesign.itemSpacing)
            }
            .onChange(of: selectedSpread?.id) { _, newValue in
                if let id = newValue {
                    withAnimation(SpreadHierarchyDesign.selectionAnimation) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var scrollableContent: some View {
        if expandedMonth != nil {
            // Show days and multiday for the expanded month
            daysContent
        } else if expandedYear != nil {
            // Show months for the expanded year
            monthsContent
        } else {
            // Show all years
            yearsContent
        }
    }

    @ViewBuilder
    private var yearsContent: some View {
        if organizer.years.isEmpty {
            emptyStateLabel
        } else {
            ForEach(organizer.years) { yearNode in
                tabItem(for: yearNode.spread, font: SpreadHierarchyDesign.yearFont) {
                    handleYearTap(yearNode.spread)
                }
                .id(yearNode.spread.id)
            }
        }
    }

    @ViewBuilder
    private var monthsContent: some View {
        if let expandedYear = expandedYear,
           let yearNode = organizer.years.first(where: { $0.spread.id == expandedYear.id }) {
            if yearNode.months.isEmpty {
                emptyStateLabel
            } else {
                ForEach(yearNode.months) { monthNode in
                    tabItem(for: monthNode.spread, font: SpreadHierarchyDesign.monthFont) {
                        handleMonthTap(monthNode.spread)
                    }
                    .id(monthNode.spread.id)
                }
            }
        }
    }

    @ViewBuilder
    private var daysContent: some View {
        if let expandedYear = expandedYear,
           let expandedMonth = expandedMonth,
           let yearNode = organizer.years.first(where: { $0.spread.id == expandedYear.id }),
           let monthNode = yearNode.months.first(where: { $0.spread.id == expandedMonth.id }) {
            if monthNode.days.isEmpty {
                emptyStateLabel
            } else {
                ForEach(monthNode.days) { dayNode in
                    tabItem(for: dayNode.spread, font: SpreadHierarchyDesign.dayFont) {
                        selectSpread(dayNode.spread)
                    }
                    .id(dayNode.spread.id)
                }
            }
        }
    }

    private var emptyStateLabel: some View {
        Text("No spreads")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, SpreadHierarchyDesign.itemSpacing)
    }

    // MARK: - Create Button

    private var createButton: some View {
        Button {
            onCreateTapped?()
        } label: {
            Image(systemName: SpreadHierarchyDesign.createButtonSymbol)
                .font(.system(size: 16, weight: .semibold))
                .frame(
                    width: SpreadHierarchyDesign.createButtonSize,
                    height: SpreadHierarchyDesign.createButtonSize
                )
                .foregroundStyle(Color.accentColor)
        }
        .padding(.trailing, SpreadHierarchyDesign.horizontalPadding)
        .accessibilityLabel("Create spread")
    }

    // MARK: - Tab Item

    @ViewBuilder
    private func tabItem(
        for spread: DataModel.Spread,
        font: Font,
        action: @escaping () -> Void
    ) -> some View {
        let isSelected = selectedSpread?.id == spread.id

        Button(action: action) {
            Text(spread.displayLabel(calendar: calendar))
                .font(font)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? SpreadHierarchyDesign.selectedForeground : SpreadHierarchyDesign.unselectedForeground)
                .padding(SpreadHierarchyDesign.itemPadding)
                .background(
                    RoundedRectangle(cornerRadius: SpreadHierarchyDesign.itemCornerRadius)
                        .fill(isSelected ? SpreadHierarchyDesign.selectedBackground : SpreadHierarchyDesign.unselectedBackground)
                )
                .frame(minWidth: SpreadHierarchyDesign.minimumItemWidth)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func initializeSelection() {
        guard selectedSpread == nil else { return }

        // Find initial selection
        if let initial = organizer.initialSelection(for: today) {
            selectedSpread = initial

            // Expand the hierarchy to show the initial selection
            expandHierarchyForSpread(initial)
        }
    }

    private func expandHierarchyForSpread(_ spread: DataModel.Spread) {
        let yearComponent = calendar.component(.year, from: spread.date)
        let monthComponent = calendar.component(.month, from: spread.date)

        // Find the year spread
        if let yearSpread = spreads.first(where: {
            $0.period == .year && calendar.component(.year, from: $0.date) == yearComponent
        }) {
            expandedYear = yearSpread
        }

        // Find the month spread (if not a year spread)
        if spread.period != .year {
            if let monthSpread = spreads.first(where: {
                $0.period == .month &&
                calendar.component(.year, from: $0.date) == yearComponent &&
                calendar.component(.month, from: $0.date) == monthComponent
            }) {
                expandedMonth = monthSpread
            }
        }
    }

    private func handleYearTap(_ year: DataModel.Spread) {
        withAnimation(SpreadHierarchyDesign.expansionAnimation) {
            if expandedYear?.id == year.id && expandedMonth == nil {
                // Already expanded at year level, collapse to show all years
                expandedYear = nil
            } else if expandedYear?.id == year.id {
                // Expanded with month showing, collapse to year level
                expandedMonth = nil
            } else {
                // Expand this year
                expandedYear = year
                expandedMonth = nil
            }
        }

        // Select the year spread
        selectSpread(year)
    }

    private func handleMonthTap(_ month: DataModel.Spread) {
        withAnimation(SpreadHierarchyDesign.expansionAnimation) {
            if expandedMonth?.id == month.id {
                // Already expanded, collapse to show all months
                expandedMonth = nil
            } else {
                // Expand this month
                expandedMonth = month
            }
        }

        // Select the month spread
        selectSpread(month)
    }

    private func selectSpread(_ spread: DataModel.Spread) {
        withAnimation(SpreadHierarchyDesign.selectionAnimation) {
            selectedSpread = spread
        }
    }
}

// MARK: - Preview

#Preview("With Spreads") {
    struct PreviewWrapper: View {
        @State private var selectedSpread: DataModel.Spread?

        var body: some View {
            let calendar = {
                var cal = Calendar(identifier: .gregorian)
                cal.timeZone = .init(identifier: "UTC")!
                return cal
            }()
            let today = Date()

            let spreads = [
                DataModel.Spread(period: .year, date: today, calendar: calendar),
                DataModel.Spread(period: .month, date: today, calendar: calendar),
                DataModel.Spread(period: .day, date: today, calendar: calendar),
                DataModel.Spread(
                    period: .day,
                    date: calendar.date(byAdding: .day, value: 1, to: today)!,
                    calendar: calendar
                ),
                DataModel.Spread(
                    period: .day,
                    date: calendar.date(byAdding: .day, value: 2, to: today)!,
                    calendar: calendar
                )
            ]

            VStack {
                SpreadHierarchyTabBar(
                    spreads: spreads,
                    selectedSpread: $selectedSpread,
                    calendar: calendar,
                    today: today
                )

                Spacer()

                if let spread = selectedSpread {
                    Text("Selected: \(spread.displayLabel(calendar: calendar))")
                } else {
                    Text("No selection")
                }

                Spacer()
            }
        }
    }

    return PreviewWrapper()
}

#Preview("Empty") {
    struct PreviewWrapper: View {
        @State private var selectedSpread: DataModel.Spread?

        var body: some View {
            let calendar = Calendar.current

            SpreadHierarchyTabBar(
                spreads: [],
                selectedSpread: $selectedSpread,
                calendar: calendar,
                today: Date()
            )
        }
    }

    return PreviewWrapper()
}
