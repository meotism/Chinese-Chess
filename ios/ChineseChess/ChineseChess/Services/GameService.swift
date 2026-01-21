//
//  GameService.swift
//  ChineseChess
//
//  Service for managing game state and coordinating with the network.
//

import Foundation
import Combine

/// Service for managing game state and coordinating with network services.
///
/// This service acts as the coordinator between:
/// - The local game engine (for move validation and state management)
/// - The network service (for multiplayer synchronization)
/// - The database service (for persistence)
final class GameService: GameServiceProtocol {

    // MARK: - Properties

    private let networkService: NetworkServiceProtocol
    private let databaseService: DatabaseServiceProtocol

    private var gameEngine: GameEngineProtocol?
    private var currentGame: Game?
    private var cancellables = Set<AnyCancellable>()

    private let stateSubject = CurrentValueSubject<GameState?, Never>(nil)

    var currentState: GameState? {
        gameEngine?.currentState
    }

    var statePublisher: AnyPublisher<GameState?, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    var isCheck: Bool {
        gameEngine?.isCheck ?? false
    }

    var isCheckmate: Bool {
        gameEngine?.isCheckmate ?? false
    }

    var isStalemate: Bool {
        gameEngine?.isStalemate ?? false
    }

    // MARK: - Initialization

    init(networkService: NetworkServiceProtocol, databaseService: DatabaseServiceProtocol) {
        self.networkService = networkService
        self.databaseService = databaseService

        setupEventSubscription()
    }

    // MARK: - GameServiceProtocol

    func getValidMoves(for position: Position) -> [Position] {
        gameEngine?.getValidMoves(for: position) ?? []
    }

    func makeMove(from: Position, to: Position) async throws -> MoveResult {
        guard let engine = gameEngine else {
            return .invalid(reason: "Game not initialized")
        }

        // Validate move locally first
        let result = engine.makeMove(from: from, to: to)

        guard result.isSuccess else {
            return result
        }

        // Send move to server if online game
        if currentGame != nil {
            guard let piece = currentState?.piece(at: to) else {
                return .invalid(reason: "Piece not found after move")
            }

            let capturedPiece = currentState?.piece(at: to)
            let pendingMove = PendingMove(
                piece: piece,
                from: from,
                to: to,
                capturedPiece: capturedPiece
            )

            try await networkService.sendMove(pendingMove)
        }

        stateSubject.send(engine.currentState)
        return result
    }

    func undoLastMove() -> Bool {
        let result = gameEngine?.undoLastMove() ?? false
        if result, let state = gameEngine?.currentState {
            stateSubject.send(state)
        }
        return result
    }

    func loadState(_ state: GameState) {
        gameEngine?.loadState(state)
        stateSubject.send(state)
    }

    func resetGame() {
        gameEngine?.resetGame()
        if let state = gameEngine?.currentState {
            stateSubject.send(state)
        }
    }

    func createOnlineGame(opponentId: String, myColor: PlayerColor, settings: GameSettings) async throws -> Game {
        // Create game record
        let game: Game
        if myColor == .red {
            game = Game(
                redPlayerId: "current_device_id", // TODO: Get from auth service
                blackPlayerId: opponentId,
                turnTimeoutSeconds: settings.turnTimeout.rawValue
            )
        } else {
            game = Game(
                redPlayerId: opponentId,
                blackPlayerId: "current_device_id", // TODO: Get from auth service
                turnTimeoutSeconds: settings.turnTimeout.rawValue
            )
        }

        currentGame = game

        // Initialize game engine
        gameEngine = GameEngine()
        stateSubject.send(gameEngine?.currentState)

        return game
    }

    func joinOnlineGame(gameId: String) async throws {
        // Connect via WebSocket
        try await networkService.connectToGame(gameId)

        // Initialize game engine (state will be synced from server)
        gameEngine = GameEngine()
    }

    func leaveGame() async throws {
        networkService.disconnect()
        currentGame = nil
        gameEngine = nil
        stateSubject.send(nil)
    }

    // MARK: - Private Methods

    private func setupEventSubscription() {
        networkService.gameEventPublisher
            .sink { [weak self] event in
                self?.handleGameEvent(event)
            }
            .store(in: &cancellables)
    }

    private func handleGameEvent(_ event: GameEvent) {
        switch event {
        case .moveMade(let moveInfo):
            // Update local state with opponent's move
            handleOpponentMove(moveInfo)

        case .rollbackResponded(let accepted, let newState):
            if accepted, let state = newState {
                loadState(state)
            }

        case .gameEnded(let result):
            handleGameEnd(result)

        default:
            break
        }
    }

    private func handleOpponentMove(_ moveInfo: MoveInfo) {
        guard let from = Position(notation: moveInfo.from),
              let to = Position(notation: moveInfo.to) else {
            return
        }

        // Apply move to local engine
        _ = gameEngine?.makeMove(from: from, to: to)
        stateSubject.send(gameEngine?.currentState)
    }

    private func handleGameEnd(_ result: GameEndInfo) {
        guard var game = currentGame else { return }

        game.status = .completed
        game.winnerId = result.winnerId
        game.resultType = result.resultType
        game.completedAt = Date()

        currentGame = game

        // Save to database
        Task {
            try? await databaseService.saveGame(game)
        }
    }
}

// MARK: - GameEngine (Placeholder)

/// Basic game engine implementation for local move validation.
/// Full implementation will be in a separate file.
final class GameEngine: GameEngineProtocol {

    private(set) var currentState: GameState
    private(set) var moveHistory: [Move] = []

    var isCheck: Bool { currentState.isCheck }
    var isCheckmate: Bool { false } // TODO: Implement
    var isStalemate: Bool { false } // TODO: Implement

    init() {
        currentState = GameState.initial()
    }

    func getValidMoves(for position: Position) -> [Position] {
        // TODO: Implement full move validation
        return []
    }

    func makeMove(from: Position, to: Position) -> MoveResult {
        // TODO: Implement full move execution
        return .invalid(reason: "Not implemented")
    }

    func undoLastMove() -> Bool {
        // TODO: Implement undo
        return false
    }

    func loadState(_ state: GameState) {
        currentState = state
    }

    func resetGame() {
        currentState = GameState.initial()
        moveHistory = []
    }
}
