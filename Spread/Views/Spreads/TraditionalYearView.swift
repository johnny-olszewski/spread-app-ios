import SwiftUI

/// Year view for traditional mode showing a grid of 12 months.
///
/// Displays all months of a year in a grid layout. Each month cell shows
/// the month name and entry count. Tapping a month triggers navigation
/// to the month view. Uses virtual spread data from `TraditionalSpreadService`.
struct TraditionalYearView: View {

    // MARK: - Properties

    /// The journal manager providing entry data.
    let journalManager: JournalManager

    /// The year to display (normalized to Jan 1).
    let yearDate: Date

    /// Callback when a month is selected for navigation.
    var onSelectMonth: ((Date) -> Void)?

    // MARK: - Private

    private var calendar: Calendar { journalManager.calendar }

    private var yearNumber: Int {
        calendar.component(.year, from: yearDate)
    }

    private var traditionalService: TraditionalSpreadService {
        TraditionalSpreadService(calendar: calendar)
    }

    /// All 12 month dates for this year.
    private var allMonths: [Date] {
        (1...12).compactMap { month in
            calendar.date(from: DateComponents(year: yearNumber, month: month, day: 1))
        }
    }

    // MARK: - Body

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Year title
                Text(String(yearNumber))
                    .font(SpreadTheme.Typography.largeTitle)
                    .padding(.horizontal)
                    .accessibilityIdentifier("traditionalYearTitle")

                // Month grid
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(allMonths, id: \.self) { monthDate in
                        MonthCell(
                            monthDate: monthDate,
                            entryCount: entryCount(for: monthDate),
                            calendar: calendar,
                            isCurrentMonth: isCurrentMonth(monthDate)
                        )
                        .onTapGesture {
                            onSelectMonth?(monthDate)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .dotGridBackground(.paper)
        .accessibilityIdentifier("traditionalYearView")
    }

    // MARK: - Helpers

    /// Returns the total entry count for a given month.
    private func entryCount(for monthDate: Date) -> Int {
        let dataModel = traditionalService.virtualSpreadDataModel(
            period: .month,
            date: monthDate,
            tasks: journalManager.tasks,
            notes: journalManager.notes,
            events: FeatureFlags.eventsEnabled ? journalManager.events : []
        )
        return dataModel.tasks.count + dataModel.notes.count
    }

    /// Whether the given month is the current month.
    private func isCurrentMonth(_ monthDate: Date) -> Bool {
        let todayYear = calendar.component(.year, from: journalManager.today)
        let todayMonth = calendar.component(.month, from: journalManager.today)
        let monthYear = calendar.component(.year, from: monthDate)
        let monthMonth = calendar.component(.month, from: monthDate)
        return todayYear == monthYear && todayMonth == monthMonth
    }
}

// MARK: - Month Cell

/// A cell in the year grid representing a single month.
private struct MonthCell: View {
    let monthDate: Date
    let entryCount: Int
    let calendar: Calendar
    let isCurrentMonth: Bool

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "MMM"
        return formatter.string(from: monthDate)
    }

    private var fullMonthName: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "MMMM"
        return formatter.string(from: monthDate)
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(monthName)
                .font(SpreadTheme.Typography.title3)
                .foregroundStyle(isCurrentMonth ? Color.accentColor : .primary)

            if entryCount > 0 {
                Text("\(entryCount)")
                    .font(SpreadTheme.Typography.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("—")
                    .font(SpreadTheme.Typography.caption)
                    .foregroundStyle(.quaternary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isCurrentMonth ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(fullMonthName), \(entryCount) entries")
        .accessibilityIdentifier("monthCell_\(calendar.component(.month, from: monthDate))")
    }
}

// MARK: - Preview

#Preview("Year with entries") {
    TraditionalYearView(
        journalManager: .previewInstance,
        yearDate: Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1))!,
        onSelectMonth: { month in
            print("Selected month: \(month)")
        }
    )
}

#Preview("Empty year") {
    let calendar = Calendar.current
    let yearDate = calendar.date(from: DateComponents(year: 2030, month: 1, day: 1))!

    TraditionalYearView(
        journalManager: .previewInstance,
        yearDate: yearDate,
        onSelectMonth: nil
    )
}
