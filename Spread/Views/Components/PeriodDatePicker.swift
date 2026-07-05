import SwiftUI
import JohnnyOFoundationUI
import JohnnyOFoundationCore

struct PeriodDatePicker: View {
    struct AccessibilityIdentifiers {
        let dayPicker: String?
        let yearPicker: String?
        let monthPicker: String?
        let monthYearPicker: String?

        init(
            dayPicker: String? = nil,
            yearPicker: String? = nil,
            monthPicker: String? = nil,
            monthYearPicker: String? = nil
        ) {
            self.dayPicker = dayPicker
            self.yearPicker = yearPicker
            self.monthPicker = monthPicker
            self.monthYearPicker = monthYearPicker
        }
    }

    /// Spread-awareness for the day/multiday calendar (EntryEditingSheets.md — Visual Redesign).
    ///
    /// When provided, existing day spreads tint their cells, multiday spreads render as
    /// coverage bars, and — for `period == .multiday` — tapping a date covered by a multiday
    /// spread selects that spread via `onMultidaySpreadSelected` instead of picking the raw
    /// date. Tapping an uncovered date in multiday mode is a no-op.
    /// - TODO: [SPRD-294] Uncovered taps will begin a free start/end range selection.
    struct SpreadContext {
        let spreads: [DataModel.Spread]
        let selectedSpreadID: UUID?
        let onMultidaySpreadSelected: (DataModel.Spread) -> Void
    }

    let period: Period
    @Binding var selectedDate: Date
    let calendar: Calendar
    let today: Date
    let minimumDate: Date
    let maximumDate: Date
    let accessibilityIdentifiers: AccessibilityIdentifiers?
    var spreadContext: SpreadContext? = nil

    var body: some View {
        switch period {
        case .year:
            yearPicker
        case .month:
            monthPicker
        case .day:
            dayPicker
        case .multiday:
            dayPicker
        }
    }

    private var yearPicker: some View {
        Picker("Year", selection: $selectedDate) {
            ForEach(availableYears, id: \.self) { year in
                Text(String(year))
                    .tag(dateFor(year: year))
            }
        }
        .pickerStyle(.wheel)
        .applyAccessibilityIdentifier(accessibilityIdentifiers?.yearPicker)
    }

    private var monthPicker: some View {
        VStack(spacing: 12) {
            Picker("Year", selection: Binding(
                get: { calendar.component(.year, from: selectedDate) },
                set: { updateMonth(year: $0) }
            )) {
                ForEach(availableYears, id: \.self) { year in
                    Text(String(year))
                        .tag(year)
                }
            }
            .applyAccessibilityIdentifier(accessibilityIdentifiers?.monthYearPicker)

            Picker("Month", selection: Binding(
                get: { calendar.component(.month, from: selectedDate) },
                set: { updateMonth(month: $0) }
            )) {
                ForEach(availableMonths, id: \.self) { month in
                    Text(monthName(for: month))
                        .tag(month)
                }
            }
            .pickerStyle(.wheel)
            .applyAccessibilityIdentifier(accessibilityIdentifiers?.monthPicker)
        }
    }

    private var dayPicker: some View {
        CalendarView(
            startDate: minimumDate,
            endDate: maximumDate,
            calendar: calendar,
            today: today,
            configuration: .init(showsPeripheralDates: false),
            displayConfiguration: .singleMonthPager,
            contentGenerator: EntrySheetCalendarGenerator(
                selectedDate: selectedDate,
                minimumDate: minimumDate,
                maximumDate: maximumDate,
                calendar: calendar,
                today: today,
                daySpreadDates: daySpreadDates,
                highlightedRange: highlightedRange
            ),
            rowOverlayGenerator: SpreadsNavigatorView.RowOverlayGenerator(
                spreads: spreadContext?.spreads ?? [],
                calendar: calendar
            ),
            initialScrollTarget: initialDayScrollTarget,
            onDateTapped: handleDayTap
        )
        .frame(height: 320)
        .applyAccessibilityIdentifier(accessibilityIdentifiers?.dayPicker)
    }

    // MARK: - Spread Context Helpers

    /// Start-of-day dates covered by existing day spreads, for created-cell tinting.
    private var daySpreadDates: Set<Date> {
        guard let spreadContext else { return [] }
        return Set(
            spreadContext.spreads
                .filter { $0.period == .day }
                .map { $0.date.startOfDay(calendar: calendar) }
        )
    }

    /// The selected multiday spread's range, for continuous selection tinting.
    private var highlightedRange: ClosedRange<Date>? {
        guard period == .multiday,
              let spreadContext,
              let selected = spreadContext.spreads.first(where: { $0.id == spreadContext.selectedSpreadID })
        else { return nil }
        let start = (selected.startDate ?? selected.date).startOfDay(calendar: calendar)
        let end = (selected.endDate ?? selected.date).startOfDay(calendar: calendar)
        return start <= end ? start...end : nil
    }

    /// In multiday mode with a selected spread, open the calendar on the spread's range.
    private var initialDayScrollTarget: Date {
        if period == .multiday, let highlightedRange {
            return highlightedRange.lowerBound
        }
        return selectedDate
    }

    private func handleDayTap(_ date: Date) {
        guard date >= minimumDate && date <= maximumDate else { return }
        if period == .multiday, let spreadContext {
            let tapped = date.startOfDay(calendar: calendar)
            guard let spread = spreadContext.spreads.first(where: {
                $0.period == .multiday && $0.contains(date: tapped, calendar: calendar)
            }) else { return }
            spreadContext.onMultidaySpreadSelected(spread)
        } else {
            selectedDate = date.startOfDay(calendar: calendar)
        }
    }

    private var availableYears: [Int] {
        let currentYear = calendar.component(.year, from: today)
        return Array(currentYear...(currentYear + 10))
    }

    private var availableMonths: [Int] {
        let currentYear = calendar.component(.year, from: today)
        let selectedYear = calendar.component(.year, from: selectedDate)
        let currentMonth = calendar.component(.month, from: today)

        if selectedYear == currentYear {
            return Array(currentMonth...12)
        }

        return Array(1...12)
    }

    private func monthName(for month: Int) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        return formatter.monthSymbols[month - 1]
    }

    private func dateFor(year: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = 1
        components.day = 1
        return calendar.date(from: components) ?? today
    }

    private func updateMonth(year: Int) {
        var components = calendar.dateComponents([.month], from: selectedDate)
        components.year = year
        components.day = 1

        let currentYear = calendar.component(.year, from: today)
        let currentMonth = calendar.component(.month, from: today)

        if year == currentYear, let month = components.month, month < currentMonth {
            components.month = currentMonth
        }

        if let newDate = calendar.date(from: components) {
            selectedDate = newDate
        }
    }

    private func updateMonth(month: Int) {
        var components = calendar.dateComponents([.year], from: selectedDate)
        components.month = month
        components.day = 1

        if let newDate = calendar.date(from: components) {
            selectedDate = newDate
        }
    }
}

private extension View {
    @ViewBuilder
    func applyAccessibilityIdentifier(_ identifier: String?) -> some View {
        if let identifier {
            self.accessibilityIdentifier(identifier)
        } else {
            self
        }
    }
}
