import Foundation
import CoreHaptics
import UIKit

// MARK: - HapticEvent

/// Discrete haptic events mapped to focus session milestones.
///
/// Each case has a carefully tuned Core Haptics pattern designed to feel
/// contextually appropriate — energizing for starts, rewarding for completions,
/// non-intrusive for distractions.
enum HapticEvent: String, CaseIterable {
    /// Session begins: strong tap + subtle ramp (energizing).
    case sessionStart
    /// Session completed successfully: triple celebration tap (rewarding).
    case sessionComplete
    /// Break period begins: gentle pulse (relaxing).
    case breakStart
    /// Break period ends: medium tap (re-engaging).
    case breakComplete
    /// User reaches a focus milestone: ascending 3-tap pattern.
    case milestone
    /// Warning or attention needed: double sharp tap (alerting).
    case warning
    /// Distraction detected: single subtle tap (non-intrusive reminder).
    case distraction

    /// Human-readable label for debug/analytics.
    var displayName: String {
        switch self {
        case .sessionStart:   return "Session Start"
        case .sessionComplete: return "Session Complete"
        case .breakStart:     return "Break Start"
        case .breakComplete:  return "Break Complete"
        case .milestone:      return "Milestone"
        case .warning:        return "Warning"
        case .distraction:    return "Distraction"
        }
    }
}

// MARK: - HapticEngine

/// Core Haptics–powered feedback engine for Kairo session events.
///
/// Wraps `CHHapticEngine` with automatic lifecycle management:
/// - Prepares the engine on demand and auto-restarts after system stops.
/// - Falls back to `UIImpactFeedbackGenerator` when Core Haptics is unavailable
///   (e.g. on devices without a Taptic Engine or in the Simulator).
/// - All patterns are built programmatically — no external AHAP files needed.
///
/// Usage:
/// ```swift
/// let haptics = HapticEngine()
/// haptics.prepare()
/// haptics.play(.sessionStart)
/// ```
@MainActor
final class HapticEngine: ObservableObject {

    // MARK: - Published State

    /// Whether Core Haptics is available on this device.
    @Published private(set) var isAvailable: Bool = false

    // MARK: - Engine

    /// The underlying Core Haptics engine (nil when unavailable or not yet prepared).
    private var engine: CHHapticEngine?

    /// Whether the engine is currently in a started state.
    private var engineStarted: Bool = false

    /// Fallback generators for devices without Core Haptics.
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()

    // MARK: - Init

    init() {
        isAvailable = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    // MARK: - Engine Lifecycle

    /// Creates and starts the Core Haptics engine.
    ///
    /// Safe to call multiple times — if the engine is already running, this is a no-op.
    /// Registers a `stoppedHandler` that auto-restarts the engine when the system
    /// reclaims it (e.g. after backgrounding).
    func prepare() {
        guard isAvailable else { return }
        guard engine == nil else { return }

        do {
            let hapticEngine = try CHHapticEngine()

            // Auto-restart when the system stops the engine
            hapticEngine.stoppedHandler = { [weak self] reason in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.engineStarted = false
                    self.restartEngine()
                }
            }

            // Handle engine reset (e.g. audio session interruption)
            hapticEngine.resetHandler = { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.startEngine()
                }
            }

            engine = hapticEngine
            startEngine()
        } catch {
            isAvailable = false
        }
    }

    /// Starts the engine if it exists and isn't already running.
    private func startEngine() {
        guard let engine, !engineStarted else { return }

        do {
            try engine.start()
            engineStarted = true
        } catch {
            engineStarted = false
        }
    }

    /// Attempts to restart the engine after it was stopped by the system.
    private func restartEngine() {
        guard isAvailable else { return }
        startEngine()
    }

    /// Stops and releases the haptic engine. Call when haptics won't be needed
    /// for a while (e.g. app backgrounded with no active session).
    func shutdown() {
        engine?.stop()
        engine = nil
        engineStarted = false
    }

    // MARK: - Play Event

    /// Plays the appropriate haptic pattern for the given event.
    ///
    /// If Core Haptics is available and the engine is running, plays a custom
    /// `CHHapticPattern`. Otherwise, falls back to `UIFeedbackGenerator`.
    ///
    /// - Parameter event: The session event to play haptics for.
    func play(_ event: HapticEvent) {
        if isAvailable && engineStarted {
            playWithCoreHaptics(event)
        } else {
            playWithFallback(event)
        }
    }

    // MARK: - Countdown

    /// Plays a 3-2-1 countdown sequence with taps at decreasing intervals.
    ///
    /// Designed for the preparing state before a focus session begins.
    /// Interval pattern: 1.0s → 0.7s → 0.4s (building anticipation).
    func playCountdown() {
        guard isAvailable, engineStarted, let engine else {
            // Fallback: three medium taps
            Task {
                mediumImpact.impactOccurred(intensity: 0.5)
                try? await Task.sleep(for: .seconds(1.0))
                mediumImpact.impactOccurred(intensity: 0.7)
                try? await Task.sleep(for: .seconds(0.7))
                heavyImpact.impactOccurred(intensity: 1.0)
            }
            return
        }

        do {
            let events: [CHHapticEvent] = [
                // "3" — light tap
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                    ],
                    relativeTime: 0
                ),
                // "2" — medium tap
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                    ],
                    relativeTime: 1.0
                ),
                // "1" — strong tap
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                    ],
                    relativeTime: 1.7
                )
            ]

            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Silent failure — haptics are non-critical
        }
    }

    // MARK: - Core Haptics Patterns

    /// Builds and plays a Core Haptics pattern for the given event type.
    private func playWithCoreHaptics(_ event: HapticEvent) {
        guard let engine else { return }

        do {
            let events = hapticEvents(for: event)
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Fall through to UIKit haptics on failure
            playWithFallback(event)
        }
    }

    /// Returns the Core Haptics event array for a given haptic event type.
    private func hapticEvents(for event: HapticEvent) -> [CHHapticEvent] {
        switch event {

        case .sessionStart:
            // Strong tap + subtle ramp — energizing launch feel
            return [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                    ],
                    relativeTime: 0.08,
                    duration: 0.25
                )
            ]

        case .sessionComplete:
            // Triple celebration tap — rewarding completion
            return [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.85),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                    ],
                    relativeTime: 0.12
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
                    ],
                    relativeTime: 0.24
                )
            ]

        case .breakStart:
            // Gentle pulse — relaxing transition
            return [
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1)
                    ],
                    relativeTime: 0,
                    duration: 0.4
                )
            ]

        case .breakComplete:
            // Medium tap — re-engaging nudge
            return [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                    ],
                    relativeTime: 0
                )
            ]

        case .milestone:
            // Ascending 3-tap pattern — increasing intensity
            return [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.65),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                    ],
                    relativeTime: 0.15
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
                    ],
                    relativeTime: 0.30
                )
            ]

        case .warning:
            // Double sharp tap — alerting
            return [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
                    ],
                    relativeTime: 0.12
                )
            ]

        case .distraction:
            // Single subtle tap — non-intrusive reminder
            return [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                    ],
                    relativeTime: 0
                )
            ]
        }
    }

    // MARK: - UIKit Fallback

    /// Plays a UIKit feedback generator pattern when Core Haptics is unavailable.
    private func playWithFallback(_ event: HapticEvent) {
        switch event {
        case .sessionStart:
            heavyImpact.impactOccurred(intensity: 0.9)

        case .sessionComplete:
            notificationGenerator.notificationOccurred(.success)

        case .breakStart:
            lightImpact.impactOccurred(intensity: 0.4)

        case .breakComplete:
            mediumImpact.impactOccurred(intensity: 0.6)

        case .milestone:
            notificationGenerator.notificationOccurred(.success)

        case .warning:
            notificationGenerator.notificationOccurred(.warning)

        case .distraction:
            lightImpact.impactOccurred(intensity: 0.3)
        }
    }
}
