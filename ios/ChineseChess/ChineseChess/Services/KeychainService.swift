//
//  KeychainService.swift
//  ChineseChess
//
//  Service for secure storage using iOS Keychain.
//

import Foundation
import Security

/// Service for securely storing and retrieving data from the iOS Keychain.
final class KeychainService {

    // MARK: - Constants

    private let serviceIdentifier = "com.xiangqi.chinesechess"
    private let deviceIdKey = "device_identifier"

    // MARK: - Public Methods

    /// Saves the device ID to the Keychain.
    ///
    /// - Parameter deviceId: The device identifier to save
    /// - Throws: KeychainError if the save fails
    func saveDeviceId(_ deviceId: String) throws {
        guard let data = deviceId.data(using: .utf8) else {
            throw KeychainError.saveFailed(errSecParam)
        }

        // First, try to delete any existing item
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: deviceIdKey
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Now add the new item
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: deviceIdKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    /// Retrieves the device ID from the Keychain.
    ///
    /// - Returns: The stored device ID, or nil if not found
    /// - Throws: KeychainError if there's an error other than item not found
    func getDeviceId() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: deviceIdKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let deviceId = String(data: data, encoding: .utf8) else {
                return nil
            }
            return deviceId

        case errSecItemNotFound:
            return nil

        default:
            throw KeychainError.readFailed(status)
        }
    }

    /// Deletes the device ID from the Keychain.
    ///
    /// - Throws: KeychainError if the delete fails
    func deleteDeviceId() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: deviceIdKey
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}
