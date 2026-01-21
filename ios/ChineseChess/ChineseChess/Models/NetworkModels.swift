//
//  NetworkModels.swift
//  ChineseChess
//
//  Models for network communication (API responses, WebSocket messages).
//

import Foundation

// MARK: - Connection State

/// The state of a network connection.
enum ConnectionState: Equatable {
    /// Not connected
    case disconnected

    /// Currently attempting to connect
    case connecting

    /// Successfully connected
    case connected

    /// Attempting to reconnect after a disconnection
    case reconnecting(attempt: Int)

    /// Connection failed
    case failed(error: String)
}

// MARK: - Queue Status

/// The status of a player in the matchmaking queue.
enum QueueStatus: Equatable {
    /// Not in queue
    case idle

    /// Waiting in queue
    case waiting(position: Int, estimatedWaitSeconds: Int)

    /// Match found
    case matched(gameId: String, opponentName: String, assignedColor: PlayerColor)

    /// Left the queue
    case left

    /// Error occurred
    case error(message: String)
}

// MARK: - Game Event

/// Events received from the game server via WebSocket.
enum GameEvent: Equatable {
    /// Successfully connected to the game
    case connected

    /// Disconnected from the game
    case disconnected(reason: String)

    /// Opponent joined the game
    case opponentJoined(player: OpponentInfo)

    /// Opponent disconnected
    case opponentDisconnected

    /// Opponent reconnected
    case opponentReconnected

    /// A move was made
    case moveMade(move: MoveInfo)

    /// Move was validated by server
    case moveValidated(move: MoveInfo, success: Bool, error: String?)

    /// Rollback was requested
    case rollbackRequested(by: String, timeoutSeconds: Int)

    /// Rollback response received
    case rollbackResponded(accepted: Bool, newState: GameState?)

    /// Game ended
    case gameEnded(result: GameEndInfo)

    /// Timer update
    case timerUpdate(redTime: Int, blackTime: Int, currentTurn: PlayerColor)

    /// Error from server
    case error(code: String, message: String)
}

// MARK: - Supporting Types

/// Information about an opponent.
struct OpponentInfo: Codable, Equatable {
    let id: String
    let displayName: String
}

/// Information about a move from the server.
struct MoveInfo: Codable, Equatable {
    let from: String
    let to: String
    let pieceType: String
    let captured: String?
    let isCheck: Bool
    let moveNumber: Int
}

/// Information about how a game ended.
struct GameEndInfo: Codable, Equatable {
    let winnerId: String?
    let winnerColor: PlayerColor?
    let resultType: ResultType
    let yourResult: GameResultOutcome
}

// MARK: - WebSocket Message Types

/// Types of messages sent to the server.
enum WebSocketMessageType: String, Codable {
    case join
    case move
    case rollbackRequest = "rollback_request"
    case rollbackResponse = "rollback_response"
    case drawOffer = "draw_offer"
    case drawResponse = "draw_response"
    case resign
    case ping
}

/// Types of messages received from the server.
enum WebSocketResponseType: String, Codable {
    case gameState = "game_state"
    case moveResult = "move_result"
    case opponentMove = "opponent_move"
    case rollbackRequested = "rollback_requested"
    case rollbackResult = "rollback_result"
    case timer
    case connectionStatus = "connection_status"
    case gameEnd = "game_end"
    case error
    case pong
}

// MARK: - WebSocket Message

/// A message sent via WebSocket.
struct WebSocketMessage: Codable {
    let type: String
    let payload: [String: AnyCodable]
    let timestamp: Date
    let messageId: String

    init(type: WebSocketMessageType, payload: [String: AnyCodable] = [:]) {
        self.type = type.rawValue
        self.payload = payload
        self.timestamp = Date()
        self.messageId = UUID().uuidString
    }
}

// MARK: - API Response Models

/// Standard API response wrapper.
struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let error: APIError?
}

/// API error information.
struct APIError: Codable, Equatable {
    let code: String
    let message: String
}

/// User registration request.
struct RegisterRequest: Codable {
    let deviceId: String
    let displayName: String
    let platform: String
    let appVersion: String

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case displayName = "display_name"
        case platform
        case appVersion = "app_version"
    }
}

/// User profile response.
struct UserProfileResponse: Codable {
    let id: String
    let displayName: String
    let stats: StatsResponse
    let createdAt: String
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case stats
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Stats in API response.
struct StatsResponse: Codable {
    let totalGames: Int
    let wins: Int
    let losses: Int
    let draws: Int

    enum CodingKeys: String, CodingKey {
        case totalGames = "total_games"
        case wins
        case losses
        case draws
    }
}

/// Match history response.
struct MatchHistoryResponse: Codable {
    let games: [GameSummaryResponse]
    let pagination: PaginationResponse
}

/// Game summary in match history.
struct GameSummaryResponse: Codable {
    let id: String
    let opponent: OpponentInfo
    let yourColor: String
    let result: String
    let resultType: String
    let totalMoves: Int
    let durationSeconds: Int
    let playedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case opponent
        case yourColor = "your_color"
        case result
        case resultType = "result_type"
        case totalMoves = "total_moves"
        case durationSeconds = "duration_seconds"
        case playedAt = "played_at"
    }
}

/// Pagination information.
struct PaginationResponse: Codable {
    let page: Int
    let pageSize: Int
    let totalPages: Int
    let totalCount: Int

    enum CodingKeys: String, CodingKey {
        case page
        case pageSize = "page_size"
        case totalPages = "total_pages"
        case totalCount = "total_count"
    }
}

/// Matchmaking join request.
struct MatchmakingJoinRequest: Codable {
    let settings: MatchmakingSettingsRequest

    struct MatchmakingSettingsRequest: Codable {
        let turnTimeout: Int
        let preferredColor: String?

        enum CodingKeys: String, CodingKey {
            case turnTimeout = "turn_timeout"
            case preferredColor = "preferred_color"
        }
    }
}

/// Matchmaking status response.
struct MatchmakingStatusResponse: Codable {
    let queueId: String?
    let position: Int?
    let estimatedWaitSeconds: Int?
    let status: String
    let gameId: String?
    let opponent: OpponentInfo?
    let yourColor: String?
    let websocketUrl: String?

    enum CodingKeys: String, CodingKey {
        case queueId = "queue_id"
        case position
        case estimatedWaitSeconds = "estimated_wait_seconds"
        case status
        case gameId = "game_id"
        case opponent
        case yourColor = "your_color"
        case websocketUrl = "websocket_url"
    }
}

// MARK: - AnyCodable

/// A type-erased Codable value for flexible JSON encoding/decoding.
struct AnyCodable: Codable, Equatable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            self.value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unable to decode AnyCodable"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Unable to encode AnyCodable"
                )
            )
        }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case is (NSNull, NSNull):
            return true
        case let (l as Bool, r as Bool):
            return l == r
        case let (l as Int, r as Int):
            return l == r
        case let (l as Double, r as Double):
            return l == r
        case let (l as String, r as String):
            return l == r
        default:
            return false
        }
    }
}
