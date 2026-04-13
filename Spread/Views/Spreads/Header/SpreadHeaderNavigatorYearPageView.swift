import SwiftUI

struct SpreadHeaderNavigatorYearPageView: View {
    private struct WeekdayHeader: Identifiable {
        let weekday: Int
        let symbol: String

        var id: Int { weekday }
    }

    let page: SpreadHeaderNavigatorModel.YearPage
    let model: SpreadHeaderNavigatorModel
    let currentSpread: DataModel.Spread
    @Binding var expandedMonth: Date?
    let onSelect: (SpreadHeaderNavigatorModel.Selection) -> Void
    let onDismiss: () -> Void

    @State private var dialogTargets: [SpreadHeaderNavigatorModel.SelectionTarget] = []
    @State private var isShowingSelectionDialog = false

    private var weekdayHeaders: [WeekdayHeader] {
        let symbols = model.calendar.veryShortWeekdaySymbols
        let firstWeekday = model.calendar.firstWeekday - 1
        let orderedOffsets = Array(firstWeekday..<symbols.count) + Array(0..<firstWeekday)
        return orderedOffsets.map { offset in
            WeekdayHeader(weekday: offset + 1, symbol: symbols[offset])
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
            HStack(spacing: 12) {
                Button {
                    expandedMonth = isExpanded ? nil : monthRow.date
                } label: {
                    HStack(spacing: 10) {
                        Text(monthRow.date.formatted(.dateTime.month(.wide)))
                            .font(SpreadTheme.Typography.body)
                            .foregroundStyle(monthRow.isDerived ? .secondary : .primary)
                        Spacer(minLength: 8)
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(model.isCurrent(monthRow: monthRow, currentSpread: currentSpread) ? Color.accentColor.opacity(0.16) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(
                    Definitions.AccessibilityIdentifiers.SpreadNavigator.monthRow(year: page.year, month: monthValue)
                )

                if isExpanded, let selection = model.selectionTarget(for: monthRow) {
                    Button("View Month") {
                        onSelect(selection)
                        onDismiss()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier(
                        Definitions.AccessibilityIdentifiers.SpreadNavigator.viewMonthButton(year: page.year, month: monthValue)
                    )
                }
            }

            if isExpanded {
                calendarGrid(for: monthRow)
                    .padding(.leading, 8)
            }
        }
    }

    private func calendarGrid(for monthRow: SpreadHeaderNavigatorModel.MonthRow) -> some View {
        let cells = CalendarGridHelper.cells(for: monthRow.date, calendar: model.calendar)
        return VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(weekdayHeaders) { header in
                    Text(header.symbol)
                        .font(SpreadTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, cellDate in
                    if let date = cellDate {
                        dayCell(for: date, monthRow: monthRow)
                    } else {
                        Color.clear
                            .frame(height: 40)
                    }
                }
            }
            .accessibilityIdentifier(
                Definitions.AccessibilityIdentifiers.SpreadNavigator.grid(
                    year: page.year,
                    month: model.calendar.component(.month, from: monthRow.date)
                )
            )
        }
    }

    private func dayCell(for date: Date, monthRow: SpreadHeaderNavigatorModel.MonthRow) -> some View {
        let targets = monthRow.targets(for: date, calendar: model.calendar)
        let isSelectable = !targets.isEmpty
        let isCurrent = model.isCurrent(date: date, currentSpread: currentSpread)

        return Button {
            if targets.count == 1, let selection = targets.first?.selection {
                onSelect(selection)
                onDismiss()
            } else {
                dialogTargets = targets
                isShowingSelectionDialog = true
            }
        } label: {
            Text("\(model.calendar.component(.day, from: date))")
                .font(SpreadTheme.Typography.body)
                .foregroundStyle(isSelectable ? .primary : .tertiary)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isCurrent ? Color.accentColor.opacity(0.16) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            isSelectable ? Color.secondary.opacity(0.12) : Color.clear,
                            lineWidth: 0.8
                        )
                )
        }
        .buttonStyle(.plain)
        .disabled(!isSelectable)
        .accessibilityIdentifier(
            Definitions.AccessibilityIdentifiers.SpreadNavigator.dayTile(date: date, calendar: model.calendar)
        )
    }
}
