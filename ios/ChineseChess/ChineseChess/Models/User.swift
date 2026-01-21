//
//  User.swift
//  ChineseChess
//
//  Represents a user/player in the system.
//

import Foundation

// MARK: - DeviceIdentity

/// Represents the device identity used for authentication.
struct DeviceIdentity: Codable, Equatable {
    /// The unique device identifier (IDFV)
    let deviceId: String

    /// When the identity was first created
    let createdAt: Date

    /// Creates a new device identity.
    init(deviceId: String, createdAt: Date = Date()) {
        self.deviceId = deviceId
        self.createdAt = createdAt
    }
}

// MARK: - UserStats

/// Statistics for a user's gameplay history.
struct UserStats: Codable, Equatable {
    /// Total number of games played
    var totalGames: Int

    /// Number of games won
    var wins: Int

    /// Number of games lost
    var losses: Int

    /// Number of games drawn
    var draws: Int

    /// Calculated win percentage (0-100)
    var winPercentage: Double {
        guard totalGames > 0 else { return 0 }
        return Double(wins) / Double(totalGames) * 100
    }

    /// Creates empty stats for a new user.
    static var empty: UserStats {
        UserStats(totalGames: 0, wins: 0, losses: 0, draws: 0)
    }

    /// Creates new stats.
    init(totalGames: Int, wins: Int, losses: Int, draws: Int) {
        self.totalGames = totalGames
        self.wins = wins
        self.losses = losses
        self.draws = draws
    }

    /// Returns updated stats after a game result.
    func updated(with result: GameResult) -> UserStats {
        var newStats = self
        newStats.totalGames += 1
        switch result {
        case .win:
            newStats.wins += 1
        case .loss:
            newStats.losses += 1
        case .draw:
            newStats.draws += 1
        }
        return newStats
    }
}

// MARK: - GameResult (for stats)

/// A simple representation of a game result for updating stats.
enum GameResultOutcome: String, Codable, CaseIterable {
    case win
    case loss
    case draw
}

/// Alias for GameResultOutcome used in stats update.
typealias GameResult = GameResultOutcome

// MARK: - User

/// Represents a user/player in the system.
struct User: Codable, Identifiable, Equatable {

    // MARK: - Properties

    /// The unique identifier (device ID)
    let id: String

    /// The user's display name
    var displayName: String

    /// When the user was created
    let createdAt: Date

    /// When the user was last updated
    var updatedAt: Date

    /// The user's gameplay statistics
    var stats: UserStats

    // MARK: - Initialization

    /// Creates a new user.
    init(
        id: String,
        displayName: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        stats: UserStats = .empty
    ) {
        self.id = id
        self.displayName = displayName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.stats = stats
    }

    /// Creates a new user with a generated display name.
    ///
    /// - Parameter deviceId: The device identifier
    /// - Returns: A new user with a random display name
    static func createNew(deviceId: String) -> User {
        let randomSuffix = String((0..<4).map { _ in
            "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()!
        })
        let displayName = "Player_\(randomSuffix)"

        return User(
            id: deviceId,
            displayName: displayName,
            stats: .empty
        )
    }
}

// MARK: - Display Name Validation

/// Result of validating a display name.
enum DisplayNameValidationResult: Equatable {
    /// The display name is valid
    case valid

    /// The display name is invalid with a reason
    case invalid(reason: String)

    /// Returns true if the validation passed
    var isValid: Bool {
        if case .valid = self {
            return true
        }
        return false
    }
}

extension User {
    /// Validates a display name.
    ///
    /// Display names must be:
    /// - 3-20 characters long
    /// - Contain only alphanumeric characters, underscores, and hyphens
    /// - Not contain offensive content
    ///
    /// - Parameter name: The display name to validate
    /// - Returns: The validation result
    static func validateDisplayName(_ name: String) -> DisplayNameValidationResult {
        // Length check
        guard name.count >= 3 else {
            return .invalid(reason: "Display name must be at least 3 characters")
        }

        guard name.count <= 20 else {
            return .invalid(reason: "Display name must be at most 20 characters")
        }

        // Character set check
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        guard name.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else {
            return .invalid(reason: "Display name can only contain letters, numbers, underscores, and hyphens")
        }

        // Basic profanity filter (would be more comprehensive in production)
        let lowercaseName = name.lowercased()
        let blockedWords = ["admin", "moderator", "system", "null", "undefined"]
        for word in blockedWords {
            if lowercaseName.contains(word) {
                return .invalid(reason: "Display name contains a reserved word")
            }
        }

        return .valid
    }
}

// MARK: - Rollback

/// Represents a rollback request in a game.
struct RollbackRequest: Codable, Identifiable, Equatable {

    // MARK: - Properties

    /// Unique identifier for the rollback request
    let id: Int

    /// The game this rollback belongs to
    let gameId: String

    /// The player requesting the rollback
    let requestingPlayerId: String

    /// The move number being reverted
    let moveNumberToRevert: Int

    /// The status of the rollback request
    var status: RollbackStatus

    /// When the request was made
    let timestamp: Date

    // MARK: - Initialization

    init(
        id: Int,
        gameId: String,
        requestingPlayerId: String,
        moveNumberToRevert: Int,
        status: RollbackStatus = .pending,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.gameId = gameId
        self.requestingPlayerId = requestingPlayerId
        self.moveNumberToRevert = moveNumberToRevert
        self.status = status
        self.timestamp = timestamp
    }
}

/// The status of a rollback request.
enum RollbackStatus: String, Codable, CaseIterable {
    /// Request is pending opponent response
    case pending

    /// Request was accepted
    case accepted

    /// Request was declined
    case declined

    /// Request expired (30 second timeout)
    case expired
}
