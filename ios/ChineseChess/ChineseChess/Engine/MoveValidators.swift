//
//  MoveValidators.swift
//  ChineseChess
//
//  Move validators for all Xiangqi piece types.
//

import Foundation

// MARK: - MoveValidator Protocol

/// Protocol for validating piece moves.
protocol MoveValidator {
    /// Returns all valid destination positions for a piece.
    func getValidMoves(for piece: Piece, on board: [[Piece?]]) -> [Position]

    /// Checks if a specific move is valid.
    func isValidMove(for piece: Piece, to: Position, on board: [[Piece?]]) -> Bool
}

// MARK: - ValidatorFactory

/// Factory for creating move validators.
enum ValidatorFactory {
    /// Returns the appropriate validator for a piece type.
    static func validator(for pieceType: PieceType) -> MoveValidator {
        switch pieceType {
        case .general:
            return GeneralValidator()
        case .advisor:
            return AdvisorValidator()
        case .elephant:
            return ElephantValidator()
        case .horse:
            return HorseValidator()
        case .chariot:
            return ChariotValidator()
        case .cannon:
            return CannonValidator()
        case .soldier:
            return SoldierValidator()
        }
    }
}

// MARK: - Board Helper Extensions

private extension Array where Element == [Piece?] {
    /// Returns the piece at the given position, if valid.
    func piece(at pos: Position) -> Piece? {
        guard pos.isValid else { return nil }
        return self[pos.rank][pos.file]
    }

    /// Returns true if the position is empty.
    func isEmpty(at pos: Position) -> Bool {
        piece(at: pos) == nil
    }

    /// Returns true if there is a piece at the position.
    func hasPiece(at pos: Position) -> Bool {
        piece(at: pos) != nil
    }

    /// Returns true if there is an enemy piece at the position.
    func hasEnemy(at pos: Position, for color: PlayerColor) -> Bool {
        guard let piece = piece(at: pos) else { return false }
        return piece.color != color
    }

    /// Returns true if there is a friendly piece at the position.
    func hasFriendly(at pos: Position, for color: PlayerColor) -> Bool {
        guard let piece = piece(at: pos) else { return false }
        return piece.color == color
    }
}

// MARK: - GeneralValidator

/// Validates moves for the General (King).
/// The General moves one step orthogonally and must stay within the palace.
struct GeneralValidator: MoveValidator {

    func getValidMoves(for piece: Piece, on board: [[Piece?]]) -> [Position] {
        let from = piece.position
        var moves: [Position] = []

        // Orthogonal offsets (up, down, left, right)
        let offsets = [(0, 1), (0, -1), (1, 0), (-1, 0)]

        for (fileOffset, rankOffset) in offsets {
            if let to = from.offset(file: fileOffset, rank: rankOffset) {
                if isValidMove(for: piece, to: to, on: board) {
                    moves.append(to)
                }
            }
        }

        return moves
    }

    func isValidMove(for piece: Piece, to: Position, on board: [[Piece?]]) -> Bool {
        let from = piece.position

        // Must be a valid position
        guard to.isValid else { return false }

        // Must stay within the palace
        guard to.isInPalace(for: piece.color) else { return false }

        // Must move exactly one step orthogonally
        let fileDiff = abs(to.file - from.file)
        let rankDiff = abs(to.rank - from.rank)

        guard (fileDiff == 1 && rankDiff == 0) || (fileDiff == 0 && rankDiff == 1) else {
            return false
        }

        // Cannot capture own piece
        guard !board.hasFriendly(at: to, for: piece.color) else { return false }

        return true
    }
}

// MARK: - AdvisorValidator

/// Validates moves for the Advisor (Guard).
/// The Advisor moves one step diagonally and must stay within the palace.
struct AdvisorValidator: MoveValidator {

    func getValidMoves(for piece: Piece, on board: [[Piece?]]) -> [Position] {
        let from = piece.position
        var moves: [Position] = []

        // Diagonal offsets
        let offsets = [(1, 1), (1, -1), (-1, 1), (-1, -1)]

        for (fileOffset, rankOffset) in offsets {
            if let to = from.offset(file: fileOffset, rank: rankOffset) {
                if isValidMove(for: piece, to: to, on: board) {
                    moves.append(to)
                }
            }
        }

        return moves
    }

    func isValidMove(for piece: Piece, to: Position, on board: [[Piece?]]) -> Bool {
        let from = piece.position

        // Must be a valid position
        guard to.isValid else { return false }

        // Must stay within the palace
        guard to.isInPalace(for: piece.color) else { return false }

        // Must move exactly one step diagonally
        let fileDiff = abs(to.file - from.file)
        let rankDiff = abs(to.rank - from.rank)

        guard fileDiff == 1 && rankDiff == 1 else { return false }

        // Cannot capture own piece
        guard !board.hasFriendly(at: to, for: piece.color) else { return false }

        return true
    }
}

// MARK: - ElephantValidator

/// Validates moves for the Elephant (Bishop).
/// The Elephant moves two steps diagonally and cannot cross the river.
/// It can be blocked by a piece at the intermediate position (elephant eye).
struct ElephantValidator: MoveValidator {

    func getValidMoves(for piece: Piece, on board: [[Piece?]]) -> [Position] {
        let from = piece.position
        var moves: [Position] = []

        // Diagonal offsets (2 steps)
        let offsets = [(2, 2), (2, -2), (-2, 2), (-2, -2)]

        for (fileOffset, rankOffset) in offsets {
            if let to = from.offset(file: fileOffset, rank: rankOffset) {
                if isValidMove(for: piece, to: to, on: board) {
                    moves.append(to)
                }
            }
        }

        return moves
    }

    func isValidMove(for piece: Piece, to: Position, on board: [[Piece?]]) -> Bool {
        let from = piece.position

        // Must be a valid position
        guard to.isValid else { return false }

        // Must move exactly two steps diagonally
        let fileDiff = abs(to.file - from.file)
        let rankDiff = abs(to.rank - from.rank)

        guard fileDiff == 2 && rankDiff == 2 else { return false }

        // Cannot cross the river
        if piece.color == .red && to.isOnBlackSide {
            return false
        }
        if piece.color == .black && to.isOnRedSide {
            return false
        }

        // Check for blocking piece at intermediate position (elephant eye)
        let midFile = (from.file + to.file) / 2
        let midRank = (from.rank + to.rank) / 2
        let midPos = Position(file: midFile, rank: midRank)

        guard board.isEmpty(at: midPos) else { return false }

        // Cannot capture own piece
        guard !board.hasFriendly(at: to, for: piece.color) else { return false }

        return true
    }
}

// MARK: - HorseValidator

/// Validates moves for the Horse (Knight).
/// The Horse moves in an L-shape: one step orthogonally, then one step diagonally.
/// It can be blocked by a piece at the adjacent orthogonal position (horse leg).
struct HorseValidator: MoveValidator {

    func getValidMoves(for piece: Piece, on board: [[Piece?]]) -> [Position] {
        let from = piece.position
        var moves: [Position] = []

        // L-shaped moves with their blocking positions
        let horseMoves: [(fileOffset: Int, rankOffset: Int, blockFile: Int, blockRank: Int)] = [
            // Moving up first
            (1, 2, 0, 1),    // Up, then right
            (-1, 2, 0, 1),   // Up, then left
            (1, -2, 0, -1),  // Down, then right
            (-1, -2, 0, -1), // Down, then left
            // Moving sideways first
            (2, 1, 1, 0),    // Right, then up
            (2, -1, 1, 0),   // Right, then down
            (-2, 1, -1, 0),  // Left, then up
            (-2, -1, -1, 0)  // Left, then down
        ]

        for move in horseMoves {
            guard let to = from.offset(file: move.fileOffset, rank: move.rankOffset) else {
                continue
            }
            guard let blocking = from.offset(file: move.blockFile, rank: move.blockRank) else {
                continue
            }

            // Check for blocking piece (horse leg)
            guard board.isEmpty(at: blocking) else { continue }

            // Cannot capture own piece
            guard !board.hasFriendly(at: to, for: piece.color) else { continue }

            moves.append(to)
        }

        return moves
    }

    func isValidMove(for piece: Piece, to: Position, on board: [[Piece?]]) -> Bool {
        let from = piece.position

        // Must be a valid position
        guard to.isValid else { return false }

        // Calculate file and rank differences
        let fileDiff = abs(to.file - from.file)
        let rankDiff = abs(to.rank - from.rank)

        // Must be L-shape: (1,2) or (2,1)
        guard (fileDiff == 1 && rankDiff == 2) || (fileDiff == 2 && rankDiff == 1) else {
            return false
        }

        // Determine blocking position based on direction
        let blockingFile: Int
        let blockingRank: Int

        if rankDiff == 2 {
            // Moving primarily vertical, blocked by adjacent vertical square
            blockingFile = from.file
            blockingRank = to.rank > from.rank ? from.rank + 1 : from.rank - 1
        } else {
            // Moving primarily horizontal, blocked by adjacent horizontal square
            blockingRank = from.rank
            blockingFile = to.file > from.file ? from.file + 1 : from.file - 1
        }

        let blockingPos = Position(file: blockingFile, rank: blockingRank)

        // Check for blocking piece
        guard board.isEmpty(at: blockingPos) else { return false }

        // Cannot capture own piece
        guard !board.hasFriendly(at: to, for: piece.color) else { return false }

        return true
    }
}

// MARK: - ChariotValidator

/// Validates moves for the Chariot (Rook).
/// The Chariot moves any number of steps orthogonally.
struct ChariotValidator: MoveValidator {

    func getValidMoves(for piece: Piece, on board: [[Piece?]]) -> [Position] {
        let from = piece.position
        var moves: [Position] = []

        // Check all four directions
        let directions = [(0, 1), (0, -1), (1, 0), (-1, 0)]

        for (fileDir, rankDir) in directions {
            for i in 1..<10 {
                guard let to = from.offset(file: fileDir * i, rank: rankDir * i) else {
                    break
                }
                guard to.isValid else { break }

                if board.isEmpty(at: to) {
                    moves.append(to)
                } else if board.hasEnemy(at: to, for: piece.color) {
                    moves.append(to)
                    break // Cannot go past a captured piece
                } else {
                    break // Blocked by friendly piece
                }
            }
        }

        return moves
    }

    func isValidMove(for piece: Piece, to: Position, on board: [[Piece?]]) -> Bool {
        let from = piece.position

        // Must be a valid position
        guard to.isValid else { return false }

        // Must move orthogonally
        guard from.file == to.file || from.rank == to.rank else { return false }

        // Cannot stay in place
        guard from.file != to.file || from.rank != to.rank else { return false }

        // Cannot capture own piece
        guard !board.hasFriendly(at: to, for: piece.color) else { return false }

        // Check path for obstacles
        if from.file == to.file {
            // Moving vertically
            let step = to.rank > from.rank ? 1 : -1
            var rank = from.rank + step
            while rank != to.rank {
                if board.hasPiece(at: Position(file: from.file, rank: rank)) {
                    return false
                }
                rank += step
            }
        } else {
            // Moving horizontally
            let step = to.file > from.file ? 1 : -1
            var file = from.file + step
            while file != to.file {
                if board.hasPiece(at: Position(file: file, rank: from.rank)) {
                    return false
                }
                file += step
            }
        }

        return true
    }
}

// MARK: - CannonValidator

/// Validates moves for the Cannon.
/// The Cannon moves like the Chariot for non-capturing moves.
/// For captures, it must jump over exactly one piece (the screen).
struct CannonValidator: MoveValidator {

    func getValidMoves(for piece: Piece, on board: [[Piece?]]) -> [Position] {
        let from = piece.position
        var moves: [Position] = []

        // Check all four directions
        let directions = [(0, 1), (0, -1), (1, 0), (-1, 0)]

        for (fileDir, rankDir) in directions {
            var foundScreen = false

            for i in 1..<10 {
                guard let to = from.offset(file: fileDir * i, rank: rankDir * i) else {
                    break
                }
                guard to.isValid else { break }

                if !foundScreen {
                    // Before finding screen, can move to empty squares
                    if board.isEmpty(at: to) {
                        moves.append(to)
                    } else {
                        // Found the screen
                        foundScreen = true
                    }
                } else {
                    // After finding screen, can only capture
                    if board.hasEnemy(at: to, for: piece.color) {
                        moves.append(to)
                        break
                    } else if board.hasFriendly(at: to, for: piece.color) {
                        break // Blocked by second friendly piece
                    }
                    // If empty, continue looking for capture target
                }
            }
        }

        return moves
    }

    func isValidMove(for piece: Piece, to: Position, on board: [[Piece?]]) -> Bool {
        let from = piece.position

        // Must be a valid position
        guard to.isValid else { return false }

        // Must move orthogonally
        guard from.file == to.file || from.rank == to.rank else { return false }

        // Cannot stay in place
        guard from.file != to.file || from.rank != to.rank else { return false }

        // Cannot capture own piece
        guard !board.hasFriendly(at: to, for: piece.color) else { return false }

        // Count pieces between from and to
        var piecesInPath = 0

        if from.file == to.file {
            // Moving vertically
            let step = to.rank > from.rank ? 1 : -1
            var rank = from.rank + step
            while rank != to.rank {
                if board.hasPiece(at: Position(file: from.file, rank: rank)) {
                    piecesInPath += 1
                }
                rank += step
            }
        } else {
            // Moving horizontally
            let step = to.file > from.file ? 1 : -1
            var file = from.file + step
            while file != to.file {
                if board.hasPiece(at: Position(file: file, rank: from.rank)) {
                    piecesInPath += 1
                }
                file += step
            }
        }

        // Determine if this is a capture move
        let isCapture = board.hasEnemy(at: to, for: piece.color)

        if isCapture {
            // For capture, must have exactly one piece (screen) between
            return piecesInPath == 1
        } else {
            // For non-capture, must have no pieces between
            return piecesInPath == 0
        }
    }
}

// MARK: - SoldierValidator

/// Validates moves for the Soldier (Pawn).
/// Before crossing the river: moves one step forward only.
/// After crossing the river: moves one step forward or sideways.
struct SoldierValidator: MoveValidator {

    func getValidMoves(for piece: Piece, on board: [[Piece?]]) -> [Position] {
        let from = piece.position
        var moves: [Position] = []

        // Determine forward direction based on color
        let forward = piece.color == .red ? 1 : -1

        // Forward move is always valid (if within bounds and not blocked)
        if let forwardPos = from.offset(file: 0, rank: forward) {
            if isValidMove(for: piece, to: forwardPos, on: board) {
                moves.append(forwardPos)
            }
        }

        // Sideways moves only if crossed the river
        if from.hasCrossedRiver(for: piece.color) {
            if let leftPos = from.offset(file: -1, rank: 0) {
                if isValidMove(for: piece, to: leftPos, on: board) {
                    moves.append(leftPos)
                }
            }

            if let rightPos = from.offset(file: 1, rank: 0) {
                if isValidMove(for: piece, to: rightPos, on: board) {
                    moves.append(rightPos)
                }
            }
        }

        return moves
    }

    func isValidMove(for piece: Piece, to: Position, on board: [[Piece?]]) -> Bool {
        let from = piece.position

        // Must be a valid position
        guard to.isValid else { return false }

        // Calculate differences
        let fileDiff = to.file - from.file
        let rankDiff = to.rank - from.rank

        // Determine forward direction based on color
        let forward = piece.color == .red ? 1 : -1

        // Check if the move is valid
        let isForwardMove = fileDiff == 0 && rankDiff == forward
        let isSidewaysMove = abs(fileDiff) == 1 && rankDiff == 0

        if isForwardMove {
            // Forward move is always allowed (for valid destination)
        } else if isSidewaysMove {
            // Sideways move only if crossed the river
            guard from.hasCrossedRiver(for: piece.color) else { return false }
        } else {
            // Invalid move pattern
            return false
        }

        // Cannot move backwards
        if piece.color == .red && rankDiff < 0 {
            return false
        }
        if piece.color == .black && rankDiff > 0 {
            return false
        }

        // Cannot capture own piece
        guard !board.hasFriendly(at: to, for: piece.color) else { return false }

        return true
    }
}
