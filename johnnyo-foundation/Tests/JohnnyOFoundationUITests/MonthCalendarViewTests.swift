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
    }

    private struct RecordingGenerator: CalendarContentGenerator {
        let recorder: Recorder

        func headerView(context: MonthCalendarHeaderContext) -> some View {
            recorder.headerCalls += 1
            return Color.clear
        }

        func weekdayHeaderView(context: MonthCalendarWeekdayContext) -> some View {
            recorder.weekdayCalls += 1
            return Color.clear
        }

        func dayCellView(context: MonthCalendarDayContext) -> some View {
            recorder.dayCalls += 1
            return Color.clear
        }

        func placeholderCellView(context: MonthCalendarPlaceholderContext) -> some View {
            recorder.placeholderCalls += 1
            return Color.clear
        }

        func weekBackgroundView(context: MonthCalendarWeekContext) -> some View {
            recorder.weekBackgroundCalls += 1
            return Color.clear
        }
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 1
        return calendar
    }

    @Test func testHeaderSlotIsInvokedDuringBodyEvaluation() {
        let recorder = Recorder()
        let view = MonthCalendarView(
            displayedMonth: Self.calendar.date(from: .init(year: 2026, month: 4, day: 1))!,
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
}
