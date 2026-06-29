import Foundation
import Testing
@testable import JohnnyOFoundationCore

// `.serialized` is required because the cache-behavior tests below assert on
// `MonthCalendarModelBuilder`'s shared static cache/counter — Swift Testing runs `@Test`
// functions in parallel by default, which would let them race on that shared state.
@Suite(.serialized)
struct MonthCalendarModelBuilderTests {
    private static var sundayFirstCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 1
        return calendar
    }

    private static var mondayFirstCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 2
        return calendar
    }

    private static func makeDate(year: Int, month: Int, day: Int = 1, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private static func makeOverlay(
        id: String,
        startYear: Int,
        startMonth: Int,
        startDay: Int,
        endYear: Int,
        endMonth: Int,
        endDay: Int,
        calendar: Calendar
    ) -> MonthCalendarLogicalRowOverlay<String, String> {
        MonthCalendarLogicalRowOverlay(
            id: id,
            startDate: makeDate(year: startYear, month: startMonth, day: startDay, calendar: calendar),
            endDate: makeDate(year: endYear, month: endMonth, day: endDay, calendar: calendar),
            payload: id
        )
    }

    /// February 2026 starts on Sunday, so the month shell should collapse to four visible rows.
    /// Expected: four week rows with seven slots each.
    @Test func testFebruary2026UsesMinimumFourWeeks() {
        let model = MonthCalendarModelBuilder.makeModel(
            displayedMonth: Self.makeDate(year: 2026, month: 2, calendar: Self.sundayFirstCalendar),
            calendar: Self.sundayFirstCalendar,
            configuration: .init(showsPeripheralDates: true),
            today: Self.makeDate(year: 2026, month: 2, day: 1, calendar: Self.sundayFirstCalendar)
        )

        #expect(model.weeks.count == 4)
        #expect(model.weeks.allSatisfy { $0.slots.count == 7 })
    }

    /// A Monday-first calendar should rotate the weekday header ordering without changing the shell structure.
    /// Expected: the header starts with Monday and ends with Sunday.
    @Test func testMondayFirstWeekdayOrdering() {
        let model = MonthCalendarModelBuilder.makeModel(
            displayedMonth: Self.makeDate(year: 2026, month: 2, calendar: Self.mondayFirstCalendar),
            calendar: Self.mondayFirstCalendar
        )

        #expect(model.weekdays.first == 2)
        #expect(model.weekdays.last == 1)
    }

    /// When peripheral dates are enabled, leading/trailing out-of-month days should be visible day slots.
    /// Expected: the first visible week for April 2026 exposes three leading peripheral day slots.
    @Test func testPeripheralDatesBecomeDaySlotsWhenEnabled() {
        let model = MonthCalendarModelBuilder.makeModel(
            displayedMonth: Self.makeDate(year: 2026, month: 4, calendar: Self.sundayFirstCalendar),
            calendar: Self.sundayFirstCalendar,
            configuration: .init(showsPeripheralDates: true)
        )

        let firstWeek = model.weeks[0]
        let leadingPeripheralCount = firstWeek.slots.reduce(into: 0) { partialResult, slot in
            if case .day(_, let isPeripheral, _) = slot, isPeripheral {
                partialResult += 1
            }
        }

        #expect(leadingPeripheralCount == 3)
    }

    /// When peripheral dates are disabled, those same leading/trailing positions should remain placeholders.
    /// Expected: the first visible week for April 2026 exposes three leading placeholders instead of day slots.
    @Test func testPeripheralDatesBecomePlaceholdersWhenDisabled() {
        let model = MonthCalendarModelBuilder.makeModel(
            displayedMonth: Self.makeDate(year: 2026, month: 4, calendar: Self.sundayFirstCalendar),
            calendar: Self.sundayFirstCalendar,
            configuration: .init(showsPeripheralDates: false)
        )

        let firstWeek = model.weeks[0]
        let leadingPlaceholderCount = firstWeek.slots.reduce(into: 0) { partialResult, slot in
            if case .placeholder(_, let isLeading) = slot, isLeading {
                partialResult += 1
            }
        }

        #expect(leadingPlaceholderCount == 3)
    }

    /// The shell should mark the current day directly in each visible day slot.
    /// Expected: the matching April 15 cell is flagged as today.
    @Test func testTodayFlagIsDerivedInDayContext() {
        let today = Self.makeDate(year: 2026, month: 4, day: 15, calendar: Self.sundayFirstCalendar)
        let model = MonthCalendarModelBuilder.makeModel(
            displayedMonth: Self.makeDate(year: 2026, month: 4, calendar: Self.sundayFirstCalendar),
            calendar: Self.sundayFirstCalendar,
            today: today
        )

        let matchingDay = model.weeks
            .flatMap(\.slots)
            .first { slot in
                guard case .day(let date, _, _) = slot else { return false }
                return Self.sundayFirstCalendar.isDate(date, inSameDayAs: today)
            }

        #expect(matchingDay?.isToday == true)
    }

    /// Row overlays should include visible peripheral dates but stop at hidden placeholders.
    /// Expected: the same logical overlay covers March 30-April 2 when peripheral dates are visible, but only April 1-2 when placeholders are hidden.
    @Test func testRowOverlayUsesVisiblePeripheralDaysAndSkipsHiddenPlaceholders() throws {
        let overlay = Self.makeOverlay(
            id: "range",
            startYear: 2026,
            startMonth: 3,
            startDay: 30,
            endYear: 2026,
            endMonth: 4,
            endDay: 2,
            calendar: Self.sundayFirstCalendar
        )

        let visiblePeripheralModel = MonthCalendarModelBuilder.makeModel(
            displayedMonth: Self.makeDate(year: 2026, month: 4, calendar: Self.sundayFirstCalendar),
            calendar: Self.sundayFirstCalendar,
            configuration: .init(showsPeripheralDates: true)
        )
        let visiblePeripheralLayouts = MonthCalendarRowOverlayLayoutBuilder.makeWeekLayouts(
            overlays: [overlay],
            model: visiblePeripheralModel,
            calendar: Self.sundayFirstCalendar,
            maximumVisibleLaneCount: 2
        )

        let hiddenPeripheralModel = MonthCalendarModelBuilder.makeModel(
            displayedMonth: Self.makeDate(year: 2026, month: 4, calendar: Self.sundayFirstCalendar),
            calendar: Self.sundayFirstCalendar,
            configuration: .init(showsPeripheralDates: false)
        )
        let hiddenPeripheralLayouts = MonthCalendarRowOverlayLayoutBuilder.makeWeekLayouts(
            overlays: [overlay],
            model: hiddenPeripheralModel,
            calendar: Self.sundayFirstCalendar,
            maximumVisibleLaneCount: 2
        )

        let visibleSegment = try #require(visiblePeripheralLayouts.first?.visibleSegments.first)
        let hiddenSegment = try #require(hiddenPeripheralLayouts.first?.visibleSegments.first)

        #expect(visibleSegment.visibleStartDate == Self.makeDate(year: 2026, month: 3, day: 30, calendar: Self.sundayFirstCalendar))
        #expect(visibleSegment.visibleEndDate == Self.makeDate(year: 2026, month: 4, day: 2, calendar: Self.sundayFirstCalendar))
        #expect(visibleSegment.startColumn == 1)
        #expect(visibleSegment.endColumn == 4)

        #expect(hiddenSegment.visibleStartDate == Self.makeDate(year: 2026, month: 4, day: 1, calendar: Self.sundayFirstCalendar))
        #expect(hiddenSegment.visibleEndDate == Self.makeDate(year: 2026, month: 4, day: 2, calendar: Self.sundayFirstCalendar))
        #expect(hiddenSegment.startColumn == 3)
        #expect(hiddenSegment.endColumn == 4)
        #expect(hiddenSegment.continuesBeforeWeek)
    }

    /// A logical overlay that crosses a week boundary should become two row-bounded segments.
    /// Expected: April 2-8 splits into one segment at the end of the first row and one at the start of the second row with continuation flags on both sides.
    @Test func testRowOverlaySplitsAcrossVisibleWeekRows() throws {
        let model = MonthCalendarModelBuilder.makeModel(
            displayedMonth: Self.makeDate(year: 2026, month: 4, calendar: Self.sundayFirstCalendar),
            calendar: Self.sundayFirstCalendar,
            configuration: .init(showsPeripheralDates: true)
        )
        let overlay = Self.makeOverlay(
            id: "split",
            startYear: 2026,
            startMonth: 4,
            startDay: 2,
            endYear: 2026,
            endMonth: 4,
            endDay: 8,
            calendar: Self.sundayFirstCalendar
        )

        let layouts = MonthCalendarRowOverlayLayoutBuilder.makeWeekLayouts(
            overlays: [overlay],
            model: model,
            calendar: Self.sundayFirstCalendar,
            maximumVisibleLaneCount: 2
        )

        let firstSegment = try #require(layouts[0].visibleSegments.first)
        let secondSegment = try #require(layouts[1].visibleSegments.first)

        #expect(firstSegment.visibleStartDate == Self.makeDate(year: 2026, month: 4, day: 2, calendar: Self.sundayFirstCalendar))
        #expect(firstSegment.visibleEndDate == Self.makeDate(year: 2026, month: 4, day: 4, calendar: Self.sundayFirstCalendar))
        #expect(firstSegment.startColumn == 4)
        #expect(firstSegment.endColumn == 6)
        #expect(!firstSegment.continuesBeforeWeek)
        #expect(firstSegment.continuesAfterWeek)

        #expect(secondSegment.visibleStartDate == Self.makeDate(year: 2026, month: 4, day: 5, calendar: Self.sundayFirstCalendar))
        #expect(secondSegment.visibleEndDate == Self.makeDate(year: 2026, month: 4, day: 8, calendar: Self.sundayFirstCalendar))
        #expect(secondSegment.startColumn == 0)
        #expect(secondSegment.endColumn == 3)
        #expect(secondSegment.continuesBeforeWeek)
        #expect(!secondSegment.continuesAfterWeek)
    }

    /// Colliding row overlays should pack into deterministic lanes and reuse a lane as soon as it becomes free.
    /// Expected: identical leading overlays keep input order across lanes, while a later non-overlapping overlay reuses lane 0.
    @Test func testRowOverlayPackingUsesStableOrderAndLaneReuse() {
        let model = MonthCalendarModelBuilder.makeModel(
            displayedMonth: Self.makeDate(year: 2026, month: 2, calendar: Self.sundayFirstCalendar),
            calendar: Self.sundayFirstCalendar,
            configuration: .init(showsPeripheralDates: true)
        )
        let overlays = [
            Self.makeOverlay(
                id: "a",
                startYear: 2026,
                startMonth: 2,
                startDay: 1,
                endYear: 2026,
                endMonth: 2,
                endDay: 2,
                calendar: Self.sundayFirstCalendar
            ),
            Self.makeOverlay(
                id: "b",
                startYear: 2026,
                startMonth: 2,
                startDay: 1,
                endYear: 2026,
                endMonth: 2,
                endDay: 2,
                calendar: Self.sundayFirstCalendar
            ),
            Self.makeOverlay(
                id: "c",
                startYear: 2026,
                startMonth: 2,
                startDay: 3,
                endYear: 2026,
                endMonth: 2,
                endDay: 4,
                calendar: Self.sundayFirstCalendar
            ),
        ]

        let layouts = MonthCalendarRowOverlayLayoutBuilder.makeWeekLayouts(
            overlays: overlays,
            model: model,
            calendar: Self.sundayFirstCalendar,
            maximumVisibleLaneCount: 3
        )

        let firstWeekSegments = layouts[0].visibleSegments
        #expect(firstWeekSegments.map(\.overlay.id) == ["a", "b", "c"])
        #expect(firstWeekSegments.map(\.laneIndex) == [0, 1, 0])
        #expect(layouts[0].totalPackedLaneCount == 2)
    }

    /// When packed overlays exceed the visible lane limit, foundation should keep the first visible lane and surface clipped-lane metadata separately.
    /// Expected: one visible segment lane, one overflow display lane, and hidden metadata for the clipped packed lanes.
    @Test func testRowOverlayOverflowMetadataIsDerivedWhenVisibleLaneLimitIsExceeded() throws {
        let model = MonthCalendarModelBuilder.makeModel(
            displayedMonth: Self.makeDate(year: 2026, month: 2, calendar: Self.sundayFirstCalendar),
            calendar: Self.sundayFirstCalendar,
            configuration: .init(showsPeripheralDates: true)
        )
        let overlays = [
            Self.makeOverlay(
                id: "a",
                startYear: 2026,
                startMonth: 2,
                startDay: 1,
                endYear: 2026,
                endMonth: 2,
                endDay: 2,
                calendar: Self.sundayFirstCalendar
            ),
            Self.makeOverlay(
                id: "b",
                startYear: 2026,
                startMonth: 2,
                startDay: 1,
                endYear: 2026,
                endMonth: 2,
                endDay: 2,
                calendar: Self.sundayFirstCalendar
            ),
            Self.makeOverlay(
                id: "c",
                startYear: 2026,
                startMonth: 2,
                startDay: 1,
                endYear: 2026,
                endMonth: 2,
                endDay: 2,
                calendar: Self.sundayFirstCalendar
            ),
        ]

        let layouts = MonthCalendarRowOverlayLayoutBuilder.makeWeekLayouts(
            overlays: overlays,
            model: model,
            calendar: Self.sundayFirstCalendar,
            maximumVisibleLaneCount: 1
        )

        let firstWeek = layouts[0]
        let overflow = try #require(firstWeek.overflow)

        #expect(firstWeek.totalPackedLaneCount == 3)
        #expect(firstWeek.visibleSegmentLaneCount == 1)
        #expect(firstWeek.displayLaneCount == 2)
        #expect(firstWeek.visibleSegments.count == 1)
        #expect(firstWeek.visibleSegments.first?.overlay.id == "a")
        #expect(firstWeek.visibleSegments.first?.frame.topFraction == 0)

        #expect(overflow.hiddenSegmentCount == 2)
        #expect(overflow.hiddenPackedLaneCount == 2)
        #expect(overflow.hiddenSegments.map(\.overlay.id) == ["b", "c"])
        #expect(overflow.hiddenSegments.map(\.packedLaneIndex) == [1, 2])
        #expect(overflow.frame.topFraction == 0.5)
        #expect(overflow.frame.heightFraction == 0.5)
    }

    /// When overlapping segments begin in the same column, packing should prefer the longest visible span first.
    /// Expected: same-start segments sort by descending end column before source order so wider segments keep the earlier visible lanes.
    @Test func testRowOverlayPackingPrefersWiderSegmentsWhenStartsCollide() throws {
        let model = MonthCalendarModelBuilder.makeModel(
            displayedMonth: Self.makeDate(year: 2026, month: 3, calendar: Self.sundayFirstCalendar),
            calendar: Self.sundayFirstCalendar,
            configuration: .init(showsPeripheralDates: true)
        )
        let overlays = [
            Self.makeOverlay(
                id: "short",
                startYear: 2026,
                startMonth: 3,
                startDay: 20,
                endYear: 2026,
                endMonth: 3,
                endDay: 24,
                calendar: Self.sundayFirstCalendar
            ),
            Self.makeOverlay(
                id: "medium",
                startYear: 2026,
                startMonth: 3,
                startDay: 21,
                endYear: 2026,
                endMonth: 3,
                endDay: 25,
                calendar: Self.sundayFirstCalendar
            ),
            Self.makeOverlay(
                id: "long",
                startYear: 2026,
                startMonth: 3,
                startDay: 22,
                endYear: 2026,
                endMonth: 3,
                endDay: 26,
                calendar: Self.sundayFirstCalendar
            ),
        ]

        let layouts = MonthCalendarRowOverlayLayoutBuilder.makeWeekLayouts(
            overlays: overlays,
            model: model,
            calendar: Self.sundayFirstCalendar,
            maximumVisibleLaneCount: 2
        )

        let overflowWeek = try #require(layouts.first(where: { $0.overflow != nil }))
        let overflow = try #require(overflowWeek.overflow)

        #expect(overflowWeek.visibleSegments.map(\.overlay.id) == ["long", "medium"])
        #expect(overflowWeek.visibleSegments.map(\.laneIndex) == [0, 1])
        #expect(overflow.hiddenSegments.map(\.overlay.id) == ["short"])
        #expect(overflow.hiddenSegments.map(\.packedLaneIndex) == [2])
    }

    /// Calling `makeModel` twice with identical inputs (month, calendar, configuration, today).
    /// Expected: the second call is served from the cache, so the build count increments only once.
    @Test func testMakeModelCachesIdenticalInputs() {
        MonthCalendarModelBuilder.resetCacheForTesting()
        let calendar = Self.sundayFirstCalendar
        let month = Self.makeDate(year: 2026, month: 3, calendar: calendar)
        let today = Self.makeDate(year: 2026, month: 3, day: 15, calendar: calendar)

        _ = MonthCalendarModelBuilder.makeModel(displayedMonth: month, calendar: calendar, today: today)
        _ = MonthCalendarModelBuilder.makeModel(displayedMonth: month, calendar: calendar, today: today)
        _ = MonthCalendarModelBuilder.makeModel(displayedMonth: month, calendar: calendar, today: today)

        #expect(MonthCalendarModelBuilder.buildCountForTesting == 1)
    }

    /// Calling `makeModel` with a different displayed month, then a different `today`, after an
    /// initial call. Expected: each distinct input combination triggers its own cache miss/build.
    @Test func testMakeModelRebuildsWhenInputsChange() {
        MonthCalendarModelBuilder.resetCacheForTesting()
        let calendar = Self.sundayFirstCalendar
        let march = Self.makeDate(year: 2026, month: 3, calendar: calendar)
        let april = Self.makeDate(year: 2026, month: 4, calendar: calendar)
        let today = Self.makeDate(year: 2026, month: 3, day: 15, calendar: calendar)
        let laterToday = Self.makeDate(year: 2026, month: 3, day: 16, calendar: calendar)

        _ = MonthCalendarModelBuilder.makeModel(displayedMonth: march, calendar: calendar, today: today)
        #expect(MonthCalendarModelBuilder.buildCountForTesting == 1)

        _ = MonthCalendarModelBuilder.makeModel(displayedMonth: april, calendar: calendar, today: today)
        #expect(MonthCalendarModelBuilder.buildCountForTesting == 2)

        _ = MonthCalendarModelBuilder.makeModel(displayedMonth: april, calendar: calendar, today: laterToday)
        #expect(MonthCalendarModelBuilder.buildCountForTesting == 3)
    }

    /// Calling `makeModel` for the same displayed month with two different days within that month
    /// (e.g. the 1st and the 15th) but otherwise identical calendar/configuration/today.
    /// Expected: both calls normalize to the same cache key (month start), so only one build occurs.
    @Test func testMakeModelNormalizesDisplayedMonthBeforeCaching() {
        MonthCalendarModelBuilder.resetCacheForTesting()
        let calendar = Self.sundayFirstCalendar
        let firstOfMonth = Self.makeDate(year: 2026, month: 5, day: 1, calendar: calendar)
        let midMonth = Self.makeDate(year: 2026, month: 5, day: 15, calendar: calendar)
        let today = Self.makeDate(year: 2026, month: 5, day: 1, calendar: calendar)

        _ = MonthCalendarModelBuilder.makeModel(displayedMonth: firstOfMonth, calendar: calendar, today: today)
        _ = MonthCalendarModelBuilder.makeModel(displayedMonth: midMonth, calendar: calendar, today: today)

        #expect(MonthCalendarModelBuilder.buildCountForTesting == 1)
    }
}
