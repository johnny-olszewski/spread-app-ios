import Foundation
import Security

/// Manages a unique device identifier stored in the Keychain.
///
/// The device ID is generated once per device and persists across app
/// reinstalls. It's used to track which device made changes during sync.
enum DeviceIdManager {

    // MARK: - Constants

    /// The Keychain service identifier.
    private static let service = "com.spread.deviceId"

    /// The Keychain account identifier.
    private static let account = "deviceId"

    // MARK: - Public Interface

    /// Returns the device ID, creating one if it doesn't exist.
    ///
    /// The device ID is stored in the Keychain and persists across app reinstalls.
    /// - Returns: The device's unique identifier.
    static func getOrCreateDeviceId() -> UUID {
        if let existingId = getDeviceId() {
            return existingId
        }

        let newId = UUID()
        saveDeviceId(newId)
        return newId
    }

    /// Returns the current device ID, if one exists.
    ///
    /// - Returns: The stored device ID, or `nil` if none exists.
    static func getDeviceId() -> UUID? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let uuidString = String(data: data, encoding: .utf8),
              let uuid = UUID(uuidString: uuidString) else {
            return nil
        }

        return uuid
    }

    // MARK: - Private Helpers

    /// Saves a device ID to the Keychain.
    private static func saveDeviceId(_ uuid: UUID) {
        let data = uuid.uuidString.data(using: .utf8)!

        // First try to update existing item
        let updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let updateAttributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)

        if updateStatus == errSecItemNotFound {
            // Item doesn't exist, create it
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
            ]

            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    /// Deletes the device ID from the Keychain.
    ///
    /// This is primarily for testing purposes.
    static func deleteDeviceId() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)
    }
}
