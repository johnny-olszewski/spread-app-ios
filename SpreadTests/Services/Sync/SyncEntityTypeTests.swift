import Testing
@testable import Spread

struct SyncEntityTypeTests {

    // MARK: - RPC Names

    /// Conditions: Each entity type.
    /// Expected: Should map to the correct merge RPC function name.
    @Test func testMergeRPCNames() {
        #expect(SyncEntityType.spread.mergeRPCName == "merge_spread")
        #expect(SyncEntityType.entry.mergeRPCName == "merge_entry")
        #expect(SyncEntityType.collection.mergeRPCName == "merge_collection")
        #expect(SyncEntityType.assignment.mergeRPCName == "merge_assignment")
        #expect(SyncEntityType.entryTag.mergeRPCName == "merge_entry_tag")
    }

    /// Conditions: Each entity type.
    /// Expected: Should map to the correct batch merge RPC function name.
    @Test func testMergeBatchRPCNames() {
        #expect(SyncEntityType.settings.mergeBatchRPCName == "merge_settings_batch")
        #expect(SyncEntityType.spread.mergeBatchRPCName == "merge_spread_batch")
        #expect(SyncEntityType.entry.mergeBatchRPCName == "merge_entry_batch")
        #expect(SyncEntityType.collection.mergeBatchRPCName == "merge_collection_batch")
        #expect(SyncEntityType.list.mergeBatchRPCName == "merge_list_batch")
        #expect(SyncEntityType.tag.mergeBatchRPCName == "merge_tag_batch")
        #expect(SyncEntityType.assignment.mergeBatchRPCName == "merge_assignment_batch")
        #expect(SyncEntityType.entryTag.mergeBatchRPCName == "merge_entry_tag_batch")
    }

    // MARK: - Raw Values (Table Names)

    /// Conditions: Each entity type.
    /// Expected: Raw values should match server table names.
    @Test func testRawValuesAreTableNames() {
        #expect(SyncEntityType.spread.rawValue == "spreads")
        #expect(SyncEntityType.entry.rawValue == "entries")
        #expect(SyncEntityType.assignment.rawValue == "assignments")
        #expect(SyncEntityType.entryTag.rawValue == "entry_tags")
    }

    // MARK: - Sync Ordering

    /// Conditions: Ordered list of entity types.
    /// Expected: Spreads should come first, then standalone entities, then assignments.
    @Test func testOrderedParentsFirst() {
        let ordered = SyncEntityType.ordered

        let spreadIndex = ordered.firstIndex(of: .spread)!
        let entryIndex = ordered.firstIndex(of: .entry)!
        let assignmentIndex = ordered.firstIndex(of: .assignment)!

        #expect(spreadIndex < entryIndex)
        #expect(entryIndex < assignmentIndex)
    }

    /// Conditions: All entity types.
    /// Expected: ordered should contain all cases.
    @Test func testOrderedContainsAllCases() {
        #expect(SyncEntityType.ordered.count == SyncEntityType.allCases.count)
    }

    /// Conditions: Standalone entities (entry, collection).
    /// Expected: Should all have the same sync order.
    @Test func testStandaloneEntitiesShareOrder() {
        #expect(SyncEntityType.entry.syncOrder == SyncEntityType.collection.syncOrder)
    }

    /// Conditions: Assignment and entry-tag entities.
    /// Expected: Should all have the same sync order, higher than standalone.
    @Test func testAssignmentsShareOrderAfterStandalone() {
        #expect(SyncEntityType.assignment.syncOrder == SyncEntityType.entryTag.syncOrder)
        #expect(SyncEntityType.assignment.syncOrder > SyncEntityType.entry.syncOrder)
    }
}
