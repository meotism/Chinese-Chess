//
//  Move.swift
//  ChineseChess
//
//  Represents a move in the game.
//

import Foundation

/// Represents a move in a Xiangqi game.
struct Move: Codable, Identifiable, Equatable, Hashable {

    // MARK: - Properties

    /// Unique identifier for the move
    let id: Int

    /// The ID of the game this move belongs to
    let gameId: String

    /// The move number in the game (1-indexed)
    let moveNumber: Int

    /// The ID of the player who made the move
    let playerId: String

    /// The starting position of the piece
    let from: Position

    /// The destination position of the piece
    let to: Position

    /// The type of piece that was moved
    let pieceType: PieceType

    /// The type of piece that was captured, if any
    let capturedPiece: PieceType?

    /// The timestamp when the move was made
    let timestamp: Date

    /// Whether this move results in check
    let isCheck: Bool

    // MARK: - Computed Properties

    /// Returns the algebraic notation for this move (e.g., "e0-e1")
    var notation: String {
        "\(from.notation)-\(to.notation)"
    }

    /// Returns a human-readable description of the move
    var description: String {
        var desc = "\(pieceType.rawValue.capitalized) \(from.notation) to \(to.notation)"
        if let captured = capturedPiece {
            desc += " captures \(captured.rawValue)"
        }
        if isCheck {
            desc += " (check)"
        }
        return desc
    }

    // MARK: - Initialization

    /// Creates a new move.
    ///
    /// - Parameters:
    ///   - id: The unique identifier
    ///   - gameId: The game ID
    ///   - moveNumber: The move number
    ///   - playerId: The player ID
    ///   - from: The starting position
    ///   - to: The destination position
    ///   - pieceType: The type of piece moved
    ///   - capturedPiece: The captured piece type, if any
    ///   - timestamp: The time of the move
    ///   - isCheck: Whether the move results in check
    init(
        id: Int,
        gameId: String,
        moveNumber: Int,
        playerId: String,
        from: Position,
        to: Position,
        pieceType: PieceType,
        capturedPiece: PieceType? = nil,
        timestamp: Date = Date(),
        isCheck: Bool = false
    ) {
        self.id = id
        self.gameId = gameId
        self.moveNumber = moveNumber
        self.playerId = playerId
        self.from = from
        self.to = to
        self.pieceType = pieceType
        self.capturedPiece = capturedPiece
        self.timestamp = timestamp
        self.isCheck = isCheck
    }
}

// MARK: - MoveResult

/// The result of attempting to make a move.
enum MoveResult: Equatable {
    /// The move was successful
    case success(move: Move)

    /// The move was successful and results in check
    case check(move: Move)

    /// The move was successful and results in checkmate
    case checkmate(move: Move)

    /// The move was successful and results in stalemate
    case stalemate(move: Move)

    /// The move was invalid
    case invalid(reason: String)

    /// Returns true if the move was successful
    var isSuccess: Bool {
        switch self {
        case .success, .check, .checkmate, .stalemate:
            return true
        case .invalid:
            return false
        }
    }

    /// Returns the move if successful, nil otherwise
    var move: Move? {
        switch self {
        case .success(let move), .check(let move), .checkmate(let move), .stalemate(let move):
            return move
        case .invalid:
            return nil
        }
    }
}

// MARK: - PendingMove

/// Represents a move that is being considered but not yet executed.
/// Used for move validation and preview purposes.
struct PendingMove: Equatable {
    /// The piece being moved
    let piece: Piece

    /// The starting position
    let from: Position

    /// The destination position
    let to: Position

    /// The piece being captured, if any
    let capturedPiece: Piece?

    /// Creates a new pending move.
    init(piece: Piece, from: Position, to: Position, capturedPiece: Piece? = nil) {
        self.piece = piece
        self.from = from
        self.to = to
        self.capturedPiece = capturedPiece
    }
}
