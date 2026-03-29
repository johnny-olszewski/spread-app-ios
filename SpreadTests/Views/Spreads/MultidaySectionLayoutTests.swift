import SwiftUI
import Testing
@testable import Spread

struct MultidaySectionLayoutTests {

    @Test("Compact width uses one multiday column")
    func compactWidthUsesOneColumn() {
        #expect(MultidaySectionLayout.columnCount(for: .compact) == 1)
    }

    @Test("Regular width uses two multiday columns")
    func regularWidthUsesTwoColumns() {
        #expect(MultidaySectionLayout.columnCount(for: .regular) == 2)
    }

    @Test("Unknown size class falls back to one multiday column")
    func unknownWidthFallsBackToOneColumn() {
        #expect(MultidaySectionLayout.columnCount(for: nil) == 1)
    }
}
