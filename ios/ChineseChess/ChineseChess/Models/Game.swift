//
//  Game.swift
//  ChineseChess
//
//  Represents a game record with metadata.
//

import Foundation

// MARK: - GameStatus

/// The status of a game.
enum GameStatus: String, Codable, CaseIterable {
    /// Game is currently in progress
    case active

    /// Game has been completed normally
    case completed

    /// Game was abandoned (player disconnected)
    case abandoned
}

// MARK: - ResultType

/// The type of result that ended a game.
enum ResultType: String, Codable, CaseIterable {
    /// Game ended by checkmate
    case checkmate

    /// Game ended by timeout
    case timeout

    /// Game ended by resignation
    case resignation

    /// Game ended by abandonment (disconnect)
    case abandonment

    /// Game ended in a draw by agreement
    case draw

    /// Game ended by stalemate (loss for stalemated player in Xiangqi)
    case stalemate

    /// Human-readable description of the result
    var displayName: String {
        switch self {
        case .checkmate: return "Checkmate"
        case .timeout: return "Timeout"
        case .resignation: return "Resignation"
        case .abandonment: return "Abandonment"
        case .draw: return "Draw"
        case .stalemate: return "Stalemate"
        }
    }
}

// MARK: - Game

/// Represents a complete game record with metadata.
struct Game: Codable, Identifiable, Equatable {

    // MARK: - Properties

    /// Unique identifier for the game (UUID)
    let id: String

    /// The device ID of the Red player
    let redPlayerId: String

    /// The device ID of the Black player
    let blackPlayerId: String

    /// The current status of the game
    var status: GameStatus

    /// The device ID of the winner, if any
    var winnerId: String?

    /// The type of result that ended the game
    var resultType: ResultType?

    /// The turn timeout in seconds
    let turnTimeoutSeconds: Int

    /// When the game was created
    let createdAt: Date

    /// When the game was completed
    var completedAt: Date?

    /// The total number of moves made
    var totalMoves: Int

    /// Remaining rollbacks for Red player
    var redRollbacksRemaining: Int

    /// Remaining rollbacks for Black player
    var blackRollbacksRemaining: Int

    // MARK: - Computed Properties

    /// Returns the duration of the game in seconds, or nil if not completed
    var durationSeconds: Int? {
        guard let completedAt = completedAt else { return nil }
        return Int(completedAt.timeIntervalSince(createdAt))
    }

    /// Returns true if the game is still in progress
    var isActive: Bool {
        status == .active
    }

    /// Returns true if the game has ended
    var isEnded: Bool {
        status == .completed || status == .abandoned
    }

    // MARK: - Initialization

    /// Creates a new game.
    init(
        id: String = UUID().uuidString,
        redPlayerId: String,
        blackPlayerId: String,
        status: GameStatus = .active,
        winnerId: String? = nil,
        resultType: ResultType? = nil,
        turnTimeoutSeconds: Int = 300,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        totalMoves: Int = 0,
        redRollbacksRemaining: Int = 3,
        blackRollbacksRemaining: Int = 3
    ) {
        self.id = id
        self.redPlayerId = redPlayerId
        self.blackPlayerId = blackPlayerId
        self.status = status
        self.winnerId = winnerId
        self.resultType = resultType
        self.turnTimeoutSeconds = turnTimeoutSeconds
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.totalMoves = totalMoves
        self.redRollbacksRemaining = redRollbacksRemaining
        self.blackRollbacksRemaining = blackRollbacksRemaining
    }

    // MARK: - Methods

    /// Returns the player's color in this game.
    ///
    /// - Parameter playerId: The player's device ID
    /// - Returns: The player's color, or nil if not a participant
    func playerColor(for playerId: String) -> PlayerColor? {
        if playerId == redPlayerId {
            return .red
        } else if playerId == blackPlayerId {
            return .black
        }
        return nil
    }

    /// Returns the opponent's ID for a given player.
    ///
    /// - Parameter playerId: The player's device ID
    /// - Returns: The opponent's device ID, or nil if not a participant
    func opponentId(for playerId: String) -> String? {
        if playerId == redPlayerId {
            return blackPlayerId
        } else if playerId == blackPlayerId {
            return redPlayerId
        }
        return nil
    }

    /// Returns the remaining rollbacks for the specified player.
    ///
    /// - Parameter playerId: The player's device ID
    /// - Returns: The number of remaining rollbacks, or nil if not a participant
    func rollbacksRemaining(for playerId: String) -> Int? {
        if playerId == redPlayerId {
            return redRollbacksRemaining
        } else if playerId == blackPlayerId {
            return blackRollbacksRemaining
        }
        return nil
    }

    /// Returns true if the specified player won the game.
    ///
    /// - Parameter playerId: The player's device ID
    /// - Returns: True if the player won
    func didWin(playerId: String) -> Bool {
        winnerId == playerId
    }

    /// Returns true if the game was a draw.
    var isDraw: Bool {
        resultType == .draw && winnerId == nil
    }
}
