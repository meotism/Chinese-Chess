//
//  MoveValidatorsTests.swift
//  ChineseChessTests
//
//  Unit tests for Xiangqi piece move validators.
//

import XCTest
@testable import ChineseChess

final class MoveValidatorsTests: XCTestCase {

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

    // MARK: - General Validator Tests

    func testGeneralValidator_ValidMovesFromCenter() {
        // General in center of palace
        let general = createPiece(.general, .red, 4, 1)
        let board = createBoard(with: [(.general, .red, 4, 1)])

        let validator = GeneralValidator()
        let moves = validator.getValidMoves(for: general, on: board)

        // Should have 4 orthogonal moves within palace
        XCTAssertEqual(moves.count, 4)
        XCTAssertTrue(moves.contains(Position(file: 4, rank: 2))) // up
        XCTAssertTrue(moves.contains(Position(file: 4, rank: 0))) // down
        XCTAssertTrue(moves.contains(Position(file: 5, rank: 1))) // right
        XCTAssertTrue(moves.contains(Position(file: 3, rank: 1))) // left
    }

    func testGeneralValidator_StaysInPalace() {
        // General at corner of palace
        let general = createPiece(.general, .red, 3, 0)
        let board = createBoard(with: [(.general, .red, 3, 0)])

        let validator = GeneralValidator()

        // Should not move outside palace
        XCTAssertFalse(validator.isValidMove(for: general, to: Position(file: 2, rank: 0), on: board))
        XCTAssertFalse(validator.isValidMove(for: general, to: Position(file: 3, rank: -1), on: board))
    }

    func testGeneralValidator_CannotCaptureOwnPiece() {
        let general = createPiece(.general, .red, 4, 0)
        let board = createBoard(with: [
            (.general, .red, 4, 0),
            (.advisor, .red, 4, 1) // Friendly piece
        ])

        let validator = GeneralValidator()
        XCTAssertFalse(validator.isValidMove(for: general, to: Position(file: 4, rank: 1), on: board))
    }

    func testGeneralValidator_CanCaptureEnemy() {
        let general = createPiece(.general, .red, 4, 1)
        let board = createBoard(with: [
            (.general, .red, 4, 1),
            (.soldier, .black, 4, 2) // Enemy piece
        ])

        let validator = GeneralValidator()
        XCTAssertTrue(validator.isValidMove(for: general, to: Position(file: 4, rank: 2), on: board))
    }

    // MARK: - Advisor Validator Tests

    func testAdvisorValidator_ValidDiagonalMoves() {
        // Advisor in center of palace
        let advisor = createPiece(.advisor, .red, 4, 1)
        let board = createBoard(with: [(.advisor, .red, 4, 1)])

        let validator = AdvisorValidator()
        let moves = validator.getValidMoves(for: advisor, on: board)

        // Should have 4 diagonal moves
        XCTAssertEqual(moves.count, 4)
        XCTAssertTrue(moves.contains(Position(file: 5, rank: 2)))
        XCTAssertTrue(moves.contains(Position(file: 3, rank: 2)))
        XCTAssertTrue(moves.contains(Position(file: 5, rank: 0)))
        XCTAssertTrue(moves.contains(Position(file: 3, rank: 0)))
    }

    func testAdvisorValidator_StaysInPalace() {
        let advisor = createPiece(.advisor, .red, 5, 0)
        let board = createBoard(with: [(.advisor, .red, 5, 0)])

        let validator = AdvisorValidator()

        // Should not move outside palace
        XCTAssertFalse(validator.isValidMove(for: advisor, to: Position(file: 6, rank: 1), on: board))
    }

    // MARK: - Elephant Validator Tests

    func testElephantValidator_ValidDiagonalMoves() {
        let elephant = createPiece(.elephant, .red, 2, 0)
        let board = createBoard(with: [(.elephant, .red, 2, 0)])

        let validator = ElephantValidator()
        let moves = validator.getValidMoves(for: elephant, on: board)

        // Should have 2 valid moves (other 2 are out of bounds or cross river)
        XCTAssertTrue(moves.contains(Position(file: 0, rank: 2)))
        XCTAssertTrue(moves.contains(Position(file: 4, rank: 2)))
    }

    func testElephantValidator_CannotCrossRiver() {
        let elephant = createPiece(.elephant, .red, 4, 4)
        let board = createBoard(with: [(.elephant, .red, 4, 4)])

        let validator = ElephantValidator()

        // Should not cross river (to black side)
        XCTAssertFalse(validator.isValidMove(for: elephant, to: Position(file: 2, rank: 6), on: board))
        XCTAssertFalse(validator.isValidMove(for: elephant, to: Position(file: 6, rank: 6), on: board))
    }

    func testElephantValidator_BlockedByEye() {
        let elephant = createPiece(.elephant, .red, 2, 0)
        let board = createBoard(with: [
            (.elephant, .red, 2, 0),
            (.soldier, .red, 3, 1) // Blocking the eye
        ])

        let validator = ElephantValidator()

        // Should be blocked from moving to (4, 2)
        XCTAssertFalse(validator.isValidMove(for: elephant, to: Position(file: 4, rank: 2), on: board))

        // Should still be able to move to (0, 2)
        XCTAssertTrue(validator.isValidMove(for: elephant, to: Position(file: 0, rank: 2), on: board))
    }

    // MARK: - Horse Validator Tests

    func testHorseValidator_ValidLShapedMoves() {
        let horse = createPiece(.horse, .red, 4, 4)
        let board = createBoard(with: [(.horse, .red, 4, 4)])

        let validator = HorseValidator()
        let moves = validator.getValidMoves(for: horse, on: board)

        // Horse should have 8 L-shaped moves from center
        XCTAssertEqual(moves.count, 8)
    }

    func testHorseValidator_BlockedByLeg() {
        let horse = createPiece(.horse, .red, 1, 0)
        let board = createBoard(with: [
            (.horse, .red, 1, 0),
            (.soldier, .red, 1, 1) // Blocking vertical moves
        ])

        let validator = HorseValidator()

        // Should be blocked from vertical L-moves
        XCTAssertFalse(validator.isValidMove(for: horse, to: Position(file: 0, rank: 2), on: board))
        XCTAssertFalse(validator.isValidMove(for: horse, to: Position(file: 2, rank: 2), on: board))

        // Should still be able to make horizontal L-moves
        let moves = validator.getValidMoves(for: horse, on: board)
        XCTAssertTrue(moves.contains(Position(file: 3, rank: 1)))
    }

    func testHorseValidator_EdgePositions() {
        let horse = createPiece(.horse, .red, 0, 0)
        let board = createBoard(with: [(.horse, .red, 0, 0)])

        let validator = HorseValidator()
        let moves = validator.getValidMoves(for: horse, on: board)

        // Limited moves from corner
        XCTAssertEqual(moves.count, 2)
        XCTAssertTrue(moves.contains(Position(file: 1, rank: 2)))
        XCTAssertTrue(moves.contains(Position(file: 2, rank: 1)))
    }

    // MARK: - Chariot Validator Tests

    func testChariotValidator_ValidOrthogonalMoves() {
        let chariot = createPiece(.chariot, .red, 4, 4)
        let board = createBoard(with: [(.chariot, .red, 4, 4)])

        let validator = ChariotValidator()
        let moves = validator.getValidMoves(for: chariot, on: board)

        // From center, chariot can move 16 positions (4 in each direction)
        // Actually: 5 up + 4 down + 4 left + 4 right = 17 positions, but center is excluded
        XCTAssertEqual(moves.count, 16) // 4+5 vertical + 4+4 horizontal - 1 (current)
    }

    func testChariotValidator_BlockedByPiece() {
        let chariot = createPiece(.chariot, .red, 0, 0)
        let board = createBoard(with: [
            (.chariot, .red, 0, 0),
            (.soldier, .red, 0, 3) // Blocking
        ])

        let validator = ChariotValidator()

        // Can move up to blocker but not past
        XCTAssertTrue(validator.isValidMove(for: chariot, to: Position(file: 0, rank: 2), on: board))
        XCTAssertFalse(validator.isValidMove(for: chariot, to: Position(file: 0, rank: 3), on: board))
        XCTAssertFalse(validator.isValidMove(for: chariot, to: Position(file: 0, rank: 4), on: board))
    }

    func testChariotValidator_CanCaptureEnemy() {
        let chariot = createPiece(.chariot, .red, 0, 0)
        let board = createBoard(with: [
            (.chariot, .red, 0, 0),
            (.soldier, .black, 0, 3) // Enemy
        ])

        let validator = ChariotValidator()

        XCTAssertTrue(validator.isValidMove(for: chariot, to: Position(file: 0, rank: 3), on: board))
        XCTAssertFalse(validator.isValidMove(for: chariot, to: Position(file: 0, rank: 4), on: board))
    }

    // MARK: - Cannon Validator Tests

    func testCannonValidator_NonCaptureMoves() {
        let cannon = createPiece(.cannon, .red, 4, 4)
        let board = createBoard(with: [(.cannon, .red, 4, 4)])

        let validator = CannonValidator()

        // Non-capture moves work like chariot
        XCTAssertTrue(validator.isValidMove(for: cannon, to: Position(file: 4, rank: 5), on: board))
        XCTAssertTrue(validator.isValidMove(for: cannon, to: Position(file: 5, rank: 4), on: board))
    }

    func testCannonValidator_CaptureWithScreen() {
        let cannon = createPiece(.cannon, .red, 0, 0)
        let board = createBoard(with: [
            (.cannon, .red, 0, 0),
            (.soldier, .red, 0, 3),  // Screen
            (.soldier, .black, 0, 6) // Target
        ])

        let validator = CannonValidator()

        // Can capture by jumping over screen
        XCTAssertTrue(validator.isValidMove(for: cannon, to: Position(file: 0, rank: 6), on: board))
    }

    func testCannonValidator_CannotCaptureWithoutScreen() {
        let cannon = createPiece(.cannon, .red, 0, 0)
        let board = createBoard(with: [
            (.cannon, .red, 0, 0),
            (.soldier, .black, 0, 3) // Direct target - no screen
        ])

        let validator = CannonValidator()

        // Cannot capture without screen
        XCTAssertFalse(validator.isValidMove(for: cannon, to: Position(file: 0, rank: 3), on: board))
    }

    func testCannonValidator_CannotCaptureWithTwoScreens() {
        let cannon = createPiece(.cannon, .red, 0, 0)
        let board = createBoard(with: [
            (.cannon, .red, 0, 0),
            (.soldier, .red, 0, 2),  // Screen 1
            (.soldier, .red, 0, 4),  // Screen 2
            (.soldier, .black, 0, 6) // Target
        ])

        let validator = CannonValidator()

        // Cannot capture with two screens
        XCTAssertFalse(validator.isValidMove(for: cannon, to: Position(file: 0, rank: 6), on: board))
    }

    // MARK: - Soldier Validator Tests

    func testSoldierValidator_BeforeRiver() {
        // Red soldier before crossing river
        let soldier = createPiece(.soldier, .red, 4, 3)
        let board = createBoard(with: [(.soldier, .red, 4, 3)])

        let validator = SoldierValidator()
        let moves = validator.getValidMoves(for: soldier, on: board)

        // Can only move forward
        XCTAssertEqual(moves.count, 1)
        XCTAssertTrue(moves.contains(Position(file: 4, rank: 4)))
    }

    func testSoldierValidator_AfterRiver() {
        // Red soldier after crossing river
        let soldier = createPiece(.soldier, .red, 4, 5)
        let board = createBoard(with: [(.soldier, .red, 4, 5)])

        let validator = SoldierValidator()
        let moves = validator.getValidMoves(for: soldier, on: board)

        // Can move forward and sideways
        XCTAssertEqual(moves.count, 3)
        XCTAssertTrue(moves.contains(Position(file: 4, rank: 6))) // forward
        XCTAssertTrue(moves.contains(Position(file: 3, rank: 5))) // left
        XCTAssertTrue(moves.contains(Position(file: 5, rank: 5))) // right
    }

    func testSoldierValidator_CannotMoveBackward() {
        let soldier = createPiece(.soldier, .red, 4, 5)
        let board = createBoard(with: [(.soldier, .red, 4, 5)])

        let validator = SoldierValidator()

        // Cannot move backward
        XCTAssertFalse(validator.isValidMove(for: soldier, to: Position(file: 4, rank: 4), on: board))
    }

    func testSoldierValidator_BlackSoldierDirection() {
        // Black soldier moves in opposite direction
        let soldier = createPiece(.soldier, .black, 4, 6)
        let board = createBoard(with: [(.soldier, .black, 4, 6)])

        let validator = SoldierValidator()

        // Forward for black is decreasing rank
        XCTAssertTrue(validator.isValidMove(for: soldier, to: Position(file: 4, rank: 5), on: board))
        XCTAssertFalse(validator.isValidMove(for: soldier, to: Position(file: 4, rank: 7), on: board))
    }

    // MARK: - Validator Factory Tests

    func testValidatorFactory_ReturnsCorrectType() {
        let generalValidator = ValidatorFactory.validator(for: .general)
        XCTAssertTrue(generalValidator is GeneralValidator)

        let advisorValidator = ValidatorFactory.validator(for: .advisor)
        XCTAssertTrue(advisorValidator is AdvisorValidator)

        let elephantValidator = ValidatorFactory.validator(for: .elephant)
        XCTAssertTrue(elephantValidator is ElephantValidator)

        let horseValidator = ValidatorFactory.validator(for: .horse)
        XCTAssertTrue(horseValidator is HorseValidator)

        let chariotValidator = ValidatorFactory.validator(for: .chariot)
        XCTAssertTrue(chariotValidator is ChariotValidator)

        let cannonValidator = ValidatorFactory.validator(for: .cannon)
        XCTAssertTrue(cannonValidator is CannonValidator)

        let soldierValidator = ValidatorFactory.validator(for: .soldier)
        XCTAssertTrue(soldierValidator is SoldierValidator)
    }
}
