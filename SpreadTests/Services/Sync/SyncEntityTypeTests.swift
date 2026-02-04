import Testing
@testable import Spread

struct SyncEntityTypeTests {

    // MARK: - RPC Names

    /// Conditions: Each entity type.
    /// Expected: Should map to the correct merge RPC function name.
    @Test func testMergeRPCNames() {
        #expect(SyncEntityType.spread.mergeRPCName == "merge_spread")
        #expect(SyncEntityType.task.mergeRPCName == "merge_task")
        #expect(SyncEntityType.note.mergeRPCName == "merge_note")
        #expect(SyncEntityType.collection.mergeRPCName == "merge_collection")
        #expect(SyncEntityType.taskAssignment.mergeRPCName == "merge_task_assignment")
        #expect(SyncEntityType.noteAssignment.mergeRPCName == "merge_note_assignment")
    }

    // MARK: - Raw Values (Table Names)

    /// Conditions: Each entity type.
    /// Expected: Raw values should match server table names.
    @Test func testRawValuesAreTableNames() {
        #expect(SyncEntityType.spread.rawValue == "spreads")
        #expect(SyncEntityType.task.rawValue == "tasks")
        #expect(SyncEntityType.taskAssignment.rawValue == "task_assignments")
    }

    // MARK: - Sync Ordering

    /// Conditions: Ordered list of entity types.
    /// Expected: Spreads should come first, then standalone entities, then assignments.
    @Test func testOrderedParentsFirst() {
        let ordered = SyncEntityType.ordered

        let spreadIndex = ordered.firstIndex(of: .spread)!
        let taskIndex = ordered.firstIndex(of: .task)!
        let taskAssignmentIndex = ordered.firstIndex(of: .taskAssignment)!

        #expect(spreadIndex < taskIndex)
        #expect(taskIndex < taskAssignmentIndex)
    }

    /// Conditions: All entity types.
    /// Expected: ordered should contain all cases.
    @Test func testOrderedContainsAllCases() {
        #expect(SyncEntityType.ordered.count == SyncEntityType.allCases.count)
    }

    /// Conditions: Standalone entities (task, note, collection).
    /// Expected: Should all have the same sync order.
    @Test func testStandaloneEntitiesShareOrder() {
        #expect(SyncEntityType.task.syncOrder == SyncEntityType.note.syncOrder)
        #expect(SyncEntityType.task.syncOrder == SyncEntityType.collection.syncOrder)
    }

    /// Conditions: Assignment entities.
    /// Expected: Should all have the same sync order, higher than standalone.
    @Test func testAssignmentsShareOrderAfterStandalone() {
        #expect(SyncEntityType.taskAssignment.syncOrder == SyncEntityType.noteAssignment.syncOrder)
        #expect(SyncEntityType.taskAssignment.syncOrder > SyncEntityType.task.syncOrder)
    }
}
