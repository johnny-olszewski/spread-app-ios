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
    typealias ServerRowsFetcher = @Sendable (SyncEntityType, Int64, Int) async throws -> (rows: [[String: Any]], maxRevision: Int64)
    typealias MergeRPCCaller = @Sendable (String, AnyEncodable) async throws -> Data
    typealias AssignmentPresenceChecker = @Sendable (SyncEntityType, UUID) async throws -> Bool

    // MARK: - Observable State

    /// The current sync status.
    var status: SyncStatus = .idle

    /// The date of the last successful sync.
    private(set) var lastSyncDate: Date?

    /// The number of pending outbox mutations.
    private(set) var outboxCount: Int = 0

    /// The number of quarantined outbox mutations — changes that failed to
    /// serialize and are held for manual retry rather than pushed (SPRD-305).
    private(set) var quarantinedCount: Int = 0

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
    private let serverRowsFetcher: ServerRowsFetcher?
    private let mergeRPCCaller: MergeRPCCaller?
    private let assignmentPresenceChecker: AssignmentPresenceChecker?

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
        static let assignmentRepairChangedFields = ["period", "date", "status"]
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
        policy: SyncPolicy = DefaultSyncPolicy(),
        serverRowsFetcher: ServerRowsFetcher? = nil,
        mergeRPCCaller: MergeRPCCaller? = nil,
        assignmentPresenceChecker: AssignmentPresenceChecker? = nil
    ) {
        self.client = client
        self.modelContainer = modelContainer
        self.authManager = authManager
        self.networkMonitor = networkMonitor
        self.deviceId = deviceId
        self.isSyncEnabled = isSyncEnabled
        self.policy = policy
        self.serverRowsFetcher = serverRowsFetcher
        self.mergeRPCCaller = mergeRPCCaller
        self.assignmentPresenceChecker = assignmentPresenceChecker

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
            syncLog.error("Failed to queue a change for sync")
            status = .error("A change couldn't be queued for sync.")
        }
    }

    /// Refreshes the outbox and quarantine counts from the store.
    func refreshOutboxCount() {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<DataModel.SyncMutation>()
        outboxCount = (try? context.fetchCount(descriptor)) ?? 0
        let quarantined = FetchDescriptor<DataModel.SyncMutation>(
            predicate: #Predicate { $0.quarantinedAt != nil }
        )
        quarantinedCount = (try? context.fetchCount(quarantined)) ?? 0
    }

    /// Returns quarantined mutations to the live queue and re-attempts a sync.
    ///
    /// The manual recovery path behind Settings' "Retry" action: clears
    /// `quarantinedAt` and the backoff counter on every quarantined mutation so
    /// the next push re-attempts serialization. Mutations that still fail to
    /// serialize are re-quarantined by that push (SPRD-305).
    func retryQuarantined() async {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<DataModel.SyncMutation>(
            predicate: #Predicate { $0.quarantinedAt != nil }
        )
        do {
            let quarantined = try context.fetch(descriptor)
            guard !quarantined.isEmpty else { return }
            for mutation in quarantined {
                mutation.quarantinedAt = nil
                mutation.retryCount = 0
            }
            try context.save()
            refreshOutboxCount()
            syncLog.info("Retrying \(quarantined.count) quarantined changes")
        } catch {
            logger.error("Failed to reset quarantined mutations: \(error)")
            return
        }
        await syncNow()
    }

    // MARK: - Core Sync

    private func performSync() async {
        guard client != nil || (serverRowsFetcher != nil && mergeRPCCaller != nil) else {
            logger.warning("Sync attempted without Supabase client")
            return
        }

        status = .syncing
        syncLog.info("Sync started")
        logger.info("Sync started")

        do {
            try await push()
            try await pull()

            let repairPlan = try await prepareAssignmentRepairPlan()
            if repairPlan.enqueuedBackfill {
                try await push()
                try await pull()
            }
            persistRepairMarkers(repairPlan.markers)

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

    /// The decoded shape of one row in a `merge_X_batch` RPC's result array.
    ///
    /// `id` and `row` are part of the server response but unused here — mutations are
    /// correlated back to their result positionally (the batch SQL functions preserve
    /// input order via `jsonb_array_elements`), since `entry_tags` mutations have no
    /// single `id` to match on.
    private struct BatchMergeRowResult: Decodable {
        let success: Bool
        let error: String?
    }

    private func push() async throws {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<DataModel.SyncMutation>(
            predicate: #Predicate { $0.quarantinedAt == nil },
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
            guard let typeMutations = grouped[entityType.rawValue], !typeMutations.isEmpty else { continue }

            try Task.checkCancellation()

            let batch = SyncSerializer.buildBatchMergeParams(
                entityType: entityType,
                mutations: typeMutations.map { (mutationID: $0.id, recordData: $0.recordData) },
                userId: userId
            )

            let failedMutationIDs = Set(batch.failedMutationIDs)
            for mutation in typeMutations where failedMutationIDs.contains(mutation.id) {
                logger.warning("Failed to build params for mutation \(mutation.id), quarantining")
                syncLog.error("Quarantined unserializable \(entityType.rawValue) change")
                mutation.quarantinedAt = .now
            }

            let validMutations = typeMutations.filter { !failedMutationIDs.contains($0.id) }
            guard !validMutations.isEmpty else { continue }

            do {
                let results = try await callBatchMergeRPC(name: batch.rpcName, params: batch.params)
                guard results.count == validMutations.count else {
                    throw SyncError.batchResultCountMismatch
                }

                for (mutation, result) in zip(validMutations, results) {
                    if result.success {
                        context.delete(mutation)
                        logger.debug("Pushed \(entityType.rawValue) \(mutation.entityId)")
                    } else {
                        mutation.retryCount += 1
                        logger.warning(
                            "Push failed for \(entityType.rawValue) \(mutation.entityId): \(result.error ?? "unknown error")"
                        )
                    }
                }
            } catch {
                for mutation in validMutations {
                    mutation.retryCount += 1
                }
                logger.warning("Batch push failed for \(entityType.rawValue): \(error)")
                throw error
            }
        }

        try context.save()
    }

    private func callBatchMergeRPC(name: String, params: BatchMergeParams) async throws -> [BatchMergeRowResult] {
        let wrapper = AnyEncodable(params)
        let data: Data
        if let mergeRPCCaller {
            data = try await mergeRPCCaller(name, wrapper)
        } else {
            guard let client else {
                throw SyncError.notAuthenticated
            }
            data = try await client.rpc(name, params: wrapper).execute().data
        }
        return try JSONDecoder().decode([BatchMergeRowResult].self, from: data)
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
        guard entityType.supportsRevisionPull else { return }

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
        if let serverRowsFetcher {
            return try await serverRowsFetcher(entityType, afterRevision, limit)
        }

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

    private func serverHasAssignmentRows(
        entityType: SyncEntityType,
        entryId: UUID
    ) async throws -> Bool {
        if let assignmentPresenceChecker {
            return try await assignmentPresenceChecker(entityType, entryId)
        }

        guard let client else {
            throw SyncError.notAuthenticated
        }

        precondition(entityType == .assignment, "Assignment presence can only be queried for the assignments table")

        let data = try await client
            .from(entityType.rawValue)
            .select("id")
            .eq("entry_id", value: entryId.uuidString)
            .limit(1)
            .execute()
            .data

        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return false
        }

        return !rows.isEmpty
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
            case .settings:
                do {
                    let row = try decoder.decode(ServerSettingsRow.self, from: rowData)
                    try applySettingsRow(row, context: context)
                } catch {
                    logDecodeFailure(error, entityType: entityType, rowDict: rowDict)
                    throw error
                }
            case .spread:
                do {
                    let row = try decoder.decode(ServerSpreadRow.self, from: rowData)
                    try applySpreadRow(row, context: context)
                } catch {
                    logDecodeFailure(error, entityType: entityType, rowDict: rowDict)
                    throw error
                }
            case .entry:
                do {
                    let row = try decoder.decode(ServerEntryRow.self, from: rowData)
                    try applyEntryRow(row, context: context)
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
            case .assignment:
                do {
                    let row = try decoder.decode(ServerAssignmentRow.self, from: rowData)
                    try applyAssignmentRow(row, context: context)
                } catch {
                    logDecodeFailure(error, entityType: entityType, rowDict: rowDict)
                    throw error
                }
            case .list:
                do {
                    let row = try decoder.decode(ServerListRow.self, from: rowData)
                    try applyListRow(row, context: context)
                } catch {
                    logDecodeFailure(error, entityType: entityType, rowDict: rowDict)
                    throw error
                }
            case .tag:
                do {
                    let row = try decoder.decode(ServerTagRow.self, from: rowData)
                    try applyTagRow(row, context: context)
                } catch {
                    logDecodeFailure(error, entityType: entityType, rowDict: rowDict)
                    throw error
                }
            case .entryTag:
                // Join table rows are applied via task/note relationship resolution;
                // pull is not yet implemented for join tables in this version.
                break
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

    private func applySettingsRow(_ row: ServerSettingsRow, context: ModelContext) throws {
        var descriptor = FetchDescriptor<DataModel.Settings>()
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            if row.deletedAt != nil {
                context.delete(existing)
            } else {
                _ = SyncSerializer.applySettingsRow(row, to: existing)
            }
        } else if row.deletedAt == nil {
            if let settings = SyncSerializer.createSettings(from: row) {
                context.insert(settings)
            }
        }
    }

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

    /// Dispatches a server entry row to the task or note apply path based on `row.type`.
    private func applyEntryRow(_ row: ServerEntryRow, context: ModelContext) throws {
        switch row.type {
        case EntryType.task.rawValue:
            try applyTaskEntryRow(row, context: context)
        case EntryType.note.rawValue:
            try applyNoteEntryRow(row, context: context)
        default:
            logger.warning("Unknown entry type '\(row.type)' for entry \(row.id)")
        }
    }

    private func applyTaskEntryRow(_ row: ServerEntryRow, context: ModelContext) throws {
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

    private func applyNoteEntryRow(_ row: ServerEntryRow, context: ModelContext) throws {
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

    /// Dispatches a server assignment row to the task or note assignment list based on `row.entryType`.
    private func applyAssignmentRow(_ row: ServerAssignmentRow, context: ModelContext) throws {
        guard let rowPeriod = Period(rawValue: row.period),
              let rowDate = SyncDateFormatting.parseDate(row.date) else { return }

        switch row.entryType {
        case EntryType.task.rawValue:
            let entryId = row.entryId
            var descriptor = FetchDescriptor<DataModel.Task>(
                predicate: #Predicate { $0.id == entryId }
            )
            descriptor.fetchLimit = 1
            guard let task = try context.fetch(descriptor).first else {
                logger.warning("Task \(entryId) not found for assignment \(row.id)")
                return
            }
            applyAssignmentRow(
                row,
                rowPeriod: rowPeriod,
                rowDate: rowDate,
                current: &task.currentAssignments,
                history: &task.migrationHistory
            )

        case EntryType.note.rawValue:
            let entryId = row.entryId
            var descriptor = FetchDescriptor<DataModel.Note>(
                predicate: #Predicate { $0.id == entryId }
            )
            descriptor.fetchLimit = 1
            guard let note = try context.fetch(descriptor).first else {
                logger.warning("Note \(entryId) not found for assignment \(row.id)")
                return
            }
            applyAssignmentRow(
                row,
                rowPeriod: rowPeriod,
                rowDate: rowDate,
                current: &note.currentAssignments,
                history: &note.migrationHistory
            )

        default:
            logger.warning("Unknown entry type '\(row.entryType)' for assignment \(row.id)")
        }
    }

    /// Applies a pulled assignment row to whichever of `current`/`history` it belongs in.
    ///
    /// Removes any existing match from both collections first, then — for a non-tombstone
    /// row — re-inserts into `history` if the incoming assignment's status is `.migrated`,
    /// or `current` otherwise. This naturally handles a status transition arriving from the
    /// server (e.g. an assignment that was current now arriving as migrated) without needing
    /// to track which collection it previously lived in.
    private func applyAssignmentRow(
        _ row: ServerAssignmentRow,
        rowPeriod: Period,
        rowDate: Date,
        current: inout [Assignment],
        history: inout [Assignment]
    ) {
        let matches: (Assignment) -> Bool = { assignment in
            self.assignmentMatches(
                assignment,
                rowID: row.id,
                rowPeriod: rowPeriod,
                rowDate: rowDate,
                rowSpreadID: row.spreadId
            )
        }
        current.removeAll(where: matches)
        history.removeAll(where: matches)

        guard row.deletedAt == nil, let assignment = SyncSerializer.createAssignment(from: row) else {
            return
        }

        if assignment.status == .migrated {
            history.append(assignment)
        } else {
            current.append(assignment)
        }
    }

    private func applyListRow(_ row: ServerListRow, context: ModelContext) throws {
        let id = row.id
        var descriptor = FetchDescriptor<DataModel.List>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            if row.deletedAt != nil {
                context.delete(existing)
            } else {
                _ = SyncSerializer.applyListRow(row, to: existing)
            }
        } else if row.deletedAt == nil {
            if let list = SyncSerializer.createList(from: row) {
                context.insert(list)
            }
        }
    }

    private func applyTagRow(_ row: ServerTagRow, context: ModelContext) throws {
        let id = row.id
        var descriptor = FetchDescriptor<DataModel.Tag>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            if row.deletedAt != nil {
                context.delete(existing)
            } else {
                _ = SyncSerializer.applyTagRow(row, to: existing)
            }
        } else if row.deletedAt == nil {
            if let tag = SyncSerializer.createTag(from: row) {
                context.insert(tag)
            }
        }
    }

    private func assignmentMatches(
        _ assignment: Assignment,
        rowID: UUID,
        rowPeriod: Period,
        rowDate: Date,
        rowSpreadID: UUID?
    ) -> Bool {
        if assignment.id == rowID {
            return true
        }

        if let rowSpreadID {
            return assignment.spreadID == rowSpreadID && assignment.period == rowPeriod
        }

        return assignment.spreadID == nil && assignment.period == rowPeriod && assignment.date == rowDate
    }

    // MARK: - Assignment Repair

    private struct AssignmentRepairMarkerRecord {
        let accountId: UUID
        let entryType: String
        let entryId: UUID
        let didBackfill: Bool
    }

    private struct AssignmentRepairPlan {
        var markers: [AssignmentRepairMarkerRecord] = []
        var enqueuedBackfill = false
    }

    private func prepareAssignmentRepairPlan() async throws -> AssignmentRepairPlan {
        guard isSyncEnabled, authManager.state.isSignedIn,
              let accountId = authManager.state.user?.id else {
            return AssignmentRepairPlan()
        }

        let context = modelContainer.mainContext
        var plan = AssignmentRepairPlan()

        let tasks = try context.fetch(FetchDescriptor<DataModel.Task>())
        for task in tasks where !(task.currentAssignments + task.migrationHistory).isEmpty {
            guard !hasCompletedRepairMarker(
                accountId: accountId,
                entryType: EntryType.task.rawValue,
                entryId: task.id,
                context: context
            ) else { continue }

            if try await serverHasAssignmentRows(entityType: .assignment, entryId: task.id) {
                plan.markers.append(.init(
                    accountId: accountId,
                    entryType: EntryType.task.rawValue,
                    entryId: task.id,
                    didBackfill: false
                ))
                continue
            }

            enqueueAssignmentBackfill(task.currentAssignments + task.migrationHistory, entryId: task.id, entryType: .task)
            plan.enqueuedBackfill = true
            plan.markers.append(.init(
                accountId: accountId,
                entryType: EntryType.task.rawValue,
                entryId: task.id,
                didBackfill: true
            ))
        }

        let notes = try context.fetch(FetchDescriptor<DataModel.Note>())
        for note in notes where !(note.currentAssignments + note.migrationHistory).isEmpty {
            guard !hasCompletedRepairMarker(
                accountId: accountId,
                entryType: EntryType.note.rawValue,
                entryId: note.id,
                context: context
            ) else { continue }

            if try await serverHasAssignmentRows(entityType: .assignment, entryId: note.id) {
                plan.markers.append(.init(
                    accountId: accountId,
                    entryType: EntryType.note.rawValue,
                    entryId: note.id,
                    didBackfill: false
                ))
                continue
            }

            enqueueAssignmentBackfill(note.currentAssignments + note.migrationHistory, entryId: note.id, entryType: .note)
            plan.enqueuedBackfill = true
            plan.markers.append(.init(
                accountId: accountId,
                entryType: EntryType.note.rawValue,
                entryId: note.id,
                didBackfill: true
            ))
        }

        return plan
    }

    private func enqueueAssignmentBackfill(_ assignments: [Assignment], entryId: UUID, entryType: EntryType) {
        let timestamp = Date.now

        for assignment in assignments {
            guard let recordData = SyncSerializer.serializeAssignment(
                assignment,
                entryId: entryId,
                entryType: entryType,
                deviceId: deviceId,
                timestamp: timestamp
            ) else { continue }

            enqueueMutation(
                entityType: .assignment,
                entityId: assignment.id,
                operation: .create,
                recordData: recordData,
                changedFields: Constants.assignmentRepairChangedFields
            )
        }
    }

    private func persistRepairMarkers(_ markers: [AssignmentRepairMarkerRecord]) {
        guard !markers.isEmpty else { return }

        let context = modelContainer.mainContext
        for marker in markers {
            if let existingMarker = fetchRepairMarker(
                accountId: marker.accountId,
                entryType: marker.entryType,
                entryId: marker.entryId,
                context: context
            ) {
                existingMarker.didBackfill = existingMarker.didBackfill || marker.didBackfill
            } else {
                context.insert(
                    DataModel.SyncRepairMarker(
                        accountId: marker.accountId,
                        entryType: marker.entryType,
                        entryId: marker.entryId,
                        didBackfill: marker.didBackfill
                    )
                )
            }
        }

        do {
            try context.save()
        } catch {
            logger.error("Failed to persist assignment repair markers: \(error)")
        }
    }

    private func hasCompletedRepairMarker(
        accountId: UUID,
        entryType: String,
        entryId: UUID,
        context: ModelContext
    ) -> Bool {
        fetchRepairMarker(
            accountId: accountId,
            entryType: entryType,
            entryId: entryId,
            context: context
        )?.didBackfill == true
    }

    private func fetchRepairMarker(
        accountId: UUID,
        entryType: String,
        entryId: UUID,
        context: ModelContext
    ) -> DataModel.SyncRepairMarker? {
        let key = DataModel.SyncRepairMarker.makeKey(
            accountId: accountId,
            entryType: entryType,
            entryId: entryId
        )
        var descriptor = FetchDescriptor<DataModel.SyncRepairMarker>(
            predicate: #Predicate { $0.key == key }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
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
///
/// @unchecked Sendable: The stored closure captures only `Sendable` values (enforced by the `init`
/// parameter constraint), but the compiler cannot verify closure captures automatically.
struct AnyEncodable: Encodable, @unchecked Sendable {
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
