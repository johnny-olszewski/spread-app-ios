import SwiftUI

struct SpreadHeaderNavigatorPopoverView: View {
    let model: SpreadHeaderNavigatorModel
    let currentSpread: DataModel.Spread
    let onSelect: (SpreadHeaderNavigatorModel.Selection) -> Void
    let onDismiss: () -> Void

    @State private var expandedYear: Int?
    @State private var expandedMonth: Date?

    var body: some View {
        List {
            ForEach(model.rootYears()) { yearRow in
                navigatorDisclosureSection(
                    isExpanded: expandedYear == yearRow.year,
                    disclosureIdentifier: Definitions.AccessibilityIdentifiers.SpreadNavigator.yearDisclosure(yearRow.year),
                    onToggle: {
                        if expandedYear == yearRow.year {
                            expandedYear = nil
                            expandedMonth = nil
                        } else {
                            let state = model.toggledYear(yearRow.year, from: currentExpansion)
                            expandedYear = state.expandedYear
                            expandedMonth = state.expandedMonth
                        }
                    }
                ) {
                    monthSection(for: yearRow.year)
                } label: {
                    navigatorRowLabel(
                        title: String(yearRow.year),
                        isCurrent: model.isCurrent(yearRow: yearRow, currentSpread: currentSpread),
                        isDerived: yearRow.isDerived,
                        rowIdentifier: Definitions.AccessibilityIdentifiers.SpreadNavigator.yearRow(yearRow.year),
                        directSelection: model.selection(for: yearRow)
                    )
                }
                .listRowInsets(.init(top: 6, leading: 8, bottom: 6, trailing: 8))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .frame(minWidth: 360, idealWidth: 420, maxWidth: 480, minHeight: 420, idealHeight: 560, maxHeight: 680)
        .background(SpreadTheme.Paper.primary)
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadNavigator.popover)
        .onAppear {
            let initialExpansion = model.initialExpansion(for: currentSpread)
            expandedYear = initialExpansion.expandedYear
            expandedMonth = initialExpansion.expandedMonth
            #if DEBUG
            print(
                "[SpreadHeaderNavigatorPopoverView] appear current=\(currentSpread.displayLabel(calendar: model.calendar)) year=\(String(describing: expandedYear)) month=\(String(describing: expandedMonth))"
            )
            #endif
        }
        .onDisappear {
            #if DEBUG
            print("[SpreadHeaderNavigatorPopoverView] disappear current=\(currentSpread.displayLabel(calendar: model.calendar))")
            #endif
        }
    }

    @ViewBuilder
    private func monthSection(for year: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(model.months(in: year)) { monthRow in
                let monthValue = model.calendar.component(.month, from: monthRow.date)
                navigatorDisclosureSection(
                    isExpanded: expandedMonth == monthRow.date,
                    disclosureIdentifier: Definitions.AccessibilityIdentifiers.SpreadNavigator.monthDisclosure(year: year, month: monthValue),
                    onToggle: {
                        if expandedMonth == monthRow.date {
                            expandedMonth = nil
                        } else {
                            let state = model.toggledMonth(monthRow.date, in: year, from: currentExpansion)
                            expandedYear = state.expandedYear
                            expandedMonth = state.expandedMonth
                        }
                    }
                ) {
                    monthGrid(forYear: year, month: monthValue)
                        .padding(.top, 8)
                } label: {
                    navigatorRowLabel(
                        title: monthRow.date.formatted(.dateTime.month(.wide)),
                        isCurrent: model.isCurrent(monthRow: monthRow, currentSpread: currentSpread),
                        isDerived: monthRow.isDerived,
                        rowIdentifier: Definitions.AccessibilityIdentifiers.SpreadNavigator.monthRow(year: year, month: monthValue),
                        directSelection: model.selection(for: monthRow)
                    )
                }
            }
        }
    }

    private func navigatorDisclosureSection<Label: View, Content: View>(
        isExpanded: Bool,
        disclosureIdentifier: String,
        onToggle: @escaping () -> Void,
        @ViewBuilder content: () -> Content,
        @ViewBuilder label: () -> Label
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                label()
                Spacer(minLength: 8)
                Button(action: onToggle) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(disclosureIdentifier)
            }

            if isExpanded {
                content()
                    .padding(.leading, 18)
            }
        }
    }

    private func monthGrid(forYear year: Int, month: Int) -> some View {
        let items = model.monthGridItems(year: year, month: month)
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
            spacing: 10
        ) {
            ForEach(items) { item in
                Button {
                    guard let selection = model.selection(for: item) else { return }
                    onSelect(selection)
                    onDismiss()
                } label: {
                    Text(item.label)
                        .font(SpreadTheme.Typography.body)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(tileBackground(for: item))
                        .overlay(tileBorder(for: item))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(gridIdentifier(for: item))
            }
        }
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadNavigator.grid(year: year, month: month))
    }

    @ViewBuilder
    private func navigatorRowLabel(
        title: String,
        isCurrent: Bool,
        isDerived: Bool,
        rowIdentifier: String,
        directSelection: SpreadHeaderNavigatorModel.Selection?
    ) -> some View {
        HStack(spacing: 12) {
            if let selection = directSelection {
                Button {
                    onSelect(selection)
                    onDismiss()
                } label: {
                    rowLabel(title: title, isCurrent: isCurrent, isDerived: isDerived)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(rowIdentifier)
            } else {
                rowLabel(title: title, isCurrent: isCurrent, isDerived: isDerived)
                    .accessibilityIdentifier(rowIdentifier)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func rowLabel(title: String, isCurrent: Bool, isDerived: Bool) -> some View {
        Text(title)
            .font(SpreadTheme.Typography.body)
            .foregroundStyle(isDerived ? .secondary : .primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isCurrent ? Color.accentColor.opacity(0.16) : Color.clear)
            )
    }

    private func tileBackground(for item: SpreadHeaderNavigatorModel.MonthGridItem) -> some ShapeStyle {
        if model.isCurrent(item: item, currentSpread: currentSpread) {
            return AnyShapeStyle(Color.accentColor.opacity(0.16))
        }
        if item.isMultiday {
            return AnyShapeStyle(Color.accentColor.opacity(0.08))
        }
        return AnyShapeStyle(SpreadTheme.Paper.primary.opacity(0.92))
    }

    private func tileBorder(for item: SpreadHeaderNavigatorModel.MonthGridItem) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(
                item.isMultiday ? Color.accentColor.opacity(0.28) : Color.secondary.opacity(0.12),
                lineWidth: item.isMultiday ? 1 : 0.8
            )
    }

    private var currentExpansion: SpreadHeaderNavigatorModel.ExpansionState {
        .init(expandedYear: expandedYear, expandedMonth: expandedMonth)
    }

    private func gridIdentifier(for item: SpreadHeaderNavigatorModel.MonthGridItem) -> String {
        switch item.kind {
        case .day(let date):
            return Definitions.AccessibilityIdentifiers.SpreadNavigator.dayTile(date: date, calendar: model.calendar)
        case .multiday(let spread):
            return Definitions.AccessibilityIdentifiers.SpreadNavigator.multidayTile(
                startDate: spread.startDate ?? spread.date,
                endDate: spread.endDate ?? spread.date,
                calendar: model.calendar
            )
        }
    }
}
