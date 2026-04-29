import SwiftUI
import JohnnyOFoundationCore

public struct MonthCalendarView<
    Generator: CalendarContentGenerator,
    OverlayGenerator: MonthCalendarRowOverlayGenerator
>: View {
    private let model: MonthCalendarModel
    private let contentGenerator: Generator
    private let rowOverlayGenerator: OverlayGenerator
    private let rowOverlayLayouts: [MonthCalendarPackedRowOverlayWeekLayout<OverlayGenerator.OverlayID, OverlayGenerator.OverlayPayload>]
    private let actionDelegate: (any MonthCalendarActionDelegate)?

    public init(
        displayedMonth: Date,
        calendar: Calendar,
        today: Date = Date(),
        configuration: MonthCalendarConfiguration = .init(),
        contentGenerator: Generator,
        actionDelegate: (any MonthCalendarActionDelegate)? = nil
    ) where OverlayGenerator == EmptyMonthCalendarRowOverlayGenerator {
        self.init(
            displayedMonth: displayedMonth,
            calendar: calendar,
            today: today,
            configuration: configuration,
            contentGenerator: contentGenerator,
            rowOverlayGenerator: EmptyMonthCalendarRowOverlayGenerator(),
            actionDelegate: actionDelegate
        )
    }

    public init(
        displayedMonth: Date,
        calendar: Calendar,
        today: Date = Date(),
        configuration: MonthCalendarConfiguration = .init(),
        contentGenerator: Generator,
        rowOverlayGenerator: OverlayGenerator,
        actionDelegate: (any MonthCalendarActionDelegate)? = nil
    ) {
        let model = MonthCalendarModelBuilder.makeModel(
            displayedMonth: displayedMonth,
            calendar: calendar,
            configuration: configuration,
            today: today
        )

        self.model = model
        self.contentGenerator = contentGenerator
        self.rowOverlayGenerator = rowOverlayGenerator
        self.rowOverlayLayouts = MonthCalendarRowOverlayLayoutBuilder.makeWeekLayouts(
            overlays: rowOverlayGenerator.overlays,
            model: model,
            calendar: calendar,
            maximumVisibleLaneCount: rowOverlayGenerator.maximumVisibleLaneCount
        )
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
                ForEach(model.weeks.indices, id: \.self) { index in
                    let week = model.weeks[index]
                    let overlayLayout = rowOverlayLayouts[index]

                    ZStack(alignment: .topLeading) {
                        contentGenerator.weekBackgroundView(context: week)
                            .contentShape(Rectangle())
                            .overlay(alignment: .topLeading) {
                                rowOverlayLayer(for: overlayLayout)
                            }
                            .onTapGesture {
                                actionDelegate?.monthCalendarDidTapWeek(week)
                            }

                        HStack(spacing: 0) {
                            ForEach(week.slots) { slot in
                                slotView(for: slot)
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
    private func rowOverlayLayer(
        for layout: MonthCalendarPackedRowOverlayWeekLayout<OverlayGenerator.OverlayID, OverlayGenerator.OverlayPayload>
    ) -> some View {
        if layout.displayLaneCount > 0 {
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    ForEach(layout.visibleSegments) { segment in
                        rowOverlayGenerator.rowOverlayView(context: segment)
                            .frame(
                                width: geometry.size.width * segment.frame.widthFraction,
                                height: geometry.size.height * segment.frame.heightFraction,
                                alignment: .topLeading
                            )
                            .offset(
                                x: geometry.size.width * segment.frame.leadingFraction,
                                y: geometry.size.height * segment.frame.topFraction
                            )
                    }

                    if let overflow = layout.overflow {
                        rowOverlayGenerator.overflowView(context: overflow)
                            .frame(
                                width: geometry.size.width * overflow.frame.widthFraction,
                                height: geometry.size.height * overflow.frame.heightFraction,
                                alignment: .topLeading
                            )
                            .offset(
                                x: geometry.size.width * overflow.frame.leadingFraction,
                                y: geometry.size.height * overflow.frame.topFraction
                            )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func slotView(for slot: MonthCalendarSlotContext) -> some View {
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
