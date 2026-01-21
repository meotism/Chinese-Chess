//
//  HistoryViewModel.swift
//  ChineseChess
//
//  ViewModel for loading and displaying match history.
//

import Foundation
import Combine

/// Filter options for match history.
enum HistoryFilter: String, CaseIterable {
    case all = "All"
    case wins = "Wins"
    case losses = "Losses"
    case draws = "Draws"

    /// The corresponding game result outcome.
    var resultOutcome: GameResultOutcome? {
        switch self {
        case .all: return nil
        case .wins: return .win
        case .losses: return .loss
        case .draws: return .draw
        }
    }
}

/// A match history entry for display.
struct MatchHistoryEntry: Identifiable, Equatable {
    let id: String
    let opponentName: String
    let opponentId: String
    let myColor: PlayerColor
    let result: GameResultOutcome
    let resultType: ResultType
    let totalMoves: Int
    let durationSeconds: Int
    let playedAt: Date

    /// Formatted date string.
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: playedAt)
    }

    /// Formatted duration string.
    var formattedDuration: String {
        let minutes = durationSeconds / 60
        let seconds = durationSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Creates a history entry from a Game object.
    static func from(game: Game, currentPlayerId: String, opponentName: String) -> MatchHistoryEntry? {
        guard let myColor = game.playerColor(for: currentPlayerId),
              let resultType = game.resultType else {
            return nil
        }

        let result: GameResultOutcome
        if game.isDraw {
            result = .draw
        } else if game.didWin(playerId: currentPlayerId) {
            result = .win
        } else {
            result = .loss
        }

        return MatchHistoryEntry(
            id: game.id,
            opponentName: opponentName,
            opponentId: game.opponentId(for: currentPlayerId) ?? "",
            myColor: myColor,
            result: result,
            resultType: resultType,
            totalMoves: game.totalMoves,
            durationSeconds: game.durationSeconds ?? 0,
            playedAt: game.createdAt
        )
    }
}

/// ViewModel for the match history screen.
@MainActor
final class HistoryViewModel: ObservableObject {

    // MARK: - Published Properties

    /// All history entries (unfiltered)
    @Published private(set) var allEntries: [MatchHistoryEntry] = []

    /// Filtered history entries based on current filter
    @Published private(set) var filteredEntries: [MatchHistoryEntry] = []

    /// The current filter selection
    @Published var selectedFilter: HistoryFilter = .all {
        didSet {
            applyFilter()
        }
    }

    /// Search text for filtering by opponent name
    @Published var searchText: String = "" {
        didSet {
            applyFilter()
        }
    }

    /// Whether data is currently loading
    @Published private(set) var isLoading = false

    /// Error message if loading failed
    @Published private(set) var errorMessage: String?

    /// Whether there are more pages to load
    @Published private(set) var hasMorePages = true

    // MARK: - Properties

    /// Database service for local data
    private let databaseService: DatabaseServiceProtocol

    /// Network service for server data
    private let networkService: NetworkServiceProtocol

    /// Current page for pagination
    private var currentPage = 1

    /// Page size for pagination
    private let pageSize = 20

    // MARK: - Computed Properties

    /// Total games played
    var totalGames: Int {
        allEntries.count
    }

    /// Total wins
    var totalWins: Int {
        allEntries.filter { $0.result == .win }.count
    }

    /// Total losses
    var totalLosses: Int {
        allEntries.filter { $0.result == .loss }.count
    }

    /// Total draws
    var totalDraws: Int {
        allEntries.filter { $0.result == .draw }.count
    }

    /// Win percentage
    var winPercentage: Double {
        guard totalGames > 0 else { return 0 }
        return Double(totalWins) / Double(totalGames) * 100
    }

    /// Whether the history is empty
    var isEmpty: Bool {
        allEntries.isEmpty && !isLoading
    }

    // MARK: - Initialization

    init(databaseService: DatabaseServiceProtocol? = nil, networkService: NetworkServiceProtocol? = nil) {
        self.databaseService = databaseService ?? DatabaseService()
        self.networkService = networkService ?? NetworkService()
    }

    // MARK: - Public Methods

    /// Loads match history from local database and server.
    func loadHistory() async {
        isLoading = true
        errorMessage = nil
        currentPage = 1

        do {
            // First load from local database
            let localGames = try await databaseService.getGameHistory(limit: pageSize, offset: 0)
            let entries = await convertGamesToEntries(localGames)
            allEntries = entries
            applyFilter()

            // Then fetch from server to get latest
            await refreshFromServer()

            hasMorePages = entries.count >= pageSize
        } catch {
            errorMessage = "Failed to load history: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Loads the next page of history.
    func loadNextPage() async {
        guard hasMorePages && !isLoading else { return }

        isLoading = true
        currentPage += 1

        do {
            let offset = (currentPage - 1) * pageSize
            let moreGames = try await databaseService.getGameHistory(limit: pageSize, offset: offset)
            let entries = await convertGamesToEntries(moreGames)

            allEntries.append(contentsOf: entries)
            applyFilter()

            hasMorePages = entries.count >= pageSize
        } catch {
            DebugLog.error("Failed to load more history", error)
            currentPage -= 1
        }

        isLoading = false
    }

    /// Refreshes history from the server.
    func refresh() async {
        await loadHistory()
    }

    // MARK: - Private Methods

    /// Converts Game objects to MatchHistoryEntry objects.
    private func convertGamesToEntries(_ games: [Game]) async -> [MatchHistoryEntry] {
        // TODO: Get current player ID from auth service
        let currentPlayerId = "current_device_id"

        var entries: [MatchHistoryEntry] = []

        for game in games {
            // TODO: Fetch opponent name from database or cache
            let opponentId = game.opponentId(for: currentPlayerId) ?? "Unknown"
            let opponentName = "Player_\(opponentId.prefix(4))"

            if let entry = MatchHistoryEntry.from(
                game: game,
                currentPlayerId: currentPlayerId,
                opponentName: opponentName
            ) {
                entries.append(entry)
            }
        }

        return entries
    }

    /// Refreshes data from the server.
    private func refreshFromServer() async {
        do {
            let serverGames = try await networkService.fetchMatchHistory(page: 1, pageSize: pageSize)
            // Save to local database
            for game in serverGames {
                try await databaseService.saveGame(game)
            }
        } catch {
            DebugLog.error("Failed to refresh from server", error)
        }
    }

    /// Applies the current filter and search text.
    private func applyFilter() {
        var filtered = allEntries

        // Apply result filter
        if let resultOutcome = selectedFilter.resultOutcome {
            filtered = filtered.filter { $0.result == resultOutcome }
        }

        // Apply search text
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.opponentName.localizedCaseInsensitiveContains(searchText)
            }
        }

        filteredEntries = filtered
    }
}
