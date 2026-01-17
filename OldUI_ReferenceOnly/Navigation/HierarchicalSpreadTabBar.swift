//
//  HierarchicalSpreadTabBar.swift
//  Bulleted
//
//  Created by Johnny O on 12/31/25.
//

import SwiftUI

/// Hierarchical spread navigation that progressively reveals child periods.
///
/// Navigation hierarchy: Year → Month → (Week | Day)
///
/// Behavior:
/// - Initially shows years, expanded to the smallest period containing today
/// - Selecting a spread navigates to it and expands its children
/// - Tapping an already-expanded spread collapses its children
/// - Ancestors of the active spread show with secondary background
struct HierarchicalSpreadTabBar: View {
    @Environment(JournalManager.self) private var journalManager

    let spreads: [DataModel.Spread]
    @Binding var selectedSpread: DataModel.Spread?

    /// The expanded year (shows its months when set)
    @State private var expandedYear: DataModel.Spread?
    /// The expanded month (shows its weeks/days when set)
    @State private var expandedMonth: DataModel.Spread?

    let creatableSpreads: [SpreadSuggestion]
    let onCreateSpread: () -> Void
    let onCreateSuggestedSpread: (SpreadSuggestion) -> Void

    private let calendar = Calendar.current

    var body: some View {
        ScrollViewReader { proxy in
            tabBarContent
                .onChange(of: selectedSpread?.id) { _, newValue in
                    if let id = newValue {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
                .onAppear {
                    initializeExpansionState()
                }
        }
    }

    // MARK: - Content

    private var tabBarContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .bottom, spacing: 0) {
                // Years
                yearsSection

                // Months (if a year is expanded)
                if expandedYear != nil {
                    monthsSection
                }

                // Weeks/Days (if a month is expanded)
                if expandedMonth != nil {
                    weeksAndDaysSection
                }

                // Creatable spreads and add button
                creatableTabs
                addButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 0)
        }
        .background(FolderTabDesign.chromeBackground)
    }

    // MARK: - Year Section

    private var yearsSection: some View {
        HStack(alignment: .bottom, spacing: FolderTabDesign.tabSpacing) {
            // Show all years only if none is expanded, otherwise show only the expanded year
            let visibleYears = expandedYear == nil ? yearSpreads : yearSpreads.filter { $0.id == expandedYear?.id }

            ForEach(visibleYears, id: \.id) { spread in
                HierarchicalTab(
                    spread: spread,
                    state: tabState(for: spread),
                    onTap: { handleYearTap(spread) }
                )
                .id(spread.id)
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }

            // Separator after years if expanded
            if expandedYear != nil {
                hierarchySeparator
            }
        }
    }

    // MARK: - Month Section

    @ViewBuilder
    private var monthsSection: some View {
        let allMonths = monthSpreads(for: expandedYear)
        // Show all months only if none is expanded, otherwise show only the expanded month
        let visibleMonths = expandedMonth == nil ? allMonths : allMonths.filter { $0.id == expandedMonth?.id }

        HStack(alignment: .bottom, spacing: FolderTabDesign.tabSpacing) {
            if allMonths.isEmpty {
                emptyChildrenLabel
            } else {
                ForEach(visibleMonths, id: \.id) { spread in
                    HierarchicalTab(
                        spread: spread,
                        state: tabState(for: spread),
                        onTap: { handleMonthTap(spread) }
                    )
                    .id(spread.id)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }
            }

            // Separator after months if expanded
            if expandedMonth != nil {
                hierarchySeparator
            }
        }
    }

    // MARK: - Weeks and Days Section

    @ViewBuilder
    private var weeksAndDaysSection: some View {
        let children = weeksAndDays(for: expandedMonth)

        HStack(alignment: .bottom, spacing: FolderTabDesign.tabSpacing) {
            if children.isEmpty {
                emptyChildrenLabel
            } else {
                ForEach(children, id: \.id) { spread in
                    HierarchicalTab(
                        spread: spread,
                        state: tabState(for: spread),
                        onTap: { handleLeafTap(spread) }
                    )
                    .id(spread.id)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }
            }
        }
    }

    // MARK: - Supporting Views

    private var hierarchySeparator: some View {
        Image(systemName: "chevron.right")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
    }

    private var emptyChildrenLabel: some View {
        Text("No spreads")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .italic()
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
    }

    private var creatableTabs: some View {
        ForEach(filteredCreatableSpreads, id: \.id) { suggestion in
            CreatableSpreadTab(
                period: suggestion.period,
                date: suggestion.date,
                onTap: {
                    onCreateSuggestedSpread(suggestion)
                }
            )
        }
    }

    private var addButton: some View {
        Button(action: onCreateSpread) {
            Image(systemName: "plus.circle")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .padding(.leading, 4)
        .padding(.bottom, 6)
    }

    // MARK: - Data Filtering

    private var yearSpreads: [DataModel.Spread] {
        spreads
            .filter { $0.period == .year }
            .sorted { $0.date < $1.date }
    }

    private func monthSpreads(for year: DataModel.Spread?) -> [DataModel.Spread] {
        guard let year = year else { return [] }
        let yearValue = calendar.component(.year, from: year.date)

        return spreads
            .filter { spread in
                spread.period == .month &&
                calendar.component(.year, from: spread.date) == yearValue
            }
            .sorted { $0.date < $1.date }
    }

    private func weeksAndDays(for month: DataModel.Spread?) -> [DataModel.Spread] {
        guard let month = month else { return [] }
        let monthValue = calendar.component(.month, from: month.date)
        let yearValue = calendar.component(.year, from: month.date)

        return spreads
            .filter { spread in
                guard spread.period == .week || spread.period == .day || spread.period == .multiday else {
                    return false
                }

                let spreadMonth = calendar.component(.month, from: spread.date)
                let spreadYear = calendar.component(.year, from: spread.date)

                // For weeks, also include if the week spans into this month
                if spread.period == .week {
                    if let weekEnd = calendar.date(byAdding: .day, value: 6, to: spread.date) {
                        let endMonth = calendar.component(.month, from: weekEnd)
                        let endYear = calendar.component(.year, from: weekEnd)
                        return (spreadMonth == monthValue && spreadYear == yearValue) ||
                               (endMonth == monthValue && endYear == yearValue)
                    }
                }

                return spreadMonth == monthValue && spreadYear == yearValue
            }
            .sorted { $0.date < $1.date }
    }

    /// Filter creatable spreads to only show those relevant to current expansion state
    private var filteredCreatableSpreads: [SpreadSuggestion] {
        creatableSpreads.filter { suggestion in
            switch suggestion.period {
            case .year:
                return true
            case .month:
                guard let expandedYear = expandedYear else { return false }
                let suggestionYear = calendar.component(.year, from: suggestion.date)
                let expandedYearValue = calendar.component(.year, from: expandedYear.date)
                return suggestionYear == expandedYearValue
            case .day, .week, .multiday:
                guard let expandedMonth = expandedMonth else { return false }
                let suggestionMonth = calendar.component(.month, from: suggestion.date)
                let suggestionYear = calendar.component(.year, from: suggestion.date)
                let expandedMonthValue = calendar.component(.month, from: expandedMonth.date)
                let expandedYearValue = calendar.component(.year, from: expandedMonth.date)
                return suggestionMonth == expandedMonthValue && suggestionYear == expandedYearValue
            }
        }
    }

    // MARK: - Tab State

    private func tabState(for spread: DataModel.Spread) -> HierarchicalTabState {
        // Active: This is the currently viewed spread
        if spread.id == selectedSpread?.id {
            return .active
        }

        // Ancestor: This spread is a parent of the active spread
        if isAncestor(spread, of: selectedSpread) {
            return .ancestor
        }

        // Inactive: Regular unselected state
        return .inactive
    }

    private func isAncestor(_ potentialAncestor: DataModel.Spread, of spread: DataModel.Spread?) -> Bool {
        guard let spread = spread else { return false }

        let ancestorYear = calendar.component(.year, from: potentialAncestor.date)
        let spreadYear = calendar.component(.year, from: spread.date)

        switch potentialAncestor.period {
        case .year:
            // Year is ancestor if spread is in the same year and spread is not a year
            return spreadYear == ancestorYear && spread.period != .year

        case .month:
            // Month is ancestor if spread is in the same month/year and spread is day/week
            let ancestorMonth = calendar.component(.month, from: potentialAncestor.date)
            let spreadMonth = calendar.component(.month, from: spread.date)
            let isChildPeriod = spread.period == .day || spread.period == .week || spread.period == .multiday
            return spreadYear == ancestorYear && spreadMonth == ancestorMonth && isChildPeriod

        default:
            return false
        }
    }

    // MARK: - Tap Handlers

    private func handleYearTap(_ spread: DataModel.Spread) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if expandedYear?.id == spread.id {
                // Collapse: Tapping already-expanded year
                expandedYear = nil
                expandedMonth = nil
            } else {
                // Expand this year, collapse month
                expandedYear = spread
                expandedMonth = nil
            }
            selectedSpread = spread
        }
    }

    private func handleMonthTap(_ spread: DataModel.Spread) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if expandedMonth?.id == spread.id {
                // Collapse: Tapping already-expanded month
                expandedMonth = nil
            } else {
                // Expand this month
                expandedMonth = spread
            }
            selectedSpread = spread
        }
    }

    private func handleLeafTap(_ spread: DataModel.Spread) {
        withAnimation(.easeInOut(duration: 0.25)) {
            selectedSpread = spread
        }
    }

    // MARK: - Initialization

    private func initializeExpansionState() {
        guard let selected = selectedSpread else {
            // Try to find today's spread
            expandToToday()
            return
        }

        // Expand to show the selected spread
        expandTo(selected)
    }

    private func expandToToday() {
        let today = journalManager.today

        // Find the smallest period spread that contains today
        // Check day first, then week, then month, then year
        if let daySpread = spreads.first(where: { spread in
            spread.period == .day && calendar.isDate(spread.date, inSameDayAs: today)
        }) {
            expandTo(daySpread)
            selectedSpread = daySpread
            return
        }

        if let weekSpread = spreads.first(where: { spread in
            guard spread.period == .week else { return false }
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: spread.date) else { return false }
            return weekInterval.contains(today)
        }) {
            expandTo(weekSpread)
            selectedSpread = weekSpread
            return
        }

        if let monthSpread = spreads.first(where: { spread in
            spread.period == .month &&
            calendar.isDate(spread.date, equalTo: today, toGranularity: .month)
        }) {
            expandTo(monthSpread)
            selectedSpread = monthSpread
            return
        }

        if let yearSpread = spreads.first(where: { spread in
            spread.period == .year &&
            calendar.isDate(spread.date, equalTo: today, toGranularity: .year)
        }) {
            expandTo(yearSpread)
            selectedSpread = yearSpread
            return
        }

        // Fallback: select first year if available
        if let firstYear = yearSpreads.first {
            expandedYear = firstYear
            selectedSpread = firstYear
        }
    }

    private func expandTo(_ spread: DataModel.Spread) {
        let spreadYear = calendar.component(.year, from: spread.date)
        let spreadMonth = calendar.component(.month, from: spread.date)

        // Find and expand the year
        if let year = spreads.first(where: { $0.period == .year && calendar.component(.year, from: $0.date) == spreadYear }) {
            expandedYear = year
        }

        // For month/week/day spreads, also expand the month
        if spread.period == .month || spread.period == .week || spread.period == .day || spread.period == .multiday {
            if let month = spreads.first(where: {
                $0.period == .month &&
                calendar.component(.year, from: $0.date) == spreadYear &&
                calendar.component(.month, from: $0.date) == spreadMonth
            }) {
                expandedMonth = month
            }
        }
    }
}

// MARK: - Tab State Enum

enum HierarchicalTabState {
    case active    // Currently viewed spread
    case ancestor  // Parent of the active spread
    case inactive  // Regular unselected state
}

// MARK: - Hierarchical Tab View

struct HierarchicalTab: View {
    let spread: DataModel.Spread
    let state: HierarchicalTabState
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            tabContent
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch state {
        case .active:
            activeTabView
        case .ancestor:
            ancestorTabView
        case .inactive:
            inactiveTabView
        }
    }

    private var activeTabView: some View {
        Text(displayText)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.primary)
            .padding(.horizontal, FolderTabDesign.horizontalPadding)
            .padding(.vertical, FolderTabDesign.verticalPadding)
            .background(
                TabShape(curveWidthFactor: FolderTabDesign.tabCurveWidthFactor)
                    .fill(FolderTabDesign.selectedBackground)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: -1)
            )
    }

    private var ancestorTabView: some View {
        Text(displayText)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(.primary)
            .padding(.horizontal, FolderTabDesign.horizontalPadding - 8)
            .padding(.vertical, FolderTabDesign.verticalPadding - 1)
            .background(
                TabShape(curveWidthFactor: FolderTabDesign.tabCurveWidthFactor)
                    .fill(FolderTabDesign.chromeBackground.opacity(0.8))
                    .overlay(
                        TabShape(curveWidthFactor: FolderTabDesign.tabCurveWidthFactor)
                            .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                    )
            )
    }

    private var inactiveTabView: some View {
        Text(displayText)
            .font(.subheadline)
            .fontWeight(.regular)
            .foregroundStyle(.secondary)
            .padding(.horizontal, FolderTabDesign.horizontalPadding - 4)
            .padding(.vertical, FolderTabDesign.verticalPadding - 2)
    }

    private var displayText: String {
        let calendar = Calendar.current
        switch spread.period {
        case .year:
            let year = calendar.component(.year, from: spread.date)
            return "\(year)"
        case .month:
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM"
            return formatter.string(from: spread.date)
        case .multiday:
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"
            return formatter.string(from: spread.date) + "+"
        case .week:
            let weekOfYear = calendar.component(.weekOfYear, from: spread.date)
            return "W\(weekOfYear)"
        case .day:
            let day = calendar.component(.day, from: spread.date)
            return "\(day)"
        }
    }
}

// MARK: - Preview

#Preview("Hierarchical Navigation") {
    struct PreviewWrapper: View {
        @State private var selectedSpread: DataModel.Spread?
        let calendar = Calendar.current

        var spreads: [DataModel.Spread] {
            var result: [DataModel.Spread] = []
            // Years
            result.append(DataModel.Spread(period: .year, date: calendar.date(from: DateComponents(year: 2025))!))
            result.append(DataModel.Spread(period: .year, date: calendar.date(from: DateComponents(year: 2026))!))
            // Months for 2026
            for month in 1...3 {
                result.append(DataModel.Spread(period: .month, date: calendar.date(from: DateComponents(year: 2026, month: month))!))
            }
            // Days for January 2026
            for day in [1, 5, 10, 15, 20] {
                result.append(DataModel.Spread(period: .day, date: calendar.date(from: DateComponents(year: 2026, month: 1, day: day))!))
            }
            // Week in January
            result.append(DataModel.Spread(period: .week, date: calendar.date(from: DateComponents(year: 2026, month: 1, day: 6))!))
            return result
        }

        var body: some View {
            VStack(spacing: 0) {
                HierarchicalSpreadTabBar(
                    spreads: spreads,
                    selectedSpread: $selectedSpread,
                    creatableSpreads: [],
                    onCreateSpread: {},
                    onCreateSuggestedSpread: { _ in }
                )

                // Content area
                VStack {
                    if let selected = selectedSpread {
                        Text("Selected: \(selected.period.name)")
                            .font(.headline)
                        Text(selected.date.formatted(date: .complete, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No selection")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DotGridView(configuration: FolderTabDesign.dotGridConfig))
            }
            .environment(JournalManager(
                calendar: calendar,
                today: calendar.date(from: DateComponents(year: 2026, month: 1, day: 10))!,
                bujoMode: .convential,
                spreadRepository: mock_SpreadRepository(calendar: calendar, today: Date()),
                taskRepository: mock_TaskRepository(calendar: calendar, today: Date())
            ))
        }
    }

    return PreviewWrapper()
}
