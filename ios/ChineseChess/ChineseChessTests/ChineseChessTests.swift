//
//  ChineseChessTests.swift
//  ChineseChessTests
//
//  Unit tests for the Chinese Chess application.
//

import XCTest
@testable import ChineseChess

final class ChineseChessTests: XCTestCase {

    // MARK: - Position Tests

    func testPositionNotation() {
        let position = Position(file: 4, rank: 0)
        XCTAssertEqual(position.notation, "e0")

        let position2 = Position(file: 0, rank: 9)
        XCTAssertEqual(position2.notation, "a9")
    }

    func testPositionFromNotation() {
        let position = Position(notation: "e0")
        XCTAssertNotNil(position)
        XCTAssertEqual(position?.file, 4)
        XCTAssertEqual(position?.rank, 0)

        let invalidPosition = Position(notation: "z99")
        XCTAssertNil(invalidPosition)
    }

    func testPositionValidity() {
        let valid = Position(file: 4, rank: 5)
        XCTAssertTrue(valid.isValid)

        let invalid = Position(file: 10, rank: 5)
        XCTAssertFalse(invalid.isValid)
    }

    func testRedPalace() {
        let inPalace = Position(file: 4, rank: 1)
        XCTAssertTrue(inPalace.isInRedPalace)
        XCTAssertFalse(inPalace.isInBlackPalace)

        let outsidePalace = Position(file: 0, rank: 0)
        XCTAssertFalse(outsidePalace.isInRedPalace)
    }

    func testBlackPalace() {
        let inPalace = Position(file: 4, rank: 8)
        XCTAssertTrue(inPalace.isInBlackPalace)
        XCTAssertFalse(inPalace.isInRedPalace)
    }

    func testRiverCrossing() {
        let redSide = Position(file: 4, rank: 3)
        XCTAssertTrue(redSide.isOnRedSide)
        XCTAssertFalse(redSide.hasCrossedRiver(for: .red))
        XCTAssertTrue(redSide.hasCrossedRiver(for: .black))

        let blackSide = Position(file: 4, rank: 6)
        XCTAssertTrue(blackSide.isOnBlackSide)
        XCTAssertTrue(blackSide.hasCrossedRiver(for: .red))
        XCTAssertFalse(blackSide.hasCrossedRiver(for: .black))
    }

    // MARK: - Piece Tests

    func testPieceCharacters() {
        let redGeneral = Piece(type: .general, color: .red, position: Position(file: 4, rank: 0))
        XCTAssertEqual(redGeneral.character, "帅")

        let blackGeneral = Piece(type: .general, color: .black, position: Position(file: 4, rank: 9))
        XCTAssertEqual(blackGeneral.character, "将")

        let redSoldier = Piece(type: .soldier, color: .red, position: Position(file: 0, rank: 3))
        XCTAssertEqual(redSoldier.character, "兵")

        let blackSoldier = Piece(type: .soldier, color: .black, position: Position(file: 0, rank: 6))
        XCTAssertEqual(blackSoldier.character, "卒")
    }

    func testPlayerColorOpposite() {
        XCTAssertEqual(PlayerColor.red.opposite, .black)
        XCTAssertEqual(PlayerColor.black.opposite, .red)
    }

    // MARK: - GameState Tests

    func testInitialGameState() {
        let state = GameState.initial()

        // Check turn
        XCTAssertEqual(state.currentTurn, .red)

        // Check piece counts
        XCTAssertEqual(state.redPieces.count, 16)
        XCTAssertEqual(state.blackPieces.count, 16)

        // Check generals are in correct positions
        let redGeneral = state.general(for: .red)
        XCTAssertNotNil(redGeneral)
        XCTAssertEqual(redGeneral?.position, Position(file: 4, rank: 0))

        let blackGeneral = state.general(for: .black)
        XCTAssertNotNil(blackGeneral)
        XCTAssertEqual(blackGeneral?.position, Position(file: 4, rank: 9))

        // Check no pieces are captured initially
        XCTAssertTrue(state.capturedByRed.isEmpty)
        XCTAssertTrue(state.capturedByBlack.isEmpty)

        // Check not in check
        XCTAssertFalse(state.isCheck)
    }

    func testPieceAtPosition() {
        let state = GameState.initial()

        // Red chariot at a0
        let redChariot = state.piece(at: Position(file: 0, rank: 0))
        XCTAssertNotNil(redChariot)
        XCTAssertEqual(redChariot?.type, .chariot)
        XCTAssertEqual(redChariot?.color, .red)

        // Empty square at d4
        let empty = state.piece(at: Position(file: 3, rank: 4))
        XCTAssertNil(empty)

        // Black cannon at b7
        let blackCannon = state.piece(at: Position(file: 1, rank: 7))
        XCTAssertNotNil(blackCannon)
        XCTAssertEqual(blackCannon?.type, .cannon)
        XCTAssertEqual(blackCannon?.color, .black)
    }

    // MARK: - User Validation Tests

    func testDisplayNameValidation() {
        // Valid names
        XCTAssertTrue(User.validateDisplayName("Player123").isValid)
        XCTAssertTrue(User.validateDisplayName("Test_User").isValid)
        XCTAssertTrue(User.validateDisplayName("Cool-Name").isValid)

        // Too short
        if case .invalid(let reason) = User.validateDisplayName("AB") {
            XCTAssertTrue(reason.contains("at least 3"))
        } else {
            XCTFail("Should be invalid")
        }

        // Too long
        if case .invalid(let reason) = User.validateDisplayName("ThisNameIsWayTooLongForDisplay") {
            XCTAssertTrue(reason.contains("at most 20"))
        } else {
            XCTFail("Should be invalid")
        }

        // Invalid characters
        if case .invalid(let reason) = User.validateDisplayName("Test@User") {
            XCTAssertTrue(reason.contains("only contain"))
        } else {
            XCTFail("Should be invalid")
        }

        // Reserved words
        if case .invalid(let reason) = User.validateDisplayName("admin123") {
            XCTAssertTrue(reason.contains("reserved"))
        } else {
            XCTFail("Should be invalid")
        }
    }

    // MARK: - Game Settings Tests

    func testTurnTimeoutValues() {
        XCTAssertEqual(TurnTimeout.oneMinute.rawValue, 60)
        XCTAssertEqual(TurnTimeout.threeMinutes.rawValue, 180)
        XCTAssertEqual(TurnTimeout.fiveMinutes.rawValue, 300)
        XCTAssertEqual(TurnTimeout.tenMinutes.rawValue, 600)
        XCTAssertEqual(TurnTimeout.unlimited.rawValue, 0)
    }

    func testDefaultGameSettings() {
        let settings = GameSettings.default
        XCTAssertEqual(settings.turnTimeout, .fiveMinutes)
        XCTAssertTrue(settings.soundEnabled)
        XCTAssertTrue(settings.hapticsEnabled)
        XCTAssertTrue(settings.showMoveHints)
    }
}
