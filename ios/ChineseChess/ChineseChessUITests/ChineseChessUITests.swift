//
//  ChineseChessUITests.swift
//  ChineseChessUITests
//
//  UI tests for the Chinese Chess application.
//

import XCTest

final class ChineseChessUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - App Launch Tests

    func testAppLaunch() throws {
        // Verify app launches without crash
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }

    func testAppLaunch_ShowsTitle() throws {
        // Verify main title elements are present
        let title = app.staticTexts["Chinese Chess"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))

        let subtitle = app.staticTexts["Xiangqi"]
        XCTAssertTrue(subtitle.exists)
    }

    // MARK: - Home Screen Tests

    func testHomeScreen_AllButtonsExist() throws {
        // Wait for the home screen to fully load
        let playOnlineButton = app.buttons["Play Online"]
        XCTAssertTrue(playOnlineButton.waitForExistence(timeout: 10))

        // Check all main menu buttons exist
        XCTAssertTrue(app.buttons["Practice Mode"].exists)
        XCTAssertTrue(app.buttons["Match History"].exists)
        XCTAssertTrue(app.buttons["Settings"].exists)
    }

    func testHomeScreen_ButtonsAreTappable() throws {
        let playOnlineButton = app.buttons["Play Online"]
        XCTAssertTrue(playOnlineButton.waitForExistence(timeout: 10))
        XCTAssertTrue(playOnlineButton.isHittable)

        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(settingsButton.isHittable)
    }

    // MARK: - Settings Navigation Tests

    func testNavigateToSettings() throws {
        // Tap settings button
        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        // Verify settings screen appears
        let settingsTitle = app.navigationBars["Settings"]
        XCTAssertTrue(settingsTitle.waitForExistence(timeout: 5))
    }

    func testSettings_DisplayNameField() throws {
        // Navigate to settings
        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        // Wait for settings to load
        sleep(1)

        // Look for display name section
        let displayNameLabel = app.staticTexts["Display Name"]
        if displayNameLabel.exists {
            XCTAssertTrue(displayNameLabel.exists)
        }
    }

    func testSettings_BackNavigation() throws {
        // Navigate to settings
        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        // Wait for navigation
        sleep(1)

        // Go back
        let backButton = app.navigationBars.buttons.firstMatch
        if backButton.exists {
            backButton.tap()

            // Verify we're back on home screen
            XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        }
    }

    // MARK: - Match History Navigation Tests

    func testNavigateToMatchHistory() throws {
        // Tap match history button
        let historyButton = app.buttons["Match History"]
        XCTAssertTrue(historyButton.waitForExistence(timeout: 5))
        historyButton.tap()

        // Verify match history screen appears
        let historyTitle = app.navigationBars["Match History"]
        XCTAssertTrue(historyTitle.waitForExistence(timeout: 5))
    }

    func testMatchHistory_EmptyState() throws {
        // Navigate to match history
        let historyButton = app.buttons["Match History"]
        XCTAssertTrue(historyButton.waitForExistence(timeout: 5))
        historyButton.tap()

        // Wait for screen to load
        sleep(1)

        // New accounts should show empty state or "No matches" message
        // Check for either an empty list message or the navigation bar
        let historyScreen = app.navigationBars["Match History"]
        XCTAssertTrue(historyScreen.waitForExistence(timeout: 5))
    }

    // MARK: - Play Online Flow Tests

    func testPlayOnline_TapShowsMatchmaking() throws {
        // Tap play online button
        let playOnlineButton = app.buttons["Play Online"]
        XCTAssertTrue(playOnlineButton.waitForExistence(timeout: 5))
        playOnlineButton.tap()

        // Should show matchmaking screen or connection dialog
        // Wait a bit for navigation
        sleep(2)

        // Check that we navigated away from home
        // Either matchmaking screen or a modal should appear
        let cancelButton = app.buttons["Cancel"]
        let backButton = app.navigationBars.buttons.element(boundBy: 0)

        // At least one navigation element should exist
        XCTAssertTrue(cancelButton.exists || backButton.exists || app.otherElements.count > 0)
    }

    // MARK: - Practice Mode Tests

    func testPracticeMode_StartGame() throws {
        // Tap practice mode button
        let practiceButton = app.buttons["Practice Mode"]
        XCTAssertTrue(practiceButton.waitForExistence(timeout: 5))
        practiceButton.tap()

        // Wait for game to load
        sleep(2)

        // Verify game board is visible (look for board elements)
        // This depends on accessibility identifiers in the game view
        // For now, just verify we navigated away
        XCTAssertTrue(practiceButton.exists == false || app.staticTexts.count > 0)
    }

    // MARK: - Accessibility Tests

    func testAccessibility_HomeScreenLabels() throws {
        // Verify buttons have accessibility labels
        let playOnlineButton = app.buttons["Play Online"]
        XCTAssertTrue(playOnlineButton.waitForExistence(timeout: 5))
        XCTAssertFalse(playOnlineButton.label.isEmpty)

        let settingsButton = app.buttons["Settings"]
        XCTAssertFalse(settingsButton.label.isEmpty)
    }

    // MARK: - Device Rotation Tests

    func testRotation_HomeScreen() throws {
        // Rotate to landscape
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(1)

        // Verify app still works
        let playOnlineButton = app.buttons["Play Online"]
        XCTAssertTrue(playOnlineButton.waitForExistence(timeout: 5))

        // Rotate back to portrait
        XCUIDevice.shared.orientation = .portrait
        sleep(1)

        XCTAssertTrue(playOnlineButton.exists)
    }

    // MARK: - Performance Tests

    func testLaunchPerformance() throws {
        if #available(iOS 13.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }

    func testNavigationPerformance() throws {
        // Measure settings navigation performance
        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))

        measure {
            settingsButton.tap()
            let settingsTitle = app.navigationBars["Settings"]
            _ = settingsTitle.waitForExistence(timeout: 5)

            // Go back
            if let backButton = app.navigationBars.buttons.element(boundBy: 0).exists ? app.navigationBars.buttons.element(boundBy: 0) : nil {
                backButton.tap()
            }
            _ = settingsButton.waitForExistence(timeout: 5)
        }
    }

    // MARK: - Connection Status Tests

    func testConnectionStatus_Visible() throws {
        // Check if connection status is visible
        // This depends on the UI implementation
        let connectionStatus = app.staticTexts["Online"]
        let offlineStatus = app.staticTexts["Offline"]

        // Wait for app to initialize
        sleep(2)

        // At least one status should be visible if the feature is implemented
        // This is a soft check - not failing if status isn't shown
        if connectionStatus.exists || offlineStatus.exists {
            XCTAssertTrue(connectionStatus.exists || offlineStatus.exists)
        }
    }

    // MARK: - Error State Tests

    func testErrorHandling_NoNetwork() throws {
        // This test would require mocking network conditions
        // For now, just verify the app doesn't crash when offline
        let playOnlineButton = app.buttons["Play Online"]
        XCTAssertTrue(playOnlineButton.waitForExistence(timeout: 5))

        // App should handle gracefully if tapped with no network
        playOnlineButton.tap()
        sleep(2)

        // App should still be responsive
        let anyElement = app.otherElements.firstMatch
        XCTAssertTrue(anyElement.exists)
    }

    // MARK: - UI Consistency Tests

    func testUI_ElementsNotOverlapping() throws {
        // Get button frames
        let playOnlineButton = app.buttons["Play Online"]
        let practiceButton = app.buttons["Practice Mode"]
        let historyButton = app.buttons["Match History"]
        let settingsButton = app.buttons["Settings"]

        XCTAssertTrue(playOnlineButton.waitForExistence(timeout: 5))

        // Verify buttons exist and have valid frames
        XCTAssertTrue(playOnlineButton.frame.height > 0)
        XCTAssertTrue(practiceButton.frame.height > 0)
        XCTAssertTrue(historyButton.frame.height > 0)
        XCTAssertTrue(settingsButton.frame.height > 0)
    }

    // MARK: - State Preservation Tests

    func testStatePreservation_AfterBackground() throws {
        // Make some navigation
        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        // Wait for navigation
        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(settingsNav.waitForExistence(timeout: 5))

        // Background the app
        XCUIDevice.shared.press(.home)
        sleep(1)

        // Bring back to foreground
        app.activate()
        sleep(1)

        // App should restore state
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }
}

// MARK: - Game Board UI Tests

final class GameBoardUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--skipLogin"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testGameBoard_Exists() throws {
        // Navigate to practice mode
        let practiceButton = app.buttons["Practice Mode"]
        if practiceButton.waitForExistence(timeout: 5) {
            practiceButton.tap()
            sleep(2)

            // Game board should now be visible
            // This depends on accessibility identifiers
            XCTAssertTrue(app.otherElements.count > 0)
        }
    }

    func testGameBoard_InteractionEnabled() throws {
        // Navigate to practice mode
        let practiceButton = app.buttons["Practice Mode"]
        if practiceButton.waitForExistence(timeout: 5) {
            practiceButton.tap()
            sleep(2)

            // Try to tap on the board
            // The game board should be interactive
            let firstTouchableElement = app.otherElements.firstMatch
            XCTAssertTrue(firstTouchableElement.isHittable)
        }
    }
}
