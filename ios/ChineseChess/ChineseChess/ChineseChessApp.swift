//
//  ChineseChessApp.swift
//  ChineseChess
//
//  Main entry point for the Chinese Chess (Xiangqi) iOS application.
//  This app provides real-time online multiplayer Chinese Chess gameplay
//  with device-based anonymous authentication.
//

import SwiftUI

/// The main application structure for Chinese Chess (Xiangqi).
///
/// This app follows the MVVM architecture pattern and provides:
/// - Anonymous user identification via device ID
/// - Real-time online multiplayer gameplay
/// - Complete implementation of traditional Xiangqi rules
/// - Match history tracking and replay functionality
@main
struct ChineseChessApp: App {

    // MARK: - State Objects

    /// The application's dependency container for service injection
    @StateObject private var appState = AppState()

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

// MARK: - App State

/// Global application state container that holds references to all services.
///
/// This class serves as a dependency injection container, providing
/// access to services throughout the application via environment objects.
@MainActor
final class AppState: ObservableObject {

    // MARK: - Published Properties

    /// The current user's profile, if authenticated
    @Published var currentUser: User?

    /// Whether the app is currently initializing
    @Published var isInitializing: Bool = true

    /// Any error that occurred during initialization
    @Published var initializationError: AppError?

    // MARK: - Services

    /// Service for managing user authentication and identity
    let authService: AuthServiceProtocol

    /// Service for database operations
    let databaseService: DatabaseServiceProtocol

    /// Service for network operations
    let networkService: NetworkServiceProtocol

    /// Service for game logic
    let gameService: GameServiceProtocol

    /// Service for audio and haptic feedback
    let audioService: AudioServiceProtocol

    // MARK: - Initialization

    init() {
        // Initialize services with concrete implementations
        // Using dependency injection for testability

        let keychainService = KeychainService()
        let databaseService = DatabaseService()
        let networkService = NetworkService()
        let audioService = AudioService()

        self.databaseService = databaseService
        self.networkService = networkService
        self.audioService = audioService
        self.authService = AuthService(
            keychainService: keychainService,
            networkService: networkService
        )
        self.gameService = GameService(
            networkService: networkService,
            databaseService: databaseService
        )

        // Perform async initialization
        Task {
            await initialize()
        }
    }

    // MARK: - Methods

    /// Initializes the application services and loads user data.
    private func initialize() async {
        do {
            // Initialize database
            try await databaseService.initialize()

            // Initialize user identity
            let identity = try await authService.initialize()

            // Load user profile
            if let user = try await databaseService.getUser(by: identity.deviceId) {
                currentUser = user
            }

            isInitializing = false
        } catch {
            initializationError = AppError.initialization(error)
            isInitializing = false
        }
    }
}
