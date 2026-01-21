//
//  GameState.swift
//  ChineseChess
//
//  Represents the current state of a Xiangqi game.
//

import Foundation

/// Represents the complete state of a Xiangqi game at any point in time.
struct GameState: Codable, Equatable {

    // MARK: - Properties

    /// The board representation as a 10x9 grid (rows x columns)
    /// board[rank][file] - rank 0 is Red's back row, rank 9 is Black's back row
    var board: [[Piece?]]

    /// The color of the player whose turn it is
    var currentTurn: PlayerColor

    /// All pieces belonging to Red
    var redPieces: [Piece]

    /// All pieces belonging to Black
    var blackPieces: [Piece]

    /// Pieces captured by Red (i.e., Black pieces that were taken)
    var capturedByRed: [Piece]

    /// Pieces captured by Black (i.e., Red pieces that were taken)
    var capturedByBlack: [Piece]

    /// The history of all moves made in the game
    var moveHistory: [Move]

    /// Whether the current player is in check
    var isCheck: Bool

    /// Positions of pieces that are giving check
    var checkingPieces: [Position]

    // MARK: - Computed Properties

    /// Returns all active pieces on the board
    var allPieces: [Piece] {
        redPieces + blackPieces
    }

    /// Returns the pieces for the specified color
    func pieces(for color: PlayerColor) -> [Piece] {
        switch color {
        case .red: return redPieces
        case .black: return blackPieces
        }
    }

    /// Returns the General for the specified color
    func general(for color: PlayerColor) -> Piece? {
        pieces(for: color).first { $0.type == .general }
    }

    /// Returns the piece at the specified position, if any
    func piece(at position: Position) -> Piece? {
        guard position.isValid else { return nil }
        return board[position.rank][position.file]
    }

    /// Returns true if the specified position is empty
    func isEmpty(at position: Position) -> Bool {
        piece(at: position) == nil
    }

    /// Returns true if the specified position contains an enemy piece
    func hasEnemy(at position: Position, for color: PlayerColor) -> Bool {
        guard let piece = piece(at: position) else { return false }
        return piece.color != color
    }

    /// Returns true if the specified position contains a friendly piece
    func hasFriendly(at position: Position, for color: PlayerColor) -> Bool {
        guard let piece = piece(at: position) else { return false }
        return piece.color == color
    }

    // MARK: - Initialization

    /// Creates an initial game state with all pieces in their starting positions.
    static func initial() -> GameState {
        var board: [[Piece?]] = Array(
            repeating: Array(repeating: nil, count: Position.fileCount),
            count: Position.rankCount
        )

        var redPieces: [Piece] = []
        var blackPieces: [Piece] = []

        // Helper function to place a piece
        func place(_ type: PieceType, color: PlayerColor, file: Int, rank: Int) {
            let position = Position(file: file, rank: rank)
            let piece = Piece(type: type, color: color, position: position)
            board[rank][file] = piece
            if color == .red {
                redPieces.append(piece)
            } else {
                blackPieces.append(piece)
            }
        }

        // Place Red pieces (ranks 0-3)
        // Back row (rank 0): Chariot, Horse, Elephant, Advisor, General, Advisor, Elephant, Horse, Chariot
        place(.chariot, color: .red, file: 0, rank: 0)
        place(.horse, color: .red, file: 1, rank: 0)
        place(.elephant, color: .red, file: 2, rank: 0)
        place(.advisor, color: .red, file: 3, rank: 0)
        place(.general, color: .red, file: 4, rank: 0)
        place(.advisor, color: .red, file: 5, rank: 0)
        place(.elephant, color: .red, file: 6, rank: 0)
        place(.horse, color: .red, file: 7, rank: 0)
        place(.chariot, color: .red, file: 8, rank: 0)

        // Cannons (rank 2)
        place(.cannon, color: .red, file: 1, rank: 2)
        place(.cannon, color: .red, file: 7, rank: 2)

        // Soldiers (rank 3)
        place(.soldier, color: .red, file: 0, rank: 3)
        place(.soldier, color: .red, file: 2, rank: 3)
        place(.soldier, color: .red, file: 4, rank: 3)
        place(.soldier, color: .red, file: 6, rank: 3)
        place(.soldier, color: .red, file: 8, rank: 3)

        // Place Black pieces (ranks 6-9)
        // Back row (rank 9): Chariot, Horse, Elephant, Advisor, General, Advisor, Elephant, Horse, Chariot
        place(.chariot, color: .black, file: 0, rank: 9)
        place(.horse, color: .black, file: 1, rank: 9)
        place(.elephant, color: .black, file: 2, rank: 9)
        place(.advisor, color: .black, file: 3, rank: 9)
        place(.general, color: .black, file: 4, rank: 9)
        place(.advisor, color: .black, file: 5, rank: 9)
        place(.elephant, color: .black, file: 6, rank: 9)
        place(.horse, color: .black, file: 7, rank: 9)
        place(.chariot, color: .black, file: 8, rank: 9)

        // Cannons (rank 7)
        place(.cannon, color: .black, file: 1, rank: 7)
        place(.cannon, color: .black, file: 7, rank: 7)

        // Soldiers (rank 6)
        place(.soldier, color: .black, file: 0, rank: 6)
        place(.soldier, color: .black, file: 2, rank: 6)
        place(.soldier, color: .black, file: 4, rank: 6)
        place(.soldier, color: .black, file: 6, rank: 6)
        place(.soldier, color: .black, file: 8, rank: 6)

        return GameState(
            board: board,
            currentTurn: .red,  // Red always moves first
            redPieces: redPieces,
            blackPieces: blackPieces,
            capturedByRed: [],
            capturedByBlack: [],
            moveHistory: [],
            isCheck: false,
            checkingPieces: []
        )
    }

    // MARK: - Board Manipulation

    /// Returns a copy of this state with the specified move applied.
    ///
    /// This method does not validate the move - it assumes the move is legal.
    ///
    /// - Parameter pendingMove: The move to apply
    /// - Returns: A new game state with the move applied
    func applying(_ pendingMove: PendingMove) -> GameState {
        var newState = self

        // Remove piece from old position
        newState.board[pendingMove.from.rank][pendingMove.from.file] = nil

        // Handle capture
        if let capturedPiece = pendingMove.capturedPiece {
            // Remove captured piece from appropriate list
            if capturedPiece.color == .red {
                newState.redPieces.removeAll { $0.id == capturedPiece.id }
                newState.capturedByBlack.append(capturedPiece)
            } else {
                newState.blackPieces.removeAll { $0.id == capturedPiece.id }
                newState.capturedByRed.append(capturedPiece)
            }
        }

        // Move piece to new position
        let movedPiece = pendingMove.piece.moved(to: pendingMove.to)
        newState.board[pendingMove.to.rank][pendingMove.to.file] = movedPiece

        // Update piece list
        if pendingMove.piece.color == .red {
            if let index = newState.redPieces.firstIndex(where: { $0.id == pendingMove.piece.id }) {
                newState.redPieces[index] = movedPiece
            }
        } else {
            if let index = newState.blackPieces.firstIndex(where: { $0.id == pendingMove.piece.id }) {
                newState.blackPieces[index] = movedPiece
            }
        }

        // Switch turn
        newState.currentTurn = newState.currentTurn.opposite

        return newState
    }
}

// MARK: - CustomStringConvertible

extension GameState: CustomStringConvertible {
    var description: String {
        var result = ""
        for rank in stride(from: Position.rankCount - 1, through: 0, by: -1) {
            result += "\(rank) "
            for file in 0..<Position.fileCount {
                if let piece = board[rank][file] {
                    result += piece.character
                } else {
                    result += "."
                }
                result += " "
            }
            result += "\n"
        }
        result += "  a b c d e f g h i\n"
        result += "Turn: \(currentTurn.rawValue.capitalized)"
        if isCheck {
            result += " (CHECK)"
        }
        return result
    }
}
