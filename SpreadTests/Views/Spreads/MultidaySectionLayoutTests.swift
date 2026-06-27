import SwiftUI
import Testing
@testable import Spread

struct MultidaySectionLayoutTests {

    @Test("Compact width uses one multiday column")
    func compactWidthUsesOneColumn() {
        #expect(UserInterfaceSizeClass.compact.multidayColumnCount == 1)
    }

    @Test("Regular width uses two multiday columns")
    func regularWidthUsesTwoColumns() {
        #expect(UserInterfaceSizeClass.regular.multidayColumnCount == 2)
    }

    @Test("Unknown size class falls back to one multiday column")
    func unknownWidthFallsBackToOneColumn() {
        let sizeClass: UserInterfaceSizeClass? = nil
        #expect(sizeClass?.multidayColumnCount ?? 1 == 1)
    }
}
