//
//  HomeView.swift
//  ChineseChess
//
//  The main menu view of the application.
//

import SwiftUI

/// The main menu view displaying navigation options and user stats.
struct HomeView: View {

    // MARK: - Environment

    @EnvironmentObject var appState: AppState

    // MARK: - Binding

    @Binding var selectedTab: Tab

    // MARK: - Body

    var body: some View {
        VStack(spacing: 24) {
            // Header with profile
            headerSection

            Spacer()

            // Logo and title
            logoSection

            Spacer()

            // Menu buttons
            menuButtons

            Spacer()

            // Stats summary
            statsSection
        }
        .padding()
        .background(Color(.systemBackground))
        .navigationTitle("")
        .navigationBarHidden(true)
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack {
            Spacer()

            // Profile button
            NavigationLink(destination: Text("Profile")) {
                Image(systemName: "person.circle")
                    .font(.title)
                    .foregroundColor(.primary)
            }
        }
    }

    private var logoSection: some View {
        VStack(spacing: 12) {
            // Chess board icon
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
        }
    }

    private var menuButtons: some View {
        VStack(spacing: 16) {
            // Play Online button
            MenuButton(
                title: "Play Online",
                icon: "globe",
                color: .red
            ) {
                selectedTab = .matchmaking
            }

            // Practice Mode button
            MenuButton(
                title: "Practice Mode",
                icon: "brain",
                color: .orange
            ) {
                // TODO: Navigate to practice mode
            }

            // Match History button
            MenuButton(
                title: "Match History",
                icon: "clock.arrow.circlepath",
                color: .blue
            ) {
                selectedTab = .history
            }

            // Settings button
            MenuButton(
                title: "Settings",
                icon: "gearshape",
                color: .gray
            ) {
                selectedTab = .settings
            }
        }
        .padding(.horizontal)
    }

    private var statsSection: some View {
        Group {
            if let user = appState.currentUser {
                let stats = user.stats
                HStack {
                    StatItem(value: stats.wins, label: "Wins", color: .green)
                    Divider().frame(height: 40)
                    StatItem(value: stats.losses, label: "Losses", color: .red)
                    Divider().frame(height: 40)
                    StatItem(value: stats.draws, label: "Draws", color: .gray)
                    Divider().frame(height: 40)
                    StatItem(
                        value: Int(stats.winPercentage),
                        label: "Win %",
                        color: .blue,
                        isPercentage: true
                    )
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Menu Button

/// A styled button for the main menu.
struct MenuButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 30)

                Text(title)
                    .font(.headline)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .foregroundColor(.white)
            .background(color)
            .cornerRadius(12)
        }
    }
}

// MARK: - Stat Item

/// A single statistic display item.
struct StatItem: View {
    let value: Int
    let label: String
    let color: Color
    var isPercentage: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            Text(isPercentage ? "\(value)%" : "\(value)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HomeView(selectedTab: .constant(.home))
            .environmentObject(AppState())
    }
}
