import Testing
@testable import Spread

struct SpreadTests {

    @Test func testContentViewInstantiates() throws {
        let container = try DependencyContainer.makeForTesting()
        let view = ContentView(container: container)
        #expect(view.body != nil)
    }
}
