//
//  AudioService.swift
//  ChineseChess
//
//  Service for audio and haptic feedback.
//

import Foundation
import AVFoundation
import UIKit
import AudioToolbox

/// Service for managing audio effects and haptic feedback.
final class AudioService: AudioServiceProtocol {

    // MARK: - Singleton

    static let shared = AudioService()

    // MARK: - Properties

    private var audioPlayers: [GameSound: AVAudioPlayer] = [:]

    private let lightFeedback = UIImpactFeedbackGenerator(style: .light)
    private let mediumFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let heavyFeedback = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    private let selectionFeedback = UISelectionFeedbackGenerator()

    /// Audio session for managing audio playback
    private let audioSession = AVAudioSession.sharedInstance()

    var isSoundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isSoundEnabled, forKey: "settings.soundEnabled")
        }
    }

    var isHapticsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isHapticsEnabled, forKey: "settings.hapticsEnabled")
        }
    }

    // MARK: - Initialization

    init() {
        self.isSoundEnabled = UserDefaults.standard.object(forKey: "settings.soundEnabled") as? Bool ?? true
        self.isHapticsEnabled = UserDefaults.standard.object(forKey: "settings.hapticsEnabled") as? Bool ?? true

        // Configure audio session
        configureAudioSession()

        // Prepare haptic generators
        lightFeedback.prepare()
        mediumFeedback.prepare()
        heavyFeedback.prepare()
        notificationFeedback.prepare()
        selectionFeedback.prepare()

        // Pre-load audio files
        preloadSounds()
    }

    // MARK: - AudioServiceProtocol

    func playSound(_ sound: GameSound) {
        guard isSoundEnabled else { return }

        if let player = audioPlayers[sound] {
            player.currentTime = 0
            player.play()
        } else {
            // Fallback to system sounds if custom sounds not available
            playSystemSound(for: sound)
        }
    }

    func triggerHaptic(_ type: HapticType) {
        guard isHapticsEnabled else { return }

        switch type {
        case .light:
            lightFeedback.impactOccurred()
        case .medium:
            mediumFeedback.impactOccurred()
        case .heavy:
            heavyFeedback.impactOccurred()
        case .success:
            notificationFeedback.notificationOccurred(.success)
        case .warning:
            notificationFeedback.notificationOccurred(.warning)
        case .error:
            notificationFeedback.notificationOccurred(.error)
        case .selection:
            selectionFeedback.selectionChanged()
        }
    }

    // MARK: - Convenience Methods for Game Events

    /// Plays sound and haptic for piece selection
    func playPieceSelect() {
        playSound(.pieceSelect)
        triggerHaptic(.selection)
    }

    /// Plays sound and haptic for a regular move
    func playPieceMove() {
        playSound(.pieceMove)
        triggerHaptic(.light)
    }

    /// Plays sound and haptic for a capture
    func playPieceCapture() {
        playSound(.pieceCapture)
        triggerHaptic(.medium)
    }

    /// Plays sound and haptic for check
    func playCheck() {
        playSound(.check)
        triggerHaptic(.warning)
    }

    /// Plays sound and haptic for checkmate
    func playCheckmate() {
        playSound(.checkmate)
        triggerHaptic(.heavy)
    }

    /// Plays sound and haptic for game start
    func playGameStart() {
        playSound(.gameStart)
        triggerHaptic(.medium)
    }

    /// Plays sound and haptic for victory
    func playVictory() {
        playSound(.gameWin)
        triggerHaptic(.success)
    }

    /// Plays sound and haptic for defeat
    func playDefeat() {
        playSound(.gameLose)
        triggerHaptic(.error)
    }

    /// Plays sound and haptic for draw
    func playDraw() {
        playSound(.gameDraw)
        triggerHaptic(.medium)
    }

    /// Plays button tap feedback
    func playButtonTap() {
        playSound(.buttonTap)
        triggerHaptic(.light)
    }

    /// Plays timer warning sound
    func playTimerWarning() {
        playSound(.timerWarning)
        triggerHaptic(.warning)
    }

    /// Plays urgent timer sound (last 10 seconds)
    func playTimerUrgent() {
        playSound(.timerUrgent)
        triggerHaptic(.error)
    }

    // MARK: - Private Methods

    private func configureAudioSession() {
        do {
            try audioSession.setCategory(.ambient, mode: .default)
            try audioSession.setActive(true)
        } catch {
            DebugLog.error("Failed to configure audio session", error)
        }
    }

    private func preloadSounds() {
        // Try to load custom sound files from bundle
        for sound in GameSound.allCases {
            // Try multiple extensions
            let extensions = ["wav", "mp3", "m4a", "aiff"]
            for ext in extensions {
                if let url = Bundle.main.url(forResource: sound.rawValue, withExtension: ext) {
                    do {
                        let player = try AVAudioPlayer(contentsOf: url)
                        player.prepareToPlay()
                        player.volume = 0.7
                        audioPlayers[sound] = player
                        break
                    } catch {
                        DebugLog.warning("Failed to load sound \(sound.rawValue).\(ext): \(error.localizedDescription)")
                    }
                }
            }
        }

        DebugLog.info("Loaded \(audioPlayers.count) custom sound files")
    }

    /// Plays system sound as fallback when custom sounds are not available
    private func playSystemSound(for sound: GameSound) {
        let systemSoundID: SystemSoundID

        switch sound {
        case .pieceSelect:
            systemSoundID = 1104 // Tap sound
        case .pieceMove:
            systemSoundID = 1306 // Keyboard tap
        case .pieceCapture:
            systemSoundID = 1105 // Lock sound
        case .check:
            systemSoundID = 1005 // Alarm
        case .checkmate:
            systemSoundID = 1023 // SMS received
        case .gameStart:
            systemSoundID = 1025 // SMS sent
        case .gameWin:
            systemSoundID = 1020 // Payment success
        case .gameLose:
            systemSoundID = 1053 // Payment failed
        case .gameDraw:
            systemSoundID = 1016 // Tweet sent
        case .buttonTap:
            systemSoundID = 1104 // Tap
        case .timerWarning:
            systemSoundID = 1007 // Alarm warning
        case .timerUrgent:
            systemSoundID = 1073 // Urgent
        }

        AudioServicesPlaySystemSound(systemSoundID)
    }
}
