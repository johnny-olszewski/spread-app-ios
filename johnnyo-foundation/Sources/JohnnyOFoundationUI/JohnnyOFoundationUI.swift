import SwiftUI
@_exported import JohnnyOFoundationCore
import JohnnyOFoundationCore

public enum JohnnyOFoundationUINamespace {
    public static let packageName = JohnnyOFoundationCoreNamespace.packageName
}

private struct ExampleMonthCalendarGenerator: CalendarContentGenerator {
    func headerView(context: MonthCalendarHeaderContext) -> some View {
        Text(context.displayedMonth.formatted(.dateTime.month(.wide).year()))
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
    }

    func weekdayHeaderView(context: MonthCalendarWeekdayContext) -> some View {
        Text(context.symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.vertical, 6)
    }

    func dayCellView(context: MonthCalendarDayContext) -> some View {
        Text("\(Calendar.current.component(.day, from: context.date))")
            .font(.body.weight(context.isToday ? .bold : .regular))
            .foregroundStyle(context.isPeripheral ? .secondary : .primary)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .topLeading)
            .padding(8)
            .background(context.isToday ? Color.accentColor.opacity(0.12) : Color.clear)
    }

    func placeholderCellView(context: MonthCalendarPlaceholderContext) -> some View {
        Color.clear
            .frame(maxWidth: .infinity, minHeight: 40)
    }

    func weekBackgroundView(context: MonthCalendarWeekContext) -> some View {
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
