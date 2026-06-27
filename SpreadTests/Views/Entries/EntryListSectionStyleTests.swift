import Foundation
import SwiftUI
import Testing
@testable import Spread

/// Tests for `EntryList.Section.style` property and `EntryList.SectionStyle` enum.
@Suite("EntryList Section Style Tests")
struct EntryListSectionStyleTests {

    private let today = Date()

    // `style` defaults to `nil` when not provided to the initializer.
    // Expected: the section's `style` property is `nil`.
    @Test func testSectionStyleDefaultsToNil() {
        let section = EntryList.Section(
            id: "test",
            title: "Test",
            date: today,
            entries: [],
            creationPeriod: .day,
            creationDate: today
        )
        #expect(section.style == nil)
    }

    // `style` is stored correctly when `.card(Color)` is passed to the initializer.
    // Expected: the section's `style` is `.card` with the supplied color.
    @Test func testSectionStyleCardIsStored() {
        let section = EntryList.Section(
            id: "test",
            title: "Overdue",
            date: today,
            entries: [],
            creationPeriod: .day,
            creationDate: today,
            style: .card(.orange)
        )
        guard case .card(let color) = section.style else {
            Issue.record("Expected .card style, got \(String(describing: section.style))")
            return
        }
        #expect(color == .orange)
    }
}
