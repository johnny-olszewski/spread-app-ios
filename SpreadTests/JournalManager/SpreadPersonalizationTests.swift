import Foundation
import Testing
@testable import Spread

@MainActor
struct SpreadPersonalizationTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func creatingSpreadStoresSanitizedNameAndDynamicFlag() async throws {
        let manager = try await JournalManager.make(
            calendar: calendar,
            today: date(2026, 4, 18)
        )

        let spread = try await manager.addSpread(
            period: .day,
            date: date(2026, 4, 18),
            customName: "  Launch  ",
            usesDynamicName: false
        )

        #expect(spread.customName == "Launch")
        #expect(!spread.usesDynamicName)
    }

    @Test func updatingFavoritePersistsFlagAndTimestamp() async throws {
        let manager = try await JournalManager.make(
            calendar: calendar,
            today: date(2026, 4, 18)
        )
        let spread = try await manager.addSpread(period: .month, date: date(2026, 4, 1))

        try await manager.updateSpreadFavorite(spread, isFavorite: true)

        let updated = try #require(manager.spreads.first { $0.id == spread.id })
        #expect(updated.isFavorite)
        #expect(updated.isFavoriteUpdatedAt != nil)
    }

    @Test func updatingNameTrimsClearsAndTimestampsIndependentFields() async throws {
        let manager = try await JournalManager.make(
            calendar: calendar,
            today: date(2026, 4, 18)
        )
        let spread = try await manager.addSpread(
            period: .day,
            date: date(2026, 4, 18),
            customName: "Plan",
            usesDynamicName: true
        )

        try await manager.updateSpreadName(
            spread,
            customName: "   ",
            usesDynamicName: false
        )

        let updated = try #require(manager.spreads.first { $0.id == spread.id })
        #expect(updated.customName == nil)
        #expect(!updated.usesDynamicName)
        #expect(updated.customNameUpdatedAt != nil)
        #expect(updated.usesDynamicNameUpdatedAt != nil)
    }

    /// Conditions: A personalized favorite multiday spread is moved to a new range.
    /// Expected: The same spread ID is updated with date timestamps while name/dynamic/favorite metadata is preserved.
    @Test func updatingMultidayDatesPreservesIdentityAndPersonalization() async throws {
        let manager = try await JournalManager.make(
            calendar: calendar,
            today: date(2026, 4, 18)
        )
        let spread = try await manager.addMultidaySpread(
            startDate: date(2026, 4, 19),
            endDate: date(2026, 4, 25),
            customName: "Launch Window",
            usesDynamicName: false
        )
        try await manager.updateSpreadFavorite(spread, isFavorite: true)

        let updated = try await manager.updateMultidaySpreadDates(
            spread,
            startDate: date(2026, 5, 3),
            endDate: date(2026, 5, 9)
        )

        #expect(updated.id == spread.id)
        #expect(updated.date == date(2026, 5, 3))
        #expect(updated.startDate == date(2026, 5, 3))
        #expect(updated.endDate == date(2026, 5, 9))
        #expect(updated.customName == "Launch Window")
        #expect(!updated.usesDynamicName)
        #expect(updated.isFavorite)
        #expect(updated.dateUpdatedAt != nil)
        #expect(updated.startDateUpdatedAt != nil)
        #expect(updated.endDateUpdatedAt != nil)

        let cached = try #require(manager.spreads.first { $0.id == spread.id })
        #expect(cached.id == spread.id)
        #expect(cached.startDate == date(2026, 5, 3))
    }
}
