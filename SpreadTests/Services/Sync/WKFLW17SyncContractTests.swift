import Foundation
import Testing

struct WKFLW17SyncContractTests {

    /// Conditions: The committed Supabase migration and local schema snapshot are inspected for WKFLW-17 fields.
    /// Expected: Only approved spread/task fields are present; deferred candidates do not appear as persisted columns or RPC args.
    @Test func schemaSnapshotsIncludeApprovedFieldsAndNoDeferredCandidates() throws {
        let migration = try readRepositoryFile("supabase/migrations/20260418000000_wkflw17_schema_sync_fields.sql")
        let snapshot = try readRepositoryFile("supabase/local/public_schema_from_dev.sql")

        for sql in [migration, snapshot] {
            for approvedField in approvedWKFLW17SQLFields {
                #expect(sql.contains(approvedField))
            }

            for deferredPattern in deferredWKFLW17SQLPatterns {
                #expect(
                    sql.range(of: deferredPattern, options: [.regularExpression, .caseInsensitive]) == nil
                )
            }
        }
    }

    /// Conditions: The merge RPC definitions are inspected for the approved metadata fields.
    /// Expected: Each independently mergeable field uses its own timestamp, and delete handling precedes metadata updates.
    @Test func mergeFunctionsUseIndependentConflictTimestampsAndDeleteWins() throws {
        let migration = try readRepositoryFile("supabase/migrations/20260418000000_wkflw17_schema_sync_fields.sql")
        let snapshot = try readRepositoryFile("supabase/local/public_schema_from_dev.sql")

        for sql in [migration, snapshot] {
            #expect(sql.contains("IF p_deleted_at IS NOT NULL"))
            #expect(sql.contains("is_favorite = CASE WHEN p_is_favorite_updated_at > v_existing.is_favorite_updated_at"))
            #expect(sql.contains("custom_name = CASE WHEN p_custom_name_updated_at > v_existing.custom_name_updated_at"))
            #expect(sql.contains("uses_dynamic_name = CASE WHEN p_uses_dynamic_name_updated_at > v_existing.uses_dynamic_name_updated_at"))
            #expect(sql.contains("body = CASE WHEN p_body_updated_at > v_existing.body_updated_at"))
            #expect(sql.contains("priority = CASE WHEN p_priority_updated_at > v_existing.priority_updated_at"))
            #expect(sql.contains("due_date = CASE WHEN p_due_date_updated_at > v_existing.due_date_updated_at"))
        }
    }

    private var approvedWKFLW17SQLFields: [String] {
        [
            "is_favorite",
            "custom_name",
            "uses_dynamic_name",
            "body",
            "priority",
            "due_date",
            "is_favorite_updated_at",
            "custom_name_updated_at",
            "uses_dynamic_name_updated_at",
            "body_updated_at",
            "priority_updated_at",
            "due_date_updated_at"
        ]
    }

    private var deferredWKFLW17SQLPatterns: [String] {
        [
            "\\blink\\b",
            "\\blinks\\b",
            "\\btag\\b",
            "\\btags\\b",
            "\\bassigned_time\\b",
            "\\bsubtask\\b",
            "\\bsubtasks\\b",
            "\\bdependency\\b",
            "\\bdependencies\\b",
            "\\bhidden_on_spreads\\b",
            "\\bhas_preferred_assignment\\b"
        ]
    }

    private func readRepositoryFile(_ relativePath: String) throws -> String {
        try String(contentsOf: repositoryRoot.appending(path: relativePath), encoding: .utf8)
    }

    private var repositoryRoot: URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 {
            url.deleteLastPathComponent()
        }
        return url
    }
}
