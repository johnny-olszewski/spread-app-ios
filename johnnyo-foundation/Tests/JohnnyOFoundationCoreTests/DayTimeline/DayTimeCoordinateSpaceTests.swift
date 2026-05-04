import Foundation
import Testing
@testable import JohnnyOFoundationCore

struct DayTimeCoordinateSpaceTests {

    // MARK: - Helpers

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private var referenceDay: Date {
        // 2024-06-15 00:00:00 UTC — a stable reference date for tests
        var components = DateComponents()
        components.year = 2024
        components.month = 6
        components.day = 15
        components.hour = 0
        components.minute = 0
        components.second = 0
        return calendar.date(from: components)!
    }

    private func makeSpace(
        startHour: Int = 6,
        endHour: Int = 22,
        height: CGFloat = 160
    ) -> DayTimeCoordinateSpace {
        let start = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: referenceDay)!
        let end = calendar.date(bySettingHour: endHour, minute: 0, second: 0, of: referenceDay)!
        return DayTimeCoordinateSpace(visibleStart: start, visibleEnd: end, totalHeight: height)
    }

    private func date(hour: Int, minute: Int = 0) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: referenceDay)!
    }

    // MARK: - yOffset boundary values

    /// Conditions: Date exactly at the visible start.
    /// Expected: yOffset returns 0.
    @Test func testYOffsetAtVisibleStart() {
        let space = makeSpace()
        #expect(space.yOffset(for: date(hour: 6)) == 0)
    }

    /// Conditions: Date exactly at the visible end.
    /// Expected: yOffset returns totalHeight.
    @Test func testYOffsetAtVisibleEnd() {
        let space = makeSpace()
        #expect(space.yOffset(for: date(hour: 22)) == 160)
    }

    /// Conditions: Date at the midpoint of the visible window (14:00 in a 6–22 window = 8h into 16h).
    /// Expected: yOffset returns totalHeight / 2.
    @Test func testYOffsetAtMidpoint() {
        let space = makeSpace(startHour: 6, endHour: 22, height: 160)
        #expect(space.yOffset(for: date(hour: 14)) == 80)
    }

    // MARK: - yOffset clamping

    /// Conditions: Date before the visible start.
    /// Expected: yOffset is clamped to 0.
    @Test func testYOffsetBeforeWindowClampsToZero() {
        let space = makeSpace()
        #expect(space.yOffset(for: date(hour: 3)) == 0)
    }

    /// Conditions: Date after the visible end.
    /// Expected: yOffset is clamped to totalHeight.
    @Test func testYOffsetAfterWindowClampsToTotalHeight() {
        let space = makeSpace()
        #expect(space.yOffset(for: date(hour: 23)) == 160)
    }

    // MARK: - height(from:to:)

    /// Conditions: Range exactly spans the entire visible window.
    /// Expected: height returns totalHeight.
    @Test func testHeightForFullWindow() {
        let space = makeSpace()
        #expect(space.height(from: date(hour: 6), to: date(hour: 22)) == 160)
    }

    /// Conditions: Range spans exactly half the visible window (6:00–14:00 in a 6–22 window).
    /// Expected: height returns totalHeight / 2.
    @Test func testHeightForHalfWindow() {
        let space = makeSpace(startHour: 6, endHour: 22, height: 160)
        #expect(space.height(from: date(hour: 6), to: date(hour: 14)) == 80)
    }

    /// Conditions: Range is entirely before the visible start.
    /// Expected: height returns 0.
    @Test func testHeightForRangeEntirelyBeforeWindow() {
        let space = makeSpace()
        #expect(space.height(from: date(hour: 2), to: date(hour: 5)) == 0)
    }

    /// Conditions: Range is entirely after the visible end.
    /// Expected: height returns 0.
    @Test func testHeightForRangeEntirelyAfterWindow() {
        let space = makeSpace()
        #expect(space.height(from: date(hour: 23), to: date(hour: 23, minute: 59)) == 0)
    }

    /// Conditions: Range starts before the window and ends at the window midpoint.
    /// Expected: height reflects only the clipped portion (6:00–14:00 → half the window).
    @Test func testHeightForRangeStartingBeforeWindowClipsToWindowStart() {
        let space = makeSpace(startHour: 6, endHour: 22, height: 160)
        // range: 4:00–14:00 → clipped to 6:00–14:00 (8h out of 16h) → 80pt
        #expect(space.height(from: date(hour: 4), to: date(hour: 14)) == 80)
    }

    /// Conditions: Zero-length range where start equals end.
    /// Expected: height returns 0.
    @Test func testHeightForZeroLengthRange() {
        let space = makeSpace()
        let point = date(hour: 10)
        #expect(space.height(from: point, to: point) == 0)
    }
}
