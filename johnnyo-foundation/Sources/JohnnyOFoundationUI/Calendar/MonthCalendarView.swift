import SwiftUI
import JohnnyOFoundationCore

public struct MonthCalendarView<Generator: CalendarContentGenerator>: View {
    private let model: MonthCalendarModel
    private let contentGenerator: Generator
    private let actionDelegate: (any MonthCalendarActionDelegate)?

    public init(
        displayedMonth: Date,
        calendar: Calendar,
        today: Date = Date(),
        configuration: MonthCalendarConfiguration = .init(),
        contentGenerator: Generator,
        actionDelegate: (any MonthCalendarActionDelegate)? = nil
    ) {
        self.model = MonthCalendarModelBuilder.makeModel(
            displayedMonth: displayedMonth,
            calendar: calendar,
            configuration: configuration,
            today: today
        )
        self.contentGenerator = contentGenerator
        self.actionDelegate = actionDelegate
    }

    public var body: some View {
        VStack(spacing: 0) {
            contentGenerator.headerView(context: model.header)
                .contentShape(Rectangle())
                .onTapGesture {
                    actionDelegate?.monthCalendarDidTapHeader(model.header)
                }

            HStack(spacing: 0) {
                ForEach(model.weekdays) { weekday in
                    contentGenerator.weekdayHeaderView(context: weekday)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            actionDelegate?.monthCalendarDidTapWeekdayHeader(weekday)
                        }
                }
            }

            VStack(spacing: 0) {
                ForEach(model.weeks) { week in
                    ZStack(alignment: .topLeading) {
                        contentGenerator.weekBackgroundView(context: week)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                actionDelegate?.monthCalendarDidTapWeek(week)
                            }

                        HStack(spacing: 0) {
                            ForEach(week.slots) { slot in
                                slotView(for: slot, week: week)
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                            }
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("johnnyo.foundation.monthCalendar")
    }

    @ViewBuilder
    private func slotView(
        for slot: MonthCalendarSlotContext,
        week: MonthCalendarWeekContext
    ) -> some View {
        switch slot {
        case .day(let context):
            contentGenerator.dayCellView(context: context)
                .contentShape(Rectangle())
                .accessibilityIdentifier(accessibilityIdentifier(for: context))
                .onTapGesture {
                    actionDelegate?.monthCalendarDidTapDay(context)
                }
        case .placeholder(let context):
            contentGenerator.placeholderCellView(context: context)
                .contentShape(Rectangle())
                .accessibilityIdentifier(accessibilityIdentifier(for: context))
                .onTapGesture {
                    actionDelegate?.monthCalendarDidTapPlaceholder(context)
                }
        }
    }

    private func accessibilityIdentifier(for context: MonthCalendarDayContext) -> String {
        let components = context.date.formatted(.iso8601.year().month().day())
            .replacingOccurrences(of: "-", with: "")
        return "johnnyo.foundation.monthCalendar.day.\(components)"
    }

    private func accessibilityIdentifier(for context: MonthCalendarPlaceholderContext) -> String {
        let components = context.representedDate.formatted(.iso8601.year().month().day())
            .replacingOccurrences(of: "-", with: "")
        return "johnnyo.foundation.monthCalendar.placeholder.\(components)"
    }
}
