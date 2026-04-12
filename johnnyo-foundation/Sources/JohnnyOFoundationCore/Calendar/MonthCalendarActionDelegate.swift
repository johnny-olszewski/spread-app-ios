import Foundation

public protocol MonthCalendarActionDelegate {
    func monthCalendarDidTapHeader(_ context: MonthCalendarHeaderContext)
    func monthCalendarDidTapWeekdayHeader(_ context: MonthCalendarWeekdayContext)
    func monthCalendarDidTapDay(_ context: MonthCalendarDayContext)
    func monthCalendarDidTapPlaceholder(_ context: MonthCalendarPlaceholderContext)
    func monthCalendarDidTapWeek(_ context: MonthCalendarWeekContext)
}

public extension MonthCalendarActionDelegate {
    func monthCalendarDidTapHeader(_ context: MonthCalendarHeaderContext) {}
    func monthCalendarDidTapWeekdayHeader(_ context: MonthCalendarWeekdayContext) {}
    func monthCalendarDidTapDay(_ context: MonthCalendarDayContext) {}
    func monthCalendarDidTapPlaceholder(_ context: MonthCalendarPlaceholderContext) {}
    func monthCalendarDidTapWeek(_ context: MonthCalendarWeekContext) {}
}
