import Foundation
import Testing

struct SPRD193MultidayAssignmentContractTests {
    /// Conditions: The committed baseline schema is inspected for SPRD-193's spread_id-based
    /// multiday assignment ownership, now expressed against the unified `assignments` table
    /// (post-SPRD-246; the original `task_assignments`/`note_assignments` tables no longer exist).
    /// Expected: spread_id columns/params, the assignments-table unique constraint, and the
    /// entry_id-keyed fallback lookup (with unique_violation handling) are present.
    @Test func schemaSnapshotsIncludeSpreadIDForAssignmentOwnership() throws {
        let migration = try readRepositoryFile("supabase/migrations/20260624000000_baseline_schema.sql")

        #expect(migration.contains("spread_id"))
        #expect(migration.contains("p_spread_id"))
        #expect(migration.contains("assignments_user_entry_multiday_spread_unique"))
        #expect(migration.contains("entry_id = p_entry_id"))
        #expect(migration.contains("WHEN unique_violation"))
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
