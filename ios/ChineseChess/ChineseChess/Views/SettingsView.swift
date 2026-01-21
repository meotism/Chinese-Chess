//
//  SettingsView.swift
//  ChineseChess
//
//  Settings screen for configuring app preferences.
//

import SwiftUI

/// View for displaying and modifying app settings.
struct SettingsView: View {

    // MARK: - Environment

    @EnvironmentObject var appState: AppState

    // MARK: - State

    @State private var settings = GameSettings.load()
    @State private var showingAbout = false
    @State private var showingResetConfirmation = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // Audio & Haptics Section
                audioHapticsSection

                // Game Settings Section
                gameSettingsSection

                // Display Section
                displaySection

                // Account Section
                accountSection

                // About Section
                aboutSection
            }
            .navigationTitle("Settings")
            .onChange(of: settings) { _, newSettings in
                newSettings.save()
                updateAudioService(newSettings)
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            .alert("Reset Settings", isPresented: $showingResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    resetToDefaults()
                }
            } message: {
                Text("This will reset all settings to their default values.")
            }
        }
    }

    // MARK: - Sections

    private var audioHapticsSection: some View {
        Section {
            Toggle(isOn: $settings.soundEnabled) {
                Label("Sound Effects", systemImage: "speaker.wave.2")
            }
            .tint(.red)

            Toggle(isOn: $settings.hapticsEnabled) {
                Label("Haptic Feedback", systemImage: "waveform")
            }
            .tint(.red)
        } header: {
            Text("Audio & Haptics")
        } footer: {
            Text("Sound effects play during moves and game events. Haptic feedback provides tactile responses.")
        }
    }

    private var gameSettingsSection: some View {
        Section {
            Picker(selection: $settings.turnTimeout) {
                ForEach(TurnTimeout.allCases) { timeout in
                    Text(timeout.displayName).tag(timeout)
                }
            } label: {
                Label("Default Turn Time", systemImage: "timer")
            }

            Toggle(isOn: $settings.showMoveHints) {
                Label("Show Move Hints", systemImage: "questionmark.circle")
            }
            .tint(.red)

            Toggle(isOn: $settings.autoConfirmMoves) {
                Label("Auto-Confirm Moves", systemImage: "checkmark.circle")
            }
            .tint(.red)
        } header: {
            Text("Game Settings")
        } footer: {
            Text("Turn time is the default time limit for online games. Move hints highlight valid moves when selecting a piece.")
        }
    }

    private var displaySection: some View {
        Section {
            NavigationLink {
                ThemeSettingsView()
            } label: {
                Label("Theme", systemImage: "paintbrush")
            }

            NavigationLink {
                BoardStyleView()
            } label: {
                Label("Board Style", systemImage: "square.grid.3x3")
            }

            NavigationLink {
                PieceStyleView()
            } label: {
                Label("Piece Style", systemImage: "circle.fill")
            }
        } header: {
            Text("Display")
        }
    }

    private var accountSection: some View {
        Section {
            if let user = appState.currentUser {
                HStack {
                    Label("Display Name", systemImage: "person")
                    Spacer()
                    Text(user.displayName)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Label("Device ID", systemImage: "iphone")
                    Spacer()
                    Text(String(user.id.prefix(8)) + "...")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }

            NavigationLink {
                EditProfileView()
            } label: {
                Label("Edit Profile", systemImage: "pencil")
            }
        } header: {
            Text("Account")
        }
    }

    private var aboutSection: some View {
        Section {
            Button {
                showingAbout = true
            } label: {
                Label("About Chinese Chess", systemImage: "info.circle")
            }

            NavigationLink {
                HowToPlayView()
            } label: {
                Label("How to Play", systemImage: "book")
            }

            Link(destination: URL(string: "https://xiangqi-app.com/privacy")!) {
                Label("Privacy Policy", systemImage: "hand.raised")
            }

            Link(destination: URL(string: "https://xiangqi-app.com/terms")!) {
                Label("Terms of Service", systemImage: "doc.text")
            }

            HStack {
                Label("Version", systemImage: "number")
                Spacer()
                Text(appVersion)
                    .foregroundColor(.secondary)
            }

            Button(role: .destructive) {
                showingResetConfirmation = true
            } label: {
                Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
            }
        } header: {
            Text("About")
        }
    }

    // MARK: - Computed Properties

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: - Methods

    private func updateAudioService(_ settings: GameSettings) {
        AudioService.shared.isSoundEnabled = settings.soundEnabled
        AudioService.shared.isHapticsEnabled = settings.hapticsEnabled
    }

    private func resetToDefaults() {
        settings = .default
        settings.save()
        updateAudioService(settings)
    }
}

// MARK: - Theme Settings View

struct ThemeSettingsView: View {
    @AppStorage("app.theme") private var selectedTheme = "system"

    var body: some View {
        Form {
            Section {
                ForEach(["system", "light", "dark"], id: \.self) { theme in
                    Button {
                        selectedTheme = theme
                    } label: {
                        HStack {
                            Label(theme.capitalized, systemImage: themeIcon(for: theme))
                            Spacer()
                            if selectedTheme == theme {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            } header: {
                Text("App Theme")
            } footer: {
                Text("System uses your device's appearance settings.")
            }
        }
        .navigationTitle("Theme")
    }

    private func themeIcon(for theme: String) -> String {
        switch theme {
        case "light": return "sun.max"
        case "dark": return "moon.fill"
        default: return "circle.lefthalf.filled"
        }
    }
}

// MARK: - Board Style View

struct BoardStyleView: View {
    @AppStorage("board.style") private var selectedStyle = "classic"

    let styles = [
        ("classic", "Classic Wood"),
        ("modern", "Modern"),
        ("paper", "Paper"),
        ("marble", "Marble")
    ]

    var body: some View {
        Form {
            Section {
                ForEach(styles, id: \.0) { style in
                    Button {
                        selectedStyle = style.0
                    } label: {
                        HStack {
                            Text(style.1)
                            Spacer()
                            if selectedStyle == style.0 {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            } header: {
                Text("Board Style")
            }
        }
        .navigationTitle("Board Style")
    }
}

// MARK: - Piece Style View

struct PieceStyleView: View {
    @AppStorage("piece.style") private var selectedStyle = "traditional"

    let styles = [
        ("traditional", "Traditional Chinese"),
        ("simplified", "Simplified"),
        ("western", "Western Icons"),
        ("symbolic", "Symbolic")
    ]

    var body: some View {
        Form {
            Section {
                ForEach(styles, id: \.0) { style in
                    Button {
                        selectedStyle = style.0
                    } label: {
                        HStack {
                            Text(style.1)
                            Spacer()
                            if selectedStyle == style.0 {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            } header: {
                Text("Piece Style")
            }
        }
        .navigationTitle("Piece Style")
    }
}

// MARK: - Edit Profile View

struct EditProfileView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                TextField("Display Name", text: $displayName)
                    .autocapitalization(.words)
                    .disableAutocorrection(true)
            } header: {
                Text("Display Name")
            } footer: {
                Text("Your display name is shown to other players. It must be 2-20 characters.")
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Edit Profile")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveProfile()
                }
                .disabled(displayName.isEmpty || isLoading)
            }
        }
        .onAppear {
            displayName = appState.currentUser?.displayName ?? ""
        }
    }

    private func saveProfile() {
        guard displayName.count >= 2 && displayName.count <= 20 else {
            errorMessage = "Display name must be 2-20 characters"
            return
        }

        isLoading = true
        errorMessage = nil

        // TODO: Call API to update display name
        // For now, just dismiss
        dismiss()
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // App icon and name
                    VStack(spacing: 12) {
                        Image(systemName: "checkerboard.rectangle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .foregroundColor(.red)

                        Text("Chinese Chess")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("Xiangqi")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 32)

                    // Description
                    VStack(alignment: .leading, spacing: 16) {
                        Text("About the Game")
                            .font(.headline)

                        Text("""
                        Chinese Chess (Xiangqi) is one of the most popular board games in the world, with origins dating back over 2,000 years. It is a strategy board game for two players, representing a battle between two armies with the goal of capturing the enemy's general (king).

                        The game is played on a board with 9 columns and 10 rows, divided by a river in the middle. Each player controls 16 pieces: 1 general, 2 advisors, 2 elephants, 2 horses, 2 chariots, 2 cannons, and 5 soldiers.
                        """)
                        .font(.body)
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    // Credits
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Credits")
                            .font(.headline)

                        Text("Developed with SwiftUI and Go")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    Spacer()
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - How to Play View

struct HowToPlayView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Objective
                ruleSection(
                    title: "Objective",
                    content: "Capture the opponent's General (King) by putting it in checkmate, a position where it cannot escape capture."
                )

                // The Board
                ruleSection(
                    title: "The Board",
                    content: "The game is played on a 9x10 board with a river in the middle. The palace is a 3x3 area where the General and Advisors must stay."
                )

                // Pieces
                VStack(alignment: .leading, spacing: 12) {
                    Text("The Pieces")
                        .font(.headline)

                    pieceDescription("General (King)", "Moves one point horizontally or vertically. Must stay within the palace.")
                    pieceDescription("Advisor", "Moves one point diagonally. Must stay within the palace.")
                    pieceDescription("Elephant", "Moves exactly two points diagonally. Cannot cross the river. Can be blocked.")
                    pieceDescription("Horse", "Moves one point horizontally/vertically, then one point diagonally. Can be blocked.")
                    pieceDescription("Chariot (Rook)", "Moves any number of points horizontally or vertically.")
                    pieceDescription("Cannon", "Moves like a Chariot but captures by jumping over exactly one piece.")
                    pieceDescription("Soldier (Pawn)", "Moves one point forward. After crossing the river, can also move horizontally.")
                }
                .padding(.horizontal)

                // Special Rules
                ruleSection(
                    title: "Special Rules",
                    content: """
                    - Flying General: The two Generals cannot face each other directly on the same file without any piece between them.
                    - Perpetual Check: A player cannot give perpetual check (checking indefinitely with the same moves).
                    - Stalemate: Unlike international chess, stalemate results in a loss for the stalemated player.
                    """
                )
            }
            .padding()
        }
        .navigationTitle("How to Play")
    }

    private func ruleSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }

    private func pieceDescription(_ name: String, _ description: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.subheadline)
                .fontWeight(.medium)

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
