//
//  MatchHistoryView.swift
//  ChineseChess
//
//  View for displaying match history.
//

import SwiftUI

/// The match history screen showing past games.
struct MatchHistoryView: View {

    // MARK: - Environment

    @EnvironmentObject var appState: AppState

    // MARK: - State

    @StateObject private var viewModel = HistoryViewModel()

    /// The selected game for viewing replay
    @State private var selectedGame: MatchHistoryEntry?

    /// Whether to show the replay view
    @State private var showReplay = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Stats summary
            if !viewModel.isEmpty {
                statsHeader
            }

            // Filter bar
            filterBar

            // Content
            if viewModel.isEmpty {
                emptyStateView
            } else if let error = viewModel.errorMessage {
                errorView(message: error)
            } else {
                historyList
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Match History")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $viewModel.searchText, prompt: "Search opponents")
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            await viewModel.loadHistory()
        }
        .sheet(item: $selectedGame) { game in
            NavigationStack {
                GameReplayView(gameId: game.id)
            }
        }
    }

    // MARK: - Sections

    private var statsHeader: some View {
        HStack(spacing: 0) {
            StatCard(
                title: "Games",
                value: "\(viewModel.totalGames)",
                color: .blue
            )

            StatCard(
                title: "Wins",
                value: "\(viewModel.totalWins)",
                color: .green
            )

            StatCard(
                title: "Losses",
                value: "\(viewModel.totalLosses)",
                color: .red
            )

            StatCard(
                title: "Win %",
                value: String(format: "%.0f%%", viewModel.winPercentage),
                color: .orange
            )
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(HistoryFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        title: filter.rawValue,
                        count: countForFilter(filter),
                        isSelected: viewModel.selectedFilter == filter
                    ) {
                        viewModel.selectedFilter = filter
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }

    private var historyList: some View {
        List {
            ForEach(viewModel.filteredEntries) { entry in
                MatchHistoryRow(entry: entry)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedGame = entry
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            // Load more trigger
            if viewModel.hasMorePages && !viewModel.filteredEntries.isEmpty {
                HStack {
                    Spacer()
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Button("Load More") {
                            Task {
                                await viewModel.loadNextPage()
                            }
                        }
                        .foregroundColor(.blue)
                    }
                    Spacer()
                }
                .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
            }
        }
        .listStyle(.plain)
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Games Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Play your first game to see your match history here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Unable to Load History")
                .font(.title2)
                .fontWeight(.semibold)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Try Again") {
                Task {
                    await viewModel.loadHistory()
                }
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func countForFilter(_ filter: HistoryFilter) -> Int {
        switch filter {
        case .all: return viewModel.totalGames
        case .wins: return viewModel.totalWins
        case .losses: return viewModel.totalLosses
        case .draws: return viewModel.totalDraws
        }
    }
}

// MARK: - Stat Card

/// A small card displaying a statistic.
struct StatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Filter Chip

/// A chip button for filtering history.
struct FilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)

                Text("\(count)")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.white.opacity(0.3) : Color(.tertiarySystemFill))
                    .cornerRadius(8)
            }
            .font(.subheadline)
            .fontWeight(isSelected ? .semibold : .regular)
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.secondarySystemBackground))
            .cornerRadius(20)
        }
    }
}

// MARK: - Match History Row

/// A row displaying a single match history entry.
struct MatchHistoryRow: View {
    let entry: MatchHistoryEntry

    var body: some View {
        HStack(spacing: 12) {
            // Result indicator
            resultIndicator

            // Match details
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.opponentName)
                    .font(.headline)

                HStack(spacing: 8) {
                    // Color played
                    HStack(spacing: 4) {
                        Circle()
                            .fill(entry.myColor == .red ? Color.red : Color.black)
                            .frame(width: 10, height: 10)
                        Text(entry.myColor.rawValue.capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("•")
                        .foregroundColor(.secondary)

                    // Result type
                    Text(entry.resultType.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(entry.formattedDate)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Game stats
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left.and.right")
                        .font(.caption)
                    Text("\(entry.totalMoves)")
                        .font(.caption)
                }
                .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text(entry.formattedDuration)
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }

            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }

    private var resultIndicator: some View {
        ZStack {
            Circle()
                .fill(resultColor.opacity(0.2))
                .frame(width: 44, height: 44)

            Image(systemName: resultIcon)
                .font(.title3)
                .foregroundColor(resultColor)
        }
    }

    private var resultColor: Color {
        switch entry.result {
        case .win: return .green
        case .loss: return .red
        case .draw: return .orange
        }
    }

    private var resultIcon: String {
        switch entry.result {
        case .win: return "trophy.fill"
        case .loss: return "xmark"
        case .draw: return "equal"
        }
    }
}

// MARK: - Preview

#Preview("Match History") {
    NavigationStack {
        MatchHistoryView()
            .environmentObject(AppState())
    }
}
