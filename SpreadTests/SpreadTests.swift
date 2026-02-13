import Testing
@testable import Spread

@MainActor
struct SpreadTests {

    /// Conditions: Create a testing AppDependencies and instantiate ContentView with it.
    /// Expected: ContentView should successfully instantiate and have a non-nil body.
    @Test func testContentViewInstantiates() throws {
        let dependencies = try AppDependencies.make()
        let view = ContentView(dependencies: dependencies)
        #expect(view.body != nil)
    }
}
