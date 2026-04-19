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

        #expect(items.map { $0.label } == [
            "This year", "Jan", "1", "2-5", "2", "Last month", "This month", "10", "20-22", "Today"
        ])
        #expect(items.map { $0.style } == [
            SpreadTitleNavigatorItemStyle.year,
            .month,
            .day,
            .multiday,
            .day,
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

    @Test func conventionalStripPlacesMultidayBeforeSameStartDay() {
        let day = DataModel.Spread(
            period: .day,
            date: Self.makeDate(year: 2026, month: 3, day: 20),
            calendar: Self.calendar
        )
        let multiday = DataModel.Spread(
            startDate: Self.makeDate(year: 2026, month: 3, day: 20),
            endDate: Self.makeDate(year: 2026, month: 3, day: 22),
            calendar: Self.calendar
        )
        let headerModel = SpreadHeaderNavigatorModel(
            mode: .conventional,
            calendar: Self.calendar,
            today: Self.makeDate(year: 2026, month: 3, day: 20),
            spreads: [day, multiday],
            tasks: [],
            notes: [],
            events: []
        )

        let items = SpreadTitleNavigatorModel(headerModel: headerModel)
            .items(for: .conventional(day))

        let multidayIndex = items.firstIndex(where: { $0.style == .multiday })!
        let dayIndex = items.firstIndex(where: { $0.style == .day })!

        #expect(multidayIndex < dayIndex)
        #expect(items[multidayIndex].label == "20-22")
        #expect(items[dayIndex].label == "Today")
    }

    /// Setup: overdue items exist on a visible day spread and on an inbox-only task.
    /// Expected: only the assigned spread item gets a badge count in the conventional strip.
    @Test func conventionalItemsIncludeOverdueCountsForAssignedSpreadsOnly() {
        let visibleDay = DataModel.Spread(
            period: .day,
            date: Self.makeDate(year: 2026, month: 1, day: 10),
            calendar: Self.calendar
        )
        let headerModel = SpreadHeaderNavigatorModel(
            mode: .conventional,
            calendar: Self.calendar,
            today: Self.makeDate(year: 2026, month: 1, day: 12),
            spreads: [visibleDay],
            tasks: [],
            notes: [],
            events: []
        )
        let overdueTask = DataModel.Task(
            title: "Assigned overdue",
            date: visibleDay.date,
            period: .day,
            status: .open
        )
        let inboxTask = DataModel.Task(
            title: "Inbox overdue",
            date: Self.makeDate(year: 2026, month: 1, day: 8),
            period: .day,
            status: .open
        )
        let items = SpreadTitleNavigatorModel(
            headerModel: headerModel,
            overdueItems: [
                OverdueTaskItem(
                    task: overdueTask,
                    sourceKey: TaskReviewSourceKey(kind: .spread(id: visibleDay.id, period: .day, date: visibleDay.date))
                ),
                OverdueTaskItem(
                    task: inboxTask,
                    sourceKey: TaskReviewSourceKey(kind: .inbox)
                )
            ]
        )
        .items(for: .conventional(visibleDay))

        let expectedDayID = SpreadHeaderNavigatorModel.Selection.conventional(visibleDay).stableID(calendar: Self.calendar)
        let dayItem = items.first(where: { $0.selection.stableID(calendar: Self.calendar) == expectedDayID })
        #expect(dayItem?.overdueCount == 1)
        #expect(items.filter { $0.overdueCount > 0 }.count == 1)
    }

    /// Setup: two overdue tasks share the same visible day spread.
    /// Expected: the strip badge count is exact and not propagated to other selections.
    @Test func conventionalItemsShowExactOverdueCountsWithoutAncestorPropagation() {
        let year = DataModel.Spread(period: .year, date: Self.makeDate(year: 2026, month: 1), calendar: Self.calendar)
        let day = DataModel.Spread(period: .day, date: Self.makeDate(year: 2026, month: 1, day: 10), calendar: Self.calendar)
        let taskA = DataModel.Task(title: "A", date: day.date, period: .day, status: .open)
        let taskB = DataModel.Task(title: "B", date: day.date, period: .day, status: .open)
        let items = SpreadTitleNavigatorModel(
            headerModel: SpreadHeaderNavigatorModel(
                mode: .conventional,
                calendar: Self.calendar,
                today: Self.makeDate(year: 2026, month: 1, day: 12),
                spreads: [year, day],
                tasks: [],
                notes: [],
                events: []
            ),
            overdueItems: [
                OverdueTaskItem(task: taskA, sourceKey: TaskReviewSourceKey(kind: .spread(id: day.id, period: .day, date: day.date))),
                OverdueTaskItem(task: taskB, sourceKey: TaskReviewSourceKey(kind: .spread(id: day.id, period: .day, date: day.date))),
            ]
        )
        .items(for: .conventional(day))

        let yearItem = items.first(where: { $0.style == .year })
        let dayItem = items.first(where: { $0.style == .day })
        #expect(yearItem?.overdueCount == 0)
        #expect(dayItem?.overdueCount == 2)
    }

    /// Setup: a traditional strip with an overdue day assignment and a multiday overdue source.
    /// Expected: only the matching day selection gets a badge because multiday assignments do not map to traditional selections.
    @Test func traditionalItemsBadgeMatchingPeriodsOnly() {
        let overdueDay = DataModel.Task(title: "Day", date: Self.makeDate(year: 2026, month: 1, day: 10), period: .day, status: .open)
        let overdueMultiday = DataModel.Task(title: "Multi", date: Self.makeDate(year: 2026, month: 1, day: 10), period: .multiday, status: .open)
        let multiday = DataModel.Spread(
            startDate: Self.makeDate(year: 2026, month: 1, day: 10),
            endDate: Self.makeDate(year: 2026, month: 1, day: 12),
            calendar: Self.calendar
        )
        let items = SpreadTitleNavigatorModel(
            headerModel: SpreadHeaderNavigatorModel(
                mode: .traditional,
                calendar: Self.calendar,
                today: Self.makeDate(year: 2026, month: 1, day: 12),
                spreads: [multiday],
                tasks: [],
                notes: [],
                events: []
            ),
            overdueItems: [
                OverdueTaskItem(
                    task: overdueDay,
                    sourceKey: TaskReviewSourceKey(kind: .spread(id: UUID(), period: .day, date: overdueDay.date))
                ),
                OverdueTaskItem(
                    task: overdueMultiday,
                    sourceKey: TaskReviewSourceKey(kind: .spread(id: multiday.id, period: .multiday, date: overdueMultiday.date))
                )
            ]
        )
        .items(for: .traditionalDay(Self.makeDate(year: 2026, month: 1, day: 12)))

        let expectedDayID = SpreadHeaderNavigatorModel.Selection
            .traditionalDay(Self.makeDate(year: 2026, month: 1, day: 10))
            .stableID(calendar: Self.calendar)
        let dayItem = items.first(where: { $0.selection.stableID(calendar: Self.calendar) == expectedDayID })
        #expect(dayItem?.overdueCount == 1)
        #expect(items.filter { $0.overdueCount > 0 }.count == 1)
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
        #expect(items.first?.style == SpreadTitleNavigatorItemStyle.year)
        #expect(items[1].label == "Jan")
        #expect(items[1].style == SpreadTitleNavigatorItemStyle.month)
        #expect(items[2].label == "1")
        #expect(items[2].style == SpreadTitleNavigatorItemStyle.day)
        #expect(items.contains(where: { $0.label == "Feb" && $0.style == SpreadTitleNavigatorItemStyle.month }))
        #expect(items.contains(where: { $0.label == "Mar" && $0.style == SpreadTitleNavigatorItemStyle.month }))
        #expect(items.last?.label == "31")
        #expect(items.last?.style == SpreadTitleNavigatorItemStyle.day)
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

        #expect(items2026.map { $0.label } == ["Today"])
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
        let year = DataModel.Spread(
            period: .year,
            date: Self.makeDate(year: 2026, month: 1),
            calendar: Self.calendar,
            usesDynamicName: false
        )
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

    /// Setup: a canonical month spread has dynamic naming disabled.
    /// Expected: the strip display keeps the canonical label and renders the year above uppercase month text.
    @Test func monthDisplayUsesYearHeaderAndUppercaseMonth() {
        let month = DataModel.Spread(
            period: .month,
            date: Self.makeDate(year: 2026, month: 4),
            calendar: Self.calendar,
            usesDynamicName: false
        )
        let item = titleNavigatorItem(for: month, today: Self.makeDate(year: 2026, month: 4, day: 18))

        #expect(item?.label == "Apr")
        #expect(item?.display.top == "2026")
        #expect(item?.display.bottom == "APR")
        #expect(item?.display.footer == nil)
        #expect(item?.display.isPersonalized == false)
    }

    @Test func dayDisplayUsesMonthSmallcapsSourceAndDayNumber() {
        let day = DataModel.Spread(
            period: .day,
            date: Self.makeDate(year: 2026, month: 3, day: 29),
            calendar: Self.calendar,
            usesDynamicName: false
        )
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

    /// Setup: explicit spreads use custom names for year/month/day/multiday periods.
    /// Expected: each personalized display uses the finalized header, name, and footer matrix.
    @Test func personalizedDisplaysUsePeriodSpecificHeaderNameFooterMatrix() {
        let today = Self.makeDate(year: 2026, month: 4, day: 18)
        let year = DataModel.Spread(
            period: .year,
            date: Self.makeDate(year: 2026, month: 1),
            calendar: Self.calendar,
            customName: "Annual plan",
            usesDynamicName: false
        )
        let month = DataModel.Spread(
            period: .month,
            date: Self.makeDate(year: 2026, month: 4),
            calendar: Self.calendar,
            customName: "Launch month",
            usesDynamicName: false
        )
        let day = DataModel.Spread(
            period: .day,
            date: today,
            calendar: Self.calendar,
            customName: "Ship day",
            usesDynamicName: false
        )
        let multiday = DataModel.Spread(
            startDate: Self.makeDate(year: 2026, month: 4, day: 12),
            endDate: Self.makeDate(year: 2026, month: 4, day: 18),
            calendar: Self.calendar,
            customName: "Launch week",
            usesDynamicName: false
        )

        let yearItem = titleNavigatorItem(for: year, today: today)
        let monthItem = titleNavigatorItem(for: month, today: today)
        let dayItem = titleNavigatorItem(for: day, today: today)
        let multidayItem = titleNavigatorItem(for: multiday, today: today)

        expectDisplay(yearItem?.display, top: "2026", bottom: "Annual plan", footer: nil, isPersonalized: true)
        expectDisplay(monthItem?.display, top: "Apr", bottom: "Launch month", footer: "2026", isPersonalized: true)
        expectDisplay(dayItem?.display, top: "Apr 18", bottom: "Ship day", footer: "Sat", isPersonalized: true)
        expectDisplay(
            multidayItem?.display,
            top: "Apr 12-18",
            bottom: "Launch week",
            footer: "Sun-Sat",
            isPersonalized: true
        )
    }

    /// Setup: a custom override and a qualifying dynamic name produce the same visible personalized name.
    /// Expected: both sources produce identical month display data and use the personalized layout path.
    @Test func customAndDynamicPersonalizedSourcesUseSameDisplayLayout() {
        let today = Self.makeDate(year: 2026, month: 4, day: 18)
        let customMonth = DataModel.Spread(
            period: .month,
            date: Self.makeDate(year: 2026, month: 4),
            calendar: Self.calendar,
            customName: "This month",
            usesDynamicName: false
        )
        let dynamicMonth = DataModel.Spread(
            period: .month,
            date: Self.makeDate(year: 2026, month: 4),
            calendar: Self.calendar,
            usesDynamicName: true
        )

        let customDisplay = titleNavigatorItem(for: customMonth, today: today)?.display
        let dynamicDisplay = titleNavigatorItem(for: dynamicMonth, today: today)?.display

        expectDisplay(customDisplay, top: "Apr", bottom: "This month", footer: "2026", isPersonalized: true)
        #expect(dynamicDisplay?.top == customDisplay?.top)
        #expect(dynamicDisplay?.bottom == customDisplay?.bottom)
        #expect(dynamicDisplay?.footer == customDisplay?.footer)
        #expect(dynamicDisplay?.isPersonalized == customDisplay?.isPersonalized)
    }

    private func expectDisplay(
        _ display: SpreadTitleNavigatorModel.Item.Display?,
        top: String?,
        bottom: String,
        footer: String?,
        isPersonalized: Bool
    ) {
        #expect(display?.top == top)
        #expect(display?.bottom == bottom)
        #expect(display?.footer == footer)
        #expect(display?.isPersonalized == isPersonalized)
    }

    private func titleNavigatorItem(
        for spread: DataModel.Spread,
        today: Date
    ) -> SpreadTitleNavigatorModel.Item? {
        let headerModel = SpreadHeaderNavigatorModel(
            mode: .conventional,
            calendar: Self.calendar,
            today: today,
            firstWeekday: .sunday,
            spreads: [spread],
            tasks: [],
            notes: [],
            events: []
        )

        return SpreadTitleNavigatorModel(headerModel: headerModel)
            .items(for: .conventional(spread))
            .first
    }
}
