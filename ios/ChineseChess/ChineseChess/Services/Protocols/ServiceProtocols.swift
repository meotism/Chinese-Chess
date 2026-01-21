//
//  ServiceProtocols.swift
//  ChineseChess
//
//  Protocol definitions for all services in the application.
//

import Foundation
import Combine

// MARK: - AuthServiceProtocol

/// Protocol for authentication and user identity management.
protocol AuthServiceProtocol {
    /// The current device ID, if available
    var currentDeviceId: String? { get }

    /// The current user's display name
    var currentDisplayName: String { get }

    /// Initializes the auth service and returns the device identity.
    /// Creates a new identity if one doesn't exist.
    func initialize() async throws -> DeviceIdentity

    /// Updates the user's display name.
    ///
    /// - Parameter name: The new display name
    /// - Returns: True if the update was successful
    func updateDisplayName(_ name: String) async throws -> Bool

    /// Validates a display name without persisting it.
    ///
    /// - Parameter name: The display name to validate
    /// - Returns: The validation result
    func validateDisplayName(_ name: String) -> DisplayNameValidationResult
}

// MARK: - DatabaseServiceProtocol

/// Protocol for local database operations.
protocol DatabaseServiceProtocol {
    /// Initializes the database and runs any pending migrations.
    func initialize() async throws

    /// Performs a database migration to the specified version.
    func migrate(to version: Int) async throws

    // MARK: User Operations

    /// Saves a user to the database.
    func saveUser(_ user: User) async throws

    /// Retrieves a user by their device ID.
    func getUser(by id: String) async throws -> User?

    // MARK: Game Operations

    /// Saves a game record to the database.
    func saveGame(_ game: Game) async throws

    /// Retrieves a game by its ID.
    func getGame(by id: String) async throws -> Game?

    /// Retrieves game history with pagination.
    func getGameHistory(limit: Int, offset: Int) async throws -> [Game]

    /// Retrieves games filtered by result type.
    func getGamesByResult(_ result: GameResultOutcome) async throws -> [Game]

    // MARK: Move Operations

    /// Saves moves for a game.
    func saveMoves(_ moves: [Move], for gameId: String) async throws

    /// Retrieves all moves for a game.
    func getMoves(for gameId: String) async throws -> [Move]

    // MARK: Stats Operations

    /// Updates user statistics.
    func updateStats(_ stats: UserStats, for userId: String) async throws

    /// Retrieves user statistics.
    func getStats(for userId: String) async throws -> UserStats?
}

// MARK: - NetworkServiceProtocol

/// Protocol for network operations (REST API and WebSocket).
protocol NetworkServiceProtocol {
    /// The current connection state
    var connectionState: ConnectionState { get }

    /// Publisher for connection state changes
    var connectionStatePublisher: AnyPublisher<ConnectionState, Never> { get }

    // MARK: REST API - User

    /// Registers a new device with the server.
    func registerDevice(_ identity: DeviceIdentity, displayName: String) async throws -> User

    /// Fetches a user profile from the server.
    func fetchUserProfile(deviceId: String) async throws -> User

    /// Updates a user's display name on the server.
    func updateDisplayName(_ name: String, deviceId: String) async throws -> User

    // MARK: REST API - Match History

    /// Fetches match history with pagination.
    func fetchMatchHistory(page: Int, pageSize: Int) async throws -> [Game]

    /// Fetches user statistics from the server.
    func fetchUserStats(deviceId: String) async throws -> UserStats

    /// Fetches moves for a specific game.
    func fetchGameMoves(gameId: String) async throws -> [Move]

    // MARK: REST API - Matchmaking

    /// Joins the matchmaking queue.
    func joinMatchmaking(settings: MatchmakingSettings) async throws -> QueueStatus

    /// Leaves the matchmaking queue.
    func leaveMatchmaking() async throws

    /// Gets the current matchmaking status.
    func getMatchmakingStatus() async throws -> QueueStatus

    // MARK: WebSocket

    /// Connects to a game via WebSocket.
    func connectToGame(_ gameId: String) async throws

    /// Disconnects from the current game.
    func disconnect()

    /// Sends a move to the server.
    func sendMove(_ move: PendingMove) async throws

    /// Sends a rollback request.
    func sendRollbackRequest() async throws

    /// Responds to a rollback request.
    func respondToRollback(accept: Bool) async throws

    /// Offers a draw.
    func offerDraw() async throws

    /// Responds to a draw offer.
    func respondToDraw(accept: Bool) async throws

    /// Resigns the current game.
    func resign() async throws

    // MARK: Events

    /// Publisher for game events from the server
    var gameEventPublisher: AnyPublisher<GameEvent, Never> { get }
}

// MARK: - GameServiceProtocol

/// Protocol for game state management and logic.
protocol GameServiceProtocol {
    /// The current game state
    var currentState: GameState? { get }

    /// Publisher for game state changes
    var statePublisher: AnyPublisher<GameState?, Never> { get }

    /// Whether the game engine reports check
    var isCheck: Bool { get }

    /// Whether the game engine reports checkmate
    var isCheckmate: Bool { get }

    /// Whether the game engine reports stalemate
    var isStalemate: Bool { get }

    /// Gets valid moves for a piece at the given position.
    func getValidMoves(for position: Position) -> [Position]

    /// Attempts to make a move.
    func makeMove(from: Position, to: Position) async throws -> MoveResult

    /// Undoes the last move (for rollback).
    func undoLastMove() -> Bool

    /// Loads a game state (for reconnection or replay).
    func loadState(_ state: GameState)

    /// Resets to a new game.
    func resetGame()

    /// Creates a new online game.
    func createOnlineGame(opponentId: String, myColor: PlayerColor, settings: GameSettings) async throws -> Game

    /// Joins an existing online game.
    func joinOnlineGame(gameId: String) async throws

    /// Leaves the current online game.
    func leaveGame() async throws
}

// MARK: - GameEngineProtocol

/// Protocol for the game rules engine.
protocol GameEngineProtocol {
    /// The current game state
    var currentState: GameState { get }

    /// The history of all moves made
    var moveHistory: [Move] { get }

    /// Whether the current player is in check
    var isCheck: Bool { get }

    /// Whether the current player is in checkmate
    var isCheckmate: Bool { get }

    /// Whether the current player is in stalemate
    var isStalemate: Bool { get }

    /// Gets all valid moves for a piece at the given position.
    func getValidMoves(for position: Position) -> [Position]

    /// Attempts to make a move and returns the result.
    func makeMove(from: Position, to: Position) -> MoveResult

    /// Undoes the last move.
    func undoLastMove() -> Bool

    /// Loads a specific game state.
    func loadState(_ state: GameState)

    /// Resets to initial position.
    func resetGame()
}

// MARK: - AudioServiceProtocol

/// Protocol for audio and haptic feedback.
protocol AudioServiceProtocol {
    /// Whether sound effects are enabled
    var isSoundEnabled: Bool { get set }

    /// Whether haptic feedback is enabled
    var isHapticsEnabled: Bool { get set }

    /// Plays a sound effect.
    func playSound(_ sound: GameSound)

    /// Triggers haptic feedback.
    func triggerHaptic(_ type: HapticType)
}

/// Types of game sounds.
enum GameSound: String, CaseIterable {
    case pieceSelect
    case pieceMove
    case pieceCapture
    case check
    case checkmate
    case gameStart
    case gameWin
    case gameLose
    case gameDraw
    case buttonTap
    case timerWarning
    case timerUrgent
}

/// Types of haptic feedback.
enum HapticType {
    case light
    case medium
    case heavy
    case success
    case warning
    case error
    case selection
}

// MARK: - MatchmakingServiceProtocol

/// Protocol for matchmaking operations.
protocol MatchmakingServiceProtocol {
    /// The current queue status
    var queueStatus: QueueStatus { get }

    /// Publisher for queue status changes
    var queueStatusPublisher: AnyPublisher<QueueStatus, Never> { get }

    /// Joins the matchmaking queue.
    func joinQueue(settings: MatchmakingSettings) async throws

    /// Leaves the matchmaking queue.
    func leaveQueue() async throws

    /// Accepts a found match.
    func acceptMatch() async throws

    /// Declines a found match.
    func declineMatch() async throws
}
