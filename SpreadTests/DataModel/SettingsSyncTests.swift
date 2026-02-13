import Foundation
import SwiftData
import Testing
@testable import Spread

@MainActor
struct SettingsSyncTests {

    // MARK: - Model Tests

    /// Conditions: Create a Settings model with default values.
    /// Expected: Defaults should be conventional mode, firstWeekday 1, revision 0, nil sync metadata.
    @Test func testSettingsModelDefaults() {
        let settings = DataModel.Settings()

        #expect(settings.bujoMode == .conventional)
        #expect(settings.firstWeekday == 1)
        #expect(settings.revision == 0)
        #expect(settings.deletedAt == nil)
        #expect(settings.deviceId == nil)
        #expect(settings.bujoModeUpdatedAt == nil)
        #expect(settings.firstWeekdayUpdatedAt == nil)
    }

    /// Conditions: Create a Settings model with custom values.
    /// Expected: All properties should match the provided values.
    @Test func testSettingsModelCustomValues() {
        let id = UUID()
        let now = Date.now
        let deviceId = UUID()

        let settings = DataModel.Settings(
            id: id,
            bujoMode: .traditional,
            firstWeekday: 2,
            createdDate: now,
            deviceId: deviceId,
            revision: 42,
            bujoModeUpdatedAt: now,
            firstWeekdayUpdatedAt: now
        )

        #expect(settings.id == id)
        #expect(settings.bujoMode == .traditional)
        #expect(settings.firstWeekday == 2)
        #expect(settings.createdDate == now)
        #expect(settings.deviceId == deviceId)
        #expect(settings.revision == 42)
        #expect(settings.bujoModeUpdatedAt == now)
        #expect(settings.firstWeekdayUpdatedAt == now)
    }

    /// Conditions: Insert and fetch a Settings model from SwiftData.
    /// Expected: The fetched model should match the inserted one.
    @Test func testSettingsModelRoundTrip() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext

        let settings = DataModel.Settings(
            bujoMode: .traditional,
            firstWeekday: 2
        )
        context.insert(settings)
        try context.save()

        var descriptor = FetchDescriptor<DataModel.Settings>()
        descriptor.fetchLimit = 1
        let fetched = try context.fetch(descriptor).first

        #expect(fetched?.id == settings.id)
        #expect(fetched?.bujoMode == .traditional)
        #expect(fetched?.firstWeekday == 2)
    }

    // MARK: - SyncEntityType Tests

    /// Conditions: Check the settings entity type registration.
    /// Expected: Raw value "settings", merge RPC "merge_settings", sync order 0.
    @Test func testSyncEntityTypeSettings() {
        let entityType = SyncEntityType.settings

        #expect(entityType.rawValue == "settings")
        #expect(entityType.mergeRPCName == "merge_settings")
        #expect(entityType.syncOrder == 0)
    }

    /// Conditions: Check that settings is included in ordered entity types.
    /// Expected: Settings should be in the ordered list.
    @Test func testSyncEntityTypeOrderedIncludesSettings() {
        let ordered = SyncEntityType.ordered
        #expect(ordered.contains(.settings))
    }

    // MARK: - Serialization Tests

    /// Conditions: Serialize a Settings model for the outbox.
    /// Expected: JSON should contain all expected fields with correct values.
    @Test func testSerializeSettings() {
        let id = UUID()
        let deviceId = UUID()
        let now = Date.now
        let settings = DataModel.Settings(
            id: id,
            bujoMode: .traditional,
            firstWeekday: 2,
            createdDate: now
        )

        let data = SyncSerializer.serializeSettings(
            settings,
            deviceId: deviceId,
            timestamp: now
        )

        #expect(data != nil)

        guard let data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            Issue.record("Failed to deserialize settings JSON")
            return
        }

        #expect(json["id"] as? String == id.uuidString)
        #expect(json["device_id"] as? String == deviceId.uuidString)
        #expect(json["bujo_mode"] as? String == "traditional")
        #expect(json["first_weekday"] as? Int == 2)
        #expect(json["bujo_mode_updated_at"] != nil)
        #expect(json["first_weekday_updated_at"] != nil)
    }

    /// Conditions: Serialize settings with existing LWW timestamps.
    /// Expected: Serialized JSON should use the model's timestamps, not the provided timestamp.
    @Test func testSerializeSettingsUsesModelTimestamps() {
        let modelTimestamp = Date(timeIntervalSince1970: 1000)
        let callTimestamp = Date(timeIntervalSince1970: 2000)

        let settings = DataModel.Settings(
            bujoMode: .conventional,
            firstWeekday: 1,
            bujoModeUpdatedAt: modelTimestamp,
            firstWeekdayUpdatedAt: modelTimestamp
        )

        let data = SyncSerializer.serializeSettings(
            settings,
            deviceId: UUID(),
            timestamp: callTimestamp
        )

        guard let data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            Issue.record("Failed to deserialize settings JSON")
            return
        }

        let expectedTs = SyncDateFormatting.formatTimestamp(modelTimestamp)
        #expect(json["bujo_mode_updated_at"] as? String == expectedTs)
        #expect(json["first_weekday_updated_at"] as? String == expectedTs)
    }

    // MARK: - Build Merge Params Tests

    /// Conditions: Build merge params from serialized settings record data.
    /// Expected: Should produce MergeSettingsParams with correct RPC name.
    @Test func testBuildMergeParamsForSettings() {
        let id = UUID()
        let deviceId = UUID()
        let userId = UUID()
        let now = Date.now

        let settings = DataModel.Settings(
            id: id,
            bujoMode: .traditional,
            firstWeekday: 2,
            createdDate: now
        )

        guard let recordData = SyncSerializer.serializeSettings(
            settings,
            deviceId: deviceId,
            timestamp: now
        ) else {
            Issue.record("Failed to serialize settings")
            return
        }

        let result = SyncSerializer.buildMergeParams(
            entityType: .settings,
            recordData: recordData,
            userId: userId
        )

        #expect(result != nil)
        #expect(result?.rpcName == "merge_settings")
        #expect(result?.params is MergeSettingsParams)
    }

    // MARK: - Pull Deserialization Tests

    /// Conditions: Apply a server settings row to an existing local settings model.
    /// Expected: Local model should be updated with server values.
    @Test func testApplySettingsRow() {
        let settings = DataModel.Settings(
            bujoMode: .conventional,
            firstWeekday: 1
        )

        let row = ServerSettingsRow(
            id: settings.id,
            bujoMode: "traditional",
            firstWeekday: 2,
            createdAt: SyncDateFormatting.formatTimestamp(.now),
            deletedAt: nil,
            revision: 5
        )

        let result = SyncSerializer.applySettingsRow(row, to: settings)

        #expect(result == true)
        #expect(settings.bujoMode == .traditional)
        #expect(settings.firstWeekday == 2)
        #expect(settings.revision == 5)
    }

    /// Conditions: Apply a deleted server settings row.
    /// Expected: Should return false (soft-deleted).
    @Test func testApplyDeletedSettingsRow() {
        let settings = DataModel.Settings()

        let row = ServerSettingsRow(
            id: settings.id,
            bujoMode: "conventional",
            firstWeekday: 1,
            createdAt: SyncDateFormatting.formatTimestamp(.now),
            deletedAt: SyncDateFormatting.formatTimestamp(.now),
            revision: 1
        )

        let result = SyncSerializer.applySettingsRow(row, to: settings)
        #expect(result == false)
    }

    /// Conditions: Create settings from a valid server row.
    /// Expected: Should produce a Settings model with matching values.
    @Test func testCreateSettingsFromServerRow() {
        let id = UUID()
        let now = Date.now

        let row = ServerSettingsRow(
            id: id,
            bujoMode: "traditional",
            firstWeekday: 2,
            createdAt: SyncDateFormatting.formatTimestamp(now),
            deletedAt: nil,
            revision: 10
        )

        let settings = SyncSerializer.createSettings(from: row)

        #expect(settings != nil)
        #expect(settings?.id == id)
        #expect(settings?.bujoMode == .traditional)
        #expect(settings?.firstWeekday == 2)
        #expect(settings?.revision == 10)
    }

    /// Conditions: Create settings from a deleted server row.
    /// Expected: Should return nil.
    @Test func testCreateSettingsFromDeletedServerRow() {
        let row = ServerSettingsRow(
            id: UUID(),
            bujoMode: "conventional",
            firstWeekday: 1,
            createdAt: SyncDateFormatting.formatTimestamp(.now),
            deletedAt: SyncDateFormatting.formatTimestamp(.now),
            revision: 1
        )

        let settings = SyncSerializer.createSettings(from: row)
        #expect(settings == nil)
    }

    /// Conditions: Create settings from a server row with invalid bujo_mode.
    /// Expected: Should return nil.
    @Test func testCreateSettingsFromInvalidBujoMode() {
        let row = ServerSettingsRow(
            id: UUID(),
            bujoMode: "invalid_mode",
            firstWeekday: 1,
            createdAt: SyncDateFormatting.formatTimestamp(.now),
            deletedAt: nil,
            revision: 1
        )

        let settings = SyncSerializer.createSettings(from: row)
        #expect(settings == nil)
    }
}
