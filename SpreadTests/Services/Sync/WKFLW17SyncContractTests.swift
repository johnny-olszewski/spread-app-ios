import Foundation
import Testing

struct WKFLW17SyncContractTests {

    /// Conditions: The committed baseline schema (post-SPRD-246/239 squash; WKFLW-17's original
    /// migration file no longer exists as a separate artifact) is inspected for WKFLW-17 fields.
    /// Expected: Approved spread/task fields are present; deferred candidates that are still
    /// genuinely unimplemented do not appear as persisted columns or RPC args. `tag`/`tags` were
    /// dropped from the deferred list — they now legitimately exist via SPRD-221/246's
    /// `tags`/`entry_tags` tables, unrelated to WKFLW-17 scope.
    @Test func schemaSnapshotsIncludeApprovedFieldsAndNoDeferredCandidates() throws {
        let migration = try readRepositoryFile("supabase/migrations/20260624000000_baseline_schema.sql")

        for approvedField in approvedWKFLW17SQLFields {
            #expect(migration.contains(approvedField))
        }

        for deferredPattern in deferredWKFLW17SQLPatterns {
            #expect(
                migration.range(of: deferredPattern, options: [.regularExpression, .caseInsensitive]) == nil
            )
        }
    }

    /// Conditions: The merge RPC definitions are inspected for the approved metadata fields.
    /// Expected: Each independently mergeable field uses its own timestamp, and delete handling precedes metadata updates.
    @Test func mergeFunctionsUseIndependentConflictTimestampsAndDeleteWins() throws {
        let migration = try readRepositoryFile("supabase/migrations/20260624000000_baseline_schema.sql")

        #expect(migration.contains("IF p_deleted_at IS NOT NULL"))
        for field in ["is_favorite", "custom_name", "uses_dynamic_name", "body", "priority", "due_date"] {
            // Whitespace between tokens is alignment padding and may vary, so match it loosely.
            let pattern = "\(field)\\s*=\\s*CASE WHEN p_\(field)_updated_at\\s*>\\s*v_existing\\.\(field)_updated_at"
            #expect(migration.range(of: pattern, options: .regularExpression) != nil)
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
