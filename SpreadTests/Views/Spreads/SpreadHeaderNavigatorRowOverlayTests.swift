import Foundation
import Testing
import JohnnyOFoundationCore
@testable import Spread

struct SpreadHeaderNavigatorRowOverlayTests {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        calendar.firstWeekday = 1
        return calendar
    }

    private static func makeDate(year: Int, month: Int, day: Int = 1) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private static func makeModel(
        mode: SpreadHeaderNavigatorModel.Mode = .conventional,
        spreads: [DataModel.Spread],
        today: Date = makeDate(year: 2026, month: 3, day: 29)
    ) -> SpreadHeaderNavigatorModel {
        SpreadHeaderNavigatorModel(
            mode: mode,
            calendar: calendar,
            today: today,
            spreads: spreads,
            tasks: [],
            notes: [],
            events: []
        )
    }

    /// Conventional rooted-navigator month rows should derive one logical row overlay per visible multiday spread.
    /// Expected: overlapping March multiday spreads become date-driven overlays while single-day spreads remain day targets only.
    @Test func conventionalMonthRowBuildsMultidayLogicalOverlays() throws {
        let daySpread = DataModel.Spread(
            period: .day,
            date: Self.makeDate(year: 2026, month: 3, day: 21),
            calendar: Self.calendar
        )
        let currentMultiday = DataModel.Spread(
            startDate: Self.makeDate(year: 2026, month: 3, day: 20),
            endDate: Self.makeDate(year: 2026, month: 3, day: 24),
            calendar: Self.calendar
        )
        let secondaryMultiday = DataModel.Spread(
            startDate: Self.makeDate(year: 2026, month: 3, day: 22),
            endDate: Self.makeDate(year: 2026, month: 3, day: 26),
            calendar: Self.calendar
        )

        let model = Self.makeModel(spreads: [daySpread, currentMultiday, secondaryMultiday])
        let march = try #require(model.months(in: 2026).first)

        let overlays = SpreadHeaderNavigatorRowOverlayGenerator.makeOverlays(
            model: model,
            monthRow: march,
            currentSpread: currentMultiday
        )

        #expect(overlays.map(\.id) == [currentMultiday.id, secondaryMultiday.id])
        #expect(overlays.map(\.startDate) == [
            Self.makeDate(year: 2026, month: 3, day: 20),
            Self.makeDate(year: 2026, month: 3, day: 22),
        ])
        #expect(overlays.map(\.endDate) == [
            Self.makeDate(year: 2026, month: 3, day: 24),
            Self.makeDate(year: 2026, month: 3, day: 26),
        ])
        #expect(overlays.map(\.payload.isCurrent) == [true, false])
    }

    /// Traditional rooted-navigator month rows do not currently participate in multiday row overlays.
    /// Expected: overlay derivation returns no overlays even when conventional multiday spreads exist in the shared spread list.
    @Test func traditionalMonthRowBuildsNoOverlays() throws {
        let multiday = DataModel.Spread(
            startDate: Self.makeDate(year: 2026, month: 3, day: 20),
            endDate: Self.makeDate(year: 2026, month: 3, day: 24),
            calendar: Self.calendar
        )

        let model = Self.makeModel(mode: .traditional, spreads: [multiday])
        let march = try #require(model.months(in: 2026).first(where: { Self.calendar.component(.month, from: $0.date) == 3 }))

        let overlays = SpreadHeaderNavigatorRowOverlayGenerator.makeOverlays(
            model: model,
            monthRow: march,
            currentSpread: multiday
        )

        #expect(overlays.isEmpty)
    }

    /// App-side rooted-navigator overlay data should feed into foundation packing without altering existing day-target semantics.
    /// Expected: overlapping multiday overlays pack into lanes with overflow metadata while direct day and multiday selection targets remain intact.
    @Test func packedNavigatorOverlayContextsPreserveTargetsAndSurfaceOverflow() throws {
        let directDay = DataModel.Spread(
            period: .day,
            date: Self.makeDate(year: 2026, month: 3, day: 21),
            calendar: Self.calendar
        )
        let multidayOne = DataModel.Spread(
            startDate: Self.makeDate(year: 2026, month: 3, day: 20),
            endDate: Self.makeDate(year: 2026, month: 3, day: 24),
            calendar: Self.calendar
        )
        let multidayTwo = DataModel.Spread(
            startDate: Self.makeDate(year: 2026, month: 3, day: 21),
            endDate: Self.makeDate(year: 2026, month: 3, day: 25),
            calendar: Self.calendar
        )
        let multidayThree = DataModel.Spread(
            startDate: Self.makeDate(year: 2026, month: 3, day: 22),
            endDate: Self.makeDate(year: 2026, month: 3, day: 26),
            calendar: Self.calendar
        )

        let model = Self.makeModel(spreads: [directDay, multidayOne, multidayTwo, multidayThree])
        let march = try #require(model.months(in: 2026).first)
        let overlays = SpreadHeaderNavigatorRowOverlayGenerator.makeOverlays(
            model: model,
            monthRow: march,
            currentSpread: multidayOne
        )
        let monthCalendarModel = MonthCalendarModelBuilder.makeModel(
            displayedMonth: march.date,
            calendar: Self.calendar,
            configuration: .init(showsPeripheralDates: false),
            today: model.today
        )

        let layouts = MonthCalendarRowOverlayLayoutBuilder.makeWeekLayouts(
            overlays: overlays,
            model: monthCalendarModel,
            calendar: Self.calendar,
            maximumVisibleLaneCount: 2
        )
        let targetDay = march.targets(for: Self.makeDate(year: 2026, month: 3, day: 21), calendar: Self.calendar)
        let firstOverflowWeek = try #require(layouts.first(where: { $0.overflow != nil }))
        let overflow = try #require(firstOverflowWeek.overflow)

        #expect(targetDay.count == 3)
        #expect(!targetDay[0].isMultiday)
        #expect(targetDay.dropFirst().allSatisfy { $0.isMultiday })

        #expect(firstOverflowWeek.visibleSegments.count == 2)
        #expect(firstOverflowWeek.totalPackedLaneCount == 3)
        #expect(firstOverflowWeek.visibleSegmentLaneCount == 2)
        #expect(firstOverflowWeek.displayLaneCount == 3)
        #expect(firstOverflowWeek.visibleSegments.map(\.overlay.id) == [multidayThree.id, multidayTwo.id])
        #expect(overflow.hiddenSegmentCount == 1)
        #expect(overflow.hiddenSegments.first?.overlay.id == multidayOne.id)
    }

    /// The rooted navigator overlay renderer should keep a fixed visible-lane limit until product scope expands.
    /// Expected: the generator exposes the approved two-lane cap by default.
    @Test func navigatorOverlayGeneratorDefaultsToTwoVisibleLanes() {
        let currentMultiday = DataModel.Spread(
            startDate: Self.makeDate(year: 2026, month: 3, day: 20),
            endDate: Self.makeDate(year: 2026, month: 3, day: 24),
            calendar: Self.calendar
        )
        let model = Self.makeModel(spreads: [currentMultiday])
        let march = model.months(in: 2026)[0]

        let generator = SpreadHeaderNavigatorRowOverlayGenerator(
            model: model,
            monthRow: march,
            currentSpread: currentMultiday
        )

        #expect(generator.maximumVisibleLaneCount == 2)
    }
}
