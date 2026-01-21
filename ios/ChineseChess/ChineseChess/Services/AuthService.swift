//
//  AuthService.swift
//  ChineseChess
//
//  Service for user authentication and identity management.
//

import Foundation
import UIKit

/// Service for managing user authentication and device identity.
final class AuthService: AuthServiceProtocol {

    // MARK: - Properties

    private let keychainService: KeychainService
    private let networkService: NetworkServiceProtocol

    private var _currentDeviceId: String?
    private var _currentDisplayName: String = "Player"

    var currentDeviceId: String? {
        _currentDeviceId
    }

    var currentDisplayName: String {
        _currentDisplayName
    }

    // MARK: - Initialization

    init(keychainService: KeychainService, networkService: NetworkServiceProtocol) {
        self.keychainService = keychainService
        self.networkService = networkService
    }

    // MARK: - AuthServiceProtocol

    func initialize() async throws -> DeviceIdentity {
        // Try to retrieve existing device ID from Keychain
        if let existingId = try keychainService.getDeviceId() {
            _currentDeviceId = existingId

            // Fetch user profile from server or local storage
            do {
                let user = try await networkService.fetchUserProfile(deviceId: existingId)
                _currentDisplayName = user.displayName
                return DeviceIdentity(deviceId: existingId, createdAt: user.createdAt)
            } catch {
                // If network fails, use stored ID anyway
                return DeviceIdentity(deviceId: existingId, createdAt: Date())
            }
        }

        // Generate new device ID using IDFV
        let newDeviceId = generateDeviceId()

        // Save to Keychain
        try keychainService.saveDeviceId(newDeviceId)
        _currentDeviceId = newDeviceId

        // Generate default display name
        let displayName = generateDisplayName()
        _currentDisplayName = displayName

        // Register with server
        let identity = DeviceIdentity(deviceId: newDeviceId, createdAt: Date())

        do {
            let user = try await networkService.registerDevice(identity, displayName: displayName)
            _currentDisplayName = user.displayName
        } catch {
            // Registration failed, but we can still use local identity
            // Will retry registration later
            #if DEBUG
            print("Registration failed: \(error)")
            #endif
        }

        return identity
    }

    func updateDisplayName(_ name: String) async throws -> Bool {
        // Validate first
        let validation = validateDisplayName(name)
        guard validation.isValid else {
            if case .invalid(let reason) = validation {
                throw AuthError.invalidDisplayName(reason)
            }
            return false
        }

        guard let deviceId = currentDeviceId else {
            throw AuthError.noDeviceId
        }

        // Update on server
        let updatedUser = try await networkService.updateDisplayName(name, deviceId: deviceId)
        _currentDisplayName = updatedUser.displayName

        return true
    }

    func validateDisplayName(_ name: String) -> DisplayNameValidationResult {
        User.validateDisplayName(name)
    }

    // MARK: - Private Methods

    /// Generates a unique device identifier using IDFV.
    private func generateDeviceId() -> String {
        // Use identifierForVendor (IDFV) as the base
        if let idfv = UIDevice.current.identifierForVendor?.uuidString {
            return idfv
        }

        // Fallback to a generated UUID if IDFV is not available
        return UUID().uuidString
    }

    /// Generates a random default display name.
    private func generateDisplayName() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let randomSuffix = String((0..<4).compactMap { _ in
            characters.randomElement()
        })
        return "Player_\(randomSuffix)"
    }
}
