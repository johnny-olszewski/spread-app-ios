import SwiftUI

/// A view for selecting an existing spread to assign a task to.
///
/// Displays spreads chronologically with:
/// - Multi-select period filter toggles (none selected by default)
/// - Multiday spreads expand inline to show contained dates
/// - "Choose another date" option for custom date entry
struct SpreadPickerView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - Properties

    /// All available spreads.
    let spreads: [DataModel.Spread]

    /// The calendar for date calculations.
    let calendar: Calendar

    /// The reference date (typically today).
    let today: Date

    /// Callback when a spread is selected.
    ///
    /// Parameters are the period and date to use for the task.
    let onSpreadSelected: (Period, Date) -> Void

    /// Callback when "Choose another date" is selected.
    let onChooseCustomDate: () -> Void

    // MARK: - State

    /// The currently active period filters.
    @State private var activeFilters: Set<Period> = []

    /// The expanded multiday spread (showing contained dates).
    @State private var expandedMultidayId: UUID?

    /// Cached width for centering filter buttons when content is narrow.
    @State private var filterBarWidth: CGFloat = 0

    // MARK: - Computed Properties

    private var configuration: SpreadPickerConfiguration {
        SpreadPickerConfiguration(
            spreads: spreads,
            calendar: calendar,
            today: today
        )
    }

    private var filteredSpreads: [DataModel.Spread] {
        configuration.filteredSpreads(periods: activeFilters)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                Divider()
                spreadList
            }
            .navigationTitle("Select Spread")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    selectAllButton
                    deselectAllButton
                    ForEach(Period.allCases, id: \.self) { period in
                        filterToggle(for: period)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(minWidth: filterBarWidth)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: FilterBarWidthKey.self, value: proxy.size.width)
            }
        )
        .onPreferenceChange(FilterBarWidthKey.self) { width in
            filterBarWidth = width
        }
    }

    private var selectAllButton: some View {
        Button("Select All") {
            withAnimation(.easeInOut(duration: 0.2)) {
                activeFilters = Set(Period.allCases)
            }
        }
        .buttonStyle(.plain)
        .font(.subheadline)
        .fontWeight(.semibold)
        .foregroundStyle(.accent)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(.systemGray4))
        )
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadPicker.selectAllFilters)
    }

    private var deselectAllButton: some View {
        Button("Deselect All") {
            withAnimation(.easeInOut(duration: 0.2)) {
                activeFilters.removeAll()
            }
        }
        .buttonStyle(.plain)
        .font(.subheadline)
        .fontWeight(.semibold)
        .foregroundStyle(.accent)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(.systemGray4))
        )
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadPicker.deselectAllFilters)
    }

    private func filterToggle(for period: Period) -> some View {
        let isActive = activeFilters.contains(period)

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if isActive {
                    activeFilters.remove(period)
                } else {
                    activeFilters.insert(period)
                }
            }
        } label: {
            Text(period.displayName)
                .font(.subheadline)
                .fontWeight(isActive ? .semibold : .regular)
                .foregroundStyle(isActive ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isActive ? Color.accentColor : Color(.systemGray5))
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(
            Definitions.AccessibilityIdentifiers.SpreadPicker.filterToggle(period.rawValue)
        )
    }

    // MARK: - Spread List

    private var spreadList: some View {
        List {
            chooseCustomDateRow

            if filteredSpreads.isEmpty {
                emptyStateRow
            } else {
                ForEach(filteredSpreads) { spread in
                    spreadRow(for: spread)
                }
            }
        }
        .listStyle(.plain)
    }

    private var chooseCustomDateRow: some View {
        Button {
            onChooseCustomDate()
            dismiss()
        } label: {
            HStack {
                Image(systemName: "calendar.badge.plus")
                    .foregroundStyle(.accent)
                Text("Choose another date")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.primary)
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadPicker.chooseCustomDate)
    }

    private var emptyStateRow: some View {
        HStack {
            Spacer()
            Text("No spreads match the selected filters")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 20)
    }

    @ViewBuilder
    private func spreadRow(for spread: DataModel.Spread) -> some View {
        if spread.period == .multiday {
            multidayRow(for: spread)
        } else {
            standardSpreadRow(for: spread)
        }
    }

    private func standardSpreadRow(for spread: DataModel.Spread) -> some View {
        Button {
            onSpreadSelected(spread.period, spread.date)
            dismiss()
        } label: {
            HStack {
                periodIcon(for: spread.period)
                VStack(alignment: .leading, spacing: 2) {
                    Text(configuration.displayLabel(for: spread))
                        .font(.body)
                    Text(spread.period.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .foregroundStyle(.primary)
        .accessibilityIdentifier(
            Definitions.AccessibilityIdentifiers.SpreadPicker.spreadRow(spread.id.uuidString)
        )
    }

    // MARK: - Multiday Expansion

    @ViewBuilder
    private func multidayRow(for spread: DataModel.Spread) -> some View {
        let isExpanded = expandedMultidayId == spread.id

        VStack(alignment: .leading, spacing: 0) {
            // Header row
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded {
                        expandedMultidayId = nil
                    } else {
                        expandedMultidayId = spread.id
                    }
                }
            } label: {
                HStack {
                    periodIcon(for: .multiday)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(configuration.displayLabel(for: spread))
                            .font(.body)
                        Text("Multiday")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)
            .accessibilityIdentifier(
                Definitions.AccessibilityIdentifiers.SpreadPicker.multidayRow(spread.id.uuidString)
            )

            // Expanded content
            if isExpanded {
                multidayExpandedContent(for: spread)
            }
        }
    }

    @ViewBuilder
    private func multidayExpandedContent(for spread: DataModel.Spread) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Caption explaining assignment behavior
            Text("Tasks cannot be assigned directly to multiday spreads. Select a day below and the task will appear on this multiday spread.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
                .padding(.leading, 32)

            // Date list
            let dates = configuration.containedDates(for: spread)
            ForEach(dates, id: \.self) { date in
                Button {
                    onSpreadSelected(.day, date)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(configuration.dateLabel(for: date))
                            .font(.subheadline)
                        Spacer()
                    }
                    .padding(.leading, 32)
                    .padding(.vertical, 4)
                }
                .foregroundStyle(.primary)
                .accessibilityIdentifier(
                    Definitions.AccessibilityIdentifiers.SpreadPicker.multidayDate(
                        spreadId: spread.id.uuidString,
                        date: dateIdentifier(for: date)
                    )
                )
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - Helpers

    private func periodIcon(for period: Period) -> some View {
        let systemName: String
        switch period {
        case .year:
            systemName = "calendar"
        case .month:
            systemName = "calendar.badge.clock"
        case .day:
            systemName = "sun.max"
        case .multiday:
            systemName = "calendar.day.timeline.left"
        }

        return Image(systemName: systemName)
            .foregroundStyle(.accent)
            .frame(width: 24)
    }

    private func dateIdentifier(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }
}

// MARK: - Preview

#Preview("With Spreads") {
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
            startDate: today,
            endDate: calendar.date(byAdding: .day, value: 6, to: today)!,
            calendar: calendar
        )
    ]

    return SpreadPickerView(
        spreads: spreads,
        calendar: calendar,
        today: today,
        onSpreadSelected: { period, date in
            print("Selected: \(period.displayName) - \(date)")
        },
        onChooseCustomDate: {
            print("Choose custom date")
        }
    )
}

#Preview("Empty") {
    let calendar = Calendar.current

    return SpreadPickerView(
        spreads: [],
        calendar: calendar,
        today: Date(),
        onSpreadSelected: { _, _ in },
        onChooseCustomDate: { }
    )
}

private struct FilterBarWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
