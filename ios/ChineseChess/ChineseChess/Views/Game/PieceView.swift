//
//  PieceView.swift
//  ChineseChess
//
//  View component for rendering a single chess piece.
//

import SwiftUI

/// A view that displays a single Xiangqi piece with its Chinese character.
struct PieceView: View {

    // MARK: - Properties

    /// The piece to display
    let piece: Piece

    /// Whether this piece is currently selected
    var isSelected: Bool = false

    /// The size of the piece
    var size: CGFloat = 44

    // MARK: - Body

    var body: some View {
        ZStack {
            // Piece background circle
            Circle()
                .fill(pieceBackgroundColor)
                .frame(width: size, height: size)

            // Piece border
            Circle()
                .strokeBorder(pieceBorderColor, lineWidth: 2)
                .frame(width: size, height: size)

            // Inner border for traditional look
            Circle()
                .strokeBorder(pieceInnerBorderColor, lineWidth: 1)
                .frame(width: size - 6, height: size - 6)

            // Chinese character
            Text(piece.character)
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundColor(pieceTextColor)

            // Selection highlight
            if isSelected {
                Circle()
                    .strokeBorder(Color.yellow, lineWidth: 3)
                    .frame(width: size + 4, height: size + 4)
            }
        }
        .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
        .accessibilityLabel("\(piece.color.rawValue) \(piece.type.rawValue)")
    }

    // MARK: - Colors

    private var pieceBackgroundColor: Color {
        switch piece.color {
        case .red:
            return Color(red: 0.95, green: 0.9, blue: 0.85)
        case .black:
            return Color(red: 0.95, green: 0.9, blue: 0.85)
        }
    }

    private var pieceBorderColor: Color {
        switch piece.color {
        case .red:
            return Color(red: 0.7, green: 0.1, blue: 0.1)
        case .black:
            return Color(red: 0.1, green: 0.1, blue: 0.1)
        }
    }

    private var pieceInnerBorderColor: Color {
        switch piece.color {
        case .red:
            return Color(red: 0.8, green: 0.2, blue: 0.2)
        case .black:
            return Color(red: 0.2, green: 0.2, blue: 0.2)
        }
    }

    private var pieceTextColor: Color {
        switch piece.color {
        case .red:
            return Color(red: 0.7, green: 0.1, blue: 0.1)
        case .black:
            return Color(red: 0.1, green: 0.1, blue: 0.1)
        }
    }
}

// MARK: - Preview

#Preview("Red General") {
    PieceView(
        piece: Piece(type: .general, color: .red, position: Position(file: 4, rank: 0)),
        size: 60
    )
}

#Preview("Black General") {
    PieceView(
        piece: Piece(type: .general, color: .black, position: Position(file: 4, rank: 9)),
        size: 60
    )
}

#Preview("Selected Piece") {
    PieceView(
        piece: Piece(type: .chariot, color: .red, position: Position(file: 0, rank: 0)),
        isSelected: true,
        size: 60
    )
}

#Preview("All Pieces") {
    VStack(spacing: 20) {
        HStack(spacing: 10) {
            ForEach(PieceType.allCases, id: \.self) { type in
                PieceView(
                    piece: Piece(type: type, color: .red, position: Position(file: 0, rank: 0)),
                    size: 44
                )
            }
        }
        HStack(spacing: 10) {
            ForEach(PieceType.allCases, id: \.self) { type in
                PieceView(
                    piece: Piece(type: type, color: .black, position: Position(file: 0, rank: 9)),
                    size: 44
                )
            }
        }
    }
    .padding()
}
