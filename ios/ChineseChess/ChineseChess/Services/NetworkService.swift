//
//  NetworkService.swift
//  ChineseChess
//
//  Service for network operations (REST API and WebSocket).
//

import Foundation
import Combine

// MARK: - API Configuration

/// Configuration for API endpoints.
/// Change these values based on your deployment environment.
enum APIConfiguration {
    #if DEBUG
    // Development configuration - connect to local server
    static let baseURL = URL(string: "http://localhost:8080/api/v1")!
    static let wsBaseURL = URL(string: "ws://localhost:8080")!
    #else
    // Production configuration - connect to production server
    // IMPORTANT: Update these URLs before deploying to TestFlight/App Store
    static let baseURL = URL(string: "https://api.xiangqi-app.com/v1")!
    static let wsBaseURL = URL(string: "wss://game.xiangqi-app.com")!
    #endif
}

/// Errors that can occur during network operations.
enum NetworkError: Error, LocalizedError {
    case invalidResponse
    case invalidURL
    case decodingFailed
    case encodingFailed
    case serverError(statusCode: Int, message: String?)
    case websocketDisconnected
    case connectionFailed(String)
    case timeout
    case noInternet

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .invalidURL:
            return "Invalid URL"
        case .decodingFailed:
            return "Failed to decode response"
        case .encodingFailed:
            return "Failed to encode request"
        case .serverError(let statusCode, let message):
            return message ?? "Server error (status \(statusCode))"
        case .websocketDisconnected:
            return "WebSocket disconnected"
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .timeout:
            return "Request timed out"
        case .noInternet:
            return "No internet connection"
        }
    }
}

/// Service for handling all network operations.
///
/// This service manages:
/// - REST API calls for user management, matchmaking, and history
/// - WebSocket connections for real-time gameplay
/// - Connection state and reconnection logic
final class NetworkService: NetworkServiceProtocol {

    // MARK: - Properties

    /// Base URL for the API server
    private let baseURL: URL

    /// WebSocket base URL
    private let wsBaseURL: URL

    /// URLSession for REST API calls
    private let session: URLSession

    /// Current device ID for authentication
    private var deviceId: String?

    /// App version for headers
    private let appVersion: String

    /// WebSocket task for game connections
    private var webSocketTask: URLSessionWebSocketTask?

    /// Current game ID for the WebSocket connection
    private var currentGameId: String?

    /// Subject for publishing connection state changes
    private let connectionStateSubject = CurrentValueSubject<ConnectionState, Never>(.disconnected)

    /// Subject for publishing game events
    private let gameEventSubject = PassthroughSubject<GameEvent, Never>()

    /// Reconnection attempt counter
    private var reconnectAttempt = 0

    /// Maximum reconnection attempts
    private let maxReconnectAttempts = 5

    /// Reconnection delay base (seconds)
    private let reconnectDelayBase: TimeInterval = 1.0

    /// Ping timer for keeping connection alive
    private var pingTimer: Timer?

    /// JSON decoder for responses
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    /// JSON encoder for requests
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    var connectionState: ConnectionState {
        connectionStateSubject.value
    }

    var connectionStatePublisher: AnyPublisher<ConnectionState, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }

    var gameEventPublisher: AnyPublisher<GameEvent, Never> {
        gameEventSubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    init(
        baseURL: URL = APIConfiguration.baseURL,
        wsBaseURL: URL = APIConfiguration.wsBaseURL,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.wsBaseURL = wsBaseURL
        self.session = session
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    /// Sets the device ID for authentication.
    func setDeviceId(_ deviceId: String) {
        self.deviceId = deviceId
    }

    // MARK: - REST API - User

    func registerDevice(_ identity: DeviceIdentity, displayName: String) async throws -> User {
        let request = RegisterRequest(
            deviceId: identity.deviceId,
            displayName: displayName,
            platform: "ios",
            appVersion: appVersion
        )

        let endpoint = baseURL.appendingPathComponent("users/register")
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(identity.deviceId, forHTTPHeaderField: "X-Device-ID")
        urlRequest.setValue(appVersion, forHTTPHeaderField: "X-App-Version")

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard httpResponse.statusCode == 201 || httpResponse.statusCode == 200 else {
            throw NetworkError.serverError(statusCode: httpResponse.statusCode, message: nil)
        }

        let decoder = JSONDecoder()
        let profileResponse = try decoder.decode(UserProfileResponse.self, from: data)

        return User(
            id: profileResponse.id,
            displayName: profileResponse.displayName,
            createdAt: ISO8601DateFormatter().date(from: profileResponse.createdAt) ?? Date(),
            updatedAt: Date(),
            stats: UserStats(
                totalGames: profileResponse.stats.totalGames,
                wins: profileResponse.stats.wins,
                losses: profileResponse.stats.losses,
                draws: profileResponse.stats.draws
            )
        )
    }

    func fetchUserProfile(deviceId: String) async throws -> User {
        let endpoint = baseURL.appendingPathComponent("users/\(deviceId)")
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        urlRequest.setValue(appVersion, forHTTPHeaderField: "X-App-Version")

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw NetworkError.serverError(statusCode: httpResponse.statusCode, message: nil)
        }

        let decoder = JSONDecoder()
        let profileResponse = try decoder.decode(UserProfileResponse.self, from: data)

        return User(
            id: profileResponse.id,
            displayName: profileResponse.displayName,
            createdAt: ISO8601DateFormatter().date(from: profileResponse.createdAt) ?? Date(),
            updatedAt: Date(),
            stats: UserStats(
                totalGames: profileResponse.stats.totalGames,
                wins: profileResponse.stats.wins,
                losses: profileResponse.stats.losses,
                draws: profileResponse.stats.draws
            )
        )
    }

    func updateDisplayName(_ name: String, deviceId: String) async throws -> User {
        // TODO: Implement PATCH /users/{device_id}
        throw NetworkError.invalidResponse
    }

    // MARK: - REST API - Match History

    func fetchMatchHistory(page: Int, pageSize: Int) async throws -> [Game] {
        guard let deviceId = deviceId else {
            throw NetworkError.connectionFailed("Device ID not set")
        }

        var components = URLComponents(url: baseURL.appendingPathComponent("games/history"), resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "page_size", value: "\(pageSize)")
        ]

        guard let endpoint = components.url else {
            throw NetworkError.invalidURL
        }

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        urlRequest.setValue(appVersion, forHTTPHeaderField: "X-App-Version")

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw NetworkError.serverError(statusCode: httpResponse.statusCode, message: nil)
        }

        let historyResponse = try decoder.decode(MatchHistoryResponse.self, from: data)

        // Convert response to Game objects
        return historyResponse.games.compactMap { summary -> Game? in
            let yourColor = PlayerColor(rawValue: summary.yourColor) ?? .red
            let resultType = ResultType(rawValue: summary.resultType) ?? .checkmate

            let status: GameStatus = .completed

            // Determine winner
            var winnerId: String? = nil
            if summary.result == "win" {
                winnerId = deviceId
            } else if summary.result == "loss" {
                winnerId = summary.opponent.id
            }

            return Game(
                id: summary.id,
                redPlayerId: yourColor == .red ? deviceId : summary.opponent.id,
                blackPlayerId: yourColor == .black ? deviceId : summary.opponent.id,
                status: status,
                winnerId: winnerId,
                resultType: resultType,
                turnTimeoutSeconds: 300,
                createdAt: ISO8601DateFormatter().date(from: summary.playedAt) ?? Date(),
                completedAt: ISO8601DateFormatter().date(from: summary.playedAt),
                totalMoves: summary.totalMoves
            )
        }
    }

    func fetchUserStats(deviceId: String) async throws -> UserStats {
        let user = try await fetchUserProfile(deviceId: deviceId)
        return user.stats
    }

    func fetchGameMoves(gameId: String) async throws -> [Move] {
        guard let deviceId = deviceId else {
            throw NetworkError.connectionFailed("Device ID not set")
        }

        let endpoint = baseURL.appendingPathComponent("games/\(gameId)/moves")

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        urlRequest.setValue(appVersion, forHTTPHeaderField: "X-App-Version")

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw NetworkError.serverError(statusCode: httpResponse.statusCode, message: nil)
        }

        // Define the response structure
        struct MovesResponse: Codable {
            let moves: [MoveResponse]

            struct MoveResponse: Codable {
                let id: Int
                let gameId: String
                let moveNumber: Int
                let playerId: String
                let from: String
                let to: String
                let pieceType: String
                let capturedPiece: String?
                let timestamp: String
                let isCheck: Bool
            }
        }

        let movesResponse = try decoder.decode(MovesResponse.self, from: data)

        return movesResponse.moves.compactMap { response -> Move? in
            guard let from = Position(notation: response.from),
                  let to = Position(notation: response.to),
                  let pieceType = PieceType(rawValue: response.pieceType) else {
                return nil
            }

            let capturedPiece = response.capturedPiece.flatMap { PieceType(rawValue: $0) }

            return Move(
                id: response.id,
                gameId: response.gameId,
                moveNumber: response.moveNumber,
                playerId: response.playerId,
                from: from,
                to: to,
                pieceType: pieceType,
                capturedPiece: capturedPiece,
                timestamp: ISO8601DateFormatter().date(from: response.timestamp) ?? Date(),
                isCheck: response.isCheck
            )
        }
    }

    // MARK: - REST API - Matchmaking

    func joinMatchmaking(settings: MatchmakingSettings) async throws -> QueueStatus {
        guard let deviceId = deviceId else {
            throw NetworkError.connectionFailed("Device ID not set")
        }

        let endpoint = baseURL.appendingPathComponent("matchmaking/join")

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        urlRequest.setValue(appVersion, forHTTPHeaderField: "X-App-Version")

        let request = MatchmakingJoinRequest(
            settings: MatchmakingJoinRequest.MatchmakingSettingsRequest(
                turnTimeout: settings.turnTimeout.rawValue,
                preferredColor: settings.preferredColor?.rawValue
            )
        )

        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            throw NetworkError.serverError(statusCode: httpResponse.statusCode, message: nil)
        }

        let statusResponse = try decoder.decode(MatchmakingStatusResponse.self, from: data)
        return parseQueueStatus(statusResponse)
    }

    func leaveMatchmaking() async throws {
        guard let deviceId = deviceId else {
            throw NetworkError.connectionFailed("Device ID not set")
        }

        let endpoint = baseURL.appendingPathComponent("matchmaking/leave")

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "DELETE"
        urlRequest.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        urlRequest.setValue(appVersion, forHTTPHeaderField: "X-App-Version")

        let (_, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 204 else {
            throw NetworkError.serverError(statusCode: httpResponse.statusCode, message: nil)
        }
    }

    func getMatchmakingStatus() async throws -> QueueStatus {
        guard let deviceId = deviceId else {
            throw NetworkError.connectionFailed("Device ID not set")
        }

        let endpoint = baseURL.appendingPathComponent("matchmaking/status")

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        urlRequest.setValue(appVersion, forHTTPHeaderField: "X-App-Version")

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw NetworkError.serverError(statusCode: httpResponse.statusCode, message: nil)
        }

        let statusResponse = try decoder.decode(MatchmakingStatusResponse.self, from: data)
        return parseQueueStatus(statusResponse)
    }

    /// Parses a matchmaking status response into a QueueStatus.
    private func parseQueueStatus(_ response: MatchmakingStatusResponse) -> QueueStatus {
        switch response.status {
        case "idle":
            return .idle

        case "waiting":
            return .waiting(
                position: response.position ?? 0,
                estimatedWaitSeconds: response.estimatedWaitSeconds ?? 30
            )

        case "matched":
            guard let gameId = response.gameId,
                  let opponent = response.opponent,
                  let colorString = response.yourColor,
                  let color = PlayerColor(rawValue: colorString) else {
                return .error(message: "Invalid match data")
            }
            return .matched(gameId: gameId, opponentName: opponent.displayName, assignedColor: color)

        case "left":
            return .left

        case "error":
            return .error(message: "Unknown error")

        default:
            return .idle
        }
    }

    // MARK: - WebSocket

    func connectToGame(_ gameId: String) async throws {
        // Cancel any existing connection
        disconnect()

        currentGameId = gameId
        reconnectAttempt = 0

        let wsURL = wsBaseURL.appendingPathComponent("games/\(gameId)")

        var request = URLRequest(url: wsURL)
        request.timeoutInterval = 10

        if let deviceId = deviceId {
            request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        }
        request.setValue(appVersion, forHTTPHeaderField: "X-App-Version")

        connectionStateSubject.send(.connecting)

        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()

        // Wait for connection to be established
        do {
            // Send a join message to register with the server
            let joinMessage = WebSocketMessage(
                type: .join,
                payload: [
                    "game_id": AnyCodable(gameId),
                    "device_id": AnyCodable(deviceId ?? "")
                ]
            )
            try await sendWebSocketMessage(joinMessage)

            connectionStateSubject.send(.connected)
            gameEventSubject.send(.connected)

            // Start receiving messages
            receiveMessages()

            // Start ping timer to keep connection alive
            startPingTimer()
        } catch {
            connectionStateSubject.send(.failed(error: error.localizedDescription))
            throw error
        }
    }

    func disconnect() {
        stopPingTimer()
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        currentGameId = nil
        reconnectAttempt = 0
        connectionStateSubject.send(.disconnected)
    }

    func sendMove(_ move: PendingMove) async throws {
        let message = WebSocketMessage(
            type: .move,
            payload: [
                "from": AnyCodable(move.from.notation),
                "to": AnyCodable(move.to.notation),
                "piece_type": AnyCodable(move.piece.type.rawValue)
            ]
        )
        try await sendWebSocketMessage(message)
    }

    func sendRollbackRequest() async throws {
        let message = WebSocketMessage(type: .rollbackRequest)
        try await sendWebSocketMessage(message)
    }

    func respondToRollback(accept: Bool) async throws {
        let message = WebSocketMessage(
            type: .rollbackResponse,
            payload: ["accept": AnyCodable(accept)]
        )
        try await sendWebSocketMessage(message)
    }

    func offerDraw() async throws {
        let message = WebSocketMessage(type: .drawOffer)
        try await sendWebSocketMessage(message)
    }

    func respondToDraw(accept: Bool) async throws {
        let message = WebSocketMessage(
            type: .drawResponse,
            payload: ["accept": AnyCodable(accept)]
        )
        try await sendWebSocketMessage(message)
    }

    func resign() async throws {
        let message = WebSocketMessage(type: .resign)
        try await sendWebSocketMessage(message)
    }

    // MARK: - Private Methods - WebSocket

    private func sendWebSocketMessage(_ message: WebSocketMessage) async throws {
        guard let webSocketTask = webSocketTask else {
            throw NetworkError.websocketDisconnected
        }

        let data = try encoder.encode(message)
        try await webSocketTask.send(.data(data))
    }

    private func receiveMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                self.handleWebSocketMessage(message)
                // Continue receiving
                self.receiveMessages()

            case .failure(let error):
                self.handleConnectionError(error)
            }
        }
    }

    private func handleWebSocketMessage(_ message: URLSessionWebSocketTask.Message) {
        let data: Data

        switch message {
        case .data(let receivedData):
            data = receivedData

        case .string(let text):
            guard let textData = text.data(using: .utf8) else { return }
            data = textData

        @unknown default:
            return
        }

        // Parse the message
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let typeString = json["type"] as? String else {
            DebugLog.error("Failed to parse WebSocket message")
            return
        }

        // Handle based on message type
        parseAndEmitEvent(type: typeString, json: json, data: data)
    }

    private func parseAndEmitEvent(type: String, json: [String: Any], data: Data) {
        switch type {
        case "game_state":
            // Initial game state or state update
            if let payload = json["payload"] as? [String: Any] {
                handleGameStateMessage(payload)
            }

        case "move_result":
            // Result of our move
            if let payload = json["payload"] as? [String: Any] {
                handleMoveResultMessage(payload)
            }

        case "opponent_move":
            // Opponent made a move
            if let payload = json["payload"] as? [String: Any] {
                handleOpponentMoveMessage(payload)
            }

        case "rollback_requested":
            // Opponent requested a rollback
            if let payload = json["payload"] as? [String: Any] {
                handleRollbackRequestMessage(payload)
            }

        case "rollback_result":
            // Rollback response
            if let payload = json["payload"] as? [String: Any] {
                handleRollbackResultMessage(payload)
            }

        case "timer":
            // Timer update
            if let payload = json["payload"] as? [String: Any] {
                handleTimerMessage(payload)
            }

        case "connection_status":
            // Opponent connection status
            if let payload = json["payload"] as? [String: Any] {
                handleConnectionStatusMessage(payload)
            }

        case "game_end":
            // Game ended
            if let payload = json["payload"] as? [String: Any] {
                handleGameEndMessage(payload)
            }

        case "error":
            // Error from server
            if let payload = json["payload"] as? [String: Any] {
                handleErrorMessage(payload)
            }

        case "pong":
            // Response to our ping, connection is alive
            break

        default:
            DebugLog.warning("Unknown message type: \(type)")
        }
    }

    // MARK: - Message Handlers

    private func handleGameStateMessage(_ payload: [String: Any]) {
        // Game state synchronization handled by the game engine
        // This is primarily for reconnection scenarios
    }

    private func handleMoveResultMessage(_ payload: [String: Any]) {
        let success = payload["success"] as? Bool ?? false
        let error = payload["error"] as? String

        if success {
            guard let moveData = payload["move"] as? [String: Any],
                  let from = moveData["from"] as? String,
                  let to = moveData["to"] as? String,
                  let pieceType = moveData["piece_type"] as? String else {
                return
            }

            let moveInfo = MoveInfo(
                from: from,
                to: to,
                pieceType: pieceType,
                captured: moveData["captured"] as? String,
                isCheck: moveData["is_check"] as? Bool ?? false,
                moveNumber: moveData["move_number"] as? Int ?? 0
            )

            gameEventSubject.send(.moveValidated(move: moveInfo, success: true, error: nil))
        } else {
            gameEventSubject.send(.moveValidated(
                move: MoveInfo(from: "", to: "", pieceType: "", captured: nil, isCheck: false, moveNumber: 0),
                success: false,
                error: error
            ))
        }
    }

    private func handleOpponentMoveMessage(_ payload: [String: Any]) {
        guard let from = payload["from"] as? String,
              let to = payload["to"] as? String,
              let pieceType = payload["piece_type"] as? String else {
            return
        }

        let moveInfo = MoveInfo(
            from: from,
            to: to,
            pieceType: pieceType,
            captured: payload["captured"] as? String,
            isCheck: payload["is_check"] as? Bool ?? false,
            moveNumber: payload["move_number"] as? Int ?? 0
        )

        gameEventSubject.send(.moveMade(move: moveInfo))
    }

    private func handleRollbackRequestMessage(_ payload: [String: Any]) {
        let requestedBy = payload["requested_by"] as? String ?? ""
        let timeout = payload["timeout_seconds"] as? Int ?? 30

        gameEventSubject.send(.rollbackRequested(by: requestedBy, timeoutSeconds: timeout))
    }

    private func handleRollbackResultMessage(_ payload: [String: Any]) {
        let accepted = payload["accepted"] as? Bool ?? false

        // If accepted, the server may send updated game state
        var newState: GameState? = nil
        if accepted, let _ = payload["game_state"] {
            // Parse game state if provided
            // For now we will let the client engine handle state reconstruction
        }

        gameEventSubject.send(.rollbackResponded(accepted: accepted, newState: newState))
    }

    private func handleTimerMessage(_ payload: [String: Any]) {
        let redTime = payload["red_time"] as? Int ?? 0
        let blackTime = payload["black_time"] as? Int ?? 0
        let currentTurnString = payload["current_turn"] as? String ?? "red"
        let currentTurn = PlayerColor(rawValue: currentTurnString) ?? .red

        gameEventSubject.send(.timerUpdate(redTime: redTime, blackTime: blackTime, currentTurn: currentTurn))
    }

    private func handleConnectionStatusMessage(_ payload: [String: Any]) {
        let status = payload["status"] as? String ?? ""

        switch status {
        case "opponent_connected":
            if let playerData = payload["player"] as? [String: Any],
               let id = playerData["id"] as? String,
               let name = playerData["display_name"] as? String {
                let opponent = OpponentInfo(id: id, displayName: name)
                gameEventSubject.send(.opponentJoined(player: opponent))
            }

        case "opponent_disconnected":
            gameEventSubject.send(.opponentDisconnected)

        case "opponent_reconnected":
            gameEventSubject.send(.opponentReconnected)

        default:
            break
        }
    }

    private func handleGameEndMessage(_ payload: [String: Any]) {
        let winnerId = payload["winner_id"] as? String
        let winnerColorString = payload["winner_color"] as? String
        let resultTypeString = payload["result_type"] as? String ?? "checkmate"
        let yourResultString = payload["your_result"] as? String ?? "loss"

        let winnerColor = winnerColorString.flatMap { PlayerColor(rawValue: $0) }
        let resultType = ResultType(rawValue: resultTypeString) ?? .checkmate
        let yourResult = GameResultOutcome(rawValue: yourResultString) ?? .loss

        let gameEndInfo = GameEndInfo(
            winnerId: winnerId,
            winnerColor: winnerColor,
            resultType: resultType,
            yourResult: yourResult
        )

        gameEventSubject.send(.gameEnded(result: gameEndInfo))
    }

    private func handleErrorMessage(_ payload: [String: Any]) {
        let code = payload["code"] as? String ?? "unknown"
        let message = payload["message"] as? String ?? "An error occurred"

        gameEventSubject.send(.error(code: code, message: message))
    }

    // MARK: - Connection Management

    private func handleConnectionError(_ error: Error) {
        DebugLog.error("WebSocket error", error)

        // Attempt reconnection if we have a game ID
        if let gameId = currentGameId, reconnectAttempt < maxReconnectAttempts {
            attemptReconnection(gameId: gameId)
        } else {
            connectionStateSubject.send(.failed(error: error.localizedDescription))
            gameEventSubject.send(.disconnected(reason: error.localizedDescription))
        }
    }

    private func attemptReconnection(gameId: String) {
        reconnectAttempt += 1
        connectionStateSubject.send(.reconnecting(attempt: reconnectAttempt))

        // Exponential backoff
        let delay = reconnectDelayBase * pow(2.0, Double(reconnectAttempt - 1))

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }

            Task {
                do {
                    try await self.connectToGame(gameId)
                } catch {
                    if self.reconnectAttempt >= self.maxReconnectAttempts {
                        self.connectionStateSubject.send(.failed(error: "Max reconnection attempts reached"))
                        self.gameEventSubject.send(.disconnected(reason: "Connection lost"))
                    }
                }
            }
        }
    }

    // MARK: - Ping/Pong

    private func startPingTimer() {
        stopPingTimer()

        pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task {
                try? await self?.sendPing()
            }
        }
    }

    private func stopPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
    }

    private func sendPing() async throws {
        let message = WebSocketMessage(type: .ping)
        try await sendWebSocketMessage(message)
    }

    deinit {
        disconnect()
    }
}
