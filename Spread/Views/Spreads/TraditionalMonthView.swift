import SwiftUI

/// Month view for traditional mode showing a calendar grid.
///
/// Displays a standard calendar grid with 7 columns (respecting firstWeekday)
/// and 5-6 rows. Day cells show entry count indicators. Tapping a day
/// triggers navigation to the day view.
struct TraditionalMonthView: View {

    // MARK: - Properties

    /// The journal manager providing entry data.
    let journalManager: JournalManager

    /// The month to display (normalized to 1st of month).
    let monthDate: Date

    /// Callback when a day is selected for navigation.
    var onSelectDay: ((Date) -> Void)?

    /// Callback to navigate back to year view.
    var onBackToYear: (() -> Void)?

    // MARK: - Private

    private var calendar: Calendar {
        journalManager.firstWeekday.configuredCalendar(from: journalManager.calendar)
    }

    private var traditionalService: TraditionalSpreadService {
        TraditionalSpreadService(calendar: journalManager.calendar)
    }

    /// Month and year title (e.g., "January 2026").
    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: monthDate)
    }

    /// Weekday headers (e.g., "S", "M", "T", ...) ordered by firstWeekday.
    private var weekdayHeaders: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let firstWeekday = calendar.firstWeekday - 1
        return Array(symbols[firstWeekday...]) + Array(symbols[..<firstWeekday])
    }

    /// All calendar cells for the month grid (includes leading/trailing nil for alignment).
    private var calendarCells: [Date?] {
        CalendarGridHelper.cells(for: monthDate, calendar: calendar)
    }

    // MARK: - Body

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Navigation header
                HStack {
                    if onBackToYear != nil {
                        Button {
                            onBackToYear?()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.caption)
                                Text(String(calendar.component(.year, from: monthDate)))
                                    .font(SpreadTheme.Typography.subheadline)
                            }
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal)

                // Month title
                Text(monthTitle)
                    .font(SpreadTheme.Typography.largeTitle)
                    .padding(.horizontal)
                    .accessibilityIdentifier("traditionalMonthTitle")

                // Month-level entries summary
                monthEntriesSummary

                // Weekday headers
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(weekdayHeaders, id: \.self) { header in
                        Text(header)
                            .font(SpreadTheme.Typography.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)

                // Calendar grid
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(Array(calendarCells.enumerated()), id: \.offset) { _, date in
                        if let date {
                            DayCell(
                                date: date,
                                entryCount: dayEntryCount(for: date),
                                isToday: isToday(date),
                                calendar: calendar
                            )
                            .onTapGesture {
                                onSelectDay?(date)
                            }
                        } else {
                            Color.clear
                                .frame(height: 44)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .dotGridBackground(.paper)
        .accessibilityIdentifier("traditionalMonthView")
    }

    // MARK: - Month-Level Entries

    /// Shows month-period entries (entries assigned at month level, not day level).
    @ViewBuilder
    private var monthEntriesSummary: some View {
        let monthModel = traditionalService.virtualSpreadDataModel(
            period: .month,
            date: monthDate,
            tasks: journalManager.tasks.filter { $0.period == .month },
            notes: journalManager.notes.filter { $0.period == .month },
            events: []
        )

        let monthEntryCount = monthModel.tasks.count + monthModel.notes.count
        if monthEntryCount > 0 {
            HStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(monthEntryCount) month-level entr\(monthEntryCount == 1 ? "y" : "ies")")
                    .font(SpreadTheme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Helpers

    /// Returns the entry count for a specific day.
    private func dayEntryCount(for date: Date) -> Int {
        let dataModel = traditionalService.virtualSpreadDataModel(
            period: .day,
            date: date,
            tasks: journalManager.tasks,
            notes: journalManager.notes,
            events: journalManager.events
        )
        return dataModel.tasks.count + dataModel.notes.count + dataModel.events.count
    }

    /// Whether the given date is today.
    private func isToday(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: journalManager.today)
    }
}

// MARK: - Day Cell

/// A cell in the calendar grid representing a single day.
private struct DayCell: View {
    let date: Date
    let entryCount: Int
    let isToday: Bool
    let calendar: Calendar

    private var dayNumber: Int {
        calendar.component(.day, from: date)
    }

    var body: some View {
        VStack(spacing: 2) {
            Text("\(dayNumber)")
                .font(SpreadTheme.Typography.body)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(isToday ? Color.accentColor : .primary)

            // Entry count dots
            if entryCount > 0 {
                HStack(spacing: 2) {
                    ForEach(0..<min(entryCount, 3), id: \.self) { _ in
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 4, height: 4)
                    }
                    if entryCount > 3 {
                        Text("+")
                            .font(.system(size: 6))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: 6)
            } else {
                Spacer()
                    .frame(height: 6)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isToday ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Day \(dayNumber), \(entryCount) entries")
        .accessibilityIdentifier("dayCell_\(dayNumber)")
    }
}

// MARK: - Calendar Grid Helper

/// Generates calendar grid cells for a month, including leading/trailing empty cells.
enum CalendarGridHelper {

    /// Returns an array of optional dates for a calendar grid.
    ///
    /// Leading `nil` values represent empty cells before the first day.
    /// Trailing `nil` values fill the last row to 7 columns.
    ///
    /// - Parameters:
    ///   - monthDate: The first day of the month.
    ///   - calendar: The calendar to use (determines firstWeekday).
    /// - Returns: Array of optional dates for the grid.
    static func cells(for monthDate: Date, calendar: Calendar) -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: monthDate) else {
            return []
        }

        let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate))!
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)

        // Calculate leading empty cells
        var leadingEmpty = firstWeekday - calendar.firstWeekday
        if leadingEmpty < 0 { leadingEmpty += 7 }

        var cells: [Date?] = Array(repeating: nil, count: leadingEmpty)

        // Add actual days
        for day in range {
            if let date = calendar.date(bySetting: .day, value: day, of: firstDayOfMonth) {
                cells.append(date)
            }
        }

        // Add trailing empty cells to fill last row
        let remainder = cells.count % 7
        if remainder > 0 {
            cells.append(contentsOf: Array(repeating: nil as Date?, count: 7 - remainder))
        }

        return cells
    }
}

// MARK: - Preview

#Preview("Month with entries") {
    TraditionalMonthView(
        journalManager: .previewInstance,
        monthDate: Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 1))!,
        onSelectDay: { day in
            print("Selected day: \(day)")
        },
        onBackToYear: {
            print("Back to year")
        }
    )
}

#Preview("Empty month") {
    TraditionalMonthView(
        journalManager: .previewInstance,
        monthDate: Calendar.current.date(from: DateComponents(year: 2030, month: 6, day: 1))!,
        onSelectDay: nil,
        onBackToYear: nil
    )
}
