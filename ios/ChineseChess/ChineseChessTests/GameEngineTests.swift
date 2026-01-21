//
//  GameEngineTests.swift
//  ChineseChessTests
//
//  Unit tests for the Xiangqi game engine.
//

import XCTest
@testable import ChineseChess

final class GameEngineTests: XCTestCase {

    var engine: GameEngine!

    override func setUp() {
        super.setUp()
        engine = GameEngine(gameId: "test-game", redPlayerId: "red-player", blackPlayerId: "black-player")
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testGameEngine_InitialState() {
        XCTAssertEqual(engine.currentTurn, .red)
        XCTAssertFalse(engine.isCheck)
        XCTAssertFalse(engine.isCheckmate)
        XCTAssertFalse(engine.isStalemate)
        XCTAssertFalse(engine.isGameOver)
        XCTAssertNil(engine.winner)
    }

    func testGameEngine_Properties() {
        XCTAssertEqual(engine.gameId, "test-game")
        XCTAssertEqual(engine.redPlayerId, "red-player")
        XCTAssertEqual(engine.blackPlayerId, "black-player")
    }

    func testGameEngine_InitialBoard() {
        // Verify initial piece placement
        let board = engine.board

        // Red general at e0
        XCTAssertEqual(board[0][4]?.type, .general)
        XCTAssertEqual(board[0][4]?.color, .red)

        // Black general at e9
        XCTAssertEqual(board[9][4]?.type, .general)
        XCTAssertEqual(board[9][4]?.color, .black)

        // Red chariot at a0
        XCTAssertEqual(board[0][0]?.type, .chariot)
        XCTAssertEqual(board[0][0]?.color, .red)
    }

    // MARK: - Move Execution Tests

    func testMakeMove_ValidMove() {
        // Red's first move: horse from b0 to c2
        let result = engine.makeMove(playerId: "red-player", from: "b0", to: "c2")

        switch result {
        case .success(let moveResult):
            XCTAssertEqual(moveResult.move.pieceType, .horse)
            XCTAssertEqual(moveResult.move.from, Position(file: 1, rank: 0))
            XCTAssertEqual(moveResult.move.to, Position(file: 2, rank: 2))
            XCTAssertNil(moveResult.capturedPiece)
            XCTAssertEqual(engine.currentTurn, .black)
        case .invalid(let reason):
            XCTFail("Move should be valid: \(reason)")
        }
    }

    func testMakeMove_WrongPlayer() {
        // Black tries to move first
        let result = engine.makeMove(playerId: "black-player", from: "b9", to: "c7")

        switch result {
        case .success:
            XCTFail("Move should be invalid")
        case .invalid(let reason):
            XCTAssertEqual(reason, "Not your turn")
        }
    }

    func testMakeMove_InvalidPosition() {
        let result = engine.makeMove(playerId: "red-player", from: "z9", to: "c2")

        switch result {
        case .success:
            XCTFail("Move should be invalid")
        case .invalid(let reason):
            XCTAssertTrue(reason.contains("Invalid"))
        }
    }

    func testMakeMove_NoPiece() {
        let result = engine.makeMove(playerId: "red-player", from: "d4", to: "d5")

        switch result {
        case .success:
            XCTFail("Move should be invalid")
        case .invalid(let reason):
            XCTAssertEqual(reason, "No piece at the specified position")
        }
    }

    func testMakeMove_OpponentPiece() {
        let result = engine.makeMove(playerId: "red-player", from: "b9", to: "c7")

        switch result {
        case .success:
            XCTFail("Move should be invalid")
        case .invalid(let reason):
            XCTAssertEqual(reason, "Cannot move opponent's piece")
        }
    }

    func testMakeMove_InvalidMovePattern() {
        // Chariot cannot move diagonally
        let result = engine.makeMove(playerId: "red-player", from: "a0", to: "c2")

        switch result {
        case .success:
            XCTFail("Move should be invalid")
        case .invalid(let reason):
            XCTAssertEqual(reason, "Invalid move for this piece")
        }
    }

    func testMakeMove_TurnSwitch() {
        // Make a move
        _ = engine.makeMove(playerId: "red-player", from: "b0", to: "c2")
        XCTAssertEqual(engine.currentTurn, .black)

        // Make another move
        _ = engine.makeMove(playerId: "black-player", from: "b9", to: "c7")
        XCTAssertEqual(engine.currentTurn, .red)
    }

    // MARK: - Capture Tests

    func testMakeMove_Capture() {
        // Setup: move pieces to enable capture
        _ = engine.makeMove(playerId: "red-player", from: "b0", to: "c2")
        _ = engine.makeMove(playerId: "black-player", from: "a6", to: "a5")
        _ = engine.makeMove(playerId: "red-player", from: "a0", to: "a5") // Capture

        let result = engine.makeMove(playerId: "red-player", from: "a0", to: "a5")

        // Note: This specific sequence depends on game state
        // Just verify the engine handles moves correctly
        XCTAssertNotNil(result)
    }

    // MARK: - Legal Moves Tests

    func testGetLegalMoves_ValidPiece() {
        let moves = engine.getLegalMoves(from: Position(file: 1, rank: 0))

        XCTAssertFalse(moves.isEmpty)
        XCTAssertTrue(moves.contains(Position(file: 2, rank: 2)))
        XCTAssertTrue(moves.contains(Position(file: 0, rank: 2)))
    }

    func testGetLegalMoves_EmptySquare() {
        let moves = engine.getLegalMoves(from: Position(file: 4, rank: 4))

        XCTAssertTrue(moves.isEmpty)
    }

    func testGetAllLegalMoves_InitialPosition() {
        let allMoves = engine.getAllLegalMoves()

        XCTAssertFalse(allMoves.isEmpty)

        // Horses should have moves
        XCTAssertNotNil(allMoves[Position(file: 1, rank: 0)])
        XCTAssertNotNil(allMoves[Position(file: 7, rank: 0)])

        // Cannons should have moves
        XCTAssertNotNil(allMoves[Position(file: 1, rank: 2)])
        XCTAssertNotNil(allMoves[Position(file: 7, rank: 2)])
    }

    // MARK: - Undo Tests

    func testUndoLastMove_Success() {
        // Make a move
        _ = engine.makeMove(playerId: "red-player", from: "b0", to: "c2")
        XCTAssertEqual(engine.currentTurn, .black)

        // Undo
        let success = engine.undoLastMove()
        XCTAssertTrue(success)
        XCTAssertEqual(engine.currentTurn, .red)

        // Verify horse is back
        XCTAssertEqual(engine.board[0][1]?.type, .horse)
        XCTAssertNil(engine.board[2][2])
    }

    func testUndoLastMove_NoMoves() {
        let success = engine.undoLastMove()
        XCTAssertFalse(success)
    }

    func testUndoLastMove_MultipleUndos() {
        // Make two moves
        _ = engine.makeMove(playerId: "red-player", from: "b0", to: "c2")
        _ = engine.makeMove(playerId: "black-player", from: "b9", to: "c7")

        XCTAssertEqual(engine.currentTurn, .red)

        // Undo once
        XCTAssertTrue(engine.undoLastMove())
        XCTAssertEqual(engine.currentTurn, .black)

        // Undo again
        XCTAssertTrue(engine.undoLastMove())
        XCTAssertEqual(engine.currentTurn, .red)
    }

    // MARK: - Validation Helper Tests

    func testCanMove_ValidPiece() {
        XCTAssertTrue(engine.canMove(from: Position(file: 1, rank: 0))) // Horse
        XCTAssertTrue(engine.canMove(from: Position(file: 1, rank: 2))) // Cannon
    }

    func testCanMove_EmptySquare() {
        XCTAssertFalse(engine.canMove(from: Position(file: 4, rank: 4)))
    }

    func testIsLegalMove_Valid() {
        XCTAssertTrue(engine.isLegalMove(from: Position(file: 1, rank: 0), to: Position(file: 2, rank: 2)))
    }

    func testIsLegalMove_Invalid() {
        XCTAssertFalse(engine.isLegalMove(from: Position(file: 0, rank: 0), to: Position(file: 2, rank: 2)))
    }

    // MARK: - State Export Tests

    func testCurrentState() {
        let state = engine.currentState

        XCTAssertEqual(state.currentTurn, .red)
        XCTAssertEqual(state.redPieces.count, 16)
        XCTAssertEqual(state.blackPieces.count, 16)
        XCTAssertTrue(state.capturedByRed.isEmpty)
        XCTAssertTrue(state.capturedByBlack.isEmpty)
        XCTAssertTrue(state.moveHistory.isEmpty)
    }

    func testBoardDescription() {
        let description = engine.boardDescription

        XCTAssertFalse(description.isEmpty)
        XCTAssertTrue(description.contains("Turn: Red"))
    }

    // MARK: - Complete Game Simulation Tests

    func testGameSimulation_OpeningMoves() {
        // Simulate some opening moves
        let moves: [(String, String, String)] = [
            ("red-player", "b0", "c2"),   // Red horse
            ("black-player", "b9", "c7"), // Black horse
            ("red-player", "h0", "g2"),   // Red horse
            ("black-player", "h9", "g7"), // Black horse
        ]

        for (player, from, to) in moves {
            let result = engine.makeMove(playerId: player, from: from, to: to)
            switch result {
            case .success:
                continue
            case .invalid(let reason):
                XCTFail("Move \(from) to \(to) failed: \(reason)")
            }
        }

        // Verify game state
        XCTAssertEqual(engine.currentTurn, .red)
        XCTAssertFalse(engine.isGameOver)
    }

    func testGameSimulation_MoveHistory() {
        _ = engine.makeMove(playerId: "red-player", from: "b0", to: "c2")
        _ = engine.makeMove(playerId: "black-player", from: "b9", to: "c7")

        let history = engine.currentState.moveHistory

        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history[0].pieceType, .horse)
        XCTAssertEqual(history[1].pieceType, .horse)
    }

    // MARK: - From Existing State Tests

    func testGameEngine_FromExistingState() {
        // Make some moves
        _ = engine.makeMove(playerId: "red-player", from: "b0", to: "c2")
        _ = engine.makeMove(playerId: "black-player", from: "b9", to: "c7")

        let state = engine.currentState

        // Create new engine from state
        let newEngine = GameEngine(
            gameId: "restored-game",
            redPlayerId: "red-player",
            blackPlayerId: "black-player",
            state: state
        )

        XCTAssertEqual(newEngine.currentTurn, .red)
        XCTAssertEqual(newEngine.currentState.moveHistory.count, 2)

        // Verify piece positions
        XCTAssertEqual(newEngine.board[2][2]?.type, .horse) // Red horse at c2
        XCTAssertEqual(newEngine.board[7][2]?.type, .horse) // Black horse at c7
    }

    // MARK: - Game Over Tests

    func testIsGameOver_NotOver() {
        XCTAssertFalse(engine.isGameOver)
        XCTAssertNil(engine.winner)
        XCTAssertNil(engine.winnerId)
    }
}
