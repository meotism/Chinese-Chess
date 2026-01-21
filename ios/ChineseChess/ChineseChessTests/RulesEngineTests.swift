//
//  RulesEngineTests.swift
//  ChineseChessTests
//
//  Unit tests for the Xiangqi rules engine.
//

import XCTest
@testable import ChineseChess

final class RulesEngineTests: XCTestCase {

    var rulesEngine: RulesEngine!

    override func setUp() {
        super.setUp()
        rulesEngine = RulesEngine()
    }

    override func tearDown() {
        rulesEngine = nil
        super.tearDown()
    }

    // MARK: - Test Helpers

    /// Creates a board with only the specified pieces
    private func createBoard(with pieces: [(PieceType, PlayerColor, Int, Int)]) -> [[Piece?]] {
        var board: [[Piece?]] = Array(
            repeating: Array(repeating: nil, count: Position.fileCount),
            count: Position.rankCount
        )

        for (type, color, file, rank) in pieces {
            let position = Position(file: file, rank: rank)
            let piece = Piece(type: type, color: color, position: position)
            board[rank][file] = piece
        }

        return board
    }

    /// Creates a piece for testing
    private func createPiece(_ type: PieceType, _ color: PlayerColor, _ file: Int, _ rank: Int) -> Piece {
        Piece(type: type, color: color, position: Position(file: file, rank: rank))
    }

    // MARK: - Flying General Tests

    func testFlyingGeneral_NotFacing() {
        let board = createBoard(with: [
            (.general, .red, 4, 0),
            (.general, .black, 3, 9) // Different file
        ])

        XCTAssertFalse(rulesEngine.isFlyingGeneral(board: board))
    }

    func testFlyingGeneral_FacingWithPieceBetween() {
        let board = createBoard(with: [
            (.general, .red, 4, 0),
            (.general, .black, 4, 9),
            (.cannon, .red, 4, 5) // Piece between
        ])

        XCTAssertFalse(rulesEngine.isFlyingGeneral(board: board))
    }

    func testFlyingGeneral_FacingWithoutPieceBetween() {
        let board = createBoard(with: [
            (.general, .red, 4, 0),
            (.general, .black, 4, 9) // Same file, no pieces between
        ])

        XCTAssertTrue(rulesEngine.isFlyingGeneral(board: board))
    }

    // MARK: - Check Detection Tests

    func testIsInCheck_InitialPosition() {
        let state = GameState.initial()

        XCTAssertFalse(rulesEngine.isInCheck(color: .red, board: state.board))
        XCTAssertFalse(rulesEngine.isInCheck(color: .black, board: state.board))
    }

    func testIsInCheck_ChariotCheck() {
        let board = createBoard(with: [
            (.general, .red, 4, 0),
            (.general, .black, 5, 9),
            (.chariot, .black, 4, 5) // Attacking red general
        ])

        XCTAssertTrue(rulesEngine.isInCheck(color: .red, board: board))
        XCTAssertFalse(rulesEngine.isInCheck(color: .black, board: board))
    }

    func testIsInCheck_HorseCheck() {
        let board = createBoard(with: [
            (.general, .red, 4, 0),
            (.general, .black, 5, 9),
            (.horse, .black, 5, 2) // Attacking red general
        ])

        XCTAssertTrue(rulesEngine.isInCheck(color: .red, board: board))
    }

    func testIsInCheck_CannonCheck() {
        let board = createBoard(with: [
            (.general, .red, 4, 0),
            (.general, .black, 5, 9),
            (.cannon, .black, 4, 7),
            (.soldier, .red, 4, 3) // Screen for cannon
        ])

        XCTAssertTrue(rulesEngine.isInCheck(color: .red, board: board))
    }

    func testIsInCheck_FlyingGeneralCheck() {
        let board = createBoard(with: [
            (.general, .red, 4, 0),
            (.general, .black, 4, 9)
        ])

        // Both should be in "check" due to flying general
        XCTAssertTrue(rulesEngine.isInCheck(color: .red, board: board))
        XCTAssertTrue(rulesEngine.isInCheck(color: .black, board: board))
    }

    // MARK: - Checkmate Tests

    func testIsCheckmate_NotInCheck() {
        let state = GameState.initial()

        XCTAssertFalse(rulesEngine.isCheckmate(color: .red, board: state.board))
        XCTAssertFalse(rulesEngine.isCheckmate(color: .black, board: state.board))
    }

    func testIsCheckmate_CanEscape() {
        let board = createBoard(with: [
            (.general, .red, 4, 1), // General can move sideways
            (.general, .black, 5, 9),
            (.chariot, .black, 4, 5)
        ])

        XCTAssertFalse(rulesEngine.isCheckmate(color: .red, board: board))
    }

    func testIsCheckmate_CanBlock() {
        let board = createBoard(with: [
            (.general, .red, 4, 0),
            (.general, .black, 5, 9),
            (.chariot, .black, 4, 5),
            (.chariot, .red, 0, 3) // Can block at e3
        ])

        XCTAssertFalse(rulesEngine.isCheckmate(color: .red, board: board))
    }

    func testIsCheckmate_CanCapture() {
        let board = createBoard(with: [
            (.general, .red, 4, 0),
            (.general, .black, 5, 9),
            (.chariot, .black, 4, 5),
            (.chariot, .red, 0, 5) // Can capture attacking chariot
        ])

        XCTAssertFalse(rulesEngine.isCheckmate(color: .red, board: board))
    }

    // MARK: - Stalemate Tests

    func testIsStalemate_NotStalemate() {
        let state = GameState.initial()

        XCTAssertFalse(rulesEngine.isStalemate(color: .red, board: state.board))
    }

    func testIsStalemate_NotWhenInCheck() {
        let board = createBoard(with: [
            (.general, .red, 4, 0),
            (.general, .black, 5, 9),
            (.chariot, .black, 4, 5) // Check
        ])

        // Even if no moves, if in check it's checkmate not stalemate
        XCTAssertFalse(rulesEngine.isStalemate(color: .red, board: board))
    }

    // MARK: - Legal Moves Tests

    func testGetLegalMoves_FiltersSelfCheck() {
        let board = createBoard(with: [
            (.general, .red, 4, 0),
            (.general, .black, 5, 9),
            (.chariot, .red, 4, 3), // Pinned piece
            (.chariot, .black, 4, 7)
        ])

        let pinnedChariot = createPiece(.chariot, .red, 4, 3)
        let legalMoves = rulesEngine.getLegalMoves(for: pinnedChariot, board: board)

        // All moves should stay on file 4 to avoid exposing general
        for move in legalMoves {
            XCTAssertEqual(move.file, 4, "Pinned chariot should only move along file")
        }
    }

    func testGetLegalMoves_FiltersFlyingGeneral() {
        let board = createBoard(with: [
            (.general, .red, 4, 0),
            (.general, .black, 4, 9),
            (.chariot, .red, 4, 4) // Blocking flying general
        ])

        let blockingChariot = createPiece(.chariot, .red, 4, 4)
        let legalMoves = rulesEngine.getLegalMoves(for: blockingChariot, board: board)

        // Moving off file would create flying general
        for move in legalMoves {
            XCTAssertEqual(move.file, 4, "Blocking chariot should stay on file")
        }
    }

    // MARK: - IsValidMove Tests

    func testIsValidMove_ValidMove() {
        let state = GameState.initial()

        // Horse can make opening move
        guard let horse = state.piece(at: Position(file: 1, rank: 0)) else {
            XCTFail("Expected horse at b0")
            return
        }

        XCTAssertTrue(rulesEngine.isValidMove(for: horse, to: Position(file: 2, rank: 2), board: state.board))
    }

    func testIsValidMove_MoveExposesCheck() {
        let board = createBoard(with: [
            (.general, .red, 4, 0),
            (.general, .black, 5, 9),
            (.chariot, .red, 4, 3),
            (.chariot, .black, 4, 7)
        ])

        let pinnedChariot = createPiece(.chariot, .red, 4, 3)

        // Moving sideways exposes general
        XCTAssertFalse(rulesEngine.isValidMove(for: pinnedChariot, to: Position(file: 5, rank: 3), board: board))

        // Moving along file is valid
        XCTAssertTrue(rulesEngine.isValidMove(for: pinnedChariot, to: Position(file: 4, rank: 4), board: board))
    }

    func testIsValidMove_MoveCreatesFlyingGeneral() {
        let board = createBoard(with: [
            (.general, .red, 4, 0),
            (.general, .black, 4, 9),
            (.chariot, .red, 4, 4)
        ])

        let chariot = createPiece(.chariot, .red, 4, 4)

        // Moving off file creates flying general
        XCTAssertFalse(rulesEngine.isValidMove(for: chariot, to: Position(file: 5, rank: 4), board: board))
    }

    // MARK: - WouldResultInCheck Tests

    func testWouldResultInCheck_Yes() {
        let board = createBoard(with: [
            (.general, .red, 4, 0),
            (.general, .black, 4, 9),
            (.chariot, .red, 0, 5) // Can check black
        ])

        let chariot = createPiece(.chariot, .red, 0, 5)

        // Moving to e5 would check black
        XCTAssertTrue(rulesEngine.wouldResultInCheck(piece: chariot, to: Position(file: 4, rank: 5), board: board))
    }

    func testWouldResultInCheck_No() {
        let board = createBoard(with: [
            (.general, .red, 4, 0),
            (.general, .black, 4, 9),
            (.cannon, .black, 4, 5), // Blocking
            (.chariot, .red, 0, 3)
        ])

        let chariot = createPiece(.chariot, .red, 0, 3)

        // Moving sideways doesn't check
        XCTAssertFalse(rulesEngine.wouldResultInCheck(piece: chariot, to: Position(file: 1, rank: 3), board: board))
    }

    // MARK: - GetCheckingPieces Tests

    func testGetCheckingPieces_None() {
        let state = GameState.initial()

        let checkingPieces = rulesEngine.getCheckingPieces(color: .red, board: state.board)

        XCTAssertEqual(checkingPieces.count, 0)
    }

    func testGetCheckingPieces_Single() {
        let board = createBoard(with: [
            (.general, .red, 4, 0),
            (.general, .black, 5, 9),
            (.chariot, .black, 4, 5)
        ])

        let checkingPieces = rulesEngine.getCheckingPieces(color: .red, board: board)

        XCTAssertEqual(checkingPieces.count, 1)
        XCTAssertEqual(checkingPieces.first?.type, .chariot)
    }

    func testGetCheckingPieces_Double() {
        let board = createBoard(with: [
            (.general, .red, 4, 0),
            (.general, .black, 3, 9),
            (.chariot, .black, 4, 5),
            (.horse, .black, 5, 2)
        ])

        let checkingPieces = rulesEngine.getCheckingPieces(color: .red, board: board)

        XCTAssertEqual(checkingPieces.count, 2)
    }

    // MARK: - HasLegalMoves Tests

    func testHasLegalMoves_InitialPosition() {
        let state = GameState.initial()

        XCTAssertTrue(rulesEngine.hasLegalMoves(color: .red, board: state.board))
        XCTAssertTrue(rulesEngine.hasLegalMoves(color: .black, board: state.board))
    }
}
