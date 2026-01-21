# Chinese Chess (Xiangqi) iPhone Application - Requirements Document

## Introduction

This document specifies the requirements for a Chinese Chess (Xiangqi) mobile application for iPhone. The application will provide an engaging online multiplayer experience without requiring user login, utilizing device-based identification for seamless user management. The app features real-time gameplay with configurable turn timeouts, a limited rollback system, and comprehensive match history tracking. The backend will use SQLite for local data persistence with server synchronization for multiplayer functionality.

### Scope

The application covers:
- Anonymous user identification via device ID
- Real-time online multiplayer Chinese Chess gameplay
- Complete implementation of traditional Xiangqi rules
- Intuitive mobile-first UI/UX design
- Turn-based gameplay with timeout management
- Move rollback functionality with usage limits
- Match history storage and retrieval
- iOS deployment via TestFlight

### Target Platform

- **Primary:** iPhone (iOS 15.0+)
- **Distribution:** TestFlight (requires Apple Developer Program membership)
- **Database:** SQLite (local) with server synchronization

---

## Requirements

### Requirement 1: User Identification System

**User Story:** As a player, I want to start playing immediately without creating an account, so that I can enjoy the game without friction.

#### Acceptance Criteria

1. WHEN the application launches for the first time THEN the system SHALL generate a unique identifier using `identifierForVendor` (IDFV) and store it securely in the iOS Keychain.

2. WHEN the application launches on subsequent occasions THEN the system SHALL retrieve the existing identifier from the Keychain to maintain user continuity.

3. IF the user reinstalls the application AND the Keychain data persists THEN the system SHALL recognize the user as the same player with their previous history intact.

4. WHEN a unique identifier is generated THEN the system SHALL create a default player profile with a randomly generated display name (e.g., "Player_XXXX" where XXXX is a random alphanumeric string).

5. WHERE the player profile settings are accessed THEN the system SHALL allow the user to customize their display name (3-20 characters, alphanumeric and common symbols only).

6. WHEN a player attempts to set a display name THEN the system SHALL validate that the name does not contain offensive content using a basic filter.

7. IF the device identifier cannot be retrieved or generated THEN the system SHALL display an error message and prevent access to online features while allowing offline practice mode.

8. WHEN a new device identifier is registered with the server THEN the system SHALL create a corresponding user record in the database with creation timestamp.

---

### Requirement 2: Real-Time Online Multiplayer

**User Story:** As a player, I want to play Chinese Chess against other players online in real-time, so that I can enjoy competitive matches anytime.

#### Acceptance Criteria

1. WHEN the player selects "Play Online" THEN the system SHALL connect to the game server and enter the matchmaking queue.

2. WHEN the player is in the matchmaking queue THEN the system SHALL display a waiting indicator with estimated wait time and option to cancel.

3. WHEN two players are matched THEN the system SHALL create a new game session, randomly assign colors (Red/Black), and notify both players.

4. WHEN a game session is created THEN the system SHALL establish a WebSocket connection between both clients and the server for real-time communication.

5. WHILE a game is in progress THEN the system SHALL synchronize game state between both players within 500ms of any move.

6. IF network connectivity is lost during a game THEN the system SHALL attempt automatic reconnection for up to 30 seconds while pausing the turn timer.

7. IF reconnection fails after 30 seconds THEN the system SHALL notify the remaining player and offer options to wait longer or claim victory by abandonment.

8. WHEN a player disconnects intentionally (closes app) THEN the system SHALL mark them as disconnected and start a 60-second grace period for reconnection.

9. IF the disconnected player does not return within the grace period THEN the system SHALL forfeit the game to the opponent and record it as an abandonment loss.

10. WHEN either player makes a move THEN the server SHALL validate the move before broadcasting to ensure game state integrity.

11. WHEN a game concludes THEN the system SHALL display the result (Win/Loss/Draw) to both players with game statistics.

12. WHEN the server receives conflicting game states THEN the server SHALL be the authoritative source and reconcile client states accordingly.

---

### Requirement 3: Chinese Chess (Xiangqi) Game Rules

**User Story:** As a player, I want the game to enforce all traditional Xiangqi rules accurately, so that I can play an authentic Chinese Chess experience.

#### Acceptance Criteria

##### Board and Setup

1. WHEN a new game starts THEN the system SHALL display a 10x9 intersection board with the river dividing the two sides and palaces marked on each side.

2. WHEN a new game starts THEN the system SHALL place 16 pieces for each player in their traditional starting positions: 1 General, 2 Advisors, 2 Elephants, 2 Horses, 2 Chariots, 2 Cannons, and 5 Soldiers.

3. WHEN displaying the board THEN the system SHALL orient the board so the player's pieces are at the bottom of the screen.

##### Piece Movement Rules

4. WHEN the General (King) is selected THEN the system SHALL highlight valid moves: one step orthogonally (up/down/left/right) within the 3x3 palace only.

5. WHEN the Advisor is selected THEN the system SHALL highlight valid moves: one step diagonally within the 3x3 palace only.

6. WHEN the Elephant is selected THEN the system SHALL highlight valid moves: two steps diagonally, blocked if any piece occupies the intermediate diagonal position, and cannot cross the river.

7. WHEN the Horse is selected THEN the system SHALL highlight valid moves: one step orthogonally followed by one step diagonally outward, blocked if any piece occupies the adjacent orthogonal position.

8. WHEN the Chariot (Rook) is selected THEN the system SHALL highlight valid moves: any number of steps orthogonally until blocked by another piece.

9. WHEN the Cannon is selected THEN the system SHALL highlight valid moves: any number of steps orthogonally for non-capturing moves; for captures, must jump over exactly one piece (screen) to capture.

10. WHEN the Soldier (Pawn) is selected before crossing the river THEN the system SHALL highlight valid moves: one step forward only.

11. WHEN the Soldier is selected after crossing the river THEN the system SHALL highlight valid moves: one step forward or one step sideways (left/right).

##### Special Rules and Win Conditions

12. WHEN a move would result in both Generals facing each other with no pieces between them THEN the system SHALL prevent that move (Flying General rule).

13. WHEN a player's General is under attack THEN the system SHALL indicate check status and restrict available moves to those that resolve the check.

14. IF a player has no legal moves AND their General is in check THEN the system SHALL declare checkmate and end the game with a loss for that player.

15. IF a player has no legal moves AND their General is not in check THEN the system SHALL declare stalemate (the stalemated player loses in Xiangqi rules).

16. WHEN a game position repeats three times with the same player to move THEN the system SHALL offer a draw or apply perpetual check/chase rules.

17. IF a player perpetually checks or chases THEN the system SHALL declare a loss for the offending player per Xiangqi competition rules.

18. WHEN both players agree to a draw THEN the system SHALL end the game and record it as a draw.

19. WHEN a player captures the opponent's General THEN the system SHALL end the game immediately with a win for the capturing player.

---

### Requirement 4: User Interface and User Experience

**User Story:** As a player, I want an attractive and intuitive interface, so that I can easily understand the game state and make moves comfortably on my iPhone.

#### Acceptance Criteria

##### Visual Design

1. WHEN the application launches THEN the system SHALL display a visually appealing main menu with options: Play Online, Practice Mode, Match History, and Settings.

2. WHEN displaying the game board THEN the system SHALL render a traditional Chinese Chess board with clear grid lines, river marking with text, and distinct palace areas.

3. WHEN displaying pieces THEN the system SHALL render pieces with traditional Chinese characters clearly visible, using red color for one side and black/dark color for the opponent.

4. WHEN displaying pieces THEN the system SHALL ensure piece size is appropriate for touch interaction (minimum 44x44 points tap target per Apple HIG).

5. WHEN a piece is selected THEN the system SHALL visually highlight the selected piece and display valid move destinations with distinct indicators.

6. WHEN a move is made THEN the system SHALL animate the piece movement smoothly (200-300ms duration) to provide clear visual feedback.

7. WHEN the last move was made THEN the system SHALL highlight both the origin and destination squares to show the most recent move.

##### Interaction Design

8. WHEN a player taps a piece THEN the system SHALL select that piece if it belongs to the current player and it is their turn.

9. WHEN a piece is selected AND the player taps a valid destination THEN the system SHALL execute the move.

10. WHEN a piece is selected AND the player taps an invalid destination THEN the system SHALL deselect the piece or show brief feedback indicating invalid move.

11. WHEN a piece is selected AND the player taps another of their own pieces THEN the system SHALL select the new piece instead.

12. WHERE the game screen is displayed THEN the system SHALL show player information for both players including display name and color.

13. WHERE the game screen is displayed THEN the system SHALL show captured pieces for both players in designated areas.

14. WHEN it is the player's turn THEN the system SHALL display a clear visual indicator (e.g., highlighted player panel, turn indicator).

##### Responsiveness and Accessibility

15. WHEN the application runs THEN the system SHALL support both portrait and landscape orientations with appropriate layout adjustments.

16. WHEN the application runs THEN the system SHALL maintain 60fps performance during normal gameplay on supported devices.

17. WHEN displaying text THEN the system SHALL use Dynamic Type to support user accessibility preferences.

18. WHEN audio feedback is enabled THEN the system SHALL play appropriate sounds for piece selection, movement, capture, check, and game end.

19. WHERE the Settings menu is accessed THEN the system SHALL allow toggling sound effects and haptic feedback.

---

### Requirement 5: Turn Timeout System

**User Story:** As a player, I want each turn to have a time limit, so that games progress at a reasonable pace and opponents cannot stall indefinitely.

#### Acceptance Criteria

1. WHEN a game starts THEN the system SHALL apply the default turn timeout of 5 minutes (300 seconds) per turn.

2. WHERE the game settings are configured THEN the system SHALL allow customizing turn timeout with options: 1 minute, 3 minutes, 5 minutes (default), 10 minutes, and unlimited.

3. WHEN a player's turn begins THEN the system SHALL start the countdown timer and display the remaining time prominently.

4. WHILE a player's turn is active THEN the system SHALL update the countdown display every second.

5. WHEN the remaining time drops below 30 seconds THEN the system SHALL display the timer in a warning color (e.g., red/orange) and optionally play a warning sound.

6. WHEN the remaining time drops below 10 seconds THEN the system SHALL display more urgent visual feedback (e.g., pulsing animation).

7. IF the turn timer reaches zero THEN the system SHALL automatically forfeit the game for the player whose time expired.

8. WHEN a player completes their move THEN the system SHALL stop their timer and start the opponent's timer.

9. IF network latency causes timer desynchronization THEN the server SHALL maintain the authoritative timer and synchronize clients.

10. WHEN a player disconnects and reconnects THEN the system SHALL resume with the correct remaining time as maintained by the server.

11. WHERE the game invitation system is used THEN the system SHALL allow the host to set the turn timeout before the game begins.

---

### Requirement 6: Rollback Turn Functionality

**User Story:** As a player, I want the ability to undo my moves a limited number of times, so that I can recover from accidental misclicks or reconsider decisions.

#### Acceptance Criteria

1. WHEN a game starts THEN the system SHALL allocate 3 rollback opportunities to each player.

2. WHEN a player makes a move THEN the system SHALL enable the "Request Rollback" button if they have remaining rollback opportunities.

3. WHEN the "Request Rollback" button is tapped THEN the system SHALL send a rollback request to the opponent.

4. WHEN a rollback request is received THEN the system SHALL display a prompt to the opponent with options to "Accept" or "Decline".

5. IF the opponent accepts the rollback request THEN the system SHALL revert the game state to before the requesting player's last move and decrement their rollback count.

6. IF the opponent declines the rollback request THEN the system SHALL notify the requesting player and the game continues without change.

7. IF the opponent does not respond to a rollback request within 30 seconds THEN the system SHALL automatically decline the request.

8. WHEN a rollback is executed THEN the system SHALL restore all piece positions, turn order, and game state to the previous state.

9. WHERE the game screen is displayed THEN the system SHALL show each player's remaining rollback count (e.g., "Rollbacks: 2/3").

10. IF a player has exhausted all rollback opportunities THEN the system SHALL disable the "Request Rollback" button for that player.

11. WHEN a rollback involves multiple consecutive moves by the same player (e.g., after opponent's timeout) THEN the system SHALL only revert the single most recent move.

12. WHEN a game is in check state THEN the system SHALL still allow rollback requests to be made and processed normally.

---

### Requirement 7: Match History

**User Story:** As a player, I want to view my past games and statistics, so that I can track my progress and review previous matches.

#### Acceptance Criteria

1. WHEN the player accesses Match History THEN the system SHALL display a list of completed games sorted by date (newest first).

2. WHEN displaying the match list THEN the system SHALL show for each game: opponent name, result (Win/Loss/Draw), date/time, and game duration.

3. WHEN a match entry is tapped THEN the system SHALL display detailed game information including: all moves made, final board position, and game statistics.

4. WHEN viewing match details THEN the system SHALL allow replaying the game move-by-move with forward/backward controls.

5. WHEN viewing match details THEN the system SHALL display move notation in standard Xiangqi format.

6. WHERE the Match History screen is displayed THEN the system SHALL show overall statistics: total games, wins, losses, draws, and win percentage.

7. WHEN match history data exceeds 100 games locally THEN the system SHALL implement pagination or lazy loading for performance.

8. IF the player has no match history THEN the system SHALL display an appropriate empty state message encouraging them to play their first game.

9. WHEN a game is completed THEN the system SHALL automatically save the match record to local SQLite database and sync with server.

10. WHEN the device is offline THEN the system SHALL store match history locally and sync when connectivity is restored.

11. WHERE the Match History screen is displayed THEN the system SHALL allow filtering by result type (All, Wins, Losses, Draws).

12. WHERE the Match History screen is displayed THEN the system SHALL allow searching by opponent name.

---

### Requirement 8: SQLite Database Schema

**User Story:** As a developer, I want a well-designed database schema, so that user data, game states, and history are stored efficiently and reliably.

#### Acceptance Criteria

##### User Table

1. WHEN storing user data THEN the system SHALL maintain a `users` table with columns: `id` (TEXT PRIMARY KEY - device identifier), `display_name` (TEXT), `created_at` (INTEGER - Unix timestamp), `updated_at` (INTEGER - Unix timestamp).

2. WHEN storing user statistics THEN the system SHALL maintain columns: `total_games` (INTEGER DEFAULT 0), `wins` (INTEGER DEFAULT 0), `losses` (INTEGER DEFAULT 0), `draws` (INTEGER DEFAULT 0).

##### Games Table

3. WHEN storing game data THEN the system SHALL maintain a `games` table with columns: `id` (TEXT PRIMARY KEY - UUID), `red_player_id` (TEXT), `black_player_id` (TEXT), `status` (TEXT - 'active', 'completed', 'abandoned'), `winner_id` (TEXT NULLABLE), `result_type` (TEXT - 'checkmate', 'timeout', 'resignation', 'abandonment', 'draw').

4. WHEN storing game metadata THEN the system SHALL include columns: `turn_timeout_seconds` (INTEGER), `created_at` (INTEGER), `completed_at` (INTEGER NULLABLE), `total_moves` (INTEGER DEFAULT 0).

##### Moves Table

5. WHEN storing move data THEN the system SHALL maintain a `moves` table with columns: `id` (INTEGER PRIMARY KEY AUTOINCREMENT), `game_id` (TEXT), `move_number` (INTEGER), `player_id` (TEXT), `from_position` (TEXT - e.g., "e1"), `to_position` (TEXT - e.g., "e2"), `piece_type` (TEXT), `captured_piece` (TEXT NULLABLE), `timestamp` (INTEGER).

6. WHEN storing moves THEN the system SHALL use standard algebraic notation compatible with Xiangqi conventions.

##### Rollback Tracking

7. WHEN storing rollback data THEN the system SHALL maintain a `rollbacks` table with columns: `id` (INTEGER PRIMARY KEY AUTOINCREMENT), `game_id` (TEXT), `requesting_player_id` (TEXT), `move_number_reverted` (INTEGER), `status` (TEXT - 'accepted', 'declined'), `timestamp` (INTEGER).

8. WHEN storing remaining rollbacks THEN the system SHALL include columns in games table: `red_rollbacks_remaining` (INTEGER DEFAULT 3), `black_rollbacks_remaining` (INTEGER DEFAULT 3).

##### Data Integrity

9. WHEN creating tables THEN the system SHALL define appropriate foreign key constraints with CASCADE delete rules.

10. WHEN the app launches THEN the system SHALL perform database migration if schema version has changed.

11. WHEN storing sensitive data THEN the system SHALL NOT store any personally identifiable information beyond device identifier and user-chosen display name.

12. WHEN database operations fail THEN the system SHALL implement proper error handling and rollback transactions appropriately.

---

### Requirement 9: Network and Server Requirements

**User Story:** As a player, I want reliable server connectivity, so that multiplayer games are smooth and my data is preserved across devices.

#### Acceptance Criteria

##### Server Architecture

1. WHEN the system architecture is designed THEN the server SHALL handle real-time game state synchronization via WebSocket connections.

2. WHEN the system architecture is designed THEN the server SHALL provide REST API endpoints for: user registration/lookup, matchmaking, match history retrieval, and statistics.

3. WHEN the server receives game moves THEN the server SHALL validate moves against game rules before broadcasting to prevent cheating.

4. WHEN the server maintains game state THEN the server SHALL be the single source of truth for all active games.

##### Performance Requirements

5. WHEN processing game moves THEN the server SHALL respond within 200ms under normal load conditions.

6. WHEN handling concurrent users THEN the server SHALL support at least 1000 simultaneous active games.

7. WHEN the server experiences high load THEN the system SHALL implement graceful degradation and queue management.

##### Data Synchronization

8. WHEN a client connects THEN the system SHALL sync local match history with server data, resolving conflicts by server timestamp.

9. WHEN match history is requested THEN the server SHALL support pagination with configurable page size (default 20 records).

10. WHEN user statistics are updated THEN the system SHALL update both local SQLite and server database atomically where possible.

##### Security

11. WHEN clients communicate with the server THEN all communication SHALL use HTTPS/WSS encryption.

12. WHEN the server receives requests THEN the server SHALL validate the device identifier format and reject malformed requests.

13. WHEN rate limiting is applied THEN the server SHALL limit API requests to 100 requests per minute per device identifier.

14. WHEN implementing the server THEN the system SHALL protect against common vulnerabilities (SQL injection, XSS, etc.).

---

### Requirement 10: iOS and TestFlight Deployment

**User Story:** As a developer, I want to deploy the app via TestFlight, so that testers can access and evaluate the application before public release.

#### Acceptance Criteria

##### Development Requirements

1. WHEN the project is configured THEN the system SHALL target iOS 15.0 as minimum deployment target for broad device compatibility.

2. WHEN the project is developed THEN the system SHALL be written in Swift 5.9+ using SwiftUI for UI components.

3. WHEN the project is structured THEN the system SHALL follow MVVM architecture pattern for maintainability.

4. WHEN dependencies are managed THEN the system SHALL use Swift Package Manager for third-party libraries.

##### App Store and TestFlight Requirements

5. WHEN preparing for TestFlight THEN the development team SHALL enroll in Apple Developer Program ($99/year).

6. WHEN preparing for TestFlight THEN the project SHALL have valid App ID, provisioning profiles, and distribution certificate.

7. WHEN submitting to TestFlight THEN the app bundle SHALL include required assets: app icons (all sizes), launch screen, and App Store screenshots.

8. WHEN submitting to TestFlight THEN the build SHALL pass all App Store validation checks.

9. WHEN configuring TestFlight THEN the team SHALL provide: app description, beta app description, contact email, and privacy policy URL.

##### Privacy and Compliance

10. WHEN the app is submitted THEN the privacy manifest SHALL accurately declare data collection: device identifier (for app functionality), gameplay data (for app functionality).

11. WHEN the app uses network features THEN the Info.plist SHALL include appropriate usage descriptions for network access.

12. WHEN handling user data THEN the application SHALL comply with Apple's App Store Review Guidelines section on data collection and privacy.

##### Build and Distribution

13. WHEN building for distribution THEN the system SHALL archive the build using Xcode's standard archive workflow.

14. WHEN uploading to TestFlight THEN the team SHALL use Xcode or Transporter app for submission.

15. WHEN a TestFlight build is approved THEN testers SHALL receive automatic notification via TestFlight app.

16. WHEN distributing via TestFlight THEN the team SHALL support both internal testers (up to 100) and external testers (up to 10,000).

---

## Non-Functional Requirements

### Performance

1. WHEN the app launches THEN the system SHALL display the main menu within 3 seconds on supported devices.

2. WHEN rendering the game board THEN the system SHALL maintain minimum 60fps during normal gameplay.

3. WHEN processing AI moves (practice mode) THEN the system SHALL complete calculations within 5 seconds.

4. WHEN storing data locally THEN SQLite operations SHALL complete within 100ms for single-record operations.

### Reliability

5. WHEN network errors occur THEN the system SHALL retry failed requests up to 3 times with exponential backoff.

6. WHEN the app crashes THEN the system SHALL preserve game state and allow resumption upon restart.

7. WHEN data corruption is detected THEN the system SHALL attempt recovery from server data when available.

### Usability

8. WHEN displaying UI elements THEN the system SHALL follow Apple Human Interface Guidelines for iOS.

9. WHEN providing feedback THEN the system SHALL use appropriate haptic feedback for key interactions (move confirmation, capture, check).

10. WHEN the user makes errors THEN the system SHALL provide clear, actionable error messages.

### Scalability

11. WHEN the user base grows THEN the server architecture SHALL support horizontal scaling.

12. WHEN match history grows THEN the local database SHALL implement efficient indexing and cleanup of records older than 1 year.

### Maintainability

13. WHEN code is written THEN developers SHALL follow Swift API Design Guidelines and include documentation for public interfaces.

14. WHEN the app is updated THEN the system SHALL support backward compatibility with existing user data.

---

## Glossary

| Term | Definition |
|------|------------|
| Xiangqi | Chinese Chess, a two-player strategy board game |
| General | The king piece in Xiangqi, confined to the palace |
| Advisor | A piece that moves diagonally within the palace |
| Elephant | A piece that moves two steps diagonally, cannot cross river |
| Horse | A piece with L-shaped movement, can be blocked |
| Chariot | A piece that moves any distance orthogonally (like Chess rook) |
| Cannon | A piece that moves orthogonally, captures by jumping over one piece |
| Soldier | A piece that moves forward, gains sideways movement after crossing river |
| Palace | The 3x3 area where General and Advisors are confined |
| River | The horizontal division in the center of the board |
| Flying General | Rule preventing Generals from facing each other with no pieces between |
| IDFV | identifierForVendor - Apple's per-vendor device identifier |
| WebSocket | Protocol for full-duplex communication channels over TCP |
| TestFlight | Apple's platform for beta testing iOS applications |

---

## References

- [Xiangqi.js - JavaScript Chinese Chess Library](https://github.com/lengyanyu258/xiangqi.js/)
- [Xiang - iOS Chinese Chess Engine Port](https://github.com/horaceho/Xiang)
- [ChineseChess - Qt-based Cross-platform Implementation](https://github.com/XMuli/ChineseChess)
- [Xiangqi Server Implementation](https://github.com/maksimKorzh/xiangqi-server)
- [Pikafish - Strong Xiangqi Engine](https://github.com/official-pikafish/Pikafish)
- [iOS Device Identifiers - NSHipster](https://nshipster.com/device-identifiers/)
- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [Xiangqi Rules and Pieces](https://www.xiangqi.com/help/pieces-and-moves)

