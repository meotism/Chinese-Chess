//
//  GameReplayView.swift
//  ChineseChess
//
//  View for replaying past games.
//

import SwiftUI
import Combine

/// ViewModel for game replay functionality.
@MainActor
final class ReplayViewModel: ObservableObject {

    // MARK: - Published Properties

    /// The current game state being displayed
    @Published private(set) var currentState: GameState

    /// The current move index (0 = initial position)
    @Published private(set) var currentMoveIndex: Int = 0

    /// All moves in the game
    @Published private(set) var moves: [Move] = []

    /// Whether auto-play is active
    @Published var isAutoPlaying = false

    /// Playback speed (moves per second)
    @Published var playbackSpeed: Double = 1.0

    /// Whether data is loading
    @Published private(set) var isLoading = true

    /// Error message if loading failed
    @Published private(set) var errorMessage: String?

    // MARK: - Properties

    /// The game ID being replayed
    let gameId: String

    /// The initial game state
    private let initialState: GameState

    /// Timer for auto-play
    private var autoPlayTimer: AnyCancellable?

    /// Network service for loading moves
    private let networkService: NetworkServiceProtocol

    /// Database service for local data
    private let databaseService: DatabaseServiceProtocol

    // MARK: - Computed Properties

    /// Total number of moves
    var totalMoves: Int {
        moves.count
    }

    /// Whether at the beginning
    var isAtStart: Bool {
        currentMoveIndex == 0
    }

    /// Whether at the end
    var isAtEnd: Bool {
        currentMoveIndex == totalMoves
    }

    /// The current move being displayed (nil if at initial position)
    var currentMove: Move? {
        guard currentMoveIndex > 0 && currentMoveIndex <= moves.count else { return nil }
        return moves[currentMoveIndex - 1]
    }

    /// Progress through the game (0.0 to 1.0)
    var progress: Double {
        guard totalMoves > 0 else { return 0 }
        return Double(currentMoveIndex) / Double(totalMoves)
    }

    // MARK: - Initialization

    init(gameId: String, networkService: NetworkServiceProtocol? = nil, databaseService: DatabaseServiceProtocol? = nil) {
        self.gameId = gameId
        self.networkService = networkService ?? NetworkService()
        self.databaseService = databaseService ?? DatabaseService()
        self.initialState = GameState.initial()
        self.currentState = initialState
    }

    // MARK: - Public Methods

    /// Loads the game moves.
    func loadMoves() async {
        isLoading = true
        errorMessage = nil

        do {
            // Try loading from local database first
            let localMoves = try await databaseService.getMoves(for: gameId)

            if !localMoves.isEmpty {
                moves = localMoves.sorted { $0.moveNumber < $1.moveNumber }
            } else {
                // Fetch from server
                let serverMoves = try await networkService.fetchGameMoves(gameId: gameId)
                moves = serverMoves.sorted { $0.moveNumber < $1.moveNumber }

                // Save to local database
                try await databaseService.saveMoves(moves, for: gameId)
            }
        } catch {
            errorMessage = "Failed to load game: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Goes to the next move.
    func nextMove() {
        guard !isAtEnd else { return }
        currentMoveIndex += 1
        rebuildState()
    }

    /// Goes to the previous move.
    func previousMove() {
        guard !isAtStart else { return }
        currentMoveIndex -= 1
        rebuildState()
    }

    /// Goes to the first move (initial position).
    func goToStart() {
        currentMoveIndex = 0
        rebuildState()
    }

    /// Goes to the last move (final position).
    func goToEnd() {
        currentMoveIndex = totalMoves
        rebuildState()
    }

    /// Goes to a specific move index.
    func goToMove(_ index: Int) {
        guard index >= 0 && index <= totalMoves else { return }
        currentMoveIndex = index
        rebuildState()
    }

    /// Toggles auto-play.
    func toggleAutoPlay() {
        isAutoPlaying.toggle()

        if isAutoPlaying {
            startAutoPlay()
        } else {
            stopAutoPlay()
        }
    }

    // MARK: - Private Methods

    /// Rebuilds the game state up to the current move index.
    private func rebuildState() {
        var state = initialState

        for i in 0..<currentMoveIndex {
            guard i < moves.count else { break }
            let move = moves[i]

            // Apply the move to the state
            guard let piece = state.piece(at: move.from) else { continue }
            let capturedPiece = state.piece(at: move.to)

            let pendingMove = PendingMove(
                piece: piece,
                from: move.from,
                to: move.to,
                capturedPiece: capturedPiece
            )

            state = state.applying(pendingMove)
        }

        currentState = state
    }

    /// Starts auto-play.
    private func startAutoPlay() {
        let interval = 1.0 / playbackSpeed

        autoPlayTimer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }

                if self.isAtEnd {
                    self.stopAutoPlay()
                    self.isAutoPlaying = false
                } else {
                    self.nextMove()
                }
            }
    }

    /// Stops auto-play.
    private func stopAutoPlay() {
        autoPlayTimer?.cancel()
        autoPlayTimer = nil
    }

    deinit {
        autoPlayTimer?.cancel()
    }
}

/// The game replay view for stepping through past games.
struct GameReplayView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @StateObject private var viewModel: ReplayViewModel

    /// Whether to show the move list
    @State private var showMoveList = false

    // MARK: - Initialization

    init(gameId: String) {
        _viewModel = StateObject(wrappedValue: ReplayViewModel(gameId: gameId))
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.errorMessage {
                errorView(message: error)
            } else {
                replayContent
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle("Game Replay")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showMoveList.toggle()
                } label: {
                    Image(systemName: "list.bullet")
                }
            }
        }
        .sheet(isPresented: $showMoveList) {
            moveListSheet
        }
        .task {
            await viewModel.loadMoves()
        }
    }

    // MARK: - Content Views

    private var replayContent: some View {
        VStack(spacing: 16) {
            // Move info header
            moveInfoHeader

            // Board
            BoardView(
                gameState: viewModel.currentState,
                lastMove: viewModel.currentMove
            )
            .padding(.horizontal)

            Spacer()

            // Progress bar
            progressBar

            // Playback controls
            playbackControls
        }
        .padding(.vertical)
    }

    private var moveInfoHeader: some View {
        HStack {
            // Current move info
            if let move = viewModel.currentMove {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Move \(move.moveNumber)")
                        .font(.headline)

                    Text(move.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Initial Position")
                        .font(.headline)

                    Text("Starting position before any moves")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Turn indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.currentState.currentTurn == .red ? Color.red : Color.black)
                    .frame(width: 12, height: 12)

                Text("\(viewModel.currentState.currentTurn.rawValue.capitalized)'s Turn")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
    }

    private var progressBar: some View {
        VStack(spacing: 8) {
            // Slider
            Slider(
                value: Binding(
                    get: { Double(viewModel.currentMoveIndex) },
                    set: { viewModel.goToMove(Int($0)) }
                ),
                in: 0...Double(max(1, viewModel.totalMoves)),
                step: 1
            )
            .tint(.red)
            .padding(.horizontal)

            // Labels
            HStack {
                Text("Move \(viewModel.currentMoveIndex)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("of \(viewModel.totalMoves)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
        }
    }

    private var playbackControls: some View {
        HStack(spacing: 20) {
            // Go to start
            Button(action: viewModel.goToStart) {
                Image(systemName: "backward.end.fill")
                    .font(.title2)
            }
            .disabled(viewModel.isAtStart)

            // Previous move
            Button(action: viewModel.previousMove) {
                Image(systemName: "backward.fill")
                    .font(.title2)
            }
            .disabled(viewModel.isAtStart)

            // Play/Pause
            Button(action: viewModel.toggleAutoPlay) {
                Image(systemName: viewModel.isAutoPlaying ? "pause.fill" : "play.fill")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(viewModel.isAtEnd ? Color.gray : Color.red)
                    .clipShape(Circle())
            }
            .disabled(viewModel.isAtEnd && !viewModel.isAutoPlaying)

            // Next move
            Button(action: viewModel.nextMove) {
                Image(systemName: "forward.fill")
                    .font(.title2)
            }
            .disabled(viewModel.isAtEnd)

            // Go to end
            Button(action: viewModel.goToEnd) {
                Image(systemName: "forward.end.fill")
                    .font(.title2)
            }
            .disabled(viewModel.isAtEnd)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading game...")
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Failed to Load Game")
                .font(.title2)
                .fontWeight(.semibold)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Try Again") {
                Task {
                    await viewModel.loadMoves()
                }
            }
            .buttonStyle(.bordered)

            Spacer()
        }
    }

    // MARK: - Move List Sheet

    private var moveListSheet: some View {
        NavigationStack {
            List {
                // Initial position
                Button {
                    viewModel.goToStart()
                    showMoveList = false
                } label: {
                    HStack {
                        Text("Initial Position")
                            .foregroundColor(.primary)
                        Spacer()
                        if viewModel.currentMoveIndex == 0 {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }

                // All moves
                ForEach(Array(viewModel.moves.enumerated()), id: \.element.id) { index, move in
                    Button {
                        viewModel.goToMove(index + 1)
                        showMoveList = false
                    } label: {
                        HStack {
                            Text("\(move.moveNumber).")
                                .foregroundColor(.secondary)
                                .frame(width: 30, alignment: .leading)

                            Text(move.notation)
                                .foregroundColor(.primary)

                            if move.capturedPiece != nil {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }

                            if move.isCheck {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                            }

                            Spacer()

                            if viewModel.currentMoveIndex == index + 1 {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Move List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showMoveList = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Preview

#Preview("Game Replay") {
    NavigationStack {
        GameReplayView(gameId: "test-game-123")
    }
}
