import Testing
@testable import Spread

struct SpreadTests {

    @Test func testContentViewInstantiates() {
        let view = ContentView()
        #expect(view.body != nil)
    }
}
