import SwiftUI
import JohnnyOFoundationCore

public protocol CalendarContentGenerator {
    associatedtype HeaderContent: View
    associatedtype WeekdayHeaderContent: View
    associatedtype DayCellContent: View
    associatedtype PlaceholderCellContent: View
    associatedtype WeekBackgroundContent: View

    @ViewBuilder
    func headerView(context: MonthCalendarHeaderContext) -> HeaderContent

    @ViewBuilder
    func weekdayHeaderView(context: MonthCalendarWeekdayContext) -> WeekdayHeaderContent

    @ViewBuilder
    func dayCellView(context: MonthCalendarDayContext) -> DayCellContent

    @ViewBuilder
    func placeholderCellView(context: MonthCalendarPlaceholderContext) -> PlaceholderCellContent

    @ViewBuilder
    func weekBackgroundView(context: MonthCalendarWeekContext) -> WeekBackgroundContent
}
