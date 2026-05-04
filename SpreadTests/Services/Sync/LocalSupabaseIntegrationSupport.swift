import Auth
import Foundation
import Supabase
import SwiftData
@testable import Spread

@MainActor
struct LocalSupabaseTestConfiguration {
    let supabaseURL: URL
    let publishableKey: String
    let serviceRoleKey: String
    let primaryEmail: String
    let secondaryEmail: String
    let password: String

    static func loadIfAvailable() throws -> LocalSupabaseTestConfiguration? {
        let envURL = repositoryRoot
            .appending(path: "supabase")
            .appending(path: "local")
            .appending(path: "test.env")

        guard FileManager.default.fileExists(atPath: envURL.path()) else {
            return nil
        }

        let contents = try String(contentsOf: envURL, encoding: .utf8)
        let values = contents
            .split(whereSeparator: \.isNewline)
            .reduce(into: [String: String]()) { result, rawLine in
                let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !line.isEmpty, !line.hasPrefix("#") else { return }
                let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
                guard parts.count == 2 else { return }
                result[parts[0]] = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }

        guard
            let urlString = values["SUPABASE_URL"],
            let url = URL(string: urlString),
            let publishableKey = values["SUPABASE_PUBLISHABLE_KEY"],
            let serviceRoleKey = values["SUPABASE_SERVICE_ROLE_KEY"],
            let primaryEmail = values["SPREAD_LOCAL_TEST_EMAIL_1"],
            let secondaryEmail = values["SPREAD_LOCAL_TEST_EMAIL_2"],
            let password = values["SPREAD_LOCAL_TEST_PASSWORD"]
        else {
            return nil
        }

        return LocalSupabaseTestConfiguration(
            supabaseURL: url,
            publishableKey: publishableKey,
            serviceRoleKey: serviceRoleKey,
            primaryEmail: primaryEmail,
            secondaryEmail: secondaryEmail,
            password: password
        )
    }

    func assertReachable() async throws {
        var request = URLRequest(url: supabaseURL.appending(path: "auth").appending(path: "v1").appending(path: "settings"))
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<500).contains(http.statusCode) else {
            throw URLError(.cannotConnectToHost)
        }
    }

    func makeAnonClient() -> SupabaseClient {
        Self.makeClient(url: supabaseURL, key: publishableKey)
    }

    func makeServiceRoleClient() -> SupabaseClient {
        Self.makeClient(url: supabaseURL, key: serviceRoleKey)
    }

    private static func makeClient(url: URL, key: String) -> SupabaseClient {
        SupabaseClient(
            supabaseURL: url,
            supabaseKey: key,
            options: SupabaseClientOptions(
                auth: .init(
                    storage: InMemoryAuthLocalStorage(),
                    autoRefreshToken: false
                )
            )
        )
    }

    private static var repositoryRoot: URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 {
            url.deleteLastPathComponent()
        }
        return url
    }
}

final class InMemoryAuthLocalStorage: AuthLocalStorage {
    private var storage: [String: Data] = [:]

    func store(key: String, value: Data) throws {
        storage[key] = value
    }

    func retrieve(key: String) throws -> Data? {
        storage[key]
    }

    func remove(key: String) throws {
        storage.removeValue(forKey: key)
    }
}

@MainActor
final class AlwaysConnectedNetworkMonitor: NetworkMonitoring {
    var isConnected: Bool = true
    var onConnectionChange: ((Bool) -> Void)?
}

struct RemoteAssignmentRow: Decodable {
    let id: UUID
    let status: String
    let period: String
    let date: String
    let spreadId: UUID?
    let deletedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case status
        case period
        case date
        case spreadId = "spread_id"
        case deletedAt = "deleted_at"
    }
}

@MainActor
struct LocalSupabaseAdmin {
    private let client: SupabaseClient

    init(configuration: LocalSupabaseTestConfiguration) {
        self.client = configuration.makeServiceRoleClient()
    }

    func clearAllData(for userId: UUID) async throws {
        try await client.from("task_assignments").delete().eq("user_id", value: userId.uuidString).execute()
        try await client.from("note_assignments").delete().eq("user_id", value: userId.uuidString).execute()
        try await client.from("tasks").delete().eq("user_id", value: userId.uuidString).execute()
        try await client.from("notes").delete().eq("user_id", value: userId.uuidString).execute()
        try await client.from("spreads").delete().eq("user_id", value: userId.uuidString).execute()
        try await client.from("collections").delete().eq("user_id", value: userId.uuidString).execute()
        try await client.from("settings").delete().eq("user_id", value: userId.uuidString).execute()
    }

    func deleteTaskAssignments(taskId: UUID, userId: UUID) async throws {
        try await client.from("task_assignments")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("task_id", value: taskId.uuidString)
            .execute()
    }

    func fetchTaskAssignments(taskId: UUID, userId: UUID) async throws -> [RemoteAssignmentRow] {
        try await client.from("task_assignments")
            .select("id, status, period, date, spread_id, deleted_at")
            .eq("user_id", value: userId.uuidString)
            .eq("task_id", value: taskId.uuidString)
            .execute()
            .value
    }
}

@MainActor
struct LocalSupabaseSyncHarness {
    let configuration: LocalSupabaseTestConfiguration
    let email: String
    let client: SupabaseClient
    let authManager: AuthManager
    let syncEngine: SyncEngine
    let journalManager: JournalManager
    let storeWiper: SwiftDataStoreWiper
    let modelContainer: ModelContainer

    static func make(
        configuration: LocalSupabaseTestConfiguration,
        email: String,
        deviceId: UUID = UUID(),
        calendar: Calendar = TestDataBuilders.testCalendar
    ) async throws -> LocalSupabaseSyncHarness {
        let modelContainer = try ModelContainerFactory.makeInMemory()
        let client = configuration.makeAnonClient()
        let authManager = AuthManager(service: SupabaseAuthService(client: client))
        let networkMonitor = AlwaysConnectedNetworkMonitor()

        let taskRepository = SwiftDataTaskRepository(modelContainer: modelContainer, deviceId: deviceId)
        let spreadRepository = SwiftDataSpreadRepository(modelContainer: modelContainer, deviceId: deviceId)
        let noteRepository = SwiftDataNoteRepository(modelContainer: modelContainer, deviceId: deviceId)
        let collectionRepository = SwiftDataCollectionRepository(modelContainer: modelContainer, deviceId: deviceId)

        let journalManager = try await JournalManager.make(
            calendar: calendar,
            today: TestDataBuilders.testDate,
            taskRepository: taskRepository,
            spreadRepository: spreadRepository,
            eventRepository: InMemoryEventRepository(),
            noteRepository: noteRepository,
            collectionRepository: collectionRepository,
            bujoMode: .conventional
        )

        let syncEngine = SyncEngine(
            client: client,
            modelContainer: modelContainer,
            authManager: authManager,
            networkMonitor: networkMonitor,
            deviceId: deviceId,
            isSyncEnabled: true
        )

        return LocalSupabaseSyncHarness(
            configuration: configuration,
            email: email,
            client: client,
            authManager: authManager,
            syncEngine: syncEngine,
            journalManager: journalManager,
            storeWiper: SwiftDataStoreWiper(modelContainer: modelContainer),
            modelContainer: modelContainer
        )
    }

    func signIn() async throws -> User {
        try await authManager.signIn(email: email, password: configuration.password)
        guard case .signedIn(let user) = authManager.state else {
            fatalError("Expected signed-in state after local Supabase sign-in")
        }
        return user
    }

    func syncAndReload() async {
        await syncEngine.syncNow()
        await journalManager.reload()
    }

    func wipeLocalAndRebuild() async throws {
        try await storeWiper.wipeAll()
        syncEngine.resetSyncState()
        await journalManager.reload()
        await syncAndReload()
    }
}
