//
//  AppError.swift
//  ChineseChess
//
//  Application error types for comprehensive error handling.
//

import Foundation

// MARK: - AppError

/// Top-level application error type.
enum AppError: LocalizedError {
    /// Error during app initialization
    case initialization(Error)

    /// Network-related error
    case network(NetworkError)

    /// Database-related error
    case database(DatabaseError)

    /// Game logic error
    case game(GameError)

    /// Authentication error
    case auth(AuthError)

    var errorDescription: String? {
        switch self {
        case .initialization(let error):
            return "Initialization failed: \(error.localizedDescription)"
        case .network(let error):
            return error.localizedDescription
        case .database(let error):
            return error.localizedDescription
        case .game(let error):
            return error.localizedDescription
        case .auth(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - NetworkError

/// Errors related to network operations.
enum NetworkError: LocalizedError {
    /// No internet connection
    case noConnection

    /// Request timed out
    case timeout

    /// Server returned an error
    case serverError(statusCode: Int, message: String?)

    /// Invalid response from server
    case invalidResponse

    /// Failed to encode request
    case encodingError

    /// Failed to decode response
    case decodingError(Error)

    /// WebSocket disconnected
    case websocketDisconnected

    /// WebSocket connection failed
    case websocketConnectionFailed(Error)

    /// Rate limited
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No internet connection. Please check your network settings."
        case .timeout:
            return "Request timed out. Please try again."
        case .serverError(let code, let message):
            if let message = message {
                return "Server error (\(code)): \(message)"
            }
            return "Server error (\(code)). Please try again later."
        case .invalidResponse:
            return "Invalid response from server."
        case .encodingError:
            return "Failed to prepare request."
        case .decodingError:
            return "Failed to process server response."
        case .websocketDisconnected:
            return "Connection to game server lost."
        case .websocketConnectionFailed:
            return "Failed to connect to game server."
        case .rateLimited:
            return "Too many requests. Please wait a moment."
        }
    }

    /// Returns true if this error might be resolved by retrying.
    var isRetryable: Bool {
        switch self {
        case .noConnection, .timeout, .serverError, .websocketDisconnected:
            return true
        case .invalidResponse, .encodingError, .decodingError, .websocketConnectionFailed, .rateLimited:
            return false
        }
    }
}

// MARK: - DatabaseError

/// Errors related to database operations.
enum DatabaseError: LocalizedError {
    /// Database initialization failed
    case initializationFailed(Error)

    /// Database migration failed
    case migrationFailed(Error)

    /// Record not found
    case notFound

    /// Database is corrupted
    case corrupted

    /// Write operation failed
    case writeFailed(Error)

    /// Read operation failed
    case readFailed(Error)

    var errorDescription: String? {
        switch self {
        case .initializationFailed(let error):
            return "Failed to initialize database: \(error.localizedDescription)"
        case .migrationFailed(let error):
            return "Database migration failed: \(error.localizedDescription)"
        case .notFound:
            return "Record not found."
        case .corrupted:
            return "Database is corrupted. Please reinstall the app."
        case .writeFailed(let error):
            return "Failed to save data: \(error.localizedDescription)"
        case .readFailed(let error):
            return "Failed to load data: \(error.localizedDescription)"
        }
    }
}

// MARK: - GameError

/// Errors related to game logic.
enum GameError: LocalizedError {
    /// Invalid move attempted
    case invalidMove(reason: String)

    /// Not the player's turn
    case notYourTurn

    /// Game has already ended
    case gameEnded

    /// Opponent disconnected
    case opponentDisconnected

    /// Rollback request was denied
    case rollbackDenied

    /// No rollbacks remaining
    case noRollbacksRemaining

    /// Game state is out of sync
    case stateOutOfSync

    /// Game not found
    case gameNotFound

    var errorDescription: String? {
        switch self {
        case .invalidMove(let reason):
            return "Invalid move: \(reason)"
        case .notYourTurn:
            return "It's not your turn."
        case .gameEnded:
            return "This game has already ended."
        case .opponentDisconnected:
            return "Your opponent has disconnected."
        case .rollbackDenied:
            return "Your rollback request was denied."
        case .noRollbacksRemaining:
            return "You have no rollbacks remaining."
        case .stateOutOfSync:
            return "Game state is out of sync. Please reconnect."
        case .gameNotFound:
            return "Game not found."
        }
    }
}

// MARK: - AuthError

/// Errors related to authentication.
enum AuthError: LocalizedError {
    /// No device ID available
    case noDeviceId

    /// Keychain access error
    case keychainError(Error)

    /// Registration failed
    case registrationFailed(Error)

    /// Invalid display name
    case invalidDisplayName(String)

    var errorDescription: String? {
        switch self {
        case .noDeviceId:
            return "Unable to identify device. Please restart the app."
        case .keychainError(let error):
            return "Secure storage error: \(error.localizedDescription)"
        case .registrationFailed(let error):
            return "Registration failed: \(error.localizedDescription)"
        case .invalidDisplayName(let reason):
            return "Invalid display name: \(reason)"
        }
    }
}

// MARK: - KeychainError

/// Specific errors for Keychain operations.
enum KeychainError: LocalizedError {
    /// Failed to save to Keychain
    case saveFailed(OSStatus)

    /// Failed to read from Keychain
    case readFailed(OSStatus)

    /// Failed to delete from Keychain
    case deleteFailed(OSStatus)

    /// Item not found
    case itemNotFound

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save to secure storage (error \(status))"
        case .readFailed(let status):
            return "Failed to read from secure storage (error \(status))"
        case .deleteFailed(let status):
            return "Failed to delete from secure storage (error \(status))"
        case .itemNotFound:
            return "Item not found in secure storage"
        }
    }
}
