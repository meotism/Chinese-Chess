//
//  GameBoardView.swift
//  ChineseChess
//
//  Main game screen displaying the chess board and game controls.
//

import SwiftUI

/// The main game screen displaying the Xiangqi board and game controls.
struct GameBoardView: View {

    // MARK: - Environment

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @StateObject private var viewModel: GameViewModel

    /// Whether to show the resign confirmation alert
    @State private var showResignAlert = false

    /// Whether to show the draw offer alert
    @State private var showDrawOfferAlert = false

    /// Whether to show the rollback request alert
    @State private var showRollbackAlert = false

    /// Whether to show the game menu
    @State private var showGameMenu = false

    /// Whether to show incoming rollback request
    @State private var showIncomingRollbackRequest = false

    // MARK: - Initialization

    init(gameId: String, myColor: PlayerColor, opponentName: String) {
        _viewModel = StateObject(wrappedValue: GameViewModel(
            gameId: gameId,
            myColor: myColor,
            opponentName: opponentName
        ))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Main game content
            VStack(spacing: 0) {
                // Opponent info panel
                opponentPanel

                // Captured by current player
                CapturedPiecesView(
                    capturedPieces: viewModel.opponentCapturedPieces
                )

                Spacer()

                // Game board
                boardSection

                // Check indicator
                if viewModel.isCheck || viewModel.isCheckmate {
                    CheckIndicator(
                        isCheck: viewModel.isCheck,
                        isCheckmate: viewModel.isCheckmate
                    )
                    .padding(.vertical, 8)
                }

                Spacer()

                // Captured by opponent
                CapturedPiecesView(
                    capturedPieces: viewModel.myCapturedPieces
                )

                // Current player info panel
                playerPanel

                // Action buttons
                actionButtons
            }
            .padding(.vertical)
            .background(Color(.systemBackground))

            // Game over overlay
            if viewModel.isGameOver {
                gameOverOverlay
            }

            // Connection overlay
            if viewModel.connectionState == .reconnecting(attempt: 0) {
                reconnectingOverlay
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Chinese Chess")
                    .font(.headline)
            }
        }
        .alert("Resign Game", isPresented: $showResignAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Resign", role: .destructive) {
                viewModel.resign()
            }
        } message: {
            Text("Are you sure you want to resign? This will count as a loss.")
        }
        .alert("Offer Draw", isPresented: $showDrawOfferAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Offer Draw") {
                viewModel.offerDraw()
            }
        } message: {
            Text("Would you like to offer a draw to your opponent?")
        }
        .alert("Request Undo", isPresented: $showRollbackAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Request") {
                viewModel.requestRollback()
            }
        } message: {
            Text("Request to undo your last move? Your opponent must accept.")
        }
        .alert("Undo Request", isPresented: $showIncomingRollbackRequest) {
            Button("Decline", role: .cancel) {
                viewModel.respondToRollback(accept: false)
            }
            Button("Accept") {
                viewModel.respondToRollback(accept: true)
            }
        } message: {
            Text("Your opponent wants to undo their last move. Do you accept?")
        }
        .sheet(isPresented: $showGameMenu) {
            GameMenuSheet(
                onResume: { showGameMenu = false },
                onLeave: {
                    showGameMenu = false
                    dismiss()
                }
            )
        }
        .onReceive(viewModel.$pendingRollbackRequest) { hasPendingRequest in
            showIncomingRollbackRequest = hasPendingRequest
        }
    }

    // MARK: - Sections

    private var opponentPanel: some View {
        PlayerInfoPanel(
            player: PlayerDisplayInfo(
                name: viewModel.opponentName,
                color: viewModel.opponentColor,
                remainingRollbacks: viewModel.opponentRollbacksRemaining,
                timeRemaining: viewModel.opponentTimeRemaining,
                isCurrentTurn: viewModel.currentTurn == viewModel.opponentColor
            ),
            isCurrentUser: false
        )
        .padding(.horizontal)
    }

    private var playerPanel: some View {
        PlayerInfoPanel(
            player: PlayerDisplayInfo(
                name: "You",
                color: viewModel.myColor,
                remainingRollbacks: viewModel.myRollbacksRemaining,
                timeRemaining: viewModel.myTimeRemaining,
                isCurrentTurn: viewModel.currentTurn == viewModel.myColor
            ),
            isCurrentUser: true
        )
        .padding(.horizontal)
    }

    private var boardSection: some View {
        BoardView(
            gameState: viewModel.gameState,
            selectedPosition: viewModel.selectedPosition,
            validMoves: viewModel.validMoves,
            lastMove: viewModel.lastMove,
            onPositionTapped: { position in
                viewModel.handlePositionTapped(position)
            }
        )
        .padding(.horizontal)
    }

    private var actionButtons: some View {
        GameActionButtons(
            rollbacksRemaining: viewModel.myRollbacksRemaining,
            canRequestRollback: viewModel.canRequestRollback,
            onRollback: { showRollbackAlert = true },
            onDrawOffer: { showDrawOfferAlert = true },
            onResign: { showResignAlert = true },
            onMenu: { showGameMenu = true }
        )
        .padding(.top, 8)
    }

    // MARK: - Overlays

    private var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Result icon
                Image(systemName: viewModel.didWin ? "crown.fill" : "xmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(viewModel.didWin ? .yellow : .red)

                // Result text
                Text(viewModel.didWin ? "Victory!" : (viewModel.isDraw ? "Draw" : "Defeat"))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                // Result type
                if let resultType = viewModel.resultType {
                    Text(resultType.displayName)
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                }

                // Stats
                HStack(spacing: 32) {
                    VStack {
                        Text("\(viewModel.totalMoves)")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Moves")
                            .font(.caption)
                    }

                    VStack {
                        Text(viewModel.gameDuration)
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Duration")
                            .font(.caption)
                    }
                }
                .foregroundColor(.white)

                // Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        // TODO: Request rematch
                    }) {
                        Text("Play Again")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    Button(action: {
                        dismiss()
                    }) {
                        Text("Return Home")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 40)
            }
            .padding()
        }
    }

    private var reconnectingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text("Reconnecting...")
                    .font(.headline)
                    .foregroundColor(.white)

                Text("Please wait while we restore your connection")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }
}

// MARK: - Game Menu Sheet

/// A sheet displaying game menu options.
struct GameMenuSheet: View {

    let onResume: () -> Void
    let onLeave: () -> Void

    @State private var showLeaveConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Resume Game") {
                        onResume()
                    }
                }

                Section {
                    Button("Leave Game", role: .destructive) {
                        showLeaveConfirmation = true
                    }
                }

                Section("Settings") {
                    Toggle("Sound Effects", isOn: .constant(true))
                    Toggle("Haptic Feedback", isOn: .constant(true))
                }
            }
            .navigationTitle("Game Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onResume()
                    }
                }
            }
            .alert("Leave Game", isPresented: $showLeaveConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Leave", role: .destructive) {
                    onLeave()
                }
            } message: {
                Text("Are you sure you want to leave? This will count as a loss.")
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Preview

#Preview("Game Board") {
    NavigationStack {
        GameBoardView(
            gameId: "test-game-123",
            myColor: .red,
            opponentName: "ChessMaster"
        )
        .environmentObject(AppState())
    }
}
