import Foundation

public enum MonthCalendarModelBuilder {
    public static func makeModel(
        displayedMonth: Date,
        calendar: Calendar,
        configuration: MonthCalendarConfiguration = .init(),
        today: Date = Date()
    ) -> MonthCalendarModel {
        let normalizedMonth = normalizeMonth(displayedMonth, calendar: calendar)
        let monthInterval = calendar.dateInterval(of: .month, for: normalizedMonth)!
        let weekdays = orderedWeekdayContexts(calendar: calendar)
        let weekRows = buildWeekRows(
            monthInterval: monthInterval,
            calendar: calendar,
            configuration: configuration,
            today: today
        )
        let header = MonthCalendarHeaderContext(
            displayedMonth: normalizedMonth,
            monthInterval: monthInterval,
            calendar: calendar,
            configuration: configuration,
            weekCount: weekRows.count
        )

        return MonthCalendarModel(
            header: header,
            weekdays: weekdays,
            weeks: weekRows
        )
    }

    private static func normalizeMonth(_ date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: DateComponents(year: components.year, month: components.month, day: 1))!
    }

    private static func orderedWeekdayContexts(calendar: Calendar) -> [MonthCalendarWeekdayContext] {
        let symbols = calendar.veryShortWeekdaySymbols
        let firstWeekdayIndex = calendar.firstWeekday - 1
        let offsets = Array(firstWeekdayIndex..<symbols.count) + Array(0..<firstWeekdayIndex)
        return offsets.enumerated().map { index, offset in
            MonthCalendarWeekdayContext(
                weekday: offset + 1,
                symbol: symbols[offset],
                index: index
            )
        }
    }

    private static func buildWeekRows(
        monthInterval: DateInterval,
        calendar: Calendar,
        configuration: MonthCalendarConfiguration,
        today: Date
    ) -> [MonthCalendarWeekContext] {
        let firstVisibleDate = startOfWeek(containing: monthInterval.start, calendar: calendar)
        let lastDayOfMonth = calendar.date(byAdding: .day, value: -1, to: monthInterval.end)!
        let lastVisibleWeekStart = startOfWeek(containing: lastDayOfMonth, calendar: calendar)
        let weekCount = calendar.dateComponents([.weekOfYear], from: firstVisibleDate, to: lastVisibleWeekStart).weekOfYear! + 1

        return (0..<weekCount).map { weekIndex in
            let weekStart = calendar.date(byAdding: .weekOfYear, value: weekIndex, to: firstVisibleDate)!
            let slots = (0..<7).map { column in
                let date = calendar.date(byAdding: .day, value: column, to: weekStart)!
                let isInMonth = monthInterval.contains(date)
                if isInMonth || configuration.showsPeripheralDates {
                    return MonthCalendarSlotContext.day(
                        MonthCalendarDayContext(
                            date: date,
                            row: weekIndex,
                            column: column,
                            isInDisplayedMonth: isInMonth,
                            isPeripheral: !isInMonth,
                            isToday: calendar.isDate(date, inSameDayAs: today)
                        )
                    )
                } else {
                    return MonthCalendarSlotContext.placeholder(
                        MonthCalendarPlaceholderContext(
                            representedDate: date,
                            row: weekIndex,
                            column: column,
                            isLeading: date < monthInterval.start,
                            isTrailing: date >= monthInterval.end
                        )
                    )
                }
            }

            return MonthCalendarWeekContext(index: weekIndex, slots: slots)
        }
    }

    private static func startOfWeek(containing date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components)!
    }
}
