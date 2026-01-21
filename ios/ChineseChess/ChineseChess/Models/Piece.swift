//
//  Piece.swift
//  ChineseChess
//
//  Represents a chess piece with its type, color, and position.
//

import Foundation

// MARK: - PieceType

/// The type of a Xiangqi piece.
enum PieceType: String, Codable, CaseIterable, Hashable {
    /// The General (King) - moves one step orthogonally within the palace
    case general

    /// The Advisor (Guard) - moves one step diagonally within the palace
    case advisor

    /// The Elephant (Bishop) - moves two steps diagonally, cannot cross the river
    case elephant

    /// The Horse (Knight) - moves in an L-shape, can be blocked
    case horse

    /// The Chariot (Rook) - moves any distance orthogonally
    case chariot

    /// The Cannon - moves orthogonally, captures by jumping over one piece
    case cannon

    /// The Soldier (Pawn) - moves forward, gains sideways movement after crossing river
    case soldier

    /// Returns the point value of the piece for evaluation purposes.
    var value: Int {
        switch self {
        case .general: return 10000  // Invaluable
        case .chariot: return 9
        case .cannon: return 4
        case .horse: return 4
        case .elephant: return 2
        case .advisor: return 2
        case .soldier: return 1
        }
    }
}

// MARK: - PlayerColor

/// The color of a player in Xiangqi.
enum PlayerColor: String, Codable, CaseIterable, Hashable {
    /// Red player - moves first
    case red

    /// Black player - moves second
    case black

    /// Returns the opposite color.
    var opposite: PlayerColor {
        switch self {
        case .red: return .black
        case .black: return .red
        }
    }

    /// Returns the starting rank for this player's back row.
    var homeRank: Int {
        switch self {
        case .red: return 0
        case .black: return 9
        }
    }

    /// Returns the direction of forward movement for this color.
    /// Positive for Red (moving up), negative for Black (moving down).
    var forwardDirection: Int {
        switch self {
        case .red: return 1
        case .black: return -1
        }
    }
}

// MARK: - Piece

/// Represents a piece on the Xiangqi board.
struct Piece: Hashable, Codable, Equatable, Identifiable {

    // MARK: - Properties

    /// Unique identifier for the piece
    let id: UUID

    /// The type of piece
    let type: PieceType

    /// The color/side of the piece
    let color: PlayerColor

    /// The current position on the board
    var position: Position

    // MARK: - Computed Properties

    /// Returns the Chinese character for this piece.
    var character: String {
        switch (type, color) {
        case (.general, .red): return "帅"
        case (.general, .black): return "将"
        case (.advisor, .red): return "仕"
        case (.advisor, .black): return "士"
        case (.elephant, .red): return "相"
        case (.elephant, .black): return "象"
        case (.horse, .red): return "马"   // Traditional: 傌
        case (.horse, .black): return "马"
        case (.chariot, .red): return "车"  // Traditional: 俥
        case (.chariot, .black): return "车"
        case (.cannon, .red): return "炮"
        case (.cannon, .black): return "炮" // Traditional: 砲
        case (.soldier, .red): return "兵"
        case (.soldier, .black): return "卒"
        }
    }

    /// Returns the English abbreviation for notation purposes.
    var abbreviation: String {
        switch type {
        case .general: return "K"
        case .advisor: return "A"
        case .elephant: return "E"
        case .horse: return "H"
        case .chariot: return "R"
        case .cannon: return "C"
        case .soldier: return "P"
        }
    }

    // MARK: - Initialization

    /// Creates a new piece.
    ///
    /// - Parameters:
    ///   - type: The type of piece
    ///   - color: The color/side of the piece
    ///   - position: The initial position on the board
    init(type: PieceType, color: PlayerColor, position: Position) {
        self.id = UUID()
        self.type = type
        self.color = color
        self.position = position
    }

    /// Creates a piece with a specific ID (for deserialization).
    ///
    /// - Parameters:
    ///   - id: The unique identifier
    ///   - type: The type of piece
    ///   - color: The color/side of the piece
    ///   - position: The position on the board
    init(id: UUID, type: PieceType, color: PlayerColor, position: Position) {
        self.id = id
        self.type = type
        self.color = color
        self.position = position
    }

    // MARK: - Methods

    /// Returns a copy of the piece at a new position.
    ///
    /// - Parameter newPosition: The new position
    /// - Returns: A new piece instance at the specified position
    func moved(to newPosition: Position) -> Piece {
        Piece(id: id, type: type, color: color, position: newPosition)
    }
}

// MARK: - CustomStringConvertible

extension Piece: CustomStringConvertible {
    var description: String {
        "\(color.rawValue.capitalized) \(type.rawValue) at \(position.notation)"
    }
}
