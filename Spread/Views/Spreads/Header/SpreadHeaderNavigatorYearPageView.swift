import SwiftUI
import JohnnyOFoundationUI

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

                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .animation(.easeInOut(duration: 0.2), value: isExpanded)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(model.isCurrent(monthRow: monthRow, currentSpread: currentSpread) ? Color.accentColor.opacity(0.16) : Color.clear)
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
                    .transition(.opacity.combined(with: .move(edge: .top)))
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
