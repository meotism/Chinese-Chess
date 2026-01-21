//
//  ContentView.swift
//  ChineseChess
//
//  The root content view that handles navigation and app state.
//

import SwiftUI

/// The root content view for the application.
///
/// This view manages the main navigation flow and displays
/// appropriate content based on the app's initialization state.
struct ContentView: View {

    // MARK: - Environment

    @EnvironmentObject var appState: AppState

    // MARK: - State

    @State private var selectedTab: Tab = .home

    // MARK: - Body

    var body: some View {
        Group {
            if appState.isInitializing {
                SplashView()
            } else if let error = appState.initializationError {
                ErrorView(error: error)
            } else {
                MainNavigationView(selectedTab: $selectedTab)
            }
        }
    }
}

// MARK: - Tab Enum

/// Represents the main navigation tabs in the application.
enum Tab: Hashable {
    case home
    case matchmaking
    case game(gameId: String)
    case history
    case settings
}

// MARK: - Splash View

/// A splash screen shown during app initialization.
struct SplashView: View {
    var body: some View {
        VStack(spacing: 20) {
            // App logo placeholder
            Image(systemName: "checkerboard.rectangle")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .foregroundColor(.red)

            Text("Chinese Chess")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Xiangqi")
                .font(.title2)
                .foregroundColor(.secondary)

            ProgressView()
                .padding(.top, 20)
        }
    }
}

// MARK: - Error View

/// A view displayed when initialization fails.
struct ErrorView: View {
    let error: AppError

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .foregroundColor(.orange)

            Text("Initialization Error")
                .font(.title)
                .fontWeight(.bold)

            Text(error.localizedDescription)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Button("Retry") {
                // Trigger retry logic
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// MARK: - Main Navigation View

/// The main navigation container for the app.
struct MainNavigationView: View {
    @Binding var selectedTab: Tab

    var body: some View {
        NavigationStack {
            Group {
                switch selectedTab {
                case .home:
                    HomeView(selectedTab: $selectedTab)

                case .matchmaking:
                    MatchmakingView()

                case .game(let gameId):
                    // Default to red color for now - actual color comes from matchmaking
                    GameBoardView(gameId: gameId, myColor: .red, opponentName: "Opponent")

                case .history:
                    MatchHistoryView()

                case .settings:
                    SettingsView()
                }
            }
        }
    }
}

// MARK: - Settings View

/// Placeholder settings view.
struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List {
            Section("Profile") {
                HStack {
                    Text("Display Name")
                    Spacer()
                    Text(appState.currentUser?.displayName ?? "Guest")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Player ID")
                    Spacer()
                    Text(appState.currentUser?.id.prefix(8) ?? "Unknown")
                        .foregroundColor(.secondary)
                        .font(.system(.body, design: .monospaced))
                }
            }

            Section("Sound & Haptics") {
                Toggle("Sound Effects", isOn: .constant(true))
                Toggle("Haptic Feedback", isOn: .constant(true))
            }

            Section("Game") {
                Picker("Default Turn Timer", selection: .constant(TurnTimeout.fiveMinutes)) {
                    ForEach(TurnTimeout.allCases, id: \.self) { timeout in
                        Text(timeout.displayName).tag(timeout)
                    }
                }
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }

                Link(destination: URL(string: "https://xiangqi-app.com/support")!) {
                    Text("Support")
                }

                Link(destination: URL(string: "https://xiangqi-app.com/privacy")!) {
                    Text("Privacy Policy")
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(AppState())
}
