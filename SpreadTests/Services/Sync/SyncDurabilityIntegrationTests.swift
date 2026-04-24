import struct Auth.User
import Foundation
import XCTest
@testable import Spread

@MainActor
final class SyncDurabilityIntegrationTests: XCTestCase {
    private var configuration: LocalSupabaseTestConfiguration!
    private var admin: LocalSupabaseAdmin!
    private let calendar = Calendar.current

    override func setUp() async throws {
        try await super.setUp()
        guard let configuration = try LocalSupabaseTestConfiguration.loadIfAvailable() else {
            throw XCTSkip("Local Supabase test environment not configured. Run ./scripts/local-supabase.sh reset first.")
        }

        do {
            try await configuration.assertReachable()
        } catch {
            throw XCTSkip("Local Supabase is not reachable. Start Docker and run ./scripts/local-supabase.sh start/reset.")
        }

        self.configuration = configuration
        self.admin = LocalSupabaseAdmin(configuration: configuration)
    }

    /// Setup: Create a task and note directly on an existing spread, sync them, wipe the local store,
    /// then rebuild from local Supabase using the same signed-in client.
    /// Expected: The task and note return on the same spread with the same active assignment IDs/statuses.
    func testDirectAssignmentDurabilitySurvivesLocalWipeAndRebuild() async throws {
        let harness = try await makeCleanHarness()
        let january = TestDataBuilders.makeDate(year: 2026, month: 1, day: 1, calendar: calendar)

        let monthSpread = try await harness.journalManager.addSpread(period: .month, date: january)
        let task = try await harness.journalManager.addTask(title: "Direct durability task", date: january, period: .month)
        let note = try await harness.journalManager.addNote(title: "Direct durability note", date: january, period: .month)
        let taskAssignmentID = try XCTUnwrap(task.assignments.first?.id)
        let noteAssignmentID = try XCTUnwrap(note.assignments.first?.id)

        await harness.syncAndReload()
        try await harness.wipeLocalAndRebuild()

        let rebuiltTask = try taskWithID(task.id, in: harness.journalManager)
        let rebuiltNote = try noteWithID(note.id, in: harness.journalManager)
        let rebuiltMonth = try spreadModel(period: .month, date: monthSpread.date, in: harness.journalManager)

        XCTAssertEqual(rebuiltTask.assignments.count, 1)
        XCTAssertEqual(rebuiltTask.assignments.first?.id, taskAssignmentID)
        XCTAssertEqual(rebuiltTask.assignments.first?.status, .open)
        XCTAssertEqual(rebuiltNote.assignments.count, 1)
        XCTAssertEqual(rebuiltNote.assignments.first?.id, noteAssignmentID)
        XCTAssertEqual(rebuiltNote.assignments.first?.status, .active)
        XCTAssertTrue(rebuiltMonth.tasks.contains { $0.id == task.id })
        XCTAssertTrue(rebuiltMonth.notes.contains { $0.id == note.id })
    }

    /// Setup: Create a task when no spread exists so it lands in Inbox, sync it, then rebuild a fresh client from server.
    /// Expected: The rebuilt client still shows the task in Inbox with no phantom assignment rows.
    func testInboxFallbackDurabilityRebuildsIntoInbox() async throws {
        let harness = try await makeCleanHarness()
        let day = TestDataBuilders.makeDate(year: 2026, month: 1, day: 10, calendar: calendar)

        let task = try await harness.journalManager.addTask(title: "Inbox durability task", date: day, period: .day)
        XCTAssertTrue(task.assignments.isEmpty)

        await harness.syncAndReload()
        let rebuilt = try await makeRebuiltHarness(from: harness)
        let rebuiltTask = try taskWithID(task.id, in: rebuilt.journalManager)

        XCTAssertTrue(rebuiltTask.assignments.isEmpty)
        XCTAssertTrue(rebuilt.journalManager.inboxEntries.contains { $0.id == task.id })
    }

    /// Setup: Create a personalized spread, one assigned metadata-rich task, and one true nil-assignment task;
    /// sync them, wipe local state, and rebuild from local Supabase.
    /// Expected: Approved WKFLW-17 fields and Inbox-first nil-assignment behavior survive the rebuild.
    func testWKFLW17MetadataDurabilitySurvivesLocalWipeAndRebuild() async throws {
        let harness = try await makeCleanHarness()
        let april = TestDataBuilders.makeDate(year: 2026, month: 4, day: 1, calendar: calendar)
        let dueDate = TestDataBuilders.makeDate(year: 2026, month: 4, day: 5, calendar: calendar)

        let spread = try await harness.journalManager.addSpread(
            period: .month,
            date: april,
            customName: "  Launch  ",
            usesDynamicName: false
        )
        try await harness.journalManager.updateSpreadFavorite(spread, isFavorite: true)
        let assignedTask = try await harness.journalManager.addTask(
            title: "Assigned WKFLW task",
            date: april,
            period: .month,
            hasPreferredAssignment: true,
            body: "Assigned body",
            priority: .high,
            dueDate: dueDate
        )
        let inboxTask = try await harness.journalManager.addTask(
            title: "Inbox WKFLW task",
            date: april,
            period: .month,
            hasPreferredAssignment: false,
            body: "Inbox body",
            priority: .medium,
            dueDate: dueDate
        )

        await harness.syncAndReload()
        try await harness.wipeLocalAndRebuild()

        let rebuiltSpread = try XCTUnwrap(harness.journalManager.spreads.first { $0.id == spread.id })
        let rebuiltAssignedTask = try taskWithID(assignedTask.id, in: harness.journalManager)
        let rebuiltInboxTask = try taskWithID(inboxTask.id, in: harness.journalManager)
        let rebuiltMonth = try spreadModel(period: .month, date: april, in: harness.journalManager)

        XCTAssertTrue(rebuiltSpread.isFavorite)
        XCTAssertEqual(rebuiltSpread.customName, "Launch")
        XCTAssertFalse(rebuiltSpread.usesDynamicName)
        XCTAssertEqual(rebuiltAssignedTask.body, "Assigned body")
        XCTAssertEqual(rebuiltAssignedTask.priority, .high)
        XCTAssertEqual(rebuiltAssignedTask.dueDate, dueDate)
        XCTAssertTrue(rebuiltAssignedTask.hasPreferredAssignment)
        XCTAssertEqual(rebuiltAssignedTask.assignments.first?.status, .open)
        XCTAssertTrue(rebuiltMonth.tasks.contains { $0.id == assignedTask.id })
        XCTAssertEqual(rebuiltInboxTask.body, "Inbox body")
        XCTAssertEqual(rebuiltInboxTask.priority, .medium)
        XCTAssertEqual(rebuiltInboxTask.dueDate, dueDate)
        XCTAssertFalse(rebuiltInboxTask.hasPreferredAssignment)
        XCTAssertTrue(rebuiltInboxTask.assignments.isEmpty)
        XCTAssertTrue(harness.journalManager.inboxEntries.contains { $0.id == inboxTask.id })
    }

    /// Setup: Create a task on a year spread, migrate it to a month spread, sync, then rebuild a clean second client.
    /// Expected: The destination spread stays active and the source spread still carries migrated-history visibility.
    func testMigrationDurabilityRebuildsDestinationAndSourceHistory() async throws {
        let harness = try await makeCleanHarness()
        let january = TestDataBuilders.makeDate(year: 2026, month: 1, day: 1, calendar: calendar)

        let yearSpread = try await harness.journalManager.addSpread(period: .year, date: january)
        let task = try await harness.journalManager.addTask(title: "Migration durability task", date: january, period: .month)
        let monthSpread = try await harness.journalManager.addSpread(period: .month, date: january)

        try await harness.journalManager.migrateTask(task, from: yearSpread, to: monthSpread)
        await harness.syncAndReload()

        let rebuilt = try await makeRebuiltHarness(from: harness)
        let rebuiltTask = try taskWithID(task.id, in: rebuilt.journalManager)
        let rebuiltMonth = try spreadModel(period: .month, date: monthSpread.date, in: rebuilt.journalManager)
        let rebuiltYear = try spreadModel(period: .year, date: yearSpread.date, in: rebuilt.journalManager)

        XCTAssertEqual(status(for: rebuiltTask, period: .year, date: yearSpread.date), .migrated)
        XCTAssertEqual(status(for: rebuiltTask, period: .month, date: monthSpread.date), .open)
        XCTAssertTrue(rebuiltMonth.tasks.contains { $0.id == task.id })
        XCTAssertTrue(rebuiltYear.tasks.contains { $0.id == task.id })
    }

    /// Setup: Reassign a task by editing its preferred date/period, sync it, then rebuild a clean second client.
    /// Expected: The second client reproduces the same active destination and source migrated-history state.
    func testReassignmentDurabilityRebuildsOnSecondClient() async throws {
        let harness = try await makeCleanHarness()
        let january = TestDataBuilders.makeDate(year: 2026, month: 1, day: 1, calendar: calendar)
        let januaryTenth = TestDataBuilders.makeDate(year: 2026, month: 1, day: 10, calendar: calendar)

        let monthSpread = try await harness.journalManager.addSpread(period: .month, date: january)
        let daySpread = try await harness.journalManager.addSpread(period: .day, date: januaryTenth)
        let task = try await harness.journalManager.addTask(title: "Reassignment durability task", date: january, period: .month)

        try await harness.journalManager.updateTaskDateAndPeriod(task, newDate: januaryTenth, newPeriod: .day)
        await harness.syncAndReload()

        let rebuilt = try await makeRebuiltHarness(from: harness)
        let rebuiltTask = try taskWithID(task.id, in: rebuilt.journalManager)
        let rebuiltMonth = try spreadModel(period: .month, date: monthSpread.date, in: rebuilt.journalManager)
        let rebuiltDay = try spreadModel(period: .day, date: daySpread.date, in: rebuilt.journalManager)

        XCTAssertEqual(status(for: rebuiltTask, period: .month, date: monthSpread.date), .migrated)
        XCTAssertEqual(status(for: rebuiltTask, period: .day, date: daySpread.date), .open)
        XCTAssertTrue(rebuiltMonth.tasks.contains { $0.id == task.id })
        XCTAssertTrue(rebuiltDay.tasks.contains { $0.id == task.id })
    }

    /// Setup: Delete a day spread that owns a task and note, sync, then rebuild from server.
    /// Expected: The reassigned month destinations and migrated source history for both entries survive the rebuild.
    func testSpreadDeletionDurabilityPreservesTaskAndNoteHistory() async throws {
        let harness = try await makeCleanHarness()
        let january = TestDataBuilders.makeDate(year: 2026, month: 1, day: 1, calendar: calendar)
        let januaryTenth = TestDataBuilders.makeDate(year: 2026, month: 1, day: 10, calendar: calendar)

        let monthSpread = try await harness.journalManager.addSpread(period: .month, date: january)
        let daySpread = try await harness.journalManager.addSpread(period: .day, date: januaryTenth)
        let task = try await harness.journalManager.addTask(title: "Deletion durability task", date: januaryTenth, period: .day)
        let note = try await harness.journalManager.addNote(title: "Deletion durability note", date: januaryTenth, period: .day)

        try await harness.journalManager.deleteSpread(daySpread)
        await harness.syncAndReload()

        let rebuilt = try await makeRebuiltHarness(from: harness)
        let rebuiltTask = try taskWithID(task.id, in: rebuilt.journalManager)
        let rebuiltNote = try noteWithID(note.id, in: rebuilt.journalManager)
        let rebuiltMonth = try spreadModel(period: .month, date: monthSpread.date, in: rebuilt.journalManager)
        let rebuiltTaskStatuses = rebuiltTask.assignments
            .map { "\($0.period.rawValue):\($0.status.rawValue)" }
            .sorted()
        let rebuiltNoteStatuses = rebuiltNote.assignments
            .map { "\($0.period.rawValue):\($0.status.rawValue)" }
            .sorted()

        XCTAssertFalse(rebuilt.journalManager.spreads.contains { $0.id == daySpread.id })
        XCTAssertEqual(rebuiltTaskStatuses, ["day:migrated", "month:open"])
        XCTAssertEqual(rebuiltNoteStatuses, ["day:migrated", "month:active"])
        XCTAssertTrue(rebuiltMonth.tasks.contains { $0.id == task.id })
        XCTAssertTrue(rebuiltMonth.notes.contains { $0.id == note.id })
    }

    /// Setup: Create and sync a task, delete it through the app flow, sync again, then rebuild a clean second client.
    /// Expected: The task and its assignment path stay deleted after rebuilding from server tombstones.
    func testAssignmentTombstoneDurabilityKeepsDeletedTaskGone() async throws {
        let harness = try await makeCleanHarness()
        let january = TestDataBuilders.makeDate(year: 2026, month: 1, day: 1, calendar: calendar)

        _ = try await harness.journalManager.addSpread(period: .month, date: january)
        let task = try await harness.journalManager.addTask(title: "Tombstone durability task", date: january, period: .month)
        await harness.syncAndReload()

        try await harness.journalManager.deleteTask(task)
        await harness.syncAndReload()

        let rebuilt = try await makeRebuiltHarness(from: harness)
        XCTAssertFalse(rebuilt.journalManager.tasks.contains { $0.id == task.id })
        XCTAssertFalse(rebuilt.journalManager.inboxEntries.contains { $0.id == task.id })
    }

    /// Setup: Sync a migrated task, delete its server assignment rows manually, trigger the automatic repair, then rebuild from server.
    /// Expected: The repair backfills the full assignment history once and the rebuilt client sees the same destination and source history.
    func testBackfillRecoveryRepairsMissingServerAssignmentRows() async throws {
        let harness = try await makeCleanHarness()
        let january = TestDataBuilders.makeDate(year: 2026, month: 1, day: 1, calendar: calendar)

        let yearSpread = try await harness.journalManager.addSpread(period: .year, date: january)
        let task = try await harness.journalManager.addTask(title: "Backfill durability task", date: january, period: .month)
        let monthSpread = try await harness.journalManager.addSpread(period: .month, date: january)

        try await harness.journalManager.migrateTask(task, from: yearSpread, to: monthSpread)
        await harness.syncAndReload()

        let user = try currentUser(in: harness)
        try await admin.deleteTaskAssignments(taskId: task.id, userId: user.id)
        let missingRows = try await admin.fetchTaskAssignments(taskId: task.id, userId: user.id)
        XCTAssertTrue(missingRows.isEmpty)

        await harness.syncAndReload()

        let repairedRows = try await admin.fetchTaskAssignments(taskId: task.id, userId: user.id)
        XCTAssertEqual(repairedRows.count, 2)

        let rebuilt = try await makeRebuiltHarness(from: harness)
        let rebuiltTask = try taskWithID(task.id, in: rebuilt.journalManager)

        XCTAssertEqual(status(for: rebuiltTask, period: .year, date: yearSpread.date), .migrated)
        XCTAssertEqual(status(for: rebuiltTask, period: .month, date: monthSpread.date), .open)
    }

    private func makeCleanHarness(email: String? = nil) async throws -> LocalSupabaseSyncHarness {
        let harness = try await LocalSupabaseSyncHarness.make(
            configuration: configuration,
            email: email ?? configuration.primaryEmail,
            calendar: calendar
        )
        let user = try await harness.signIn()
        try await admin.clearAllData(for: user.id)
        await harness.syncAndReload()
        return harness
    }

    private func makeRebuiltHarness(from source: LocalSupabaseSyncHarness) async throws -> LocalSupabaseSyncHarness {
        let rebuilt = try await LocalSupabaseSyncHarness.make(
            configuration: configuration,
            email: source.email,
            calendar: calendar
        )
        _ = try await rebuilt.signIn()
        await rebuilt.syncAndReload()
        return rebuilt
    }

    private func currentUser(in harness: LocalSupabaseSyncHarness) throws -> User {
        guard case .signedIn(let user) = harness.authManager.state else {
            throw XCTSkip("Expected a signed-in local Supabase user.")
        }
        return user
    }

    private func taskWithID(_ id: UUID, in manager: JournalManager) throws -> DataModel.Task {
        try XCTUnwrap(manager.tasks.first { $0.id == id })
    }

    private func noteWithID(_ id: UUID, in manager: JournalManager) throws -> DataModel.Note {
        try XCTUnwrap(manager.notes.first { $0.id == id })
    }

    private func spreadModel(period: Period, date: Date, in manager: JournalManager) throws -> SpreadDataModel {
        let normalizedDate = period.normalizeDate(date, calendar: calendar)
        return try XCTUnwrap(manager.dataModel[period]?[normalizedDate])
    }

    private func status(for task: DataModel.Task, period: Period, date: Date) -> DataModel.Task.Status? {
        task.assignments.first { assignment in
            assignment.matches(period: period, date: date, calendar: calendar)
        }?.status
    }

    private func noteStatus(for note: DataModel.Note, period: Period, date: Date) -> DataModel.Note.Status? {
        note.assignments.first { assignment in
            assignment.matches(period: period, date: date, calendar: calendar)
        }?.status
    }
}
