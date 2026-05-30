import Foundation
import Testing
@testable import Spread

struct EntryStatusTests {
    
    // MARK: - Test Helpers
    
    private var taskOptions: [EntryStatus] = [.open, .complete, .cancelled]
    
    @Test func testEmptyOptions() {
        let sut = EntryStatus.open
        #expect(sut.rotate(in: []) == .open)
    }
    
    @Test func testNotInOptions() {
        let sut = EntryStatus.open
        let options: [EntryStatus] = [.complete, .cancelled]
        #expect(sut.rotate(in: options) == .complete)
    }
    
    @Test func testSelfIsLast() {
        let sut = EntryStatus.cancelled
        #expect(sut.rotate(in: taskOptions) == .open)
    }
    
    @Test func testReturnNext() {
        let sut = EntryStatus.open
        #expect(sut.rotate(in: taskOptions) == .complete)
    }
}
