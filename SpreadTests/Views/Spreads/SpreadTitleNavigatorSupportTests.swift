import Foundation
import SwiftUI
import Testing
@testable import Spread

struct SpreadTitleNavigatorSupportTests {

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        calendar.firstWeekday = 1
        return calendar
    }

    private static func makeDate(year: Int, month: Int, day: Int = 1) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    // Verifies that a conventional model with no explicit year/month/day spreads for today
    // recommends each missing period in hierarchical order.
    @Test func recommendationProviderReturnsMissingYearMonthAndDayForToday() {
        let provider = TodayMissingSpreadRecommendationProvider()
        let model = SpreadHeaderNavigatorModel(
            mode: .conventional,
            calendar: Self.calendar,
            today: Self.makeDate(year: 2026, month: 3, day: 29),
            spreads: [],
            tasks: [],
            notes: [],
            events: []
        )

        let recommendations = provider.recommendations(for: model)

        #expect(recommendations.map(\.period) == [.year, .month, .day])
        #expect(recommendations.map(\.date) == [
            Self.makeDate(year: 2026, month: 1, day: 1),
            Self.makeDate(year: 2026, month: 3, day: 1),
            Self.makeDate(year: 2026, month: 3, day: 29),
        ])
    }

    // Verifies that existing explicit year/month/day spreads suppress their matching recommendations.
    @Test func recommendationProviderOmitsExistingExplicitPeriods() {
        let provider = TodayMissingSpreadRecommendationProvider()
        let year = DataModel.Spread(period: .year, date: Self.makeDate(year: 2026, month: 1), calendar: Self.calendar)
        let day = DataModel.Spread(period: .day, date: Self.makeDate(year: 2026, month: 3, day: 29), calendar: Self.calendar)
        let model = SpreadHeaderNavigatorModel(
            mode: .conventional,
            calendar: Self.calendar,
            today: Self.makeDate(year: 2026, month: 3, day: 29),
            spreads: [year, day],
            tasks: [],
            notes: [],
            events: []
        )

        let recommendations = provider.recommendations(for: model)

        #expect(recommendations.map(\.period) == [.month])
        #expect(recommendations.first?.date == Self.makeDate(year: 2026, month: 3, day: 1))
    }

    // Verifies that a multiday spread containing today does not satisfy the explicit day recommendation.
    @Test func recommendationProviderDoesNotTreatMultidayAsDayCoverage() {
        let provider = TodayMissingSpreadRecommendationProvider()
        let multiday = DataModel.Spread(
            startDate: Self.makeDate(year: 2026, month: 3, day: 27),
            endDate: Self.makeDate(year: 2026, month: 3, day: 31),
            calendar: Self.calendar
        )
        let model = SpreadHeaderNavigatorModel(
            mode: .conventional,
            calendar: Self.calendar,
            today: Self.makeDate(year: 2026, month: 3, day: 29),
            spreads: [multiday],
            tasks: [],
            notes: [],
            events: []
        )

        let recommendations = provider.recommendations(for: model)

        #expect(recommendations.map(\.period) == [.year, .month, .day])
    }

    // Verifies that traditional mode never surfaces conventional spread-creation recommendations.
    @Test func recommendationProviderReturnsNoRecommendationsInTraditionalMode() {
        let provider = TodayMissingSpreadRecommendationProvider()
        let model = SpreadHeaderNavigatorModel(
            mode: .traditional,
            calendar: Self.calendar,
            today: Self.makeDate(year: 2026, month: 3, day: 29),
            spreads: [],
            tasks: [],
            notes: [],
            events: []
        )

        let recommendations = provider.recommendations(for: model)

        #expect(recommendations.isEmpty)
    }

    @Test func recommendationFullTitlesUseExpandedDateFormatting() {
        let yearRecommendation = SpreadTitleNavigatorRecommendation(
            period: .year,
            date: Self.makeDate(year: 2026, month: 1, day: 1),
            calendar: Self.calendar
        )
        let monthRecommendation = SpreadTitleNavigatorRecommendation(
            period: .month,
            date: Self.makeDate(year: 2026, month: 4, day: 1),
            calendar: Self.calendar
        )
        let dayRecommendation = SpreadTitleNavigatorRecommendation(
            period: .day,
            date: Self.makeDate(year: 2026, month: 4, day: 5),
            calendar: Self.calendar
        )

        #expect(yearRecommendation.fullTitle == "2026")
        #expect(monthRecommendation.fullTitle == "April 2026")
        #expect(dayRecommendation.fullTitle == "April 5, 2026")
    }

    @Test func recommendationCardLayoutUsesSharedThreeToFiveAspectRatio() {
        let size = SpreadTitleNavigatorRecommendationLayout.cardSize(
            widths: [42, 60, 38],
            heights: [70, 64, 68]
        )

        #expect(size?.width == 60)
        #expect(size?.height == 100)
    }

    @Test func recommendationCardsCollapseToMenuOnlyOnCompactWhenMultiple() {
        #expect(
            SpreadTitleNavigatorRecommendationLayout.collapsesToMenu(
                horizontalSizeClass: .compact,
                recommendationCount: 2
            )
        )
        #expect(
            !SpreadTitleNavigatorRecommendationLayout.collapsesToMenu(
                horizontalSizeClass: .compact,
                recommendationCount: 1
            )
        )
        #expect(
            !SpreadTitleNavigatorRecommendationLayout.collapsesToMenu(
                horizontalSizeClass: .regular,
                recommendationCount: 3
            )
        )
    }

    @Test func conventionalSelectionUsesExplicitSpreadsAcrossEntireYear() {
        let year = DataModel.Spread(period: .year, date: Self.makeDate(year: 2026, month: 1), calendar: Self.calendar)
        let january = DataModel.Spread(period: .month, date: Self.makeDate(year: 2026, month: 1), calendar: Self.calendar)
        let february = DataModel.Spread(period: .month, date: Self.makeDate(year: 2026, month: 2), calendar: Self.calendar)
        let march = DataModel.Spread(period: .month, date: Self.makeDate(year: 2026, month: 3), calendar: Self.calendar)
        let januaryOne = DataModel.Spread(period: .day, date: Self.makeDate(year: 2026, month: 1, day: 1), calendar: Self.calendar)
        let januaryTwo = DataModel.Spread(period: .day, date: Self.makeDate(year: 2026, month: 1, day: 2), calendar: Self.calendar)
        let januaryMulti = DataModel.Spread(
            startDate: Self.makeDate(year: 2026, month: 1, day: 2),
            endDate: Self.makeDate(year: 2026, month: 1, day: 5),
            calendar: Self.calendar
        )
        let dayTen = DataModel.Spread(period: .day, date: Self.makeDate(year: 2026, month: 3, day: 10), calendar: Self.calendar)
        let multiday = DataModel.Spread(
            startDate: Self.makeDate(year: 2026, month: 3, day: 20),
            endDate: Self.makeDate(year: 2026, month: 3, day: 22),
            calendar: Self.calendar
        )
        let dayTwentyNine = DataModel.Spread(period: .day, date: Self.makeDate(year: 2026, month: 3, day: 29), calendar: Self.calendar)
        let headerModel = SpreadHeaderNavigatorModel(
            mode: .conventional,
            calendar: Self.calendar,
            today: Self.makeDate(year: 2026, month: 3, day: 29),
            spreads: [dayTwentyNine, multiday, march, dayTen, januaryTwo, januaryMulti, year, january, januaryOne, february],
            tasks: [],
            notes: [],
            events: []
        )

        let stripModel = SpreadTitleNavigatorModel(headerModel: headerModel)
        let items = stripModel.items(for: SpreadHeaderNavigatorModel.Selection.conventional(dayTwentyNine))

        #expect(items.map { $0.label } == ["2026", "Jan", "1", "2", "2-5", "Feb", "Mar", "10", "20-22", "29"])
        #expect(items.map { $0.style } == [
            SpreadTitleNavigatorModel.Item.Style.year,
            .month,
            .day,
            .day,
            .multiday,
            .month,
            .month,
            .day,
            .multiday,
            .day,
        ])
    }

    @Test func conventionalStripContentsStayStableWithinSameYear() {
        let year = DataModel.Spread(period: .year, date: Self.makeDate(year: 2026, month: 1), calendar: Self.calendar)
        let january = DataModel.Spread(period: .month, date: Self.makeDate(year: 2026, month: 1), calendar: Self.calendar)
        let januaryOne = DataModel.Spread(period: .day, date: Self.makeDate(year: 2026, month: 1, day: 1), calendar: Self.calendar)
        let march = DataModel.Spread(period: .month, date: Self.makeDate(year: 2026, month: 3), calendar: Self.calendar)
        let marchTwentyNine = DataModel.Spread(period: .day, date: Self.makeDate(year: 2026, month: 3, day: 29), calendar: Self.calendar)
        let headerModel = SpreadHeaderNavigatorModel(
            mode: .conventional,
            calendar: Self.calendar,
            today: Self.makeDate(year: 2026, month: 3, day: 29),
            spreads: [year, january, januaryOne, march, marchTwentyNine],
            tasks: [],
            notes: [],
            events: []
        )

        let stripModel = SpreadTitleNavigatorModel(headerModel: headerModel)
        let monthItems = stripModel.items(for: SpreadHeaderNavigatorModel.Selection.conventional(march))
        let dayItems = stripModel.items(for: SpreadHeaderNavigatorModel.Selection.conventional(marchTwentyNine))

        #expect(monthItems.map { $0.label } == dayItems.map { $0.label })
    }

    @Test func traditionalSelectionUsesFullYearSequence() {
        let headerModel = SpreadHeaderNavigatorModel(
            mode: .traditional,
            calendar: Self.calendar,
            today: Self.makeDate(year: 2026, month: 3, day: 29),
            spreads: [],
            tasks: [],
            notes: [],
            events: []
        )

        let stripModel = SpreadTitleNavigatorModel(headerModel: headerModel)
        let items = stripModel.items(for: .traditionalDay(Self.makeDate(year: 2026, month: 3, day: 29)))

        #expect(items.first?.label == "2026")
        #expect(items.first?.style == SpreadTitleNavigatorModel.Item.Style.year)
        #expect(items[1].label == "Jan")
        #expect(items[1].style == SpreadTitleNavigatorModel.Item.Style.month)
        #expect(items[2].label == "1")
        #expect(items[2].style == SpreadTitleNavigatorModel.Item.Style.day)
        #expect(items.contains(where: { $0.label == "Feb" && $0.style == SpreadTitleNavigatorModel.Item.Style.month }))
        #expect(items.contains(where: { $0.label == "Mar" && $0.style == SpreadTitleNavigatorModel.Item.Style.month }))
        #expect(items.last?.label == "31")
        #expect(items.last?.style == SpreadTitleNavigatorModel.Item.Style.day)
    }

    @Test func stripRebuildsWhenSelectionMovesToDifferentYear() {
        let day2026 = DataModel.Spread(period: .day, date: Self.makeDate(year: 2026, month: 3, day: 29), calendar: Self.calendar)
        let day2027 = DataModel.Spread(period: .day, date: Self.makeDate(year: 2027, month: 4, day: 1), calendar: Self.calendar)
        let headerModel = SpreadHeaderNavigatorModel(
            mode: .conventional,
            calendar: Self.calendar,
            today: Self.makeDate(year: 2026, month: 3, day: 29),
            spreads: [day2026, day2027],
            tasks: [],
            notes: [],
            events: []
        )
        let stripModel = SpreadTitleNavigatorModel(headerModel: headerModel)

        let items2026 = stripModel.items(for: SpreadHeaderNavigatorModel.Selection.conventional(day2026))
        let items2027 = stripModel.items(for: SpreadHeaderNavigatorModel.Selection.conventional(day2027))

        #expect(items2026.map { $0.label } == ["29"])
        #expect(items2027.map { $0.label } == ["1"])
    }

    @Test func liveWindowKeepsCurrentPlusTwoNeighborsPerSide() {
        let headerModel = SpreadHeaderNavigatorModel(
            mode: .traditional,
            calendar: Self.calendar,
            today: Self.makeDate(year: 2026, month: 3, day: 29),
            spreads: [],
            tasks: [],
            notes: [],
            events: []
        )
        let stripModel = SpreadTitleNavigatorModel(headerModel: headerModel)
        let items = stripModel.items(for: .traditionalDay(Self.makeDate(year: 2026, month: 1, day: 3)))

        let window = stripModel.liveWindowIDs(
            items: items,
            anchorID: items[3].id,
            radius: 2
        )

        #expect(window == Set(items[1...5].map(\.id)))
    }

    @Test func liveWindowClampsAtSequenceEdges() {
        let headerModel = SpreadHeaderNavigatorModel(
            mode: .traditional,
            calendar: Self.calendar,
            today: Self.makeDate(year: 2026, month: 3, day: 29),
            spreads: [],
            tasks: [],
            notes: [],
            events: []
        )
        let stripModel = SpreadTitleNavigatorModel(headerModel: headerModel)
        let items = stripModel.items(for: .traditionalYear(Self.makeDate(year: 2026, month: 1)))

        let leadingWindow = stripModel.liveWindowIDs(items: items, anchorID: items[0].id, radius: 2)
        let trailingWindow = stripModel.liveWindowIDs(items: items, anchorID: items.last!.id, radius: 2)

        #expect(leadingWindow == Set(items.prefix(3).map(\.id)))
        #expect(trailingWindow == Set(items.suffix(3).map(\.id)))
    }

    @Test func yearDisplayUsesStackedCenturyAndSuffix() {
        let year = DataModel.Spread(period: .year, date: Self.makeDate(year: 2026, month: 1), calendar: Self.calendar)
        let headerModel = SpreadHeaderNavigatorModel(
            mode: .conventional,
            calendar: Self.calendar,
            today: Self.makeDate(year: 2026, month: 1, day: 1),
            spreads: [year],
            tasks: [],
            notes: [],
            events: []
        )
        let item = SpreadTitleNavigatorModel(headerModel: headerModel).items(for: .conventional(year)).first

        #expect(item?.label == "2026")
        #expect(item?.display.top == "20")
        #expect(item?.display.bottom == "26")
    }

    @Test func dayDisplayUsesMonthSmallcapsSourceAndDayNumber() {
        let day = DataModel.Spread(period: .day, date: Self.makeDate(year: 2026, month: 3, day: 29), calendar: Self.calendar)
        let headerModel = SpreadHeaderNavigatorModel(
            mode: .conventional,
            calendar: Self.calendar,
            today: Self.makeDate(year: 2026, month: 3, day: 29),
            spreads: [day],
            tasks: [],
            notes: [],
            events: []
        )
        let item = SpreadTitleNavigatorModel(headerModel: headerModel).items(for: .conventional(day)).first

        #expect(item?.label == "29")
        #expect(item?.display.top == "MAR")
        #expect(item?.display.bottom == "29")
        #expect(item?.display.footer == "SUN")
    }

    @Test func multidayDisplayUsesSameMonthCompactRange() {
        let multiday = DataModel.Spread(
            startDate: Self.makeDate(year: 2026, month: 3, day: 20),
            endDate: Self.makeDate(year: 2026, month: 3, day: 22),
            calendar: Self.calendar
        )
        let headerModel = SpreadHeaderNavigatorModel(
            mode: .conventional,
            calendar: Self.calendar,
            today: Self.makeDate(year: 2026, month: 3, day: 20),
            spreads: [multiday],
            tasks: [],
            notes: [],
            events: []
        )
        let item = SpreadTitleNavigatorModel(headerModel: headerModel).items(for: .conventional(multiday)).first

        #expect(item?.display.top == "MAR")
        #expect(item?.display.bottom == "20-22")
        #expect(item?.display.footer == "FRI-SUN")
    }

    @Test func multidayDisplayUsesCrossMonthSpanWhenNeeded() {
        let multiday = DataModel.Spread(
            startDate: Self.makeDate(year: 2026, month: 3, day: 30),
            endDate: Self.makeDate(year: 2026, month: 4, day: 5),
            calendar: Self.calendar
        )
        let headerModel = SpreadHeaderNavigatorModel(
            mode: .conventional,
            calendar: Self.calendar,
            today: Self.makeDate(year: 2026, month: 3, day: 30),
            spreads: [multiday],
            tasks: [],
            notes: [],
            events: []
        )
        let item = SpreadTitleNavigatorModel(headerModel: headerModel).items(for: .conventional(multiday)).first

        #expect(item?.display.top == "MAR-APR")
        #expect(item?.display.bottom == "30-5")
        #expect(item?.display.footer == "MON-SUN")
    }
}
