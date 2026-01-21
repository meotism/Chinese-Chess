//
//  ConnectionManager.swift
//  ChineseChess
//
//  Manages WebSocket connection lifecycle and reconnection logic.
//

import Foundation
import Combine
import Network

/// Manages WebSocket connection lifecycle, including reconnection logic and network monitoring.
final class ConnectionManager: ObservableObject {

    // MARK: - Singleton

    static let shared = ConnectionManager()

    // MARK: - Published Properties

    /// Current connection state
    @Published private(set) var connectionState: ConnectionState = .disconnected

    /// Whether the device has network connectivity
    @Published private(set) var isNetworkAvailable = true

    /// Whether an opponent is currently connected
    @Published private(set) var isOpponentConnected = false

    // MARK: - Properties

    /// Network service for WebSocket communication
    private var networkService: NetworkService?

    /// Network path monitor
    private let networkMonitor = NWPathMonitor()

    /// Queue for network monitoring
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")

    /// Subscriptions
    private var cancellables = Set<AnyCancellable>()

    /// Current game ID
    private var currentGameId: String?

    /// Reconnection configuration
    private let maxReconnectAttempts = 5
    private let initialReconnectDelay: TimeInterval = 1.0
    private let maxReconnectDelay: TimeInterval = 30.0

    /// Current reconnection state
    private var reconnectAttempt = 0
    private var reconnectWorkItem: DispatchWorkItem?
    private var isManuallyDisconnected = false

    /// Callback for state synchronization after reconnect
    var onReconnected: (() async -> Void)?

    /// Callback for game events
    var onGameEvent: ((GameEvent) -> Void)?

    // MARK: - Initialization

    private init() {
        setupNetworkMonitor()
    }

    // MARK: - Public Methods

    /// Initializes the connection manager with a network service.
    func initialize(with networkService: NetworkService) {
        self.networkService = networkService

        // Subscribe to connection state changes
        networkService.connectionStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleConnectionStateChange(state)
            }
            .store(in: &cancellables)

        // Subscribe to game events
        networkService.gameEventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleGameEvent(event)
            }
            .store(in: &cancellables)
    }

    /// Connects to a game.
    func connect(to gameId: String) async throws {
        guard let networkService = networkService else {
            throw NetworkError.connectionFailed("Network service not initialized")
        }

        currentGameId = gameId
        reconnectAttempt = 0
        isManuallyDisconnected = false

        try await networkService.connectToGame(gameId)
    }

    /// Disconnects from the current game.
    func disconnect() {
        isManuallyDisconnected = true
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        networkService?.disconnect()
        currentGameId = nil
        connectionState = .disconnected
    }

    /// Manually trigger a reconnection attempt.
    func reconnect() async throws {
        guard let gameId = currentGameId else {
            throw NetworkError.connectionFailed("No game to reconnect to")
        }

        reconnectAttempt = 0
        isManuallyDisconnected = false

        try await connect(to: gameId)
    }

    // MARK: - Private Methods

    private func setupNetworkMonitor() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasAvailable = self?.isNetworkAvailable ?? true
                self?.isNetworkAvailable = path.status == .satisfied

                // If network became available and we have a game, try to reconnect
                if !wasAvailable && path.status == .satisfied {
                    self?.handleNetworkRestored()
                }
            }
        }

        networkMonitor.start(queue: monitorQueue)
    }

    private func handleConnectionStateChange(_ state: ConnectionState) {
        connectionState = state

        switch state {
        case .connected:
            reconnectAttempt = 0
            reconnectWorkItem?.cancel()

            // Sync state after successful reconnection
            if reconnectAttempt > 0 {
                Task {
                    await onReconnected?()
                }
            }

        case .disconnected:
            if !isManuallyDisconnected {
                scheduleReconnection()
            }

        case .failed:
            if !isManuallyDisconnected && reconnectAttempt < maxReconnectAttempts {
                scheduleReconnection()
            }

        case .connecting, .reconnecting:
            break
        }
    }

    private func handleGameEvent(_ event: GameEvent) {
        switch event {
        case .connected:
            isOpponentConnected = false // Will be updated when opponent joins

        case .opponentJoined:
            isOpponentConnected = true

        case .opponentDisconnected:
            isOpponentConnected = false

        case .opponentReconnected:
            isOpponentConnected = true

        case .disconnected:
            if !isManuallyDisconnected {
                scheduleReconnection()
            }

        default:
            break
        }

        onGameEvent?(event)
    }

    private func handleNetworkRestored() {
        guard !isManuallyDisconnected,
              currentGameId != nil,
              connectionState == .disconnected || connectionState == .failed(error: "") else {
            return
        }

        // Cancel any pending reconnect and try immediately
        reconnectWorkItem?.cancel()
        reconnectAttempt = 0
        scheduleReconnection(immediate: true)
    }

    private func scheduleReconnection(immediate: Bool = false) {
        guard !isManuallyDisconnected,
              let gameId = currentGameId,
              reconnectAttempt < maxReconnectAttempts else {
            return
        }

        reconnectAttempt += 1
        connectionState = .reconnecting(attempt: reconnectAttempt)

        // Calculate delay with exponential backoff
        let delay: TimeInterval
        if immediate {
            delay = 0
        } else {
            delay = min(initialReconnectDelay * pow(2.0, Double(reconnectAttempt - 1)), maxReconnectDelay)
        }

        reconnectWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            Task {
                do {
                    try await self.networkService?.connectToGame(gameId)
                } catch {
                    DispatchQueue.main.async {
                        if self.reconnectAttempt >= self.maxReconnectAttempts {
                            self.connectionState = .failed(error: "Max reconnection attempts reached")
                        }
                    }
                }
            }
        }

        reconnectWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    deinit {
        networkMonitor.cancel()
        reconnectWorkItem?.cancel()
    }
}

// MARK: - State Sync Helper

extension ConnectionManager {

    /// Requests the current game state from the server after reconnection.
    func syncGameState() async throws {
        guard let networkService = networkService,
              let gameId = currentGameId else {
            return
        }

        // The server will send game_state message after join
        // We just need to make sure we're connected and join the game
        let joinMessage = WebSocketMessage(
            type: .join,
            payload: [
                "game_id": AnyCodable(gameId),
                "request_state": AnyCodable(true)
            ]
        )

        // The NetworkService handles sending join messages internally
        // State will be received via the gameEventPublisher
    }
}
