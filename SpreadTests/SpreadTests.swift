import Testing
@testable import Spread

struct SpreadTests {

    @Test func testContentViewInstantiates() {
        let container = DependencyContainer.makeForTesting()
        let view = ContentView(container: container)
        #expect(view.body != nil)
    }
}
