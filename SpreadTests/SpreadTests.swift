import Testing
@testable import Spread

struct SpreadTests {

    /// Conditions: Create a testing DependencyContainer and instantiate ContentView with it.
    /// Expected: ContentView should successfully instantiate and have a non-nil body.
    @Test func testContentViewInstantiates() throws {
        let container = try DependencyContainer.makeForTesting()
        let view = ContentView(container: container)
        #expect(view.body != nil)
    }
}
