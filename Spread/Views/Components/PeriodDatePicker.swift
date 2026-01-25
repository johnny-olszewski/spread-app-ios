import SwiftUI

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

    let period: Period
    @Binding var selectedDate: Date
    let calendar: Calendar
    let today: Date
    let minimumDate: Date
    let maximumDate: Date
    let accessibilityIdentifiers: AccessibilityIdentifiers?

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
        DatePicker(
            "Date",
            selection: $selectedDate,
            in: minimumDate...maximumDate,
            displayedComponents: [.date]
        )
        .datePickerStyle(.graphical)
        .applyAccessibilityIdentifier(accessibilityIdentifiers?.dayPicker)
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
