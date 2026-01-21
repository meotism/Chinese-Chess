//
//  MatchmakingView.swift
//  ChineseChess
//
//  View for finding an opponent to play against.
//

import SwiftUI

/// The matchmaking screen displayed while searching for an opponent.
struct MatchmakingView: View {

    // MARK: - Environment

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @StateObject private var viewModel = MatchmakingViewModel()

    /// Whether to navigate to the game
    @State private var navigateToGame = false

    /// The game info when a match is found
    @State private var matchedGameInfo: (gameId: String, opponentName: String, myColor: PlayerColor)?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animation section
            searchingAnimation

            // Status text
            statusSection

            Spacer()

            // Settings section
            if !viewModel.isSearching {
                settingsSection
            }

            Spacer()

            // Action buttons
            actionButtons
        }
        .padding()
        .background(Color(.systemBackground))
        .navigationTitle("Find Match")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.isSearching)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if !viewModel.isSearching {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onChange(of: viewModel.state) { _, newState in
            if case .matchFound(let gameId, let opponentName, let assignedColor) = newState {
                matchedGameInfo = (gameId, opponentName, assignedColor)
                // Delay navigation slightly for visual feedback
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    navigateToGame = true
                }
            }
        }
        .navigationDestination(isPresented: $navigateToGame) {
            if let info = matchedGameInfo {
                GameBoardView(
                    gameId: info.gameId,
                    myColor: info.myColor,
                    opponentName: info.opponentName
                )
            }
        }
    }

    // MARK: - Sections

    private var searchingAnimation: some View {
        ZStack {
            // Pulsing circles
            ForEach(0..<3) { index in
                Circle()
                    .stroke(Color.red.opacity(0.3 - Double(index) * 0.1), lineWidth: 2)
                    .frame(width: 100 + CGFloat(index) * 40, height: 100 + CGFloat(index) * 40)
                    .scaleEffect(viewModel.isSearching ? 1.2 : 1.0)
                    .opacity(viewModel.isSearching ? 0.0 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.3),
                        value: viewModel.isSearching
                    )
            }

            // Center icon
            Image(systemName: viewModel.matchFound ? "checkmark.circle.fill" : "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(viewModel.matchFound ? .green : .red)
                .scaleEffect(viewModel.matchFound ? 1.2 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.matchFound)
        }
        .frame(height: 200)
    }

    private var statusSection: some View {
        VStack(spacing: 12) {
            switch viewModel.state {
            case .idle:
                Text("Ready to Play")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Tap 'Find Match' to start searching for an opponent")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

            case .searching:
                Text("Finding Opponent...")
                    .font(.title2)
                    .fontWeight(.semibold)

                HStack(spacing: 24) {
                    VStack(spacing: 4) {
                        Text(viewModel.formattedSearchTime)
                            .font(.system(.title, design: .monospaced, weight: .bold))
                            .foregroundColor(.blue)
                        Text("Search Time")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Divider()
                        .frame(height: 40)

                    VStack(spacing: 4) {
                        Text(viewModel.formattedEstimatedWait)
                            .font(.system(.title, design: .monospaced, weight: .bold))
                            .foregroundColor(.orange)
                        Text("Est. Wait")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)

            case .matchFound(_, let opponentName, let assignedColor):
                Text("Match Found!")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)

                VStack(spacing: 8) {
                    Text("Opponent: \(opponentName)")
                        .font(.headline)

                    HStack(spacing: 8) {
                        Text("You play as:")
                            .foregroundColor(.secondary)

                        HStack(spacing: 4) {
                            Circle()
                                .fill(assignedColor == .red ? Color.red : Color.black)
                                .frame(width: 16, height: 16)
                            Text(assignedColor.rawValue.capitalized)
                                .fontWeight(.medium)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)

            case .error(let message):
                Text("Error")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

            case .cancelled:
                Text("Search Cancelled")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Game Settings")
                .font(.headline)

            // Turn timeout picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Turn Timeout")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("Turn Timeout", selection: $viewModel.selectedTimeout) {
                    ForEach(TurnTimeout.allCases, id: \.self) { timeout in
                        Text(timeout.displayName).tag(timeout)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if viewModel.isSearching {
                Button(action: {
                    viewModel.cancelSearch()
                }) {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Cancel Search")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .foregroundColor(.red)
                    .cornerRadius(12)
                }
            } else if case .error = viewModel.state {
                Button(action: {
                    viewModel.startSearching()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            } else if !viewModel.matchFound {
                Button(action: {
                    viewModel.startSearching()
                }) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Find Match")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Idle") {
    NavigationStack {
        MatchmakingView()
            .environmentObject(AppState())
    }
}
