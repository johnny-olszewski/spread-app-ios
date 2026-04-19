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
}
