import SwiftUI
import JohnnyOFoundationUI
import JohnnyOFoundationCore

/// A `CalendarContentGenerator` for the entry sheet day-picker context.
///
/// Renders month headers, weekday column headers, and day cells with three visual states:
/// - **Selected**: filled accent circle (the current `selectedDate`).
/// - **Today**: outlined accent circle (today when not selected).
/// - **Out-of-range**: dimmed and not interactive (before `minimumDate` or after `maximumDate`).
/// - **Default**: plain day number.
///
/// The generator is a value type and is recreated on every render of `PeriodDatePicker`,
/// so `selectedDate` is always current without any additional observation machinery.
struct EntrySheetCalendarGenerator: CalendarContentGenerator {

    let selectedDate: Date
    let minimumDate: Date
    let maximumDate: Date
    let calendar: Calendar
    let today: Date

    // MARK: - Header

    func headerView(month: Date) -> some View {
        let formatter: DateFormatter = {
            let f = DateFormatter()
            f.calendar = calendar
            f.timeZone = calendar.timeZone
            f.dateFormat = "MMMM yyyy"
            return f
        }()

        return HStack {
            Text(formatter.string(from: month))
                .font(SpreadTheme.Typography.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 16)
        .padding(.bottom, 4)
    }

    // MARK: - Weekday Header

    func weekdayHeaderView(weekday: Int) -> some View {
        Text(calendar.veryShortWeekdaySymbols[weekday - 1].prefix(1))
            .font(SpreadTheme.Typography.caption2)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Day Cell

    func dayCellView(date: Date) -> some View {
        let dayNumber = calendar.component(.day, from: date)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDate(date, inSameDayAs: today)
        let isInRange = date >= minimumDate && date <= maximumDate

        return Text("\(dayNumber)")
            .font(SpreadTheme.Typography.subheadline)
            .fontWeight(isSelected || isToday ? .semibold : .regular)
            .foregroundStyle(cellTextColor(isSelected: isSelected, isToday: isToday, isInRange: isInRange))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(cellBackground(isSelected: isSelected, isToday: isToday, isInRange: isInRange))
            .clipShape(Circle())
            .aspectRatio(1, contentMode: .fit)
            .padding(3)
    }

    // MARK: - Placeholder Cell

    func placeholderCellView(date: Date) -> some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Week Background

    func weekBackgroundView(week: MonthCalendarWeek) -> some View {
        Color.clear
    }

    // MARK: - Private Helpers

    private func cellTextColor(isSelected: Bool, isToday: Bool, isInRange: Bool) -> Color {
        if !isInRange { return .secondary.opacity(0.4) }
        if isSelected { return .white }
        if isToday { return .accentColor }
        return .primary
    }

    @ViewBuilder
    private func cellBackground(isSelected: Bool, isToday: Bool, isInRange: Bool) -> some View {
        if isSelected {
            Color.accentColor
        } else if isToday && isInRange {
            Color.accentColor.opacity(0.15)
        } else {
            Color.clear
        }
    }
}
