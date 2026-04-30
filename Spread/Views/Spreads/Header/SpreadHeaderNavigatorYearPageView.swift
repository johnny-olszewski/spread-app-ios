import SwiftUI
import JohnnyOFoundationUI
import JohnnyOFoundationCore

struct SpreadHeaderNavigatorYearPageView: View {
    let page: SpreadHeaderNavigatorModel.YearPage
    let model: SpreadHeaderNavigatorModel
    let currentSpread: DataModel.Spread
    @Binding var expandedMonth: Date?
    let onSelect: (SpreadHeaderNavigatorModel.Selection) -> Void
    let onDismiss: () -> Void

    @State private var dialogTargets: [SpreadHeaderNavigatorModel.SelectionTarget] = []
    @State private var isShowingSelectionDialog = false

    private struct CalendarDelegate: MonthCalendarActionDelegate {
        let monthRow: SpreadHeaderNavigatorModel.MonthRow
        let calendar: Calendar
        let onSingleTarget: (SpreadHeaderNavigatorModel.Selection) -> Void
        let onMultipleTargets: ([SpreadHeaderNavigatorModel.SelectionTarget]) -> Void

        func monthCalendarDidTapDay(_ context: MonthCalendarDayContext) {
            let targets = monthRow.targets(for: context.date, calendar: calendar)
            guard !targets.isEmpty else { return }
            if targets.count == 1, let selection = targets.first?.selection {
                onSingleTarget(selection)
            } else {
                onMultipleTargets(targets)
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(page.months) { monthRow in
                    monthSection(for: monthRow)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .confirmationDialog(
            "Choose Spread",
            isPresented: $isShowingSelectionDialog,
            titleVisibility: .visible
        ) {
            ForEach(dialogTargets) { target in
                Button(target.title) {
                    onSelect(target.selection)
                    onDismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadNavigator.yearPage(page.year))
    }

    @ViewBuilder
    private func monthSection(for monthRow: SpreadHeaderNavigatorModel.MonthRow) -> some View {
        let monthValue = model.calendar.component(.month, from: monthRow.date)
        let isExpanded = expandedMonth == monthRow.date

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(monthRow.date.formatted(.dateTime.month(.wide)))
                    .font(SpreadTheme.Typography.body)
                    .foregroundStyle(monthRow.isDerived ? .secondary : .primary)

                Spacer(minLength: 8)

                if isExpanded, let selection = model.selectionTarget(for: monthRow) {
                    Button("View Month") {
                        onSelect(selection)
                        onDismiss()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier(
                        Definitions.AccessibilityIdentifiers.SpreadNavigator.viewMonthButton(year: page.year, month: monthValue)
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.easeInOut(duration: 0.2), value: isExpanded)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        model.isCurrent(monthRow: monthRow, currentSpread: currentSpread)
                            ? SpreadSelectionVisualStyle.surfaceFill
                            : Color.clear
                    )
            )
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.25)) {
                    expandedMonth = isExpanded ? nil : monthRow.date
                }
            }
            .accessibilityIdentifier(
                Definitions.AccessibilityIdentifiers.SpreadNavigator.monthRow(year: page.year, month: monthValue)
            )

            if isExpanded {
                calendarGrid(for: monthRow)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isExpanded)
    }

    private func calendarGrid(for monthRow: SpreadHeaderNavigatorModel.MonthRow) -> some View {
        MonthCalendarView(
            displayedMonth: monthRow.date,
            calendar: model.calendar,
            today: model.today,
            configuration: .init(showsPeripheralDates: false),
            contentGenerator: SpreadHeaderNavigatorCalendarGenerator(
                model: model,
                monthRow: monthRow,
                currentSpread: currentSpread
            ),
            rowOverlayGenerator: SpreadHeaderNavigatorRowOverlayGenerator(
                model: model,
                monthRow: monthRow,
                currentSpread: currentSpread
            ),
            actionDelegate: CalendarDelegate(
                monthRow: monthRow,
                calendar: model.calendar,
                onSingleTarget: { selection in
                    onSelect(selection)
                    onDismiss()
                },
                onMultipleTargets: { targets in
                    dialogTargets = targets
                    isShowingSelectionDialog = true
                }
            )
        )
        .padding(.leading, 8)
        .accessibilityIdentifier(
            Definitions.AccessibilityIdentifiers.SpreadNavigator.grid(
                year: page.year,
                month: model.calendar.component(.month, from: monthRow.date)
            )
        )
    }
}

#if DEBUG
private enum SpreadHeaderNavigatorPreviewMode: String, CaseIterable, Identifiable {
    case conventional
    case traditional

    var id: String { rawValue }

    var title: String {
        switch self {
        case .conventional:
            return "Conventional"
        case .traditional:
            return "Traditional"
        }
    }

    var navigatorMode: SpreadHeaderNavigatorModel.Mode {
        switch self {
        case .conventional:
            return .conventional
        case .traditional:
            return .traditional
        }
    }
}

private struct SpreadHeaderNavigatorPreviewSurface: View {
    private static let previewDataSets: [MockDataSet] = [
        .scenarioSpreadNavigator,
        .multiday,
        .baseline,
        .boundary,
        .empty,
    ]

    @State private var selectedDataSet: MockDataSet = .scenarioSpreadNavigator
    @State private var selectedMode: SpreadHeaderNavigatorPreviewMode = .conventional
    @State private var selectedSpreadID: UUID?
    @State private var expandedMonth: Date?

    private var previewCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 1
        return calendar
    }

    private var previewToday: Date {
        previewCalendar.date(from: DateComponents(year: 2026, month: 3, day: 29))!
    }

    private var generatedData: MockDataSet.GeneratedData {
        selectedDataSet.generateData(calendar: previewCalendar, today: previewToday)
    }

    private var availableSpreads: [DataModel.Spread] {
        generatedData.spreads.sorted(by: previewSpreadSortOrder)
    }

    private var selectedSpread: DataModel.Spread? {
        if let selectedSpreadID,
           let matchedSpread = availableSpreads.first(where: { $0.id == selectedSpreadID }) {
            return matchedSpread
        }

        return availableSpreads.first(where: { $0.period == .multiday })
            ?? availableSpreads.first(where: { $0.period == .day })
            ?? availableSpreads.first
    }

    private var model: SpreadHeaderNavigatorModel {
        SpreadHeaderNavigatorModel(
            mode: selectedMode.navigatorMode,
            calendar: previewCalendar,
            today: previewToday,
            spreads: generatedData.spreads,
            tasks: generatedData.tasks,
            notes: generatedData.notes,
            events: generatedData.events
        )
    }

    private var selectedPage: SpreadHeaderNavigatorModel.YearPage? {
        guard let selectedSpread else { return nil }
        let initialYear = model.initialYear(for: selectedSpread)
        return model.yearPages().first(where: { $0.year == initialYear }) ?? model.yearPages().first
    }

    private var expandedMonthBinding: Binding<Date?> {
        Binding(
            get: { expandedMonth },
            set: { expandedMonth = $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            previewControls

            if let selectedPage, let selectedSpread {
                SpreadHeaderNavigatorYearPageView(
                    page: selectedPage,
                    model: model,
                    currentSpread: selectedSpread,
                    expandedMonth: expandedMonthBinding,
                    onSelect: { _ in },
                    onDismiss: {}
                )
                .frame(width: 340, height: 560)
                .background(SpreadTheme.Paper.primary)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            } else {
                ContentUnavailableView(
                    "No Spreads",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("The selected data set does not contain any spreads to preview.")
                )
                .frame(width: 340, height: 560)
                .background(SpreadTheme.Paper.primary)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
        }
        .padding()
        .frame(width: 380, height: 700, alignment: .topLeading)
        .background(Color.black)
        .preferredColorScheme(.dark)
        .onAppear(perform: synchronizeSelectedSpread)
        .onChange(of: selectedDataSet) { _, _ in
            synchronizeSelectedSpread()
        }
        .onChange(of: selectedMode) { _, _ in
            synchronizeSelectedSpread()
        }
    }

    private var previewControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Navigator Overlay Preview")
                .font(.headline)
                .foregroundStyle(.white)

            Picker("Data Set", selection: $selectedDataSet) {
                ForEach(Self.previewDataSets, id: \.rawValue) { dataSet in
                    Text(dataSet.displayName).tag(dataSet)
                }
            }
            .pickerStyle(.menu)

            Picker("Mode", selection: $selectedMode) {
                ForEach(SpreadHeaderNavigatorPreviewMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Picker("Current Spread", selection: currentSpreadSelectionBinding) {
                ForEach(availableSpreads, id: \.id) { spread in
                    Text(previewSpreadTitle(for: spread)).tag(Optional(spread.id))
                }
            }
            .pickerStyle(.menu)
            .disabled(availableSpreads.isEmpty)
        }
    }

    private var currentSpreadSelectionBinding: Binding<UUID?> {
        Binding(
            get: { selectedSpread?.id },
            set: { selectedSpreadID = $0 }
        )
    }

    private func synchronizeSelectedSpread() {
        let resolvedSpread = selectedSpread
        selectedSpreadID = resolvedSpread?.id
        expandedMonth = resolvedSpread.map { model.initialExpandedMonth(for: $0) }
            ?? previewCalendar.date(from: DateComponents(year: 2026, month: 3, day: 1))
    }

    private func previewSpreadTitle(for spread: DataModel.Spread) -> String {
        "\(spread.period.displayName): \(spread.displayLabel(calendar: previewCalendar))"
    }

    private func previewSpreadSortOrder(_ lhs: DataModel.Spread, _ rhs: DataModel.Spread) -> Bool {
        let lhsPriority = previewSpreadPriority(lhs.period)
        let rhsPriority = previewSpreadPriority(rhs.period)
        if lhsPriority != rhsPriority {
            return lhsPriority < rhsPriority
        }

        let lhsStart = Period.day.normalizeDate(lhs.startDate ?? lhs.date, calendar: previewCalendar)
        let rhsStart = Period.day.normalizeDate(rhs.startDate ?? rhs.date, calendar: previewCalendar)
        if lhsStart != rhsStart {
            return lhsStart < rhsStart
        }

        return lhs.displayLabel(calendar: previewCalendar) < rhs.displayLabel(calendar: previewCalendar)
    }

    private func previewSpreadPriority(_ period: Period) -> Int {
        switch period {
        case .multiday:
            return 0
        case .day:
            return 1
        case .month:
            return 2
        case .year:
            return 3
        }
    }
}

#Preview("Navigator Overlay Surface") {
    SpreadHeaderNavigatorPreviewSurface()
}
#endif
