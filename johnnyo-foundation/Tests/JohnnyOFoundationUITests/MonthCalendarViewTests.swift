import CoreGraphics
import Foundation
import SwiftUI
import Testing
import JohnnyOFoundationCore
@testable import JohnnyOFoundationUI

@MainActor
struct MonthCalendarViewTests {
    private final class Recorder {
        var headerCalls = 0
        var weekdayCalls = 0
        var dayCalls = 0
        var placeholderCalls = 0
        var weekBackgroundCalls = 0
        var rowOverlayCalls = 0
        var overflowCalls = 0
        var events: [String] = []
    }

    private struct RecordingGenerator: CalendarContentGenerator {
        typealias HeaderContent = AnyView
        typealias WeekdayHeaderContent = AnyView
        typealias DayCellContent = AnyView
        typealias PlaceholderCellContent = AnyView
        typealias WeekBackgroundContent = AnyView

        let recorder: Recorder

        func headerView(context: MonthCalendarHeaderContext) -> AnyView {
            recorder.headerCalls += 1
            recorder.events.append("header")
            return AnyView(Color.clear.frame(height: 0))
        }

        func weekdayHeaderView(context: MonthCalendarWeekdayContext) -> AnyView {
            recorder.weekdayCalls += 1
            recorder.events.append("weekday:\(context.index)")
            return AnyView(Color.clear.frame(height: 0))
        }

        func dayCellView(context: MonthCalendarDayContext) -> AnyView {
            recorder.dayCalls += 1
            recorder.events.append("day:\(context.row)-\(context.column)")

            let color: Color = context.row == 0 && context.column == 0 ? .green : .clear
            return AnyView(
                color
                    .frame(maxWidth: .infinity, minHeight: 20, maxHeight: 20)
            )
        }

        func placeholderCellView(context: MonthCalendarPlaceholderContext) -> AnyView {
            recorder.placeholderCalls += 1
            recorder.events.append("placeholder:\(context.row)-\(context.column)")
            return AnyView(Color.clear.frame(maxWidth: .infinity, minHeight: 20, maxHeight: 20))
        }

        func weekBackgroundView(context: MonthCalendarWeekContext) -> AnyView {
            recorder.weekBackgroundCalls += 1
            recorder.events.append("week:\(context.index)")
            return AnyView(Color.blue.frame(maxWidth: .infinity, minHeight: 20, maxHeight: 20))
        }
    }

    private struct RecordingOverlayGenerator: MonthCalendarRowOverlayGenerator {
        typealias RowOverlayContent = AnyView
        typealias OverflowContent = AnyView

        let recorder: Recorder
        let overlays: [MonthCalendarLogicalRowOverlay<String, String>]
        let maximumVisibleLaneCount: Int

        func rowOverlayView(
            context: MonthCalendarPackedRowOverlayRenderContext<String, String>
        ) -> AnyView {
            recorder.rowOverlayCalls += 1
            recorder.events.append("overlay:\(context.week.index)")
            return AnyView(Color.red)
        }

        func overflowView(
            context: MonthCalendarRowOverlayOverflowRenderContext<String, String>
        ) -> AnyView {
            recorder.overflowCalls += 1
            recorder.events.append("overflow:\(context.week.index)")
            return AnyView(Color.orange)
        }
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 1
        return calendar
    }

    private static var displayedMonth: Date {
        calendar.date(from: .init(year: 2026, month: 2, day: 1))!
    }

    private static func makeOverlay() -> MonthCalendarLogicalRowOverlay<String, String> {
        MonthCalendarLogicalRowOverlay(
            id: "fullWeek",
            startDate: calendar.date(from: .init(year: 2026, month: 2, day: 1))!,
            endDate: calendar.date(from: .init(year: 2026, month: 2, day: 7))!,
            payload: "fullWeek"
        )
    }

    /// The month shell should still build its header slot eagerly when the view body is read.
    /// Expected: header content is invoked once while deeper week/day slots remain lazy.
    @Test func testHeaderSlotIsInvokedDuringBodyEvaluation() {
        let recorder = Recorder()
        let view = MonthCalendarView(
            displayedMonth: Self.displayedMonth,
            calendar: Self.calendar,
            configuration: .init(showsPeripheralDates: false),
            contentGenerator: RecordingGenerator(recorder: recorder)
        )

        _ = view.body

        #expect(recorder.headerCalls == 1)
        #expect(recorder.weekdayCalls == 0)
        #expect(recorder.weekBackgroundCalls == 0)
        #expect(recorder.dayCalls == 0)
        #expect(recorder.placeholderCalls == 0)
    }

    /// The row-overlay seam should render overlay content without changing existing week/day slot invocation counts.
    /// Expected: the first week background callback occurs before the first overlay callback, and the day/week slot counts match the no-overlay render.
    @Test func testRowOverlayRendersBetweenWeekBackgroundAndDayCellsWithoutChangingSlotCalls() throws {
        let withoutOverlay = try renderCalendar(includeOverlay: false)
        let withOverlay = try renderCalendar(includeOverlay: true)
        let weekIndex = try #require(withOverlay.events.firstIndex(of: "week:0"))
        let overlayIndex = try #require(withOverlay.events.firstIndex(of: "overlay:0"))

        #expect(weekIndex < overlayIndex)

        #expect(withOverlay.dayCalls == withoutOverlay.dayCalls)
        #expect(withOverlay.weekBackgroundCalls == withoutOverlay.weekBackgroundCalls)
        #expect(withOverlay.placeholderCalls == withoutOverlay.placeholderCalls)
        #expect(withOverlay.rowOverlayCalls > 0)
        #expect(withOverlay.overflowCalls == 0)
    }

    private func renderCalendar(includeOverlay: Bool) throws -> (
        image: CGImage,
        dayCalls: Int,
        weekBackgroundCalls: Int,
        placeholderCalls: Int,
        rowOverlayCalls: Int,
        overflowCalls: Int,
        events: [String]
    ) {
        let recorder = Recorder()
        let contentGenerator = RecordingGenerator(recorder: recorder)

        let content: AnyView
        if includeOverlay {
            content = AnyView(
                MonthCalendarView(
                    displayedMonth: Self.displayedMonth,
                    calendar: Self.calendar,
                    configuration: .init(showsPeripheralDates: true),
                    contentGenerator: contentGenerator,
                    rowOverlayGenerator: RecordingOverlayGenerator(
                        recorder: recorder,
                        overlays: [Self.makeOverlay()],
                        maximumVisibleLaneCount: 1
                    )
                )
                .frame(width: 140, height: 80)
            )
        } else {
            content = AnyView(
                MonthCalendarView(
                    displayedMonth: Self.displayedMonth,
                    calendar: Self.calendar,
                    configuration: .init(showsPeripheralDates: true),
                    contentGenerator: contentGenerator
                )
                .frame(width: 140, height: 80)
            )
        }

        let renderer = ImageRenderer(content: content)
        renderer.scale = 1

        let image = try #require(renderer.cgImage)
        return (
            image: image,
            dayCalls: recorder.dayCalls,
            weekBackgroundCalls: recorder.weekBackgroundCalls,
            placeholderCalls: recorder.placeholderCalls,
            rowOverlayCalls: recorder.rowOverlayCalls,
            overflowCalls: recorder.overflowCalls,
            events: recorder.events
        )
    }
}
