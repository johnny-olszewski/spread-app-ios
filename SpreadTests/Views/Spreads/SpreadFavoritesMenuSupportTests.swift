import Foundation
import Testing
@testable import Spread

struct SpreadFavoritesMenuSupportTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int = 1) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// Conditions: Conventional navigator items are built for a selected 2026 spread while another 2027
    /// spread is favorite.
    /// Expected: Favorites support returns only favorite items present in the selected year's item set.
    @Test func favoritesAreScopedToCurrentConventionalYearItems() {
        let april2026 = DataModel.Spread(
            period: .month,
            date: date(2026, 4),
            calendar: calendar,
            isFavorite: true
        )
        let april2027 = DataModel.Spread(
            period: .month,
            date: date(2027, 4),
            calendar: calendar,
            isFavorite: true
        )
        let model = SpreadHeaderNavigatorModel(
            mode: .conventional,
            calendar: calendar,
            today: date(2026, 4, 6),
            spreads: [april2026, april2027],
            tasks: [],
            notes: [],
            events: []
        )
        let items = SpreadTitleNavigatorModel(headerModel: model)
            .items(for: .conventional(april2026))

        let favorites = SpreadFavoritesMenuSupport.favoriteItemsForCurrentYear(
            mode: .conventional,
            items: items
        )

        let expectedFavoriteID = SpreadHeaderNavigatorModel.Selection.conventional(april2026)
            .stableID(calendar: calendar)

        #expect(favorites.count == 1)
        #expect(favorites.first?.id == expectedFavoriteID)
    }

    /// Conditions: A favorite spread exists but the app is in traditional mode.
    /// Expected: Favorites support returns no items, matching the hidden traditional-mode menu contract.
    @Test func favoritesAreHiddenInTraditionalMode() {
        let spread = DataModel.Spread(
            period: .month,
            date: date(2026, 4),
            calendar: calendar,
            isFavorite: true
        )
        let item = SpreadTitleNavigatorModel.Item(
            id: "favorite",
            label: "Favorite",
            selection: .conventional(spread),
            style: .month,
            display: .init(top: nil, bottom: "Favorite", footer: nil),
            badge: .favorite
        )

        let favorites = SpreadFavoritesMenuSupport.favoriteItemsForCurrentYear(
            mode: .traditional,
            items: [item]
        )

        #expect(favorites.isEmpty)
    }

    /// Conditions: A favorited spread has been removed from the navigator item set after normal spread deletion.
    /// Expected: Favorites support no longer returns that favorite shortcut.
    @Test @MainActor func deletedFavoritedSpreadDropsOutOfFavoritesMenu() async throws {
        let year = DataModel.Spread(
            period: .year,
            date: date(2026, 1),
            calendar: calendar
        )
        let favoriteMonth = DataModel.Spread(
            period: .month,
            date: date(2026, 4),
            calendar: calendar,
            isFavorite: true
        )
        let manager = try await JournalManager.make(
            calendar: calendar,
            today: date(2026, 4, 15),
            spreadRepository: InMemorySpreadRepository(spreads: [year, favoriteMonth])
        )

        try await manager.deleteSpread(favoriteMonth)
        let items = manager.titleNavigatorModel.items(for: .conventional(year))
        let favorites = SpreadFavoritesMenuSupport.favoriteItemsForCurrentYear(
            mode: manager.bujoMode,
            items: items
        )

        #expect(manager.spreads.allSatisfy { $0.id != favoriteMonth.id })
        #expect(favorites.isEmpty)
    }
}
