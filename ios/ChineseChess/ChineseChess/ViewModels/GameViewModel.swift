//
//  GameViewModel.swift
//  ChineseChess
//
//  ViewModel for managing game state, moves, and timer.
//

import Foundation
import Combine

/// ViewModel for the game board screen.
@MainActor
final class GameViewModel: ObservableObject {

    // MARK: - Published Properties

    /// The current game state
    @Published private(set) var gameState: GameState

    /// The currently selected position
    @Published private(set) var selectedPosition: Position?

    /// Valid moves for the selected piece
    @Published private(set) var validMoves: [Position] = []

    /// The last move made
    @Published private(set) var lastMove: Move?

    /// Whether the game is over
    @Published private(set) var isGameOver = false

    /// Whether the current player won
    @Published private(set) var didWin = false

    /// Whether the game ended in a draw
    @Published private(set) var isDraw = false

    /// The result type of the game
    @Published private(set) var resultType: ResultType?

    /// Total moves made in the game
    @Published private(set) var totalMoves = 0

    /// Connection state for online games
    @Published private(set) var connectionState: ConnectionState = .connected

    /// Whether there is a pending rollback request from opponent
    @Published var pendingRollbackRequest = false

    /// My remaining time in seconds
    @Published private(set) var myTimeRemaining: Int

    /// Opponent remaining time in seconds
    @Published private(set) var opponentTimeRemaining: Int

    /// My remaining rollbacks
    @Published private(set) var myRollbacksRemaining = 3

    /// Opponent remaining rollbacks
    @Published private(set) var opponentRollbacksRemaining = 3

    /// Whether there is a pending draw offer
    @Published var pendingDrawOffer = false

    /// Whether timer warning has been triggered
    @Published private(set) var isTimerWarning = false

    // MARK: - Properties

    /// The game identifier
    let gameId: String

    /// My assigned color
    let myColor: PlayerColor

    /// Opponent's name
    let opponentName: String

    /// The game engine
    private var engine: GameEngine

    /// Timer for the countdown
    private var timer: AnyCancellable?

    /// Start time of the game
    private let gameStartTime = Date()

    /// Default turn timeout in seconds
    private let turnTimeout: Int

    /// Audio service for sound effects
    private let audioService = AudioService.shared

    /// Timer warning threshold (seconds)
    private let timerWarningThreshold = 30

    /// Timer urgent threshold (seconds)
    private let timerUrgentThreshold = 10

    // MARK: - Computed Properties

    /// The opponent's color
    var opponentColor: PlayerColor {
        myColor.opposite
    }

    /// The current turn color
    var currentTurn: PlayerColor {
        gameState.currentTurn
    }

    /// Whether the player is in check
    var isCheck: Bool {
        gameState.isCheck && gameState.currentTurn == myColor
    }

    /// Whether the game has ended in checkmate
    var isCheckmate: Bool {
        engine.isCheckmate
    }

    /// Whether the game has ended in stalemate
    var isStalemate: Bool {
        engine.isStalemate
    }

    /// Whether the player can request a rollback
    var canRequestRollback: Bool {
        myRollbacksRemaining > 0 &&
        currentTurn == opponentColor &&
        !isGameOver &&
        totalMoves > 0
    }

    /// Pieces captured by the player (opponent's pieces)
    var myCapturedPieces: [Piece] {
        myColor == .red ? gameState.capturedByRed : gameState.capturedByBlack
    }

    /// Pieces captured by the opponent (player's pieces)
    var opponentCapturedPieces: [Piece] {
        myColor == .red ? gameState.capturedByBlack : gameState.capturedByRed
    }

    /// Game duration formatted as string
    var gameDuration: String {
        let elapsed = Int(Date().timeIntervalSince(gameStartTime))
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Initialization

    init(gameId: String, myColor: PlayerColor, opponentName: String, turnTimeout: Int = 300) {
        self.gameId = gameId
        self.myColor = myColor
        self.opponentName = opponentName
        self.turnTimeout = turnTimeout
        self.myTimeRemaining = turnTimeout
        self.opponentTimeRemaining = turnTimeout

        // Initialize game engine
        self.engine = GameEngine(
            gameId: gameId,
            redPlayerId: myColor == .red ? "me" : "opponent",
            blackPlayerId: myColor == .black ? "me" : "opponent"
        )
        self.gameState = engine.currentState

        // Play game start sound
        audioService.playGameStart()

        // Start timer
        startTimer()
    }

    // MARK: - User Interaction

    /// Handles a tap on a board position.
    func handlePositionTapped(_ position: Position) {
        // Cannot interact if not our turn or game is over
        guard currentTurn == myColor && !isGameOver else { return }

        if let selected = selectedPosition {
            // If tapping a valid move destination, make the move
            if validMoves.contains(position) {
                makeMove(from: selected, to: position)
                return
            }

            // If tapping the same piece, deselect
            if selected == position {
                clearSelection()
                return
            }
        }

        // Try to select a piece at this position
        if let piece = gameState.piece(at: position), piece.color == myColor {
            selectPiece(at: position)
        } else {
            clearSelection()
        }
    }

    /// Selects a piece at the given position.
    private func selectPiece(at position: Position) {
        selectedPosition = position
        validMoves = engine.getLegalMoves(from: position)

        // Play piece select sound
        audioService.playPieceSelect()
    }

    /// Clears the current selection.
    private func clearSelection() {
        selectedPosition = nil
        validMoves = []
    }

    /// Makes a move from one position to another.
    private func makeMove(from: Position, to: Position) {
        let playerId = myColor == .red ? engine.redPlayerId : engine.blackPlayerId
        let result = engine.makeMove(playerId: playerId, from: from, to: to)

        switch result {
        case .success(let moveResult):
            applyMoveResult(moveResult)
        case .invalid(let reason):
            DebugLog.game("Invalid move: \(reason)")
        }

        clearSelection()
    }

    /// Applies the result of a successful move.
    private func applyMoveResult(_ result: GameMoveResult) {
        gameState = engine.currentState
        lastMove = result.move
        totalMoves = gameState.moveHistory.count

        // Play appropriate sound based on move result
        if result.capturedPiece != nil {
            audioService.playPieceCapture()
        } else {
            audioService.playPieceMove()
        }

        // Play check sound if applicable
        if result.isCheck && !result.isCheckmate {
            // Delay slightly so capture/move sound plays first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.audioService.playCheck()
            }
        }

        // Reset timer for the player who just moved
        if currentTurn == myColor {
            opponentTimeRemaining = turnTimeout
        } else {
            myTimeRemaining = turnTimeout
        }

        // Reset timer warning state
        isTimerWarning = false

        // Check for game end
        if result.isCheckmate {
            endGame(winner: myColor, resultType: .checkmate)
        } else if result.isStalemate {
            endGame(winner: myColor, resultType: .stalemate)
        }

        // TODO: Send move to server via WebSocket
    }

    // MARK: - Timer

    /// Starts the game timer.
    private func startTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateTimer()
            }
    }

    /// Updates the timer each second.
    private func updateTimer() {
        guard !isGameOver else {
            timer?.cancel()
            return
        }

        if currentTurn == myColor {
            myTimeRemaining -= 1

            // Play timer warning sounds
            if myTimeRemaining == timerWarningThreshold {
                isTimerWarning = true
                audioService.playTimerWarning()
            } else if myTimeRemaining <= timerUrgentThreshold && myTimeRemaining > 0 {
                audioService.playTimerUrgent()
            }

            if myTimeRemaining <= 0 {
                endGame(winner: opponentColor, resultType: .timeout)
            }
        } else {
            opponentTimeRemaining -= 1
            if opponentTimeRemaining <= 0 {
                endGame(winner: myColor, resultType: .timeout)
            }
        }
    }

    // MARK: - Game Actions

    /// Requests a rollback of the last move.
    func requestRollback() {
        guard canRequestRollback else { return }
        // TODO: Send rollback request via WebSocket
        DebugLog.game("Rollback requested")
    }

    /// Responds to an opponent's rollback request.
    func respondToRollback(accept: Bool) {
        pendingRollbackRequest = false

        if accept {
            // Undo the last move
            if engine.undoLastMove() {
                gameState = engine.currentState
                lastMove = gameState.moveHistory.last
                totalMoves = gameState.moveHistory.count
                opponentRollbacksRemaining -= 1
            }
        }

        // TODO: Send response via WebSocket
    }

    /// Offers a draw to the opponent.
    func offerDraw() {
        // TODO: Send draw offer via WebSocket
        DebugLog.game("Draw offered")
    }

    /// Responds to an opponent's draw offer.
    func respondToDrawOffer(accept: Bool) {
        if accept {
            endGame(winner: nil, resultType: .draw)
        }
        // TODO: Send response via WebSocket
    }

    /// Resigns the game.
    func resign() {
        endGame(winner: opponentColor, resultType: .resignation)
        // TODO: Send resignation via WebSocket
    }

    // MARK: - Game End

    /// Ends the game with the specified result.
    private func endGame(winner: PlayerColor?, resultType: ResultType) {
        isGameOver = true
        self.resultType = resultType

        if let winner = winner {
            didWin = winner == myColor
            isDraw = false

            // Play victory or defeat sound
            if didWin {
                if resultType == .checkmate {
                    audioService.playCheckmate()
                } else {
                    audioService.playVictory()
                }
            } else {
                audioService.playDefeat()
            }
        } else {
            isDraw = true
            didWin = false
            audioService.playDraw()
        }

        timer?.cancel()
    }

    // MARK: - Network Events

    /// Handles an opponent's move received from the server.
    func handleOpponentMove(from: Position, to: Position) {
        let playerId = opponentColor == .red ? engine.redPlayerId : engine.blackPlayerId
        let result = engine.makeMove(playerId: playerId, from: from, to: to)

        switch result {
        case .success(let moveResult):
            gameState = engine.currentState
            lastMove = moveResult.move
            totalMoves = gameState.moveHistory.count

            // Reset opponent's timer
            opponentTimeRemaining = turnTimeout

            // Check for game end
            if moveResult.isCheckmate {
                endGame(winner: opponentColor, resultType: .checkmate)
            } else if moveResult.isStalemate {
                endGame(winner: opponentColor, resultType: .stalemate)
            }

        case .invalid(let reason):
            DebugLog.game("Invalid opponent move: \(reason)")
        }
    }

    /// Handles connection state changes.
    func handleConnectionStateChange(_ state: ConnectionState) {
        connectionState = state

        // Handle reconnection-specific logic
        switch state {
        case .reconnecting:
            // Pause local timer during reconnection
            timer?.cancel()

        case .connected:
            // Resume timer if game is not over
            if !isGameOver {
                startTimer()
            }

        default:
            break
        }
    }

    /// Handles timer updates from the server.
    func handleTimerUpdate(redTime: Int, blackTime: Int) {
        if myColor == .red {
            myTimeRemaining = redTime
            opponentTimeRemaining = blackTime
        } else {
            myTimeRemaining = blackTime
            opponentTimeRemaining = redTime
        }
    }

    // MARK: - Reconnection Handling

    /// Synchronizes game state after reconnection.
    func syncStateFromServer(_ serverState: ServerGameState) {
        // Update timer from server
        if myColor == .red {
            myTimeRemaining = serverState.redTime
            opponentTimeRemaining = serverState.blackTime
        } else {
            myTimeRemaining = serverState.blackTime
            opponentTimeRemaining = serverState.redTime
        }

        // Update rollback counts
        if myColor == .red {
            myRollbacksRemaining = serverState.redRollbacksRemaining
            opponentRollbacksRemaining = serverState.blackRollbacksRemaining
        } else {
            myRollbacksRemaining = serverState.blackRollbacksRemaining
            opponentRollbacksRemaining = serverState.redRollbacksRemaining
        }

        // Update move count
        totalMoves = serverState.moveCount

        // If server says game is over, update local state
        if serverState.isGameOver {
            if let winnerColor = serverState.winnerColor {
                endGame(winner: winnerColor, resultType: serverState.resultType ?? .checkmate)
            } else {
                endGame(winner: nil, resultType: .draw)
            }
        }

        // Clear any pending selections
        clearSelection()

        // Reset timer warning
        isTimerWarning = false
    }

    /// Handles a draw offer from opponent
    func handleDrawOffer() {
        pendingDrawOffer = true
        audioService.triggerHaptic(.warning)
    }

    /// Responds to opponent's draw offer
    func respondToDrawOffer(accept: Bool) {
        pendingDrawOffer = false
        if accept {
            endGame(winner: nil, resultType: .draw)
        }
        // TODO: Send response via WebSocket
    }

    /// Handles rollback request from opponent
    func handleRollbackRequestFromOpponent() {
        pendingRollbackRequest = true
        audioService.triggerHaptic(.warning)
    }
}

// MARK: - Server Game State

/// Represents the game state received from the server after reconnection.
struct ServerGameState {
    let redTime: Int
    let blackTime: Int
    let currentTurn: PlayerColor
    let moveCount: Int
    let redRollbacksRemaining: Int
    let blackRollbacksRemaining: Int
    let isGameOver: Bool
    let winnerColor: PlayerColor?
    let resultType: ResultType?
    let isCheck: Bool
}
