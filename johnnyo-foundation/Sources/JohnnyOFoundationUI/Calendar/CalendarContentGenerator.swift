import SwiftUI
import JohnnyOFoundationCore

public protocol CalendarContentGenerator {
    associatedtype HeaderContent: View
    associatedtype WeekdayHeaderContent: View
    associatedtype DayCellContent: View
    associatedtype PlaceholderCellContent: View
    associatedtype WeekBackgroundContent: View

    @ViewBuilder
    func headerView(month: Date) -> HeaderContent

    @ViewBuilder
    func weekdayHeaderView(weekday: Int) -> WeekdayHeaderContent

    @ViewBuilder
    func dayCellView(date: Date) -> DayCellContent

    @ViewBuilder
    func placeholderCellView(date: Date) -> PlaceholderCellContent

    @ViewBuilder
    func weekBackgroundView(week: MonthCalendarWeek) -> WeekBackgroundContent
}
