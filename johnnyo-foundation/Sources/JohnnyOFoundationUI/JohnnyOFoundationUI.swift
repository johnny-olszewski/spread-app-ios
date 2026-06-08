import SwiftUI
@_exported import JohnnyOFoundationCore
import JohnnyOFoundationCore

public enum JohnnyOFoundationUINamespace {
    public static let packageName = JohnnyOFoundationCoreNamespace.packageName
}

private struct ExampleMonthCalendarGenerator: CalendarContentGenerator {
    func headerView(month: Date) -> some View {
        Text(month.formatted(.dateTime.month(.wide).year()))
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
    }

    func weekdayHeaderView(weekday: Int) -> some View {
        Text(Calendar.current.veryShortWeekdaySymbols[weekday - 1])
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.vertical, 6)
    }

    func dayCellView(date: Date) -> some View {
        let isToday = Calendar.current.isDate(date, inSameDayAs: Date())
        return Text("\(Calendar.current.component(.day, from: date))")
            .font(.body.weight(isToday ? .bold : .regular))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .topLeading)
            .padding(8)
            .background(isToday ? Color.accentColor.opacity(0.12) : Color.clear)
    }

    func placeholderCellView(date: Date) -> some View {
        Color.clear
            .frame(maxWidth: .infinity, minHeight: 40)
    }

    func weekBackgroundView(week: MonthCalendarWeek) -> some View {
        Color.clear.frame(maxWidth: .infinity, minHeight: 0)
    }
}

public struct JohnnyOFoundationPackagePreview: View {
    public init() {}

    public var body: some View {
        MonthCalendarView(
            displayedMonth: Date(),
            calendar: Calendar.current,
            configuration: .init(showsPeripheralDates: true),
            contentGenerator: ExampleMonthCalendarGenerator()
        )
        .padding()
    }
}

#Preview {
    JohnnyOFoundationPackagePreview()
}
