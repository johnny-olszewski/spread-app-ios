import Foundation
import Testing
@testable import Spread

@MainActor
struct YearSpreadContentSupportTests {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 1
        return calendar
    }

    private static func makeDate(year: Int, month: Int, day: Int = 1) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func modelSeparatesYearEntriesFromMonthCardsAndAddsDayLabels() throws {
        let yearDate = Self.makeDate(year: 2026, month: 1)
        let yearSpread = DataModel.Spread(period: .year, date: yearDate, calendar: Self.calendar)

        var spreadDataModel = SpreadDataModel(spread: yearSpread)
        let yearTask = DataModel.Task(title: "Year Task", date: yearDate, period: .year)
        let monthTask = DataModel.Task(title: "January Month Task", date: yearDate, period: .month)
        let dayNote = DataModel.Note(
            title: "January Day Note",
            date: Self.makeDate(year: 2026, month: 1, day: 18),
            period: .day
        )
        let marchTask = DataModel.Task(
            title: "March Day Task",
            date: Self.makeDate(year: 2026, month: 3, day: 7),
            period: .day
        )

        spreadDataModel.tasks = [yearTask, monthTask, marchTask]
        spreadDataModel.notes = [dayNote]

        let model = YearSpreadContentSupport.model(
            for: yearSpread,
            spreadDataModel: spreadDataModel,
            spreads: [],
            today: Self.makeDate(year: 2026, month: 5, day: 1),
            calendar: Self.calendar
        )

        #expect(model.yearEntries.map(\.title) == ["Year Task"])

        let januaryCard = try #require(model.monthCards.first { Self.calendar.component(.month, from: $0.monthDate) == 1 })
        #expect(januaryCard.previews.map { $0.entry.title } == ["January Month Task", "January Day Note"])
        #expect(januaryCard.previews.last?.contextualLabel == "18")

        let marchCard = try #require(model.monthCards.first { Self.calendar.component(.month, from: $0.monthDate) == 3 })
        #expect(marchCard.previews.map { $0.entry.title } == ["March Day Task"])
        #expect(marchCard.previews.first?.contextualLabel == "7")
    }

    @Test func monthCardVisualStateDistinguishesCreatedMissingAndCurrentMonth() {
        let januaryDate = Self.makeDate(year: 2026, month: 1)
        let februaryDate = Self.makeDate(year: 2026, month: 2)
        let januarySpread = DataModel.Spread(period: .month, date: januaryDate, calendar: Self.calendar)

        let januaryCard = YearSpreadContentSupport.monthCard(
            for: januaryDate,
            entries: [],
            spreads: [januarySpread],
            today: Self.makeDate(year: 2026, month: 1, day: 15),
            calendar: Self.calendar
        )
        let februaryCard = YearSpreadContentSupport.monthCard(
            for: februaryDate,
            entries: [],
            spreads: [januarySpread],
            today: Self.makeDate(year: 2026, month: 1, day: 15),
            calendar: Self.calendar
        )

        #expect(januaryCard.visualState == .todayCreated)
        #expect(februaryCard.visualState == .uncreated)
    }

    @Test func monthCardActionUsesViewWhenMonthSpreadExistsOtherwiseCreate() {
        let januaryDate = Self.makeDate(year: 2026, month: 1)
        let januarySpread = DataModel.Spread(period: .month, date: januaryDate, calendar: Self.calendar)

        let createdCard = YearSpreadContentSupport.monthCard(
            for: januaryDate,
            entries: [],
            spreads: [januarySpread],
            today: Self.makeDate(year: 2026, month: 4, day: 1),
            calendar: Self.calendar
        )
        let missingCard = YearSpreadContentSupport.monthCard(
            for: Self.makeDate(year: 2026, month: 2),
            entries: [],
            spreads: [januarySpread],
            today: Self.makeDate(year: 2026, month: 4, day: 1),
            calendar: Self.calendar
        )

        #expect(createdCard.action == .view(januarySpread))
        #expect(missingCard.action == .create(Self.makeDate(year: 2026, month: 2)))
    }

    @Test func monthCardLimitsDensePreviewsAndTracksOverflow() {
        let januaryDate = Self.makeDate(year: 2026, month: 1)
        let entries: [any Entry] = [
            DataModel.Task(title: "One", date: Self.makeDate(year: 2026, month: 1, day: 1), period: .day),
            DataModel.Task(title: "Two", date: Self.makeDate(year: 2026, month: 1, day: 2), period: .day),
            DataModel.Task(title: "Three", date: Self.makeDate(year: 2026, month: 1, day: 3), period: .day),
            DataModel.Task(title: "Four", date: Self.makeDate(year: 2026, month: 1, day: 4), period: .day),
            DataModel.Note(title: "Five", date: Self.makeDate(year: 2026, month: 1, day: 5), period: .day),
        ]

        let card = YearSpreadContentSupport.monthCard(
            for: januaryDate,
            entries: entries,
            spreads: [],
            today: Self.makeDate(year: 2026, month: 4, day: 1),
            calendar: Self.calendar
        )

        #expect(card.previews.map { $0.entry.title } == ["One", "Two", "Three"])
        #expect(card.overflowCount == 2)
    }

    @Test func migratedHistoryRowsAreAbsentWhileCurrentYearAssignmentsAppearInCorrectCards() async throws {
        let yearDate = Self.makeDate(year: 2026, month: 1)
        let yearSpread = DataModel.Spread(period: .year, date: yearDate, calendar: Self.calendar)
        let monthSpread = DataModel.Spread(period: .month, date: yearDate, calendar: Self.calendar)

        let currentYearTask = DataModel.Task(
            title: "Current Year Task",
            date: Self.makeDate(year: 2026, month: 1, day: 12),
            period: .day,
            assignments: [TaskAssignment(period: .year, date: yearDate, status: .open)]
        )
        let migratedHistoryTask = DataModel.Task(
            title: "Migrated Away",
            date: Self.makeDate(year: 2026, month: 1, day: 13),
            period: .day,
            assignments: [
                TaskAssignment(period: .year, date: yearDate, status: .migrated),
                TaskAssignment(period: .month, date: yearDate, status: .open)
            ]
        )

        let manager = try await JournalManager.make(
            calendar: Self.calendar,
            today: Self.makeDate(year: 2026, month: 1, day: 15),
            taskRepository: InMemoryTaskRepository(tasks: [currentYearTask, migratedHistoryTask]),
            spreadRepository: InMemorySpreadRepository(spreads: [yearSpread, monthSpread]),
            bujoMode: .conventional
        )

        let dataModel = try #require(manager.dataModel[.year]?[Period.year.normalizeDate(yearDate, calendar: Self.calendar)])
        let contentModel = YearSpreadContentSupport.model(
            for: yearSpread,
            spreadDataModel: dataModel,
            spreads: manager.spreads,
            today: manager.today,
            calendar: Self.calendar
        )

        let januaryCard = try #require(contentModel.monthCards.first { Self.calendar.component(.month, from: $0.monthDate) == 1 })
        #expect(januaryCard.previews.map { $0.entry.title } == ["Current Year Task"])
    }
}
