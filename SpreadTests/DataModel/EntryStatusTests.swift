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

    /// Conditions: a full walk of the real product tap-cycle, `EntryStatus.userEditableTaskStatuses`
    /// ([.open, .inFlight, .complete, .cancelled]), rotating one status at a time.
    /// Expected: `.open` rotates to `.inFlight`, `.inFlight` rotates to `.complete`, `.complete`
    /// rotates to `.cancelled`, and `.cancelled` wraps back around to `.open`.
    @Test func userEditableTaskStatusesFullCycleWalk() {
        let cycle = EntryStatus.userEditableTaskStatuses
        #expect(EntryStatus.open.rotate(in: cycle) == .inFlight)
        #expect(EntryStatus.inFlight.rotate(in: cycle) == .complete)
        #expect(EntryStatus.complete.rotate(in: cycle) == .cancelled)
        #expect(EntryStatus.cancelled.rotate(in: cycle) == .open)
    }
}
