//
//  MatchmakingViewModel.swift
//  ChineseChess
//
//  ViewModel for handling the matchmaking flow.
//

import Foundation
import Combine

/// The current state of matchmaking.
enum MatchmakingState: Equatable {
    /// Idle, not in queue
    case idle

    /// Searching for an opponent
    case searching(estimatedWaitSeconds: Int)

    /// Match found, connecting to game
    case matchFound(gameId: String, opponentName: String, assignedColor: PlayerColor)

    /// Error occurred
    case error(message: String)

    /// Cancelled by user
    case cancelled
}

/// ViewModel for the matchmaking screen.
@MainActor
final class MatchmakingViewModel: ObservableObject {

    // MARK: - Published Properties

    /// The current matchmaking state
    @Published private(set) var state: MatchmakingState = .idle

    /// The current position in queue
    @Published private(set) var queuePosition: Int = 0

    /// Estimated wait time in seconds
    @Published private(set) var estimatedWaitSeconds: Int = 30

    /// Time spent searching
    @Published private(set) var searchTimeSeconds: Int = 0

    /// The selected turn timeout
    @Published var selectedTimeout: TurnTimeout = .fiveMinutes

    // MARK: - Properties

    /// Network service for API calls
    private let networkService: NetworkServiceProtocol

    /// Timer for updating search time
    private var searchTimer: AnyCancellable?

    /// Timer for polling matchmaking status
    private var pollingTimer: AnyCancellable?

    /// Cancellables for subscriptions
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    /// Whether the user is currently searching
    var isSearching: Bool {
        if case .searching = state {
            return true
        }
        return false
    }

    /// Whether a match was found
    var matchFound: Bool {
        if case .matchFound = state {
            return true
        }
        return false
    }

    /// Formatted search time
    var formattedSearchTime: String {
        let minutes = searchTimeSeconds / 60
        let seconds = searchTimeSeconds % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    /// Formatted estimated wait time
    var formattedEstimatedWait: String {
        if estimatedWaitSeconds < 60 {
            return "~\(estimatedWaitSeconds)s"
        } else {
            let minutes = estimatedWaitSeconds / 60
            return "~\(minutes)m"
        }
    }

    // MARK: - Initialization

    init(networkService: NetworkServiceProtocol? = nil) {
        // Use provided service or create a new one
        self.networkService = networkService ?? NetworkService()
    }

    // MARK: - Public Methods

    /// Starts searching for an opponent.
    func startSearching() {
        guard state == .idle || state == .cancelled else { return }

        state = .searching(estimatedWaitSeconds: 30)
        searchTimeSeconds = 0
        estimatedWaitSeconds = 30

        // Start timers
        startSearchTimer()
        startPolling()

        // Join matchmaking queue
        Task {
            await joinQueue()
        }
    }

    /// Cancels the search.
    func cancelSearch() {
        state = .cancelled
        stopTimers()

        Task {
            await leaveQueue()
        }

        // Reset to idle after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.state = .idle
        }
    }

    // MARK: - Private Methods

    /// Joins the matchmaking queue.
    private func joinQueue() async {
        let settings = MatchmakingSettings(
            turnTimeout: selectedTimeout,
            preferredColor: nil
        )

        do {
            let status = try await networkService.joinMatchmaking(settings: settings)
            handleQueueStatus(status)
        } catch {
            state = .error(message: "Failed to join queue: \(error.localizedDescription)")
        }
    }

    /// Leaves the matchmaking queue.
    private func leaveQueue() async {
        do {
            try await networkService.leaveMatchmaking()
        } catch {
            DebugLog.error("Failed to leave queue", error)
        }
    }

    /// Polls the matchmaking status.
    private func pollStatus() async {
        guard isSearching else { return }

        do {
            let status = try await networkService.getMatchmakingStatus()
            handleQueueStatus(status)
        } catch {
            DebugLog.error("Failed to get status", error)
        }
    }

    /// Handles a queue status update.
    private func handleQueueStatus(_ status: QueueStatus) {
        switch status {
        case .idle:
            break

        case .waiting(let position, let estimatedWait):
            queuePosition = position
            estimatedWaitSeconds = estimatedWait
            state = .searching(estimatedWaitSeconds: estimatedWait)

        case .matched(let gameId, let opponentName, let assignedColor):
            stopTimers()
            state = .matchFound(
                gameId: gameId,
                opponentName: opponentName,
                assignedColor: assignedColor
            )

        case .left:
            state = .cancelled

        case .error(let message):
            stopTimers()
            state = .error(message: message)
        }
    }

    /// Starts the search time timer.
    private func startSearchTimer() {
        searchTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.searchTimeSeconds += 1
            }
    }

    /// Starts polling for matchmaking status.
    private func startPolling() {
        pollingTimer = Timer.publish(every: 2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.pollStatus()
                }
            }
    }

    /// Stops all timers.
    private func stopTimers() {
        searchTimer?.cancel()
        searchTimer = nil
        pollingTimer?.cancel()
        pollingTimer = nil
    }

    deinit {
        searchTimer?.cancel()
        pollingTimer?.cancel()
    }
}
