//
//  PlayerInfoPanel.swift
//  ChineseChess
//
//  View component for displaying player information during a game.
//

import SwiftUI

/// Information about a player for display.
struct PlayerDisplayInfo {
    let name: String
    let color: PlayerColor
    let remainingRollbacks: Int
    let timeRemaining: Int
    let isCurrentTurn: Bool
}

/// A panel displaying player information including name, timer, and rollback count.
struct PlayerInfoPanel: View {

    // MARK: - Properties

    /// The player information to display
    let player: PlayerDisplayInfo

    /// Whether this is the current user (displayed at bottom)
    var isCurrentUser: Bool = false

    // MARK: - Body

    var body: some View {
        HStack(spacing: 16) {
            // Player color indicator
            Circle()
                .fill(player.color == .red ? Color.red : Color.black)
                .frame(width: 16, height: 16)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 1)
                )

            // Player name
            VStack(alignment: .leading, spacing: 2) {
                Text(isCurrentUser ? "You" : player.name)
                    .font(.headline)
                    .foregroundColor(.primary)

                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.backward.circle")
                        .font(.caption)
                    Text("\(player.remainingRollbacks)")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }

            Spacer()

            // Timer
            TimerDisplay(
                timeRemaining: player.timeRemaining,
                isActive: player.isCurrentTurn
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(player.isCurrentTurn ? turnActiveBackground : Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(player.isCurrentTurn ? turnActiveBorder : Color.clear, lineWidth: 2)
        )
    }

    // MARK: - Colors

    private var turnActiveBackground: Color {
        player.color == .red
            ? Color.red.opacity(0.1)
            : Color.black.opacity(0.1)
    }

    private var turnActiveBorder: Color {
        player.color == .red ? Color.red : Color.black
    }
}

// MARK: - Timer Display

/// A view that displays a countdown timer.
struct TimerDisplay: View {

    // MARK: - Properties

    /// The remaining time in seconds
    let timeRemaining: Int

    /// Whether this timer is currently active
    let isActive: Bool

    // MARK: - Computed Properties

    private var minutes: Int {
        timeRemaining / 60
    }

    private var seconds: Int {
        timeRemaining % 60
    }

    private var timerText: String {
        String(format: "%d:%02d", minutes, seconds)
    }

    private var isWarning: Bool {
        timeRemaining <= 30 && timeRemaining > 10
    }

    private var isUrgent: Bool {
        timeRemaining <= 10
    }

    private var timerColor: Color {
        if isUrgent {
            return .red
        } else if isWarning {
            return .orange
        } else {
            return .primary
        }
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock")
                .font(.caption)
                .foregroundColor(timerColor)

            Text(timerText)
                .font(.system(.title2, design: .monospaced, weight: .bold))
                .foregroundColor(timerColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(timerBackground)
        )
        .scaleEffect(isUrgent && isActive ? 1.05 : 1.0)
        .animation(
            isUrgent && isActive
                ? Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)
                : .default,
            value: isUrgent
        )
    }

    private var timerBackground: Color {
        if isUrgent {
            return Color.red.opacity(0.2)
        } else if isWarning {
            return Color.orange.opacity(0.1)
        } else {
            return Color(.tertiarySystemBackground)
        }
    }
}

// MARK: - Captured Pieces View

/// A view that displays pieces captured by a player.
struct CapturedPiecesView: View {

    // MARK: - Properties

    /// The captured pieces to display
    let capturedPieces: [Piece]

    /// The size of each captured piece icon
    var pieceSize: CGFloat = 24

    // MARK: - Body

    var body: some View {
        HStack(spacing: 2) {
            ForEach(capturedPieces, id: \.id) { piece in
                Text(piece.character)
                    .font(.system(size: pieceSize * 0.7))
                    .foregroundColor(piece.color == .red ? .red : .black)
            }

            if capturedPieces.isEmpty {
                Text("No captures")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

// MARK: - Game Action Buttons

/// Buttons for game actions like rollback, draw, and resign.
struct GameActionButtons: View {

    // MARK: - Properties

    /// Remaining rollback count for the current player
    let rollbacksRemaining: Int

    /// Whether the current player can request a rollback
    var canRequestRollback: Bool = true

    /// Callback when rollback is tapped
    var onRollback: (() -> Void)?

    /// Callback when draw offer is tapped
    var onDrawOffer: (() -> Void)?

    /// Callback when resign is tapped
    var onResign: (() -> Void)?

    /// Callback when menu is tapped
    var onMenu: (() -> Void)?

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            // Menu button
            ActionButton(
                title: "Menu",
                icon: "line.3.horizontal",
                style: .secondary
            ) {
                onMenu?()
            }

            Spacer()

            // Rollback button
            ActionButton(
                title: "Undo (\(rollbacksRemaining))",
                icon: "arrow.uturn.backward",
                style: .secondary,
                isDisabled: rollbacksRemaining == 0 || !canRequestRollback
            ) {
                onRollback?()
            }

            // Draw button
            ActionButton(
                title: "Draw",
                icon: "handshake",
                style: .secondary
            ) {
                onDrawOffer?()
            }

            // Resign button
            ActionButton(
                title: "Resign",
                icon: "flag",
                style: .destructive
            ) {
                onResign?()
            }
        }
        .padding(.horizontal)
    }
}

/// A styled action button for game controls.
struct ActionButton: View {

    enum Style {
        case primary
        case secondary
        case destructive
    }

    let title: String
    let icon: String
    var style: Style = .primary
    var isDisabled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))

                Text(title)
                    .font(.caption2)
            }
            .frame(minWidth: 60)
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .foregroundColor(foregroundColor)
            .background(backgroundColor)
            .cornerRadius(8)
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1.0)
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return .primary
        case .destructive:
            return .red
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary:
            return .blue
        case .secondary:
            return Color(.secondarySystemBackground)
        case .destructive:
            return Color.red.opacity(0.1)
        }
    }
}

// MARK: - Check Indicator

/// A view that displays when the player is in check.
struct CheckIndicator: View {

    // MARK: - Properties

    /// Whether to show the check indicator
    let isCheck: Bool

    /// Whether the game has ended in checkmate
    let isCheckmate: Bool

    // MARK: - Body

    var body: some View {
        Group {
            if isCheckmate {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                    Text("CHECKMATE!")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(20)
            } else if isCheck {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    Text("CHECK!")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(20)
            }
        }
    }
}

// MARK: - Preview

#Preview("Player Info Panel - Active") {
    VStack(spacing: 20) {
        PlayerInfoPanel(
            player: PlayerDisplayInfo(
                name: "ChessMaster",
                color: .black,
                remainingRollbacks: 3,
                timeRemaining: 245,
                isCurrentTurn: true
            )
        )

        PlayerInfoPanel(
            player: PlayerDisplayInfo(
                name: "You",
                color: .red,
                remainingRollbacks: 2,
                timeRemaining: 300,
                isCurrentTurn: false
            ),
            isCurrentUser: true
        )
    }
    .padding()
}

#Preview("Timer Warnings") {
    VStack(spacing: 20) {
        TimerDisplay(timeRemaining: 300, isActive: true)
        TimerDisplay(timeRemaining: 25, isActive: true)
        TimerDisplay(timeRemaining: 8, isActive: true)
    }
    .padding()
}

#Preview("Action Buttons") {
    GameActionButtons(rollbacksRemaining: 2)
        .padding()
}

#Preview("Check Indicator") {
    VStack(spacing: 20) {
        CheckIndicator(isCheck: true, isCheckmate: false)
        CheckIndicator(isCheck: true, isCheckmate: true)
    }
    .padding()
}
