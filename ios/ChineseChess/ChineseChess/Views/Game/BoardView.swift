//
//  BoardView.swift
//  ChineseChess
//
//  View component for rendering the Xiangqi game board.
//

import SwiftUI

/// Constants for board layout and drawing.
struct BoardConstants {
    /// Number of files (columns) on the board
    static let fileCount = 9

    /// Number of ranks (rows) on the board
    static let rankCount = 10

    /// The padding around the board
    static let boardPadding: CGFloat = 20

    /// Board background color (traditional wood color)
    static let boardColor = Color(red: 0.87, green: 0.72, blue: 0.53)

    /// Line color for the board grid
    static let lineColor = Color(red: 0.4, green: 0.25, blue: 0.1)

    /// River text
    static let riverText = "楚河          汉界"
}

/// A view that renders the Xiangqi game board with grid, river, and palace markings.
struct BoardView: View {

    // MARK: - Properties

    /// The current game state
    let gameState: GameState

    /// The currently selected position
    var selectedPosition: Position?

    /// Valid move destinations for the selected piece
    var validMoves: [Position] = []

    /// The last move made (for highlighting)
    var lastMove: Move?

    /// Callback when a position is tapped
    var onPositionTapped: ((Position) -> Void)?

    /// The size of the board (width)
    @State private var boardSize: CGSize = .zero

    // MARK: - Computed Properties

    /// The size of each cell
    private var cellSize: CGFloat {
        let availableWidth = boardSize.width - BoardConstants.boardPadding * 2
        return availableWidth / CGFloat(BoardConstants.fileCount - 1)
    }

    /// The size of each piece
    private var pieceSize: CGFloat {
        cellSize * 0.9
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let boardWidth = min(geometry.size.width, geometry.size.height * 0.9)
            let boardHeight = boardWidth * CGFloat(BoardConstants.rankCount - 1) / CGFloat(BoardConstants.fileCount - 1) + BoardConstants.boardPadding * 2

            ZStack {
                // Board background
                RoundedRectangle(cornerRadius: 8)
                    .fill(BoardConstants.boardColor)
                    .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)

                // Board content
                Canvas { context, size in
                    drawBoard(context: context, size: size)
                }

                // Move highlights and pieces
                piecesOverlay
            }
            .frame(width: boardWidth, height: boardHeight)
            .onAppear {
                boardSize = CGSize(width: boardWidth, height: boardHeight)
            }
            .onChange(of: geometry.size) { _, newValue in
                let newWidth = min(newValue.width, newValue.height * 0.9)
                let newHeight = newWidth * CGFloat(BoardConstants.rankCount - 1) / CGFloat(BoardConstants.fileCount - 1) + BoardConstants.boardPadding * 2
                boardSize = CGSize(width: newWidth, height: newHeight)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Board Drawing

    /// Draws the board grid, river, and palace markings.
    private func drawBoard(context: GraphicsContext, size: CGSize) {
        let padding = BoardConstants.boardPadding
        let availableWidth = size.width - padding * 2
        let cellWidth = availableWidth / CGFloat(BoardConstants.fileCount - 1)
        let cellHeight = cellWidth

        // Draw horizontal lines
        for rank in 0..<BoardConstants.rankCount {
            let y = padding + CGFloat(BoardConstants.rankCount - 1 - rank) * cellHeight
            var path = Path()
            path.move(to: CGPoint(x: padding, y: y))
            path.addLine(to: CGPoint(x: size.width - padding, y: y))
            context.stroke(path, with: .color(BoardConstants.lineColor), lineWidth: rank == 0 || rank == 9 ? 2 : 1)
        }

        // Draw vertical lines (different handling for river)
        for file in 0..<BoardConstants.fileCount {
            let x = padding + CGFloat(file) * cellWidth

            // Upper half (Black side)
            var upperPath = Path()
            let upperStartY = padding
            let upperEndY = padding + 4 * cellHeight
            upperPath.move(to: CGPoint(x: x, y: upperStartY))
            upperPath.addLine(to: CGPoint(x: x, y: upperEndY))
            context.stroke(upperPath, with: .color(BoardConstants.lineColor), lineWidth: file == 0 || file == 8 ? 2 : 1)

            // Lower half (Red side)
            var lowerPath = Path()
            let lowerStartY = padding + 5 * cellHeight
            let lowerEndY = padding + 9 * cellHeight
            lowerPath.move(to: CGPoint(x: x, y: lowerStartY))
            lowerPath.addLine(to: CGPoint(x: x, y: lowerEndY))
            context.stroke(lowerPath, with: .color(BoardConstants.lineColor), lineWidth: file == 0 || file == 8 ? 2 : 1)

            // Edge lines cross the river
            if file == 0 || file == 8 {
                var riverPath = Path()
                riverPath.move(to: CGPoint(x: x, y: upperEndY))
                riverPath.addLine(to: CGPoint(x: x, y: lowerStartY))
                context.stroke(riverPath, with: .color(BoardConstants.lineColor), lineWidth: 2)
            }
        }

        // Draw palace diagonals (Red palace: files 3-5, ranks 0-2)
        drawPalaceDiagonals(context: context, size: size, centerFile: 4, startRank: 0, cellWidth: cellWidth)

        // Draw palace diagonals (Black palace: files 3-5, ranks 7-9)
        drawPalaceDiagonals(context: context, size: size, centerFile: 4, startRank: 7, cellWidth: cellWidth)

        // Draw cannon and soldier position markers
        drawPositionMarkers(context: context, size: size, cellWidth: cellWidth)

        // Draw river text
        drawRiverText(context: context, size: size, cellWidth: cellWidth)
    }

    /// Draws the diagonal lines in a palace.
    private func drawPalaceDiagonals(context: GraphicsContext, size: CGSize, centerFile: Int, startRank: Int, cellWidth: CGFloat) {
        let padding = BoardConstants.boardPadding
        let endRank = startRank + 2

        // Calculate positions
        let leftX = padding + CGFloat(centerFile - 1) * cellWidth
        let centerX = padding + CGFloat(centerFile) * cellWidth
        let rightX = padding + CGFloat(centerFile + 1) * cellWidth

        let topY = padding + CGFloat(BoardConstants.rankCount - 1 - endRank) * cellWidth
        let middleY = padding + CGFloat(BoardConstants.rankCount - 1 - (startRank + 1)) * cellWidth
        let bottomY = padding + CGFloat(BoardConstants.rankCount - 1 - startRank) * cellWidth

        // Draw X pattern
        var path1 = Path()
        path1.move(to: CGPoint(x: leftX, y: topY))
        path1.addLine(to: CGPoint(x: rightX, y: bottomY))
        context.stroke(path1, with: .color(BoardConstants.lineColor), lineWidth: 1)

        var path2 = Path()
        path2.move(to: CGPoint(x: rightX, y: topY))
        path2.addLine(to: CGPoint(x: leftX, y: bottomY))
        context.stroke(path2, with: .color(BoardConstants.lineColor), lineWidth: 1)
    }

    /// Draws position markers for cannons and soldiers.
    private func drawPositionMarkers(context: GraphicsContext, size: CGSize, cellWidth: CGFloat) {
        let padding = BoardConstants.boardPadding
        let markerSize: CGFloat = 6
        let markerOffset: CGFloat = 4

        // Cannon positions
        let cannonPositions = [
            (1, 2), (7, 2), // Red cannons
            (1, 7), (7, 7)  // Black cannons
        ]

        // Soldier positions
        let soldierPositions = [
            (0, 3), (2, 3), (4, 3), (6, 3), (8, 3), // Red soldiers
            (0, 6), (2, 6), (4, 6), (6, 6), (8, 6)  // Black soldiers
        ]

        for (file, rank) in cannonPositions + soldierPositions {
            let x = padding + CGFloat(file) * cellWidth
            let y = padding + CGFloat(BoardConstants.rankCount - 1 - rank) * cellWidth

            drawPositionMarker(context: context, x: x, y: y, file: file, markerSize: markerSize, markerOffset: markerOffset)
        }
    }

    /// Draws a position marker at the specified coordinates.
    private func drawPositionMarker(context: GraphicsContext, x: CGFloat, y: CGFloat, file: Int, markerSize: CGFloat, markerOffset: CGFloat) {
        let corners: [(dx: CGFloat, dy: CGFloat, hx: CGFloat, hy: CGFloat, vx: CGFloat, vy: CGFloat)] = [
            (-1, -1, 1, 0, 0, 1),  // Top-left
            (1, -1, -1, 0, 0, 1),  // Top-right
            (-1, 1, 1, 0, 0, -1),  // Bottom-left
            (1, 1, -1, 0, 0, -1)   // Bottom-right
        ]

        for corner in corners {
            // Skip markers that would go off the edge of the board
            if file == 0 && corner.dx < 0 { continue }
            if file == 8 && corner.dx > 0 { continue }

            let startX = x + corner.dx * markerOffset
            let startY = y + corner.dy * markerOffset

            var path = Path()
            // Horizontal line
            path.move(to: CGPoint(x: startX, y: startY))
            path.addLine(to: CGPoint(x: startX + corner.hx * markerSize, y: startY))

            // Vertical line
            path.move(to: CGPoint(x: startX, y: startY))
            path.addLine(to: CGPoint(x: startX, y: startY + corner.vy * markerSize))

            context.stroke(path, with: .color(BoardConstants.lineColor), lineWidth: 1)
        }
    }

    /// Draws the river text.
    private func drawRiverText(context: GraphicsContext, size: CGSize, cellWidth: CGFloat) {
        let padding = BoardConstants.boardPadding
        let centerX = size.width / 2
        let riverY = padding + 4.5 * cellWidth

        let text = Text(BoardConstants.riverText)
            .font(.system(size: cellWidth * 0.4, weight: .medium))
            .foregroundColor(BoardConstants.lineColor)

        context.draw(text, at: CGPoint(x: centerX, y: riverY), anchor: .center)
    }

    // MARK: - Pieces Overlay

    /// The overlay containing move highlights and pieces.
    private var piecesOverlay: some View {
        let padding = BoardConstants.boardPadding
        let availableWidth = boardSize.width - padding * 2
        let cellWidth = availableWidth / CGFloat(BoardConstants.fileCount - 1)

        return ZStack {
            // Last move highlight
            if let lastMove = lastMove {
                moveHighlight(from: lastMove.from, to: lastMove.to, cellWidth: cellWidth, padding: padding)
            }

            // Valid move indicators
            ForEach(validMoves, id: \.self) { position in
                validMoveIndicator(at: position, cellWidth: cellWidth, padding: padding)
            }

            // Pieces
            ForEach(gameState.allPieces, id: \.id) { piece in
                pieceView(piece: piece, cellWidth: cellWidth, padding: padding)
            }
        }
    }

    /// Creates a highlight for the last move.
    private func moveHighlight(from: Position, to: Position, cellWidth: CGFloat, padding: CGFloat) -> some View {
        Group {
            // From position highlight
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.yellow.opacity(0.3))
                .frame(width: cellWidth * 0.9, height: cellWidth * 0.9)
                .position(positionToPoint(from, cellWidth: cellWidth, padding: padding))

            // To position highlight
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.yellow.opacity(0.3))
                .frame(width: cellWidth * 0.9, height: cellWidth * 0.9)
                .position(positionToPoint(to, cellWidth: cellWidth, padding: padding))
        }
    }

    /// Creates an indicator for a valid move destination.
    private func validMoveIndicator(at position: Position, cellWidth: CGFloat, padding: CGFloat) -> some View {
        let point = positionToPoint(position, cellWidth: cellWidth, padding: padding)
        let hasEnemy = gameState.hasEnemy(at: position, for: gameState.currentTurn)

        return Group {
            if hasEnemy {
                // Capture indicator - ring around enemy piece
                Circle()
                    .strokeBorder(Color.green.opacity(0.8), lineWidth: 3)
                    .frame(width: pieceSize + 8, height: pieceSize + 8)
                    .position(point)
            } else {
                // Move indicator - small dot
                Circle()
                    .fill(Color.green.opacity(0.6))
                    .frame(width: cellWidth * 0.3, height: cellWidth * 0.3)
                    .position(point)
            }
        }
        .onTapGesture {
            onPositionTapped?(position)
        }
    }

    /// Creates a piece view at the specified position.
    private func pieceView(piece: Piece, cellWidth: CGFloat, padding: CGFloat) -> some View {
        let point = positionToPoint(piece.position, cellWidth: cellWidth, padding: padding)
        let isSelected = selectedPosition == piece.position

        return PieceView(piece: piece, isSelected: isSelected, size: pieceSize)
            .position(point)
            .onTapGesture {
                onPositionTapped?(piece.position)
            }
            .animation(.easeInOut(duration: 0.25), value: piece.position)
    }

    /// Converts a board position to a point in the view.
    private func positionToPoint(_ position: Position, cellWidth: CGFloat, padding: CGFloat) -> CGPoint {
        let x = padding + CGFloat(position.file) * cellWidth
        let y = padding + CGFloat(BoardConstants.rankCount - 1 - position.rank) * cellWidth
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Preview

#Preview("Initial Position") {
    BoardView(gameState: .initial())
        .padding()
}

#Preview("With Selection") {
    let state = GameState.initial()
    BoardView(
        gameState: state,
        selectedPosition: Position(file: 1, rank: 0),
        validMoves: [
            Position(file: 2, rank: 2),
            Position(file: 0, rank: 2)
        ]
    )
    .padding()
}
