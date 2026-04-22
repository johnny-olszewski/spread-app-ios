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

    /// Setup: The selected year contains hidden-eligible past spreads plus current, future, favorite, and open-task spreads.
    /// Expected: Relevant Past Only hides only irrelevant past spreads before title item rendering.
    @Test func relevantPastOnlyFiltersConventionalPastSpreadsByFavoriteOrOpenTask() {
        let today = Self.makeDate(year: 2026, month: 4, day: 15)
        let hiddenPastDay = DataModel.Spread(period: .day, date: Self.makeDate(year: 2026, month: 4, day: 8), calendar: Self.calendar)
        let favoritePastDay = DataModel.Spread(
            period: .day,
            date: Self.makeDate(year: 2026, month: 4, day: 9),
            calendar: Self.calendar,
            isFavorite: true
        )
        let openPastDay = DataModel.Spread(period: .day, date: Self.makeDate(year: 2026, month: 4, day: 10), calendar: Self.calendar)
        let migratedOnlyPastDay = DataModel.Spread(period: .day, date: Self.makeDate(year: 2026, month: 4, day: 11), calendar: Self.calendar)
        let completePastDay = DataModel.Spread(period: .day, date: Self.makeDate(year: 2026, month: 4, day: 12), calendar: Self.calendar)
        let currentDay = DataModel.Spread(period: .day, date: today, calendar: Self.calendar)
        let futureMonth = DataModel.Spread(period: .month, date: Self.makeDate(year: 2026, month: 5), calendar: Self.calendar)
        let openPastMonth = DataModel.Spread(period: .month, date: Self.makeDate(year: 2026, month: 3), calendar: Self.calendar)
        let hiddenPastMultiday = DataModel.Spread(
            startDate: Self.makeDate(year: 2026, month: 4, day: 1),
            endDate: Self.makeDate(year: 2026, month: 4, day: 3),
            calendar: Self.calendar
        )
        let openPastMultiday = DataModel.Spread(
            startDate: Self.makeDate(year: 2026, month: 4, day: 4),
            endDate: Self.makeDate(year: 2026, month: 4, day: 6),
            calendar: Self.calendar
        )
        let futureMultiday = DataModel.Spread(
            startDate: Self.makeDate(year: 2026, month: 4, day: 20),
            endDate: Self.makeDate(year: 2026, month: 4, day: 22),
            calendar: Self.calendar
        )
        let openDayTask = DataModel.Task(
            title: "Open day",
            date: openPastDay.date,
            period: .day,
            status: .open,
            assignments: [TaskAssignment(period: .day, date: openPastDay.date, status: .open)]
        )
        let migratedOnlyTask = DataModel.Task(
            title: "Migrated source",
            date: migratedOnlyPastDay.date,
            period: .day,
            status: .open,
            assignments: [TaskAssignment(period: .day, date: migratedOnlyPastDay.date, status: .migrated)]
        )
        let completeTask = DataModel.Task(
            title: "Complete",
            date: completePastDay.date,
            period: .day,
            status: .complete,
            assignments: [TaskAssignment(period: .day, date: completePastDay.date, status: .open)]
        )
        let openMonthTask = DataModel.Task(
            title: "Open month",
            date: openPastMonth.date,
            period: .month,
            status: .open,
            assignments: [TaskAssignment(period: .month, date: openPastMonth.date, status: .open)]
        )
        let openMultidayTask = DataModel.Task(
            title: "Open multiday",
            date: Self.makeDate(year: 2026, month: 4, day: 5),
            period: .day,
            hasPreferredAssignment: true,
            status: .open
        )
        let stripModel = SpreadTitleNavigatorModel(
            headerModel: SpreadHeaderNavigatorModel(
                mode: .conventional,
                calendar: Self.calendar,
                today: today,
                spreads: [
                    hiddenPastDay,
                    favoritePastDay,
                    openPastDay,
                    migratedOnlyPastDay,
                    completePastDay,
                    currentDay,
                    futureMonth,
                    openPastMonth,
                    hiddenPastMultiday,
                    openPastMultiday,
                    futureMultiday
                ],
                tasks: [openDayTask, migratedOnlyTask, completeTask, openMonthTask, openMultidayTask],
                notes: [],
                events: []
            )
        )

        let filteredIDs = stripModel.titleStripItems(
            for: .conventional(currentDay),
            displayPreference: .relevantPastOnly
        )
        .map(\.id)

        #expect(filteredIDs.contains(stableID(for: favoritePastDay)))
        #expect(filteredIDs.contains(stableID(for: openPastDay)))
        #expect(filteredIDs.contains(stableID(for: openPastMonth)))
        #expect(filteredIDs.contains(stableID(for: openPastMultiday)))
        #expect(filteredIDs.contains(stableID(for: currentDay)))
        #expect(filteredIDs.contains(stableID(for: futureMonth)))
        #expect(filteredIDs.contains(stableID(for: futureMultiday)))
        #expect(!filteredIDs.contains(stableID(for: hiddenPastDay)))
        #expect(!filteredIDs.contains(stableID(for: migratedOnlyPastDay)))
        #expect(!filteredIDs.contains(stableID(for: completePastDay)))
        #expect(!filteredIDs.contains(stableID(for: hiddenPastMultiday)))
    }

    /// Setup: Conventional strip filtering is switched to Show All Spreads.
    /// Expected: The presentation sequence exactly matches the existing complete conventional item sequence.
    @Test func showAllSpreadsPreservesCompleteConventionalTitleStripSequence() {
        let today = Self.makeDate(year: 2026, month: 4, day: 15)
        let pastDay = DataModel.Spread(period: .day, date: Self.makeDate(year: 2026, month: 4, day: 8), calendar: Self.calendar)
        let currentDay = DataModel.Spread(period: .day, date: today, calendar: Self.calendar)
        let futureMonth = DataModel.Spread(period: .month, date: Self.makeDate(year: 2026, month: 5), calendar: Self.calendar)
        let stripModel = SpreadTitleNavigatorModel(
            headerModel: SpreadHeaderNavigatorModel(
                mode: .conventional,
                calendar: Self.calendar,
                today: today,
                spreads: [futureMonth, currentDay, pastDay],
                tasks: [],
                notes: [],
                events: []
            )
        )

        let completeItems = stripModel.items(for: .conventional(currentDay))
        let showAllItems = stripModel.titleStripItems(
            for: .conventional(currentDay),
            displayPreference: .showAllSpreads
        )

        #expect(showAllItems.map(\.id) == completeItems.map(\.id))
    }

    /// Setup: Traditional title strip uses the Relevant Past Only preference.
    /// Expected: Traditional mode remains unfiltered and keeps its full year sequence.
    @Test func relevantPastOnlyDoesNotFilterTraditionalTitleStrip() {
        let selection = SpreadHeaderNavigatorModel.Selection.traditionalDay(Self.makeDate(year: 2026, month: 4, day: 15))
        let stripModel = SpreadTitleNavigatorModel(
            headerModel: SpreadHeaderNavigatorModel(
                mode: .traditional,
                calendar: Self.calendar,
                today: Self.makeDate(year: 2026, month: 4, day: 15),
                spreads: [],
                tasks: [],
                notes: [],
                events: []
            )
        )

        let completeItems = stripModel.items(for: selection)
        let filteredItems = stripModel.titleStripItems(
            for: selection,
            displayPreference: .relevantPastOnly
        )

        #expect(filteredItems.map(\.id) == completeItems.map(\.id))
    }

    /// Setup: Day, month, year, and multiday spreads sit just before or on today's boundary.
    /// Expected: A spread becomes past only after its full period has passed.
    @Test func relevantPastOnlyUsesPeriodSpecificPastBoundaries() {
        let today = Self.makeDate(year: 2026, month: 4, day: 15)

        #expect(SpreadTitleStripRelevanceFilter.isPast(
            DataModel.Spread(period: .day, date: Self.makeDate(year: 2026, month: 4, day: 14), calendar: Self.calendar),
            calendar: Self.calendar,
            today: today
        ))
        #expect(!SpreadTitleStripRelevanceFilter.isPast(
            DataModel.Spread(period: .day, date: today, calendar: Self.calendar),
            calendar: Self.calendar,
            today: today
        ))
        #expect(SpreadTitleStripRelevanceFilter.isPast(
            DataModel.Spread(period: .month, date: Self.makeDate(year: 2026, month: 3), calendar: Self.calendar),
            calendar: Self.calendar,
            today: today
        ))
        #expect(!SpreadTitleStripRelevanceFilter.isPast(
            DataModel.Spread(period: .month, date: Self.makeDate(year: 2026, month: 4), calendar: Self.calendar),
            calendar: Self.calendar,
            today: today
        ))
        #expect(SpreadTitleStripRelevanceFilter.isPast(
            DataModel.Spread(period: .year, date: Self.makeDate(year: 2025, month: 1), calendar: Self.calendar),
            calendar: Self.calendar,
            today: today
        ))
        #expect(!SpreadTitleStripRelevanceFilter.isPast(
            DataModel.Spread(period: .year, date: Self.makeDate(year: 2026, month: 1), calendar: Self.calendar),
            calendar: Self.calendar,
            today: today
        ))
        #expect(SpreadTitleStripRelevanceFilter.isPast(
            DataModel.Spread(
                startDate: Self.makeDate(year: 2026, month: 4, day: 10),
                endDate: Self.makeDate(year: 2026, month: 4, day: 14),
                calendar: Self.calendar
            ),
            calendar: Self.calendar,
            today: today
        ))
        #expect(!SpreadTitleStripRelevanceFilter.isPast(
            DataModel.Spread(
                startDate: Self.makeDate(year: 2026, month: 4, day: 10),
                endDate: today,
                calendar: Self.calendar
            ),
            calendar: Self.calendar,
            today: today
        ))
    }

    /// Setup: Past multiday spreads have no open task relevance, completed/cancelled tasks, favorite state, or open tasks.
    /// Expected: Fully past multiday ranges are hidden unless they are favorited or currently show an open task.
    @Test func relevantPastOnlyHidesFullyPastMultidayRangesWithoutRelevance() {
        let today = Self.makeDate(year: 2026, month: 4, day: 15)
        let hiddenPastMultiday = DataModel.Spread(
            startDate: Self.makeDate(year: 2026, month: 4, day: 1),
            endDate: Self.makeDate(year: 2026, month: 4, day: 3),
            calendar: Self.calendar
        )
        let completeOnlyMultiday = DataModel.Spread(
            startDate: Self.makeDate(year: 2026, month: 4, day: 4),
            endDate: Self.makeDate(year: 2026, month: 4, day: 6),
            calendar: Self.calendar
        )
        let favoritePastMultiday = DataModel.Spread(
            startDate: Self.makeDate(year: 2026, month: 4, day: 7),
            endDate: Self.makeDate(year: 2026, month: 4, day: 9),
            calendar: Self.calendar,
            isFavorite: true
        )
        let openPastMultiday = DataModel.Spread(
            startDate: Self.makeDate(year: 2026, month: 4, day: 10),
            endDate: Self.makeDate(year: 2026, month: 4, day: 12),
            calendar: Self.calendar
        )
        let currentDay = DataModel.Spread(period: .day, date: today, calendar: Self.calendar)
        let completeTask = DataModel.Task(
            title: "Complete only",
            date: Self.makeDate(year: 2026, month: 4, day: 5),
            period: .day,
            hasPreferredAssignment: true,
            status: .complete
        )
        let cancelledTask = DataModel.Task(
            title: "Cancelled only",
            date: Self.makeDate(year: 2026, month: 4, day: 2),
            period: .day,
            hasPreferredAssignment: true,
            status: .cancelled
        )
        let openTask = DataModel.Task(
            title: "Open",
            date: Self.makeDate(year: 2026, month: 4, day: 11),
            period: .day,
            hasPreferredAssignment: true,
            status: .open
        )
        let stripModel = SpreadTitleNavigatorModel(
            headerModel: SpreadHeaderNavigatorModel(
                mode: .conventional,
                calendar: Self.calendar,
                today: today,
                spreads: [
                    hiddenPastMultiday,
                    completeOnlyMultiday,
                    favoritePastMultiday,
                    openPastMultiday,
                    currentDay
                ],
                tasks: [completeTask, cancelledTask, openTask],
                notes: [],
                events: []
            )
        )

        let filteredIDs = stripModel.titleStripItems(
            for: .conventional(currentDay),
            displayPreference: .relevantPastOnly
        )
        .map(\.id)

        #expect(!filteredIDs.contains(stableID(for: hiddenPastMultiday)))
        #expect(!filteredIDs.contains(stableID(for: completeOnlyMultiday)))
        #expect(filteredIDs.contains(stableID(for: favoritePastMultiday)))
        #expect(filteredIDs.contains(stableID(for: openPastMultiday)))
    }

    /// Setup: A multiday spread crosses a year boundary and ended before today.
    /// Expected: Past detection uses the normalized end date rather than the start date's period.
    @Test func relevantPastOnlyTreatsCrossYearMultidayPastByEndDate() {
        let crossYearPastMultiday = DataModel.Spread(
            startDate: Self.makeDate(year: 2025, month: 12, day: 29),
            endDate: Self.makeDate(year: 2026, month: 1, day: 2),
            calendar: Self.calendar
        )

        #expect(SpreadTitleStripRelevanceFilter.isPast(
            crossYearPastMultiday,
            calendar: Self.calendar,
            today: Self.makeDate(year: 2026, month: 1, day: 3)
        ))
        #expect(!SpreadTitleStripRelevanceFilter.isPast(
            crossYearPastMultiday,
            calendar: Self.calendar,
            today: Self.makeDate(year: 2026, month: 1, day: 2)
        ))
    }

    /// Setup: A past selected spread is hidden by the Relevant Past Only title-strip filter.
    /// Expected: Selection remains valid but visibility support reports that the leading chevron must act as proxy.
    @Test func hiddenFilteredSelectionActivatesLeadingNavigatorProxy() {
        let today = Self.makeDate(year: 2026, month: 4, day: 15)
        let hiddenPastDay = DataModel.Spread(period: .day, date: Self.makeDate(year: 2026, month: 4, day: 8), calendar: Self.calendar)
        let visibleCurrentDay = DataModel.Spread(period: .day, date: today, calendar: Self.calendar)
        let selection = SpreadHeaderNavigatorModel.Selection.conventional(hiddenPastDay)
        let stripModel = SpreadTitleNavigatorModel(
            headerModel: SpreadHeaderNavigatorModel(
                mode: .conventional,
                calendar: Self.calendar,
                today: today,
                spreads: [hiddenPastDay, visibleCurrentDay],
                tasks: [],
                notes: [],
                events: []
            )
        )

        let filteredItems = stripModel.titleStripItems(
            for: selection,
            displayPreference: .relevantPastOnly
        )

        #expect(!SpreadTitleNavigatorSelectionVisibility.isSelectionVisible(
            selection,
            in: filteredItems,
            calendar: Self.calendar
        ))
        #expect(stripModel.items(for: selection).contains { $0.id == stableID(for: hiddenPastDay) })
    }

    /// Setup: The user taps either the selected strip item or a different visible strip item.
    /// Expected: Selected item taps are a no-op; only non-selected items return a selection change.
    @Test func selectedTitleStripItemTapDoesNotOpenOrChangeNavigatorSelection() {
        let selected = DataModel.Spread(period: .day, date: Self.makeDate(year: 2026, month: 4, day: 15), calendar: Self.calendar)
        let other = DataModel.Spread(period: .day, date: Self.makeDate(year: 2026, month: 4, day: 16), calendar: Self.calendar)
        let stripModel = SpreadTitleNavigatorModel(
            headerModel: SpreadHeaderNavigatorModel(
                mode: .conventional,
                calendar: Self.calendar,
                today: selected.date,
                spreads: [selected, other],
                tasks: [],
                notes: [],
                events: []
            )
        )
        let items = stripModel.items(for: .conventional(selected))
        let selectedID = stableID(for: selected)
        let selectedItem = items.first { $0.id == selectedID }!
        let otherItem = items.first { $0.id == stableID(for: other) }!

        #expect(SpreadTitleNavigatorTapSupport.selectionChange(
            for: selectedItem,
            selectedSemanticID: selectedID
        ) == nil)
        #expect(SpreadTitleNavigatorTapSupport.selectionChange(
            for: otherItem,
            selectedSemanticID: selectedID
        )?.stableID(calendar: Self.calendar) == Optional(stableID(for: other)))
    }

    /// Setup: The rooted navigator trigger runs under compact and regular horizontal size classes.
    /// Expected: Regular width presents as a popover; compact width presents as a large sheet.
    @Test func rootedNavigatorTriggerUsesAdaptivePresentationSurface() {
        #expect(SpreadNavigatorPresentationSupport.presentsAsPopover(horizontalSizeClass: .regular))
        #expect(!SpreadNavigatorPresentationSupport.presentsAsPopover(horizontalSizeClass: .compact))
        #expect(!SpreadNavigatorPresentationSupport.presentsAsPopover(horizontalSizeClass: nil))
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
        #expect(dayItem?.badge == .overdue(count: 1))
        #expect(items.filter { $0.badge == .overdue(count: 1) }.count == 1)
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
                OverdueTaskItem(
                    task: taskA,
                    sourceKey: TaskReviewSourceKey(kind: .spread(id: day.id, period: .day, date: day.date))
                ),
                OverdueTaskItem(
                    task: taskB,
                    sourceKey: TaskReviewSourceKey(kind: .spread(id: day.id, period: .day, date: day.date))
                ),
            ]
        )
        .items(for: .conventional(day))

        let yearItem = items.first(where: { $0.style == .year })
        let dayItem = items.first(where: { $0.style == .day })
        #expect(yearItem?.badge == nil)
        #expect(dayItem?.badge == .overdue(count: 2))
    }

    /// Setup: conventional year, month, and day spreads each have one overdue open task source.
    /// Expected: each matching explicit spread receives an overdue badge through the badge enum path.
    @Test func conventionalYearMonthAndDayItemsUseOverdueBadges() {
        let year = DataModel.Spread(period: .year, date: Self.makeDate(year: 2025, month: 1), calendar: Self.calendar)
        let month = DataModel.Spread(period: .month, date: Self.makeDate(year: 2025, month: 12), calendar: Self.calendar)
        let day = DataModel.Spread(period: .day, date: Self.makeDate(year: 2025, month: 12, day: 30), calendar: Self.calendar)
        let yearTask = DataModel.Task(title: "Year", date: year.date, period: .year, status: .open)
        let monthTask = DataModel.Task(title: "Month", date: month.date, period: .month, status: .open)
        let dayTask = DataModel.Task(title: "Day", date: day.date, period: .day, status: .open)

        let items = SpreadTitleNavigatorModel(
            headerModel: SpreadHeaderNavigatorModel(
                mode: .conventional,
                calendar: Self.calendar,
                today: Self.makeDate(year: 2026, month: 1, day: 2),
                spreads: [year, month, day],
                tasks: [],
                notes: [],
                events: []
            ),
            overdueItems: [
                OverdueTaskItem(
                    task: yearTask,
                    sourceKey: TaskReviewSourceKey(kind: .spread(id: year.id, period: .year, date: year.date))
                ),
                OverdueTaskItem(
                    task: monthTask,
                    sourceKey: TaskReviewSourceKey(kind: .spread(id: month.id, period: .month, date: month.date))
                ),
                OverdueTaskItem(
                    task: dayTask,
                    sourceKey: TaskReviewSourceKey(kind: .spread(id: day.id, period: .day, date: day.date))
                )
            ]
        )
        .items(for: .conventional(day))

        #expect(items.first(where: { $0.style == .year })?.badge == .overdue(count: 1))
        #expect(items.first(where: { $0.style == .month })?.badge == .overdue(count: 1))
        #expect(items.first(where: { $0.style == .day })?.badge == .overdue(count: 1))
    }

    /// Setup: a conventional explicit spread is favorited and also has overdue work.
    /// Expected: the overdue badge wins priority and the favorite badge is hidden.
    @Test func overdueBadgeTakesPriorityOverFavoriteBadge() {
        let spread = DataModel.Spread(
            period: .day,
            date: Self.makeDate(year: 2026, month: 1, day: 10),
            calendar: Self.calendar,
            isFavorite: true
        )
        let task = DataModel.Task(title: "Overdue", date: spread.date, period: .day, status: .open)

        let item = SpreadTitleNavigatorModel(
            headerModel: SpreadHeaderNavigatorModel(
                mode: .conventional,
                calendar: Self.calendar,
                today: Self.makeDate(year: 2026, month: 1, day: 12),
                spreads: [spread],
                tasks: [],
                notes: [],
                events: []
            ),
            overdueItems: [
                OverdueTaskItem(
                    task: task,
                    sourceKey: TaskReviewSourceKey(kind: .spread(id: spread.id, period: .day, date: spread.date))
                )
            ]
        )
        .items(for: .conventional(spread))
        .first

        #expect(item?.badge == .overdue(count: 1))
    }

    /// Setup: a conventional explicit spread is favorited and has no overdue work.
    /// Expected: the item receives a favorite badge.
    @Test func favoriteBadgeAppearsWhenNoOverdueBadgeExists() {
        let spread = DataModel.Spread(
            period: .month,
            date: Self.makeDate(year: 2026, month: 1),
            calendar: Self.calendar,
            isFavorite: true
        )

        let item = SpreadTitleNavigatorModel(
            headerModel: SpreadHeaderNavigatorModel(
                mode: .conventional,
                calendar: Self.calendar,
                today: Self.makeDate(year: 2026, month: 1, day: 12),
                spreads: [spread],
                tasks: [],
                notes: [],
                events: []
            )
        )
        .items(for: .conventional(spread))
        .first

        #expect(item?.badge == .favorite)
    }

    /// Setup: both conventional title-strip display preferences include a favorite past spread.
    /// Expected: the same favorite badge is present in Relevant Past Only and Show All Spreads modes.
    @Test func favoriteBadgesApplyInBothConventionalDisplayModes() {
        let spread = DataModel.Spread(
            period: .day,
            date: Self.makeDate(year: 2026, month: 1, day: 10),
            calendar: Self.calendar,
            isFavorite: true
        )
        let model = SpreadTitleNavigatorModel(
            headerModel: SpreadHeaderNavigatorModel(
                mode: .conventional,
                calendar: Self.calendar,
                today: Self.makeDate(year: 2026, month: 1, day: 12),
                spreads: [spread],
                tasks: [],
                notes: [],
                events: []
            )
        )

        let relevantItems = model.titleStripItems(for: .conventional(spread), displayPreference: .relevantPastOnly)
        let allItems = model.titleStripItems(for: .conventional(spread), displayPreference: .showAllSpreads)

        #expect(relevantItems.first?.badge == .favorite)
        #expect(allItems.first?.badge == .favorite)
    }

    /// Setup: a conventional multiday spread contains overdue open preferred-assignment tasks, including Inbox tasks.
    /// Expected: the multiday item shows the exact overdue count for tasks in the date range.
    @Test func conventionalMultidayItemCountsOverduePreferredAssignmentsInsideRange() {
        let multiday = DataModel.Spread(
            startDate: Self.makeDate(year: 2026, month: 1, day: 10),
            endDate: Self.makeDate(year: 2026, month: 1, day: 12),
            calendar: Self.calendar
        )
        let taskA = DataModel.Task(
            title: "Inside A",
            date: Self.makeDate(year: 2026, month: 1, day: 10),
            period: .day,
            status: .open
        )
        let taskB = DataModel.Task(
            title: "Inside B",
            date: Self.makeDate(year: 2026, month: 1, day: 12),
            period: .day,
            status: .open
        )
        let outsideTask = DataModel.Task(
            title: "Outside",
            date: Self.makeDate(year: 2026, month: 1, day: 9),
            period: .day,
            status: .open
        )

        let item = SpreadTitleNavigatorModel(
            headerModel: SpreadHeaderNavigatorModel(
                mode: .conventional,
                calendar: Self.calendar,
                today: Self.makeDate(year: 2026, month: 1, day: 13),
                spreads: [multiday],
                tasks: [taskA, taskB, outsideTask],
                notes: [],
                events: []
            )
        )
        .items(for: .conventional(multiday))
        .first

        #expect(item?.badge == .overdue(count: 2))
    }

    /// Setup: completed, cancelled, and migrated tasks fall inside an overdue conventional multiday range.
    /// Expected: non-open tasks do not contribute to the multiday overdue badge.
    @Test func conventionalMultidayBadgeExcludesCompletedCancelledAndMigratedTasks() {
        let multiday = DataModel.Spread(
            startDate: Self.makeDate(year: 2026, month: 1, day: 10),
            endDate: Self.makeDate(year: 2026, month: 1, day: 12),
            calendar: Self.calendar
        )
        let completed = DataModel.Task(
            title: "Completed",
            date: Self.makeDate(year: 2026, month: 1, day: 10),
            period: .day,
            status: .complete
        )
        let cancelled = DataModel.Task(
            title: "Cancelled",
            date: Self.makeDate(year: 2026, month: 1, day: 11),
            period: .day,
            status: .cancelled
        )
        let migrated = DataModel.Task(
            title: "Migrated",
            date: Self.makeDate(year: 2026, month: 1, day: 12),
            period: .day,
            status: .migrated
        )

        let item = SpreadTitleNavigatorModel(
            headerModel: SpreadHeaderNavigatorModel(
                mode: .conventional,
                calendar: Self.calendar,
                today: Self.makeDate(year: 2026, month: 1, day: 13),
                spreads: [multiday],
                tasks: [completed, cancelled, migrated],
                notes: [],
                events: []
            )
        )
        .items(for: .conventional(multiday))
        .first

        #expect(item?.badge == nil)
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
        #expect(dayItem?.badge == .overdue(count: 1))
        #expect(items.filter { $0.badge == .overdue(count: 1) }.count == 1)
    }

    /// Setup: traditional mode has an explicit favorite spread in the same year but no overdue items.
    /// Expected: virtual traditional title-strip items never receive favorite badges.
    @Test func traditionalItemsNeverShowFavoriteBadges() {
        let favorite = DataModel.Spread(
            period: .day,
            date: Self.makeDate(year: 2026, month: 1, day: 10),
            calendar: Self.calendar,
            isFavorite: true
        )

        let items = SpreadTitleNavigatorModel(
            headerModel: SpreadHeaderNavigatorModel(
                mode: .traditional,
                calendar: Self.calendar,
                today: Self.makeDate(year: 2026, month: 1, day: 12),
                spreads: [favorite],
                tasks: [],
                notes: [],
                events: []
            )
        )
        .items(for: .traditionalDay(Self.makeDate(year: 2026, month: 1, day: 12)))

        #expect(items.allSatisfy { $0.badge != .favorite })
    }

    /// Setup: the selected conventional item has an overdue badge.
    /// Expected: selected state does not suppress the item's badge value.
    @Test func selectedTitleStripItemKeepsBadge() {
        let spread = DataModel.Spread(
            period: .day,
            date: Self.makeDate(year: 2026, month: 1, day: 10),
            calendar: Self.calendar
        )
        let task = DataModel.Task(title: "Overdue", date: spread.date, period: .day, status: .open)

        let items = SpreadTitleNavigatorModel(
            headerModel: SpreadHeaderNavigatorModel(
                mode: .conventional,
                calendar: Self.calendar,
                today: Self.makeDate(year: 2026, month: 1, day: 12),
                spreads: [spread],
                tasks: [],
                notes: [],
                events: []
            ),
            overdueItems: [
                OverdueTaskItem(
                    task: task,
                    sourceKey: TaskReviewSourceKey(kind: .spread(id: spread.id, period: .day, date: spread.date))
                )
            ]
        )
        .items(for: .conventional(spread))

        let selectedID = SpreadHeaderNavigatorModel.Selection.conventional(spread).stableID(calendar: Self.calendar)
        let selectedItem = items.first(where: { $0.id == selectedID })
        #expect(selectedItem?.badge == .overdue(count: 1))
    }

    /// Setup: badge accessibility helpers format overdue and favorite badge metadata.
    /// Expected: labels are semantic and identifiers include badge kind plus normalized spread date and period.
    @Test func badgeAccessibilityLabelsAndIdentifiersAreSemantic() {
        let day = DataModel.Spread(
            period: .day,
            date: Self.makeDate(year: 2026, month: 3, day: 1),
            calendar: Self.calendar
        )
        let year = DataModel.Spread(
            period: .year,
            date: Self.makeDate(year: 2026, month: 1),
            calendar: Self.calendar
        )

        let overdue = SpreadTitleNavigatorBadge.overdue(count: 3)
        let favorite = SpreadTitleNavigatorBadge.favorite

        #expect(overdue.accessibilityLabel(style: .day) == "3 overdue tasks")
        #expect(overdue.accessibilityLabel(style: .multiday) == "3 overdue tasks in this date range")
        #expect(favorite.accessibilityLabel(style: .year) == "Favorited spread")
        #expect(
            overdue.accessibilityIdentifier(for: .conventional(day), calendar: Self.calendar) ==
                "overdue-2026-03-01-day"
        )
        #expect(
            favorite.accessibilityIdentifier(for: .conventional(year), calendar: Self.calendar) ==
                "favorite-2026-01-01-year"
        )
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

    private func stableID(for spread: DataModel.Spread) -> String {
        SpreadHeaderNavigatorModel.Selection.conventional(spread).stableID(calendar: Self.calendar)
    }
}
