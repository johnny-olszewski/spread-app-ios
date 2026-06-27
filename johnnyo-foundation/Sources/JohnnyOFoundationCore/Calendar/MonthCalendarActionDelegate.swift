import Foundation

public protocol MonthCalendarActionDelegate {
    func monthCalendarDidTapHeader(month: Date)
    func monthCalendarDidTapWeekdayHeader(weekday: Int)
    func monthCalendarDidTapDay(date: Date)
    func monthCalendarDidTapPlaceholder(date: Date)
    func monthCalendarDidTapWeek(week: MonthCalendarWeek)
}

public extension MonthCalendarActionDelegate {
    func monthCalendarDidTapHeader(month: Date) {}
    func monthCalendarDidTapWeekdayHeader(weekday: Int) {}
    func monthCalendarDidTapDay(date: Date) {}
    func monthCalendarDidTapPlaceholder(date: Date) {}
    func monthCalendarDidTapWeek(week: MonthCalendarWeek) {}
}
