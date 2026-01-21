//
//  GameSettings.swift
//  ChineseChess
//
//  Game and application settings.
//

import Foundation

// MARK: - TurnTimeout

/// Available turn timeout options.
enum TurnTimeout: Int, Codable, CaseIterable, Identifiable {
    /// 1 minute per turn
    case oneMinute = 60

    /// 3 minutes per turn
    case threeMinutes = 180

    /// 5 minutes per turn (default)
    case fiveMinutes = 300

    /// 10 minutes per turn
    case tenMinutes = 600

    /// No time limit
    case unlimited = 0

    var id: Int { rawValue }

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .oneMinute: return "1 minute"
        case .threeMinutes: return "3 minutes"
        case .fiveMinutes: return "5 minutes"
        case .tenMinutes: return "10 minutes"
        case .unlimited: return "Unlimited"
        }
    }

    /// Short display name for compact UI
    var shortName: String {
        switch self {
        case .oneMinute: return "1 min"
        case .threeMinutes: return "3 min"
        case .fiveMinutes: return "5 min"
        case .tenMinutes: return "10 min"
        case .unlimited: return "No limit"
        }
    }
}

// MARK: - GameSettings

/// User preferences for game settings.
struct GameSettings: Codable, Equatable {

    // MARK: - Properties

    /// The turn timeout setting
    var turnTimeout: TurnTimeout

    /// Whether sound effects are enabled
    var soundEnabled: Bool

    /// Whether haptic feedback is enabled
    var hapticsEnabled: Bool

    /// Whether to show valid move hints when selecting a piece
    var showMoveHints: Bool

    /// Whether to automatically confirm moves (vs. requiring tap-to-confirm)
    var autoConfirmMoves: Bool

    // MARK: - Default Settings

    /// Returns the default game settings.
    static var `default`: GameSettings {
        GameSettings(
            turnTimeout: .fiveMinutes,
            soundEnabled: true,
            hapticsEnabled: true,
            showMoveHints: true,
            autoConfirmMoves: true
        )
    }

    // MARK: - Persistence Keys

    private enum Keys {
        static let turnTimeout = "settings.turnTimeout"
        static let soundEnabled = "settings.soundEnabled"
        static let hapticsEnabled = "settings.hapticsEnabled"
        static let showMoveHints = "settings.showMoveHints"
        static let autoConfirmMoves = "settings.autoConfirmMoves"
    }

    // MARK: - UserDefaults Persistence

    /// Saves the settings to UserDefaults.
    func save() {
        let defaults = UserDefaults.standard
        defaults.set(turnTimeout.rawValue, forKey: Keys.turnTimeout)
        defaults.set(soundEnabled, forKey: Keys.soundEnabled)
        defaults.set(hapticsEnabled, forKey: Keys.hapticsEnabled)
        defaults.set(showMoveHints, forKey: Keys.showMoveHints)
        defaults.set(autoConfirmMoves, forKey: Keys.autoConfirmMoves)
    }

    /// Loads settings from UserDefaults, or returns defaults if not found.
    static func load() -> GameSettings {
        let defaults = UserDefaults.standard

        // Check if settings have been saved before
        guard defaults.object(forKey: Keys.soundEnabled) != nil else {
            return .default
        }

        let timeoutValue = defaults.integer(forKey: Keys.turnTimeout)
        let turnTimeout = TurnTimeout(rawValue: timeoutValue) ?? .fiveMinutes

        return GameSettings(
            turnTimeout: turnTimeout,
            soundEnabled: defaults.bool(forKey: Keys.soundEnabled),
            hapticsEnabled: defaults.bool(forKey: Keys.hapticsEnabled),
            showMoveHints: defaults.bool(forKey: Keys.showMoveHints),
            autoConfirmMoves: defaults.bool(forKey: Keys.autoConfirmMoves)
        )
    }
}

// MARK: - MatchmakingSettings

/// Settings used when joining the matchmaking queue.
struct MatchmakingSettings: Codable, Equatable {
    /// The desired turn timeout for the game
    var turnTimeout: TurnTimeout

    /// Preferred color (nil for random assignment)
    var preferredColor: PlayerColor?

    /// Creates matchmaking settings from game settings.
    init(from gameSettings: GameSettings) {
        self.turnTimeout = gameSettings.turnTimeout
        self.preferredColor = nil
    }

    /// Creates custom matchmaking settings.
    init(turnTimeout: TurnTimeout, preferredColor: PlayerColor? = nil) {
        self.turnTimeout = turnTimeout
        self.preferredColor = preferredColor
    }
}
