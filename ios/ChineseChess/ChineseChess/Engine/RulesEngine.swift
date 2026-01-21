//
//  RulesEngine.swift
//  ChineseChess
//
//  Rules engine for Xiangqi special rules and game state detection.
//

import Foundation

/// Engine for validating special Xiangqi rules and detecting game states.
final class RulesEngine {

    // MARK: - Initialization

    init() {}

    // MARK: - Flying General Rule

    /// Checks if the two generals are facing each other with no pieces between.
    /// This rule prevents the generals from being on the same file without intervening pieces.
    ///
    /// - Parameter board: The current board state
    /// - Returns: True if the generals are illegally facing each other
    func isFlyingGeneral(board: [[Piece?]]) -> Bool {
        guard let redGeneral = findGeneral(color: .red, on: board),
              let blackGeneral = findGeneral(color: .black, on: board) else {
            return false
        }

        // Generals must be on the same file for flying general to apply
        guard redGeneral.position.file == blackGeneral.position.file else {
            return false
        }

        // Check if there are any pieces between the generals
        let minRank = redGeneral.position.rank + 1
        let maxRank = blackGeneral.position.rank
        let file = redGeneral.position.file

        for rank in minRank..<maxRank {
            if board[rank][file] != nil {
                return false // There's a piece between, no flying general
            }
        }

        // No pieces between - this would be flying general
        return true
    }

    // MARK: - Check Detection

    /// Returns true if the specified color's general is in check.
    ///
    /// - Parameters:
    ///   - color: The color to check
    ///   - board: The current board state
    /// - Returns: True if the general is in check
    func isInCheck(color: PlayerColor, board: [[Piece?]]) -> Bool {
        guard let general = findGeneral(color: color, on: board) else {
            return false
        }

        let generalPos = general.position
        let enemyColor = color.opposite

        // Check if any enemy piece can attack the general
        let enemyPieces = getAllPieces(color: enemyColor, on: board)
        for piece in enemyPieces {
            let validator = ValidatorFactory.validator(for: piece.type)
            if validator.isValidMove(for: piece, to: generalPos, on: board) {
                return true
            }
        }

        // Also check for flying general
        guard let enemyGeneral = findGeneral(color: enemyColor, on: board) else {
            return false
        }

        if enemyGeneral.position.file == generalPos.file {
            // Check if there are no pieces between
            let minRank = min(generalPos.rank, enemyGeneral.position.rank) + 1
            let maxRank = max(generalPos.rank, enemyGeneral.position.rank)

            var hasPieceBetween = false
            for rank in minRank..<maxRank {
                if board[rank][generalPos.file] != nil {
                    hasPieceBetween = true
                    break
                }
            }

            if !hasPieceBetween {
                return true // Flying general - opponent's general is attacking
            }
        }

        return false
    }

    /// Returns all pieces that are giving check to the specified color's general.
    ///
    /// - Parameters:
    ///   - color: The color being checked
    ///   - board: The current board state
    /// - Returns: Array of pieces giving check
    func getCheckingPieces(color: PlayerColor, board: [[Piece?]]) -> [Piece] {
        guard let general = findGeneral(color: color, on: board) else {
            return []
        }

        let generalPos = general.position
        let enemyColor = color.opposite
        var checkingPieces: [Piece] = []

        let enemyPieces = getAllPieces(color: enemyColor, on: board)
        for piece in enemyPieces {
            let validator = ValidatorFactory.validator(for: piece.type)
            if validator.isValidMove(for: piece, to: generalPos, on: board) {
                checkingPieces.append(piece)
            }
        }

        return checkingPieces
    }

    // MARK: - Legal Move Detection

    /// Returns true if the specified color has any legal moves.
    ///
    /// - Parameters:
    ///   - color: The color to check
    ///   - board: The current board state
    /// - Returns: True if there is at least one legal move
    func hasLegalMoves(color: PlayerColor, board: [[Piece?]]) -> Bool {
        let pieces = getAllPieces(color: color, on: board)

        for piece in pieces {
            let legalMoves = getLegalMoves(for: piece, board: board)
            if !legalMoves.isEmpty {
                return true
            }
        }

        return false
    }

    /// Returns all legal moves for a piece, filtering out moves that would
    /// leave the general in check or create a flying general situation.
    ///
    /// - Parameters:
    ///   - piece: The piece to get moves for
    ///   - board: The current board state
    /// - Returns: Array of legal destination positions
    func getLegalMoves(for piece: Piece, board: [[Piece?]]) -> [Position] {
        let validator = ValidatorFactory.validator(for: piece.type)
        let validMoves = validator.getValidMoves(for: piece, on: board)
        var legalMoves: [Position] = []

        for to in validMoves {
            // Simulate the move
            var testBoard = board
            testBoard[piece.position.rank][piece.position.file] = nil
            let movedPiece = piece.moved(to: to)
            testBoard[to.rank][to.file] = movedPiece

            // Check if this move would leave the general in check or create flying general
            if !isInCheck(color: piece.color, board: testBoard) && !isFlyingGeneral(board: testBoard) {
                legalMoves.append(to)
            }
        }

        return legalMoves
    }

    // MARK: - Game End Detection

    /// Returns true if the specified color is in checkmate.
    ///
    /// - Parameters:
    ///   - color: The color to check
    ///   - board: The current board state
    /// - Returns: True if the color is in checkmate
    func isCheckmate(color: PlayerColor, board: [[Piece?]]) -> Bool {
        guard isInCheck(color: color, board: board) else {
            return false
        }

        return !hasLegalMoves(color: color, board: board)
    }

    /// Returns true if the specified color is in stalemate.
    ///
    /// - Parameters:
    ///   - color: The color to check
    ///   - board: The current board state
    /// - Returns: True if the color is in stalemate
    func isStalemate(color: PlayerColor, board: [[Piece?]]) -> Bool {
        guard !isInCheck(color: color, board: board) else {
            return false
        }

        return !hasLegalMoves(color: color, board: board)
    }

    // MARK: - Move Validation

    /// Validates a move considering all rules.
    ///
    /// - Parameters:
    ///   - piece: The piece to move
    ///   - to: The destination position
    ///   - board: The current board state
    /// - Returns: True if the move is legal
    func isValidMove(for piece: Piece, to: Position, board: [[Piece?]]) -> Bool {
        // First, check basic piece movement rules
        let validator = ValidatorFactory.validator(for: piece.type)

        guard validator.isValidMove(for: piece, to: to, on: board) else {
            return false
        }

        // Simulate the move
        var testBoard = board
        testBoard[piece.position.rank][piece.position.file] = nil
        let movedPiece = piece.moved(to: to)
        testBoard[to.rank][to.file] = movedPiece

        // Check if this move would leave the general in check
        if isInCheck(color: piece.color, board: testBoard) {
            return false
        }

        // Check for flying general
        if isFlyingGeneral(board: testBoard) {
            return false
        }

        return true
    }

    /// Checks if a move would result in check for the opponent.
    ///
    /// - Parameters:
    ///   - piece: The piece being moved
    ///   - to: The destination position
    ///   - board: The current board state
    /// - Returns: True if the move results in check
    func wouldResultInCheck(piece: Piece, to: Position, board: [[Piece?]]) -> Bool {
        var testBoard = board
        testBoard[piece.position.rank][piece.position.file] = nil
        let movedPiece = piece.moved(to: to)
        testBoard[to.rank][to.file] = movedPiece

        return isInCheck(color: piece.color.opposite, board: testBoard)
    }

    // MARK: - Helper Methods

    /// Finds the general for the specified color.
    ///
    /// - Parameters:
    ///   - color: The color of the general to find
    ///   - board: The current board state
    /// - Returns: The general piece, or nil if not found
    private func findGeneral(color: PlayerColor, on board: [[Piece?]]) -> Piece? {
        for rank in 0..<Position.rankCount {
            for file in 0..<Position.fileCount {
                if let piece = board[rank][file],
                   piece.type == .general && piece.color == color {
                    return piece
                }
            }
        }
        return nil
    }

    /// Returns all pieces of the specified color.
    ///
    /// - Parameters:
    ///   - color: The color of pieces to find
    ///   - board: The current board state
    /// - Returns: Array of pieces
    private func getAllPieces(color: PlayerColor, on board: [[Piece?]]) -> [Piece] {
        var pieces: [Piece] = []
        for rank in 0..<Position.rankCount {
            for file in 0..<Position.fileCount {
                if let piece = board[rank][file], piece.color == color {
                    pieces.append(piece)
                }
            }
        }
        return pieces
    }
}
