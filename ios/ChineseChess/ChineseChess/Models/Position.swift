//
//  Position.swift
//  ChineseChess
//
//  Represents a position on the Xiangqi board.
//

import Foundation

/// Represents a position on the 9x10 Xiangqi board.
///
/// The board uses a coordinate system where:
/// - `file` ranges from 0-8 (columns a-i from left to right)
/// - `rank` ranges from 0-9 (rows 0-9 from bottom to top)
///
/// Red pieces start at ranks 0-4, Black pieces start at ranks 5-9.
/// The river is between ranks 4 and 5.
struct Position: Hashable, Codable, Equatable {

    // MARK: - Constants

    /// The number of files (columns) on the board
    static let fileCount = 9

    /// The number of ranks (rows) on the board
    static let rankCount = 10

    /// File labels for notation
    static let fileLabels = "abcdefghi"

    // MARK: - Properties

    /// The file (column) index, 0-8 from left to right
    let file: Int

    /// The rank (row) index, 0-9 from bottom to top
    let rank: Int

    // MARK: - Computed Properties

    /// Returns the algebraic notation for this position (e.g., "e0", "d9")
    var notation: String {
        let fileChar = Position.fileLabels[
            Position.fileLabels.index(Position.fileLabels.startIndex, offsetBy: file)
        ]
        return "\(fileChar)\(rank)"
    }

    /// Returns true if this position is valid (within board bounds)
    var isValid: Bool {
        file >= 0 && file < Position.fileCount &&
        rank >= 0 && rank < Position.rankCount
    }

    /// Returns true if this position is within the Red palace (ranks 0-2, files 3-5)
    var isInRedPalace: Bool {
        file >= 3 && file <= 5 && rank >= 0 && rank <= 2
    }

    /// Returns true if this position is within the Black palace (ranks 7-9, files 3-5)
    var isInBlackPalace: Bool {
        file >= 3 && file <= 5 && rank >= 7 && rank <= 9
    }

    /// Returns true if this position is on the Red side of the river (ranks 0-4)
    var isOnRedSide: Bool {
        rank >= 0 && rank <= 4
    }

    /// Returns true if this position is on the Black side of the river (ranks 5-9)
    var isOnBlackSide: Bool {
        rank >= 5 && rank <= 9
    }

    // MARK: - Initialization

    /// Creates a new position with the given file and rank.
    ///
    /// - Parameters:
    ///   - file: The file (column) index, 0-8
    ///   - rank: The rank (row) index, 0-9
    init(file: Int, rank: Int) {
        self.file = file
        self.rank = rank
    }

    /// Creates a position from algebraic notation.
    ///
    /// - Parameter notation: The algebraic notation (e.g., "e0", "d9")
    /// - Returns: A Position if the notation is valid, nil otherwise
    init?(notation: String) {
        guard notation.count >= 2 else { return nil }

        let fileChar = notation[notation.startIndex]
        guard let fileIndex = Position.fileLabels.firstIndex(of: fileChar) else {
            return nil
        }

        let rankString = String(notation.dropFirst())
        guard let rank = Int(rankString) else { return nil }

        self.file = Position.fileLabels.distance(
            from: Position.fileLabels.startIndex,
            to: fileIndex
        )
        self.rank = rank

        guard isValid else { return nil }
    }

    // MARK: - Methods

    /// Returns true if this position is within the palace for the given color.
    ///
    /// - Parameter color: The player color
    /// - Returns: True if within the palace
    func isInPalace(for color: PlayerColor) -> Bool {
        switch color {
        case .red:
            return isInRedPalace
        case .black:
            return isInBlackPalace
        }
    }

    /// Returns true if this position has crossed the river for the given color.
    ///
    /// - Parameter color: The player color
    /// - Returns: True if the position has crossed the river
    func hasCrossedRiver(for color: PlayerColor) -> Bool {
        switch color {
        case .red:
            return isOnBlackSide
        case .black:
            return isOnRedSide
        }
    }

    /// Returns the Manhattan distance to another position.
    ///
    /// - Parameter other: The other position
    /// - Returns: The sum of absolute differences in file and rank
    func manhattanDistance(to other: Position) -> Int {
        abs(file - other.file) + abs(rank - other.rank)
    }

    /// Returns a new position offset by the given values.
    ///
    /// - Parameters:
    ///   - fileOffset: The file offset
    ///   - rankOffset: The rank offset
    /// - Returns: A new position, or nil if the result is invalid
    func offset(file fileOffset: Int, rank rankOffset: Int) -> Position? {
        let newPosition = Position(file: file + fileOffset, rank: rank + rankOffset)
        return newPosition.isValid ? newPosition : nil
    }
}

// MARK: - CustomStringConvertible

extension Position: CustomStringConvertible {
    var description: String {
        notation
    }
}
