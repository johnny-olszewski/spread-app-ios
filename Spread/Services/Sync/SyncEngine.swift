import Foundation
import Observation
import os
import Supabase
import SwiftData
import UIKit

/// Offline-first sync engine with outbox push and incremental pull.
///
/// The engine coordinates:
/// - **Push**: Dequeues local mutations from the outbox and calls merge RPCs
///   in parent-first order (spreads → entities → assignments).
/// - **Pull**: Incrementally fetches server changes per table using revision
///   cursors, then applies them to local SwiftData models.
/// - **Scheduling**: Auto-syncs on launch, foreground, and connectivity changes.
///   Manual sync via `syncNow()`. Exponential backoff on failure.
/// - **Status**: Observable sync state for UI display.
///
/// When `DataEnvironment.current.isLocalOnly` is true, sync is fully disabled
/// and the engine shows `.localOnly` status.
@Observable
@MainActor
final class SyncEngine {

    // MARK: - Observable State

    /// The current sync status.
    /// Settable by `AuthLifecycleCoordinator` for entitlement gating.
    var status: SyncStatus = .idle

    /// The date of the last successful sync.
    private(set) var lastSyncDate: Date?

    /// The number of pending outbox mutations.
    private(set) var outboxCount: Int = 0

    /// The sync event log.
    let syncLog = SyncLog()

    // MARK: - Dependencies

    private let client: SupabaseClient?
    private let modelContainer: ModelContainer
    private let authManager: AuthManager
    private let networkMonitor: any NetworkMonitoring
    private let deviceId: UUID
    private let isSyncEnabled: Bool
    let policy: SyncPolicy

    // MARK: - Private State

    private let logger = Logger(subsystem: "dev.johnnyo.Spread", category: "SyncEngine")
    private var consecutiveFailures = 0
    private var syncTask: Task<Void, Never>?
    private var foregroundObserver: Any?

    // MARK: - Constants

    private enum Constants {
        static let baseBackoffSeconds: TimeInterval = 2
        static let maxBackoffSeconds: TimeInterval = 300
        static let pullPageSize = 100
    }

    // MARK: - Initialization

    /// Creates a sync engine with the required dependencies.
    ///
    /// - Parameters:
    ///   - client: The Supabase client for network operations (nil for localhost).
    ///   - modelContainer: The SwiftData container for local persistence.
    ///   - authManager: The auth manager to check sign-in state.
    ///   - networkMonitor: The network connectivity monitor (any NetworkMonitoring).
    ///   - deviceId: The unique device identifier.
    ///   - isSyncEnabled: Whether sync is enabled for the current data environment.
    ///   - policy: Policy overrides for sync behavior.
    init(
        client: SupabaseClient?,
        modelContainer: ModelContainer,
        authManager: AuthManager,
        networkMonitor: any NetworkMonitoring,
        deviceId: UUID,
        isSyncEnabled: Bool,
        policy: SyncPolicy = DefaultSyncPolicy()
    ) {
        self.client = client
        self.modelContainer = modelContainer
        self.authManager = authManager
        self.networkMonitor = networkMonitor
        self.deviceId = deviceId
        self.isSyncEnabled = isSyncEnabled
        self.policy = policy

        if !isSyncEnabled {
            self.status = .localOnly
        }
    }

    // MARK: - Auto Sync Lifecycle

    /// Starts automatic sync scheduling.
    ///
    /// Registers for foreground notifications and triggers an initial sync.
    /// In localhost mode, this is a no-op since sync is disabled.
    func startAutoSync() {
        guard isSyncEnabled else {
            logger.info("Auto sync not started (sync disabled)")
            syncLog.info("Sync disabled (local only)")
            return
        }

        if authManager.state.isSignedIn && !authManager.hasBackupEntitlement {
            status = .backupUnavailable
            logger.info("Auto sync not started (no backup entitlement)")
            syncLog.warning("Backup unavailable")
            return
        }

        logger.info("Auto sync started")
        syncLog.info("Auto sync started")

        networkMonitor.onConnectionChange = { [weak self] isConnected in
            guard let self else { return }
            if isConnected {
                Task { @MainActor in
                    await self.syncNow()
                }
            } else if self.status != .syncing {
                self.status = .offline
                self.syncLog.warning("Sync paused: offline")
            }
        }

        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.logger.info("Foreground detected, triggering sync")
                await self?.syncNow()
            }
        }

        Task { [weak self] in
            await self?.syncNow()
        }
    }

    /// Stops automatic sync scheduling and cancels any in-progress sync.
    func stopAutoSync() {
        logger.info("Auto sync stopped")
        syncLog.info("Auto sync stopped")

        syncTask?.cancel()
        syncTask = nil

        if let foregroundObserver {
            NotificationCenter.default.removeObserver(foregroundObserver)
        }
        foregroundObserver = nil
        networkMonitor.onConnectionChange = nil
    }

    // MARK: - Manual Sync

    /// Triggers a sync immediately if conditions allow.
    ///
    /// No-op if sync is disabled, a sync is already in progress,
    /// the device is offline, or the user is not signed in.
    func syncNow() async {
        guard isSyncEnabled else {
            logger.debug("Sync disabled")
            return
        }

        guard policy.shouldAllowSync() else {
            logger.debug("Sync blocked by policy")
            return
        }

        guard status != .syncing else {
            logger.debug("Sync already in progress, skipping")
            return
        }

        guard networkMonitor.isConnected else {
            status = .offline
            syncLog.warning("Sync skipped: offline")
            return
        }

        guard authManager.state.isSignedIn else {
            logger.debug("Sync skipped: not signed in")
            return
        }

        guard authManager.hasBackupEntitlement else {
            status = .backupUnavailable
            logger.debug("Sync skipped: no backup entitlement")
            syncLog.warning("Backup unavailable")
            return
        }

        if let forcedDuration = policy.forceSyncingDuration() {
            await simulateSync(duration: forcedDuration)
            return
        }

        if policy.forceSyncFailure() {
            let message = "Sync failed. Will retry."
            status = .error(message)
            syncLog.error("Sync failed (forced)")
            consecutiveFailures += 1
            scheduleRetry()
            return
        }

        await performSync()
    }

    // MARK: - Outbox Management

    /// Enqueues a sync mutation in the outbox.
    ///
    /// Called by repositories after local writes to record changes
    /// that need to be pushed to the server.
    func enqueueMutation(
        entityType: SyncEntityType,
        entityId: UUID,
        operation: SyncOperation,
        recordData: Data,
        changedFields: [String] = []
    ) {
        let context = modelContainer.mainContext
        let mutation = DataModel.SyncMutation(
            entityType: entityType.rawValue,
            entityId: entityId,
            operation: operation.rawValue,
            recordData: recordData,
            changedFields: changedFields
        )
        context.insert(mutation)
        do {
            try context.save()
            outboxCount += 1
            logger.debug("Enqueued \(operation.rawValue) for \(entityType.rawValue) \(entityId)")
        } catch {
            logger.error("Failed to enqueue mutation: \(error)")
        }
    }

    /// Refreshes the outbox count from the store.
    func refreshOutboxCount() {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<DataModel.SyncMutation>()
        outboxCount = (try? context.fetchCount(descriptor)) ?? 0
    }

    // MARK: - Core Sync

    private func performSync() async {
        guard client != nil else {
            logger.warning("Sync attempted without Supabase client")
            return
        }

        status = .syncing
        syncLog.info("Sync started")
        logger.info("Sync started")

        do {
            try await push()
            try await pull()

            consecutiveFailures = 0
            lastSyncDate = .now
            status = .synced(.now)
            syncLog.info("Sync completed successfully")
            logger.info("Sync completed successfully")
            refreshOutboxCount()

        } catch is CancellationError {
            status = .idle
            syncLog.warning("Sync cancelled")

        } catch {
            consecutiveFailures += 1
            let message = mapSyncError(error)
            status = .error(message)
            syncLog.error("Sync failed: \(message)")
            logger.error("Sync failed: \(error)")

            scheduleRetry()
        }
    }

    private func simulateSync(duration: TimeInterval) async {
        status = .syncing
        syncLog.info("Sync started (forced)")
        logger.info("Sync started (forced)")

        do {
            try await Task.sleep(for: .seconds(duration))
        } catch {
            status = .idle
            syncLog.warning("Sync cancelled")
            return
        }

        lastSyncDate = .now
        status = .synced(.now)
        syncLog.info("Sync completed (forced)")
        logger.info("Sync completed (forced)")
    }

    // MARK: - Push

    private func push() async throws {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<DataModel.SyncMutation>(
            sortBy: [SortDescriptor(\.createdDate, order: .forward)]
        )
        let mutations = try context.fetch(descriptor)

        guard !mutations.isEmpty else {
            logger.debug("No outbox mutations to push")
            return
        }

        logger.info("Pushing \(mutations.count) mutations")
        syncLog.info("Pushing \(mutations.count) mutations")

        guard let userId = authManager.state.user?.id else {
            throw SyncError.notAuthenticated
        }

        let grouped = Dictionary(grouping: mutations) { $0.entityType }

        for entityType in SyncEntityType.ordered {
            guard let typeMutations = grouped[entityType.rawValue] else { continue }

            for mutation in typeMutations {
                try Task.checkCancellation()

                guard let result = SyncSerializer.buildMergeParams(
                    entityType: entityType,
                    recordData: mutation.recordData,
                    userId: userId
                ) else {
                    logger.warning("Failed to build params for mutation \(mutation.id), removing")
                    context.delete(mutation)
                    continue
                }

                do {
                    try await callMergeRPC(name: result.rpcName, params: result.params)
                    context.delete(mutation)
                    logger.debug("Pushed \(entityType.rawValue) \(mutation.entityId)")
                } catch {
                    mutation.retryCount += 1
                    logger.warning(
                        "Push failed for \(entityType.rawValue) \(mutation.entityId): \(error)"
                    )
                    throw error
                }
            }
        }

        try context.save()
    }

    private func callMergeRPC(name: String, params: any Encodable) async throws {
        guard let client else {
            throw SyncError.notAuthenticated
        }
        let wrapper = AnyEncodable(params)
        _ = try await client.rpc(name, params: wrapper).execute()
    }

    // MARK: - Pull

    private func pull() async throws {
        guard let userId = authManager.state.user?.id else {
            throw SyncError.notAuthenticated
        }

        logger.info("Starting incremental pull")

        for entityType in SyncEntityType.ordered {
            try Task.checkCancellation()
            try await pullTable(entityType, userId: userId)
        }
    }

    private func pullTable(_ entityType: SyncEntityType, userId: UUID) async throws {
        let context = modelContainer.mainContext
        let cursor = fetchOrCreateCursor(for: entityType, context: context)
        var lastRevision = cursor.lastRevision
        var hasMore = true

        while hasMore {
            try Task.checkCancellation()

            let (rows, maxRevision) = try await fetchServerRows(
                entityType: entityType,
                afterRevision: lastRevision,
                limit: Constants.pullPageSize
            )

            if rows.isEmpty {
                hasMore = false
                continue
            }

            try applyPulledRows(entityType: entityType, rows: rows, context: context)

            lastRevision = maxRevision
            cursor.lastRevision = maxRevision
            cursor.lastSyncDate = Date.now

            hasMore = rows.count >= Constants.pullPageSize
        }

        try context.save()
        logger.debug("Pulled \(entityType.rawValue) up to revision \(lastRevision)")
    }

    private func fetchOrCreateCursor(
        for entityType: SyncEntityType,
        context: ModelContext
    ) -> DataModel.SyncCursor {
        let tableName = entityType.rawValue
        var descriptor = FetchDescriptor<DataModel.SyncCursor>(
            predicate: #Predicate { $0.tableName == tableName }
        )
        descriptor.fetchLimit = 1

        if let existing = try? context.fetch(descriptor).first {
            return existing
        }

        let cursor = DataModel.SyncCursor(tableName: tableName)
        context.insert(cursor)
        return cursor
    }

    private func fetchServerRows(
        entityType: SyncEntityType,
        afterRevision: Int64,
        limit: Int
    ) async throws -> (rows: [[String: Any]], maxRevision: Int64) {
        guard let client else {
            throw SyncError.notAuthenticated
        }

        let data = try await client
            .from(entityType.rawValue)
            .select()
            .gt("revision", value: Int(afterRevision))
            .order("revision", ascending: true)
            .limit(limit)
            .execute()
            .data

        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return ([], afterRevision)
        }

        let maxRevision = rows.compactMap { ($0["revision"] as? NSNumber)?.int64Value }
            .max() ?? afterRevision
        return (rows, maxRevision)
    }

    private func applyPulledRows(
        entityType: SyncEntityType,
        rows: [[String: Any]],
        context: ModelContext
    ) throws {
        let decoder = JSONDecoder()

        for rowDict in rows {
            if rowDict["created_at"] == nil {
                let keys = rowDict.keys.compactMap { $0 as? String }.sorted()
                let id = rowDict["id"] as? String ?? "unknown"
                let revision = rowDict["revision"] as? NSNumber
                logger.error(
                    "Pull row missing created_at for \(entityType.rawValue) id=\(id) rev=\(revision?.int64Value ?? -1) keys=\(keys)"
                )
                syncLog.error("Pull row missing created_at for \(entityType.rawValue)")
            }
            let rowData = try JSONSerialization.data(withJSONObject: rowDict)

            switch entityType {
            case .spread:
                do {
                    let row = try decoder.decode(ServerSpreadRow.self, from: rowData)
                    try applySpreadRow(row, context: context)
                } catch {
                    logDecodeFailure(error, entityType: entityType, rowDict: rowDict)
                    throw error
                }
            case .task:
                do {
                    let row = try decoder.decode(ServerTaskRow.self, from: rowData)
                    try applyTaskRow(row, context: context)
                } catch {
                    logDecodeFailure(error, entityType: entityType, rowDict: rowDict)
                    throw error
                }
            case .note:
                do {
                    let row = try decoder.decode(ServerNoteRow.self, from: rowData)
                    try applyNoteRow(row, context: context)
                } catch {
                    logDecodeFailure(error, entityType: entityType, rowDict: rowDict)
                    throw error
                }
            case .collection:
                do {
                    let row = try decoder.decode(ServerCollectionRow.self, from: rowData)
                    try applyCollectionRow(row, context: context)
                } catch {
                    logDecodeFailure(error, entityType: entityType, rowDict: rowDict)
                    throw error
                }
            case .taskAssignment:
                do {
                    let row = try decoder.decode(ServerTaskAssignmentRow.self, from: rowData)
                    try applyTaskAssignmentRow(row, context: context)
                } catch {
                    logDecodeFailure(error, entityType: entityType, rowDict: rowDict)
                    throw error
                }
            case .noteAssignment:
                do {
                    let row = try decoder.decode(ServerNoteAssignmentRow.self, from: rowData)
                    try applyNoteAssignmentRow(row, context: context)
                } catch {
                    logDecodeFailure(error, entityType: entityType, rowDict: rowDict)
                    throw error
                }
            }
        }
    }

    private func logDecodeFailure(
        _ error: Error,
        entityType: SyncEntityType,
        rowDict: [String: Any]
    ) {
        let keys = rowDict.keys.compactMap { $0 as? String }.sorted()
        let id = rowDict["id"] as? String ?? "unknown"
        let revision = rowDict["revision"] as? NSNumber
        logger.error(
            "Failed to decode \(entityType.rawValue) row id=\(id) rev=\(revision?.int64Value ?? -1): \(error). keys=\(keys)"
        )
        syncLog.error("Decode failure for \(entityType.rawValue)")
    }

    // MARK: - Pull Apply Helpers

    private func applySpreadRow(_ row: ServerSpreadRow, context: ModelContext) throws {
        let id = row.id
        var descriptor = FetchDescriptor<DataModel.Spread>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            if row.deletedAt != nil {
                context.delete(existing)
            } else {
                _ = SyncSerializer.applySpreadRow(row, to: existing)
            }
        } else if row.deletedAt == nil {
            if let spread = SyncSerializer.createSpread(from: row, calendar: .current) {
                context.insert(spread)
            }
        }
    }

    private func applyTaskRow(_ row: ServerTaskRow, context: ModelContext) throws {
        let id = row.id
        var descriptor = FetchDescriptor<DataModel.Task>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            if row.deletedAt != nil {
                context.delete(existing)
            } else {
                _ = SyncSerializer.applyTaskRow(row, to: existing)
            }
        } else if row.deletedAt == nil {
            if let task = SyncSerializer.createTask(from: row) {
                context.insert(task)
            }
        }
    }

    private func applyNoteRow(_ row: ServerNoteRow, context: ModelContext) throws {
        let id = row.id
        var descriptor = FetchDescriptor<DataModel.Note>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            if row.deletedAt != nil {
                context.delete(existing)
            } else {
                _ = SyncSerializer.applyNoteRow(row, to: existing)
            }
        } else if row.deletedAt == nil {
            if let note = SyncSerializer.createNote(from: row) {
                context.insert(note)
            }
        }
    }

    private func applyCollectionRow(_ row: ServerCollectionRow, context: ModelContext) throws {
        let id = row.id
        var descriptor = FetchDescriptor<DataModel.Collection>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            if row.deletedAt != nil {
                context.delete(existing)
            } else {
                _ = SyncSerializer.applyCollectionRow(row, to: existing)
            }
        } else if row.deletedAt == nil {
            if let collection = SyncSerializer.createCollection(from: row) {
                context.insert(collection)
            }
        }
    }

    private func applyTaskAssignmentRow(
        _ row: ServerTaskAssignmentRow,
        context: ModelContext
    ) throws {
        let taskId = row.taskId
        var descriptor = FetchDescriptor<DataModel.Task>(
            predicate: #Predicate { $0.id == taskId }
        )
        descriptor.fetchLimit = 1

        guard let task = try context.fetch(descriptor).first else {
            logger.warning("Task \(taskId) not found for assignment \(row.id)")
            return
        }

        guard let rowPeriod = Period(rawValue: row.period),
              let rowDate = SyncDateFormatting.parseDate(row.date) else { return }

        if row.deletedAt != nil {
            task.assignments.removeAll {
                $0.period == rowPeriod && $0.date == rowDate
            }
        } else if let assignment = SyncSerializer.createTaskAssignment(from: row) {
            if let index = task.assignments.firstIndex(where: {
                $0.period == rowPeriod && $0.date == rowDate
            }) {
                task.assignments[index] = assignment
            } else {
                task.assignments.append(assignment)
            }
        }
    }

    private func applyNoteAssignmentRow(
        _ row: ServerNoteAssignmentRow,
        context: ModelContext
    ) throws {
        let noteId = row.noteId
        var descriptor = FetchDescriptor<DataModel.Note>(
            predicate: #Predicate { $0.id == noteId }
        )
        descriptor.fetchLimit = 1

        guard let note = try context.fetch(descriptor).first else {
            logger.warning("Note \(noteId) not found for assignment \(row.id)")
            return
        }

        guard let rowPeriod = Period(rawValue: row.period),
              let rowDate = SyncDateFormatting.parseDate(row.date) else { return }

        if row.deletedAt != nil {
            note.assignments.removeAll {
                $0.period == rowPeriod && $0.date == rowDate
            }
        } else if let assignment = SyncSerializer.createNoteAssignment(from: row) {
            if let index = note.assignments.firstIndex(where: {
                $0.period == rowPeriod && $0.date == rowDate
            }) {
                note.assignments[index] = assignment
            } else {
                note.assignments.append(assignment)
            }
        }
    }

    // MARK: - Backoff & Retry

    private func scheduleRetry() {
        let delay = min(
            Constants.baseBackoffSeconds * pow(2.0, Double(consecutiveFailures - 1)),
            Constants.maxBackoffSeconds
        )
        logger.info("Scheduling retry in \(delay)s (attempt \(self.consecutiveFailures))")
        syncLog.info("Retry in \(Int(delay))s")

        syncTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await self?.syncNow()
        }
    }

    // MARK: - Error Handling

    private func mapSyncError(_ error: Error) -> String {
        if let syncError = error as? SyncError {
            return syncError.userMessage
        }
        return "Sync failed. Will retry."
    }

    /// Clears all outbox mutations and resets sync state.
    ///
    /// Called on sign-out to prevent pushing stale data.
    func resetSyncState() {
        syncTask?.cancel()
        syncTask = nil
        consecutiveFailures = 0
        status = .idle
        lastSyncDate = nil
        outboxCount = 0
        syncLog.clear()

        let context = modelContainer.mainContext
        do {
            let mutations = try context.fetch(FetchDescriptor<DataModel.SyncMutation>())
            for mutation in mutations { context.delete(mutation) }

            let cursors = try context.fetch(FetchDescriptor<DataModel.SyncCursor>())
            for cursor in cursors { context.delete(cursor) }

            try context.save()
            logger.info("Sync state reset")
        } catch {
            logger.error("Failed to reset sync state: \(error)")
        }
    }
}

// MARK: - AnyEncodable

/// Type-erased Encodable wrapper for passing heterogeneous params to the RPC client.
private struct AnyEncodable: Encodable, @unchecked Sendable {
    private let encodeClosure: @Sendable (Encoder) throws -> Void

    init(_ value: any Encodable & Sendable) {
        self.encodeClosure = { encoder in
            try value.encode(to: encoder)
        }
    }

    nonisolated func encode(to encoder: Encoder) throws {
        try encodeClosure(encoder)
    }
}
