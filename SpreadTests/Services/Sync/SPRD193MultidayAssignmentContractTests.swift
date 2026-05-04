import Foundation
import Testing

struct SPRD193MultidayAssignmentContractTests {
    @Test func schemaSnapshotsIncludeSpreadIDForAssignmentOwnership() throws {
        let migration = try readRepositoryFile("supabase/migrations/20260503000000_sprd193_multiday_assignment_spread_id.sql")
        let snapshot = try readRepositoryFile("supabase/local/public_schema_from_dev.sql")

        for sql in [migration, snapshot] {
            #expect(sql.contains("spread_id"))
            #expect(sql.contains("p_spread_id"))
            #expect(sql.contains("task_assignments_user_task_multiday_spread_unique"))
            #expect(sql.contains("note_assignments_user_note_multiday_spread_unique"))
            #expect(sql.contains("task_id = p_task_id"))
            #expect(sql.contains("note_id = p_note_id"))
            #expect(sql.contains("WHEN unique_violation"))
        }
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
