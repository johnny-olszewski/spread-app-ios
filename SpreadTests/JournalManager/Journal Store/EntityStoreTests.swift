import Foundation
import Testing
@testable import Spread

struct EntityStoreTests {
    private static func makeTask(title: String = "Task") -> DataModel.Task {
        DataModel.Task(title: title, date: nil, period: nil)
    }

    /// Setup: an empty store has a task upserted.
    /// Expected: the task is retrievable by ID and counted.
    @Test func testUpsertInsertsNewEntity() {
        var store = EntityStore<DataModel.Task>(idKeyPath: \.id)
        let task = Self.makeTask()

        let previous = store.upsert(task)

        #expect(previous == nil)
        #expect(store.count == 1)
        #expect(store[task.id]?.id == task.id)
    }

    /// Setup: a store already containing a task is upserted again with the same ID.
    /// Expected: the previous value is returned and the store still has exactly one entry.
    @Test func testUpsertReplacesExistingEntityWithSameID() {
        var store = EntityStore<DataModel.Task>(idKeyPath: \.id)
        let task = Self.makeTask(title: "Original")
        store.upsert(task)

        task.title = "Updated"
        let previous = store.upsert(task)

        #expect(previous?.title == "Updated")
        #expect(store.count == 1)
        #expect(store[task.id]?.title == "Updated")
    }

    /// Setup: a store with two tasks has one removed by ID.
    /// Expected: only the removed task is gone; the other remains.
    @Test func testRemoveDeletesEntityByID() {
        var store = EntityStore<DataModel.Task>(idKeyPath: \.id)
        let keep = Self.makeTask(title: "Keep")
        let remove = Self.makeTask(title: "Remove")
        store.upsert(keep)
        store.upsert(remove)

        let removed = store.remove(id: remove.id)

        #expect(removed?.id == remove.id)
        #expect(store.count == 1)
        #expect(store[keep.id] != nil)
        #expect(store[remove.id] == nil)
    }

    /// Setup: removing an ID that was never inserted.
    /// Expected: returns `nil`, no crash, store unaffected.
    @Test func testRemoveNonexistentIDReturnsNil() {
        var store = EntityStore<DataModel.Task>(idKeyPath: \.id)
        store.upsert(Self.makeTask())

        let removed = store.remove(id: UUID())

        #expect(removed == nil)
        #expect(store.count == 1)
    }

    /// Setup: a store is constructed directly from an array of entities (cold-load path).
    /// Expected: all entities are present and individually retrievable.
    @Test func testInitFromArrayPopulatesAllEntities() {
        let tasks = [Self.makeTask(title: "A"), Self.makeTask(title: "B"), Self.makeTask(title: "C")]
        let store = EntityStore(tasks, idKeyPath: \.id)

        #expect(store.count == 3)
        for task in tasks {
            #expect(store[task.id]?.id == task.id)
        }
    }

    /// Setup: a populated store has `replaceAll` called with a different set of entities.
    /// Expected: the store's contents are entirely replaced, not merged.
    @Test func testReplaceAllOverwritesExistingContents() {
        var store = EntityStore<DataModel.Task>(idKeyPath: \.id)
        let stale = Self.makeTask(title: "Stale")
        store.upsert(stale)

        let fresh = [Self.makeTask(title: "Fresh1"), Self.makeTask(title: "Fresh2")]
        store.replaceAll(fresh)

        #expect(store.count == 2)
        #expect(store[stale.id] == nil)
        for task in fresh {
            #expect(store[task.id] != nil)
        }
    }
}
