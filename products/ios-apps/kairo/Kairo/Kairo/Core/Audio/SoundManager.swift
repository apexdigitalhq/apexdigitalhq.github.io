import AVFoundation
import Combine
import SwiftUI

// MARK: - Sound Type

/// Available ambient soundscapes for focus sessions.
enum SoundType: String, CaseIterable, Identifiable, Codable {
    case rain       = "rain"
    case forest     = "forest"
    case ocean      = "ocean"
    case whiteNoise = "white_noise"
    case coffeeShop = "coffee_shop"
    case silence    = "silence"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rain:       return "Rain"
        case .forest:     return "Forest"
        case .ocean:      return "Ocean"
        case .whiteNoise: return "White Noise"
        case .coffeeShop: return "Coffee Shop"
        case .silence:    return "Silence"
        }
    }

    var iconName: String {
        switch self {
        case .rain:       return "cloud.rain.fill"
        case .forest:     return "leaf.fill"
        case .ocean:      return "water.waves"
        case .whiteNoise: return "waveform"
        case .coffeeShop: return "cup.and.saucer.fill"
        case .silence:    return "speaker.slash.fill"
        }
    }

    var color: Color {
        switch self {
        case .rain:       return Color(hex: 0x3498DB)
        case .forest:     return Color(hex: 0x27AE60)
        case .ocean:      return Color(hex: 0x2980B9)
        case .whiteNoise: return KairoColors.mutedAdaptive
        case .coffeeShop: return Color(hex: 0x8B6914)
        case .silence:    return KairoColors.primaryAdaptive
        }
    }

    /// Audio file name in the bundle (without extension).
    /// Silence has no audio file — it simply stops playback.
    var fileName: String? {
        switch self {
        case .silence: return nil
        default:       return rawValue
        }
    }
}

// MARK: - Sound Manager

/// AVFoundation-based ambient sound player for focus sessions.
///
/// Manages playback of looping soundscapes with fade transitions,
/// volume control, and SwiftUI-friendly published state.
///
/// Usage:
/// ```swift
/// let manager = SoundManager.shared
/// manager.select(.rain)
/// manager.play()
/// manager.setVolume(0.6)
/// manager.stop()
/// ```
final class SoundManager: ObservableObject {

    static let shared = SoundManager()

    // MARK: - Published State

    /// The currently selected sound type.
    @Published private(set) var selectedSound: SoundType = .silence

    /// Whether audio is currently playing.
    @Published private(set) var isPlaying: Bool = false

    /// Current volume level (0.0 – 1.0).
    @Published var volume: Float = 0.7 {
        didSet {
            let clamped = min(max(volume, 0.0), 1.0)
            if clamped != volume { volume = clamped }
            player?.volume = clamped
            persistVolume()
        }
    }

    // MARK: - Private

    private var player: AVAudioPlayer?
    private var fadeTimer: Timer?

    /// Duration for fade in/out transitions.
    private let fadeDuration: TimeInterval = 0.5

    /// Steps per fade transition (controls smoothness).
    private let fadeSteps: Int = 25

    /// UserDefaults keys
    private enum DefaultsKey {
        static let selectedSound = "kairo_selected_sound"
        static let volume = "kairo_sound_volume"
    }

    // MARK: - Init

    private init() {
        restorePersistedState()
        configureAudioSession()
    }

    // MARK: - Audio Session

    /// Configures AVAudioSession for ambient sound playback.
    ///
    /// Uses `.playback` category so audio plays even when the silent switch is on
    /// (standard for focus/meditation apps). `.mixWithOthers` lets music apps coexist.
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            #if DEBUG
            print("[SoundManager] Audio session config failed: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Selection

    /// Select a sound type. Does not auto-play.
    func select(_ type: SoundType) {
        guard type != selectedSound else { return }
        let wasPlaying = isPlaying

        if isPlaying {
            stopImmediate()
        }

        selectedSound = type
        persistSelectedSound()

        if wasPlaying && type != .silence {
            play()
        }
    }

    // MARK: - Playback Controls

    /// Start playing the selected sound with a fade-in.
    func play() {
        guard selectedSound != .silence else {
            stopImmediate()
            return
        }

        guard let fileName = selectedSound.fileName else { return }

        // Try common audio extensions
        let extensions = ["m4a", "mp3", "wav", "aac", "caf"]
        var url: URL?

        for ext in extensions {
            if let found = Bundle.main.url(forResource: fileName, withExtension: ext) {
                url = found
                break
            }
        }

        guard let audioURL = url else {
            #if DEBUG
            print("[SoundManager] Audio file not found for: \(fileName)")
            #endif
            // Still mark as playing so UI reflects intent — silent fallback
            isPlaying = true
            return
        }

        do {
            player = try AVAudioPlayer(contentsOf: audioURL)
            player?.numberOfLoops = -1 // infinite loop
            player?.volume = 0.0       // start silent for fade-in
            player?.prepareToPlay()
            player?.play()
            isPlaying = true
            fadeIn()
        } catch {
            #if DEBUG
            print("[SoundManager] Playback failed: \(error.localizedDescription)")
            #endif
        }
    }

    /// Pause playback (maintains position).
    func pause() {
        guard isPlaying else { return }
        fadeOut { [weak self] in
            self?.player?.pause()
            self?.isPlaying = false
        }
    }

    /// Resume playback from paused position.
    func resume() {
        guard let player, !player.isPlaying else {
            if !isPlaying { play() }
            return
        }

        player.play()
        isPlaying = true
        fadeIn()
    }

    /// Stop playback with a fade-out and reset position.
    func stop() {
        fadeOut { [weak self] in
            self?.stopImmediate()
        }
    }

    /// Immediately stop without fade (used internally).
    private func stopImmediate() {
        cancelFade()
        player?.stop()
        player?.currentTime = 0
        player = nil
        isPlaying = false
    }

    // MARK: - Volume

    /// Set volume with optional animation.
    func setVolume(_ newVolume: Float, animated: Bool = false) {
        let clamped = min(max(newVolume, 0.0), 1.0)
        if animated {
            animateVolume(to: clamped)
        } else {
            volume = clamped
        }
    }

    // MARK: - Preview

    /// Play a short preview of a sound type (3 seconds), then stop.
    func preview(_ type: SoundType, duration: TimeInterval = 3.0) {
        let previousSound = selectedSound
        let wasPlaying = isPlaying

        // Stop current if playing
        stopImmediate()

        // Temporarily select and play
        selectedSound = type

        guard type != .silence else {
            // Restore after brief pause
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.selectedSound = previousSound
                if wasPlaying { self?.play() }
            }
            return
        }

        play()

        // Stop after duration and restore
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self else { return }
            self.stop()
            self.selectedSound = previousSound
            self.persistSelectedSound()
            if wasPlaying {
                self.play()
            }
        }
    }

    // MARK: - Fade Transitions

    private func fadeIn() {
        cancelFade()
        let targetVolume = volume
        let stepDuration = fadeDuration / Double(fadeSteps)
        let volumeStep = targetVolume / Float(fadeSteps)
        var currentStep = 0

        player?.volume = 0.0

        fadeTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            currentStep += 1

            if currentStep >= self.fadeSteps {
                self.player?.volume = targetVolume
                timer.invalidate()
                self.fadeTimer = nil
            } else {
                self.player?.volume = volumeStep * Float(currentStep)
            }
        }
    }

    private func fadeOut(completion: @escaping () -> Void) {
        cancelFade()
        guard let player, player.volume > 0 else {
            completion()
            return
        }

        let startVolume = player.volume
        let stepDuration = fadeDuration / Double(fadeSteps)
        let volumeStep = startVolume / Float(fadeSteps)
        var currentStep = 0

        fadeTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            currentStep += 1

            if currentStep >= self.fadeSteps {
                self.player?.volume = 0.0
                timer.invalidate()
                self.fadeTimer = nil
                completion()
            } else {
                self.player?.volume = startVolume - (volumeStep * Float(currentStep))
            }
        }
    }

    private func animateVolume(to target: Float) {
        cancelFade()
        let startVolume = player?.volume ?? volume
        let stepDuration = fadeDuration / Double(fadeSteps)
        let delta = target - startVolume
        let volumeStep = delta / Float(fadeSteps)
        var currentStep = 0

        fadeTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            currentStep += 1

            if currentStep >= self.fadeSteps {
                self.player?.volume = target
                self.volume = target
                timer.invalidate()
                self.fadeTimer = nil
            } else {
                let newVol = startVolume + (volumeStep * Float(currentStep))
                self.player?.volume = newVol
            }
        }
    }

    private func cancelFade() {
        fadeTimer?.invalidate()
        fadeTimer = nil
    }

    // MARK: - Persistence

    private func persistSelectedSound() {
        UserDefaults.standard.set(selectedSound.rawValue, forKey: DefaultsKey.selectedSound)
    }

    private func persistVolume() {
        UserDefaults.standard.set(volume, forKey: DefaultsKey.volume)
    }

    private func restorePersistedState() {
        if let raw = UserDefaults.standard.string(forKey: DefaultsKey.selectedSound),
           let sound = SoundType(rawValue: raw) {
            selectedSound = sound
        }

        let storedVolume = UserDefaults.standard.float(forKey: DefaultsKey.volume)
        if storedVolume > 0 {
            volume = storedVolume
        }
    }

    // MARK: - Cleanup

    deinit {
        cancelFade()
        player?.stop()
        player = nil
    }
}
