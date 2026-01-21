//
//  ConnectionStatusView.swift
//  ChineseChess
//
//  A view component that displays the current connection status.
//

import SwiftUI

/// A view that displays the current connection status with an indicator.
struct ConnectionStatusView: View {

    // MARK: - Properties

    let state: ConnectionState

    /// Whether to show detailed text
    var showText: Bool = true

    /// Whether to show in compact mode
    var isCompact: Bool = false

    // MARK: - Body

    var body: some View {
        HStack(spacing: 8) {
            // Status indicator
            Circle()
                .fill(indicatorColor)
                .frame(width: isCompact ? 8 : 10, height: isCompact ? 8 : 10)
                .overlay(
                    Circle()
                        .stroke(indicatorColor.opacity(0.3), lineWidth: isCompact ? 2 : 3)
                        .scaleEffect(isPulsing ? 1.5 : 1.0)
                        .opacity(isPulsing ? 0 : 1)
                        .animation(
                            isPulsing ? Animation.easeOut(duration: 1).repeatForever(autoreverses: false) : .default,
                            value: isPulsing
                        )
                )

            // Status text
            if showText {
                Text(statusText)
                    .font(isCompact ? .caption : .subheadline)
                    .foregroundColor(textColor)
            }
        }
        .padding(.horizontal, isCompact ? 8 : 12)
        .padding(.vertical, isCompact ? 4 : 6)
        .background(backgroundColor)
        .cornerRadius(isCompact ? 8 : 12)
    }

    // MARK: - Computed Properties

    private var indicatorColor: Color {
        switch state {
        case .connected:
            return .green
        case .connecting, .reconnecting:
            return .orange
        case .disconnected:
            return .gray
        case .failed:
            return .red
        }
    }

    private var textColor: Color {
        switch state {
        case .connected:
            return .green
        case .connecting, .reconnecting:
            return .orange
        case .disconnected:
            return .gray
        case .failed:
            return .red
        }
    }

    private var backgroundColor: Color {
        switch state {
        case .connected:
            return .green.opacity(0.1)
        case .connecting, .reconnecting:
            return .orange.opacity(0.1)
        case .disconnected:
            return .gray.opacity(0.1)
        case .failed:
            return .red.opacity(0.1)
        }
    }

    private var statusText: String {
        switch state {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting..."
        case .reconnecting(let attempt):
            return "Reconnecting (\(attempt))..."
        case .disconnected:
            return "Disconnected"
        case .failed(let error):
            return "Failed: \(error)"
        }
    }

    private var isPulsing: Bool {
        switch state {
        case .connecting, .reconnecting:
            return true
        default:
            return false
        }
    }
}

/// A banner view that shows at the top of the screen when connection issues occur.
struct ConnectionBannerView: View {

    // MARK: - Properties

    let state: ConnectionState
    var onRetry: (() -> Void)?

    // MARK: - State

    @State private var isVisible = false

    // MARK: - Body

    var body: some View {
        Group {
            if shouldShowBanner {
                HStack {
                    Image(systemName: bannerIcon)
                        .foregroundColor(.white)

                    Text(bannerText)
                        .font(.subheadline)
                        .foregroundColor(.white)

                    Spacer()

                    if showRetryButton {
                        Button("Retry") {
                            onRetry?()
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                    }
                }
                .padding()
                .background(bannerColor)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: shouldShowBanner)
    }

    // MARK: - Computed Properties

    private var shouldShowBanner: Bool {
        switch state {
        case .connected:
            return false
        case .connecting, .reconnecting, .disconnected, .failed:
            return true
        }
    }

    private var bannerColor: Color {
        switch state {
        case .connecting, .reconnecting:
            return .orange
        case .disconnected:
            return .gray
        case .failed:
            return .red
        default:
            return .clear
        }
    }

    private var bannerIcon: String {
        switch state {
        case .connecting, .reconnecting:
            return "arrow.triangle.2.circlepath"
        case .disconnected:
            return "wifi.slash"
        case .failed:
            return "exclamationmark.triangle"
        default:
            return "checkmark.circle"
        }
    }

    private var bannerText: String {
        switch state {
        case .connecting:
            return "Connecting to server..."
        case .reconnecting(let attempt):
            return "Reconnecting... (Attempt \(attempt))"
        case .disconnected:
            return "Connection lost"
        case .failed(let error):
            return "Connection failed: \(error)"
        default:
            return ""
        }
    }

    private var showRetryButton: Bool {
        switch state {
        case .failed, .disconnected:
            return onRetry != nil
        default:
            return false
        }
    }
}

/// A full-screen overlay for when reconnection is in progress.
struct ReconnectionOverlayView: View {

    // MARK: - Properties

    let state: ConnectionState
    var onCancel: (() -> Void)?
    var onRetry: (() -> Void)?

    // MARK: - Body

    var body: some View {
        Group {
            if shouldShowOverlay {
                ZStack {
                    // Dimmed background
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()

                    // Content
                    VStack(spacing: 24) {
                        // Spinner or error icon
                        if isReconnecting {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                        } else {
                            Image(systemName: "wifi.exclamationmark")
                                .font(.system(size: 48))
                                .foregroundColor(.white)
                        }

                        // Status text
                        Text(overlayTitle)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text(overlaySubtitle)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        // Action buttons
                        HStack(spacing: 16) {
                            if let onCancel = onCancel {
                                Button("Leave Game") {
                                    onCancel()
                                }
                                .buttonStyle(SecondaryButtonStyle())
                            }

                            if let onRetry = onRetry, showRetryButton {
                                Button("Try Again") {
                                    onRetry()
                                }
                                .buttonStyle(PrimaryButtonStyle())
                            }
                        }
                        .padding(.top, 16)
                    }
                    .padding(32)
                    .background(Color(.systemBackground).opacity(0.95))
                    .cornerRadius(20)
                    .shadow(radius: 20)
                    .padding(32)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: shouldShowOverlay)
    }

    // MARK: - Computed Properties

    private var shouldShowOverlay: Bool {
        switch state {
        case .reconnecting, .failed:
            return true
        default:
            return false
        }
    }

    private var isReconnecting: Bool {
        switch state {
        case .reconnecting:
            return true
        default:
            return false
        }
    }

    private var overlayTitle: String {
        switch state {
        case .reconnecting:
            return "Reconnecting"
        case .failed:
            return "Connection Lost"
        default:
            return ""
        }
    }

    private var overlaySubtitle: String {
        switch state {
        case .reconnecting(let attempt):
            return "Attempting to reconnect... (\(attempt)/5)\nPlease wait."
        case .failed(let error):
            return "Unable to connect to the server.\n\(error)"
        default:
            return ""
        }
    }

    private var showRetryButton: Bool {
        switch state {
        case .failed:
            return true
        default:
            return false
        }
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.red)
            .cornerRadius(12)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.primary)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

// MARK: - Previews

#Preview("Connected") {
    VStack {
        ConnectionStatusView(state: .connected)
        ConnectionStatusView(state: .connecting)
        ConnectionStatusView(state: .reconnecting(attempt: 2))
        ConnectionStatusView(state: .disconnected)
        ConnectionStatusView(state: .failed(error: "Timeout"))
    }
}

#Preview("Banner") {
    VStack {
        ConnectionBannerView(state: .reconnecting(attempt: 2))
        Spacer()
    }
}

#Preview("Overlay") {
    ReconnectionOverlayView(
        state: .reconnecting(attempt: 3),
        onCancel: {},
        onRetry: {}
    )
}
