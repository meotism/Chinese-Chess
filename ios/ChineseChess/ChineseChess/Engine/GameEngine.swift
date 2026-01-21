//
//  GameEngine.swift
//  ChineseChess
//
//  Main game engine that manages game state and coordinates all game logic.
//

import Foundation

/// Result of a move attempt.
enum MoveAttemptResult {
    /// Move was successful
    case success(GameMoveResult)
    /// Move was invalid
    case invalid(reason: String)
}

/// Details about a successful move.
struct GameMoveResult {
    let move: Move
    let capturedPiece: Piece?
    let isCheck: Bool
    let isCheckmate: Bool
    let isStalemate: Bool
}

/// The main game engine for Xiangqi.
final class GameEngine {

    // MARK: - Properties

    /// The current game state
    private(set) var state: GameState

    /// The rules engine for validation
    private let rules: RulesEngine

    /// The game identifier
    let gameId: String

    /// Red player identifier
    let redPlayerId: String

    /// Black player identifier
    let blackPlayerId: String

    /// Move counter for generating move IDs
    private var moveCounter: Int = 0

    // MARK: - Computed Properties

    /// The current board state
    var board: [[Piece?]] {
        state.board
    }

    /// The color of the player to move
    var currentTurn: PlayerColor {
        state.currentTurn
    }

    /// Whether the current player is in check
    var isCheck: Bool {
        state.isCheck
    }

    /// Whether the game has ended in checkmate
    var isCheckmate: Bool {
        rules.isCheckmate(color: state.currentTurn, board: state.board)
    }

    /// Whether the game has ended in stalemate
    var isStalemate: Bool {
        rules.isStalemate(color: state.currentTurn, board: state.board)
    }

    /// Whether the game is over
    var isGameOver: Bool {
        isCheckmate || isStalemate
    }

    /// The winner, if the game is over
    var winner: PlayerColor? {
        if isCheckmate || isStalemate {
            return state.currentTurn.opposite
        }
        return nil
    }

    /// The winner's player ID
    var winnerId: String? {
        guard let winner = winner else { return nil }
        return winner == .red ? redPlayerId : blackPlayerId
    }

    // MARK: - Initialization

    /// Creates a new game engine with the initial position.
    ///
    /// - Parameters:
    ///   - gameId: The game identifier
    ///   - redPlayerId: The red player's identifier
    ///   - blackPlayerId: The black player's identifier
    init(gameId: String, redPlayerId: String, blackPlayerId: String) {
        self.gameId = gameId
        self.redPlayerId = redPlayerId
        self.blackPlayerId = blackPlayerId
        self.state = GameState.initial()
        self.rules = RulesEngine()
    }

    /// Creates a game engine from an existing state.
    ///
    /// - Parameters:
    ///   - gameId: The game identifier
    ///   - redPlayerId: The red player's identifier
    ///   - blackPlayerId: The black player's identifier
    ///   - state: The existing game state
    init(gameId: String, redPlayerId: String, blackPlayerId: String, state: GameState) {
        self.gameId = gameId
        self.redPlayerId = redPlayerId
        self.blackPlayerId = blackPlayerId
        self.state = state
        self.rules = RulesEngine()
        self.moveCounter = state.moveHistory.count
    }

    // MARK: - Move Execution

    /// Attempts to make a move.
    ///
    /// - Parameters:
    ///   - playerId: The ID of the player making the move
    ///   - from: The starting position
    ///   - to: The destination position
    /// - Returns: The result of the move attempt
    func makeMove(playerId: String, from: Position, to: Position) -> MoveAttemptResult {
        // Check if game is already over
        guard !isGameOver else {
            return .invalid(reason: "Game has already ended")
        }

        // Verify it's the player's turn
        let expectedPlayerId = state.currentTurn == .red ? redPlayerId : blackPlayerId
        guard playerId == expectedPlayerId else {
            return .invalid(reason: "Not your turn")
        }

        // Get the piece at the from position
        guard let piece = state.piece(at: from) else {
            return .invalid(reason: "No piece at the specified position")
        }

        // Verify the piece belongs to the current player
        guard piece.color == state.currentTurn else {
            return .invalid(reason: "Cannot move opponent's piece")
        }

        // Validate the move using the rules engine
        guard rules.isValidMove(for: piece, to: to, board: state.board) else {
            return .invalid(reason: "Invalid move for this piece")
        }

        // Get the captured piece before the move
        let capturedPiece = state.piece(at: to)

        // Create the pending move
        let pendingMove = PendingMove(
            piece: piece,
            from: from,
            to: to,
            capturedPiece: capturedPiece
        )

        // Apply the move
        state = state.applying(pendingMove)

        // Increment move counter
        moveCounter += 1

        // Check game state after move
        let isNowCheck = rules.isInCheck(color: state.currentTurn, board: state.board)
        let isNowCheckmate = rules.isCheckmate(color: state.currentTurn, board: state.board)
        let isNowStalemate = rules.isStalemate(color: state.currentTurn, board: state.board)

        // Update state's check status
        state.isCheck = isNowCheck
        state.checkingPieces = isNowCheck
            ? rules.getCheckingPieces(color: state.currentTurn, board: state.board).map { $0.position }
            : []

        // Create the move record
        let move = Move(
            id: moveCounter,
            gameId: gameId,
            moveNumber: state.moveHistory.count + 1,
            playerId: playerId,
            from: from,
            to: to,
            pieceType: piece.type,
            capturedPiece: capturedPiece?.type,
            timestamp: Date(),
            isCheck: isNowCheck
        )

        // Add to history
        state.moveHistory.append(move)

        let result = GameMoveResult(
            move: move,
            capturedPiece: capturedPiece,
            isCheck: isNowCheck,
            isCheckmate: isNowCheckmate,
            isStalemate: isNowStalemate
        )

        return .success(result)
    }

    /// Attempts to make a move using notation strings.
    ///
    /// - Parameters:
    ///   - playerId: The ID of the player making the move
    ///   - from: The starting position notation (e.g., "e0")
    ///   - to: The destination position notation (e.g., "e1")
    /// - Returns: The result of the move attempt
    func makeMove(playerId: String, from fromNotation: String, to toNotation: String) -> MoveAttemptResult {
        guard let from = Position(notation: fromNotation) else {
            return .invalid(reason: "Invalid from position: \(fromNotation)")
        }

        guard let to = Position(notation: toNotation) else {
            return .invalid(reason: "Invalid to position: \(toNotation)")
        }

        return makeMove(playerId: playerId, from: from, to: to)
    }

    // MARK: - Move Queries

    /// Returns all legal moves for a piece at the given position.
    ///
    /// - Parameter position: The position of the piece
    /// - Returns: Array of legal destination positions
    func getLegalMoves(from position: Position) -> [Position] {
        guard let piece = state.piece(at: position) else {
            return []
        }

        return rules.getLegalMoves(for: piece, board: state.board)
    }

    /// Returns all legal moves for the current player.
    ///
    /// - Returns: Dictionary mapping piece positions to their legal moves
    func getAllLegalMoves() -> [Position: [Position]] {
        var moves: [Position: [Position]] = [:]

        let pieces = state.pieces(for: state.currentTurn)
        for piece in pieces {
            let legalMoves = rules.getLegalMoves(for: piece, board: state.board)
            if !legalMoves.isEmpty {
                moves[piece.position] = legalMoves
            }
        }

        return moves
    }

    // MARK: - Undo

    /// Undoes the last move.
    ///
    /// - Returns: True if the undo was successful
    @discardableResult
    func undoLastMove() -> Bool {
        guard !state.moveHistory.isEmpty else {
            return false
        }

        // Rebuild the state from scratch by replaying moves
        let movesToReplay = Array(state.moveHistory.dropLast())

        // Reset to initial state
        state = GameState.initial()
        moveCounter = 0

        // Replay all moves except the last one
        for move in movesToReplay {
            let from = move.from
            let to = move.to

            guard let piece = state.piece(at: from) else {
                continue
            }

            let capturedPiece = state.piece(at: to)
            let pendingMove = PendingMove(
                piece: piece,
                from: from,
                to: to,
                capturedPiece: capturedPiece
            )

            state = state.applying(pendingMove)
            moveCounter += 1
        }

        // Restore move history
        state.moveHistory = movesToReplay

        // Recalculate check status
        state.isCheck = rules.isInCheck(color: state.currentTurn, board: state.board)
        state.checkingPieces = state.isCheck
            ? rules.getCheckingPieces(color: state.currentTurn, board: state.board).map { $0.position }
            : []

        return true
    }

    // MARK: - Game End

    /// Marks a player as having resigned.
    ///
    /// - Parameter playerId: The ID of the resigning player
    func resign(playerId: String) {
        // The resigning player loses, so we need to mark the game as over
        // This is handled externally by the game service
    }

    /// Marks the game as a draw.
    func declareDraw() {
        // This is handled externally by the game service
    }

    // MARK: - State Export

    /// Returns the current game state for serialization.
    var currentState: GameState {
        state
    }

    /// Returns a description of the current board state.
    var boardDescription: String {
        state.description
    }
}

// MARK: - Validation Helpers

extension GameEngine {

    /// Checks if a piece at a position can make any legal move.
    ///
    /// - Parameter position: The position to check
    /// - Returns: True if the piece can move
    func canMove(from position: Position) -> Bool {
        !getLegalMoves(from: position).isEmpty
    }

    /// Checks if a specific move would be legal.
    ///
    /// - Parameters:
    ///   - from: The starting position
    ///   - to: The destination position
    /// - Returns: True if the move would be legal
    func isLegalMove(from: Position, to: Position) -> Bool {
        guard let piece = state.piece(at: from) else {
            return false
        }

        return rules.isValidMove(for: piece, to: to, board: state.board)
    }

    /// Checks if a move would result in check.
    ///
    /// - Parameters:
    ///   - from: The starting position
    ///   - to: The destination position
    /// - Returns: True if the move would result in check
    func wouldBeCheck(from: Position, to: Position) -> Bool {
        guard let piece = state.piece(at: from) else {
            return false
        }

        return rules.wouldResultInCheck(piece: piece, to: to, board: state.board)
    }
}
