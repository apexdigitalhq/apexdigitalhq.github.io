import Foundation
import SwiftUI

// MARK: - BreakType

/// The type of break between focus sessions.
///
/// Follows the Pomodoro technique: short breaks after each session,
/// long breaks every N sessions. Duration can be overridden per-break.
enum BreakType: String, CaseIterable, Identifiable {
    /// A short rest between consecutive focus sessions (default: 5 minutes).
    case short = "short"
    /// An extended rest after completing a block of sessions (default: 15 minutes).
    case long = "long"

    var id: String { rawValue }

    /// Default duration in seconds for this break type.
    var defaultDuration: TimeInterval {
        switch self {
        case .short: return TimeInterval(KairoTheme.SessionPreset.shortBreak * 60)
        case .long:  return TimeInterval(KairoTheme.SessionPreset.longBreak * 60)
        }
    }

    /// Human-readable label for the UI.
    var displayName: String {
        switch self {
        case .short: return "Short Break"
        case .long:  return "Long Break"
        }
    }

    /// SF Symbol icon representing this break type.
    var icon: String {
        switch self {
        case .short: return "cup.and.saucer.fill"
        case .long:  return "leaf.fill"
        }
    }

    /// Descriptive subtitle shown on the break screen.
    var subtitle: String {
        switch self {
        case .short: return "Quick reset before the next session"
        case .long:  return "You've earned a proper rest"
        }
    }
}

// MARK: - BreakManager

/// Manages break periods between focus sessions.
///
/// Provides a standalone break timer with countdown, progress tracking,
/// and intelligent break suggestions based on session history. Designed
/// to integrate with `SessionCoordinator` — the coordinator calls
/// `startBreak(type:)` after a completed session and wires `onBreakComplete`
/// to transition back to the next focus phase.
///
/// Timer precision: fires every 1 second (break screens don't need the
/// 10 Hz display rate of `FocusEngine`).
@MainActor
final class BreakManager: ObservableObject {

    // MARK: - Published State

    /// Whether a break is currently in progress.
    @Published private(set) var isOnBreak: Bool = false

    /// Seconds remaining in the current break.
    @Published private(set) var breakTimeRemaining: TimeInterval = 0

    /// Progress from 0.0 (break just started) to 1.0 (break complete).
    @Published private(set) var breakProgress: Double = 0

    /// The type of the active or most recently completed break.
    @Published private(set) var currentBreakType: BreakType = .short

    /// Sessions remaining until the next long break triggers.
    @Published private(set) var sessionsUntilLongBreak: Int = KairoTheme.SessionPreset.longBreakInterval

    /// Cumulative count of breaks taken in the current usage session.
    @Published private(set) var totalBreaksTaken: Int = 0

    // MARK: - Callbacks

    /// Fired when a break ends naturally (timer reaches zero).
    /// Not called when the user skips — the caller handles that transition.
    var onBreakComplete: (() -> Void)?

    // MARK: - Private State

    /// The repeating 1-second timer driving the break countdown.
    private var breakTimer: Timer?

    /// Total duration of the current break in seconds (for progress calculation).
    private var breakDuration: TimeInterval = 0

    /// Number of focus sessions completed in the current block.
    private var completedSessionsInBlock: Int = 0

    // MARK: - Break Lifecycle

    /// Starts a break of the given type.
    ///
    /// If a break is already running it is silently replaced. The timer fires
    /// every second, updating `breakTimeRemaining` and `breakProgress`.
    /// When time reaches zero, `onBreakComplete` is invoked.
    ///
    /// - Parameters:
    ///   - type: The break type (`.short` or `.long`).
    ///   - customDuration: Optional override in seconds. Uses the type's
    ///     default if `nil`.
    func startBreak(type: BreakType, customDuration: TimeInterval? = nil) {
        // Tear down any existing break timer
        breakTimer?.invalidate()
        breakTimer = nil

        let duration = customDuration ?? type.defaultDuration
        currentBreakType = type
        breakDuration = duration
        breakTimeRemaining = duration
        breakProgress = 0
        isOnBreak = true
        totalBreaksTaken += 1

        // Update block tracking
        completedSessionsInBlock += 1
        sessionsUntilLongBreak = max(0,
            KairoTheme.SessionPreset.longBreakInterval - (completedSessionsInBlock % KairoTheme.SessionPreset.longBreakInterval)
        )

        startTimer()
    }

    /// Skips the current break immediately.
    ///
    /// Stops the timer and resets break state. Does **not** fire
    /// `onBreakComplete` — the caller (typically `SessionCoordinator`)
    /// decides what happens next (start next session, return to idle, etc.).
    func skipBreak() {
        breakTimer?.invalidate()
        breakTimer = nil
        isOnBreak = false
        breakTimeRemaining = 0
        breakProgress = 1
    }

    /// Extends the running break by additional seconds.
    ///
    /// Adjusts both `breakDuration` and `breakTimeRemaining` so progress
    /// recalculates smoothly relative to the new total.
    ///
    /// - Parameter seconds: Seconds to add (clamped to a minimum of 1).
    func extendBreak(by seconds: TimeInterval) {
        guard isOnBreak, seconds > 0 else { return }
        let additionalTime = max(1, seconds)
        breakDuration += additionalTime
        breakTimeRemaining += additionalTime

        // Recalculate progress against the new total duration
        if breakDuration > 0 {
            breakProgress = max(0, min(1, 1.0 - (breakTimeRemaining / breakDuration)))
        }
    }

    /// Suggests the appropriate break type based on completed session count.
    ///
    /// Follows the Pomodoro pattern: every Nth session triggers a long break
    /// (N = `KairoTheme.SessionPreset.longBreakInterval`, default 4).
    ///
    /// - Parameter sessionsCompleted: Total sessions completed in the block.
    /// - Returns: `.long` on every Nth session, `.short` otherwise.
    func suggestBreakType(sessionsCompleted: Int) -> BreakType {
        guard sessionsCompleted > 0 else { return .short }
        return (sessionsCompleted % KairoTheme.SessionPreset.longBreakInterval == 0)
            ? .long
            : .short
    }

    /// Suggests a break duration adapted to the user's recent performance.
    ///
    /// Low-quality sessions earn a longer break to recover focus. Long breaks
    /// and high session counts also shift the suggestion upward.
    ///
    /// - Parameters:
    ///   - lastSessionQuality: Quality rating string ("high", "medium", "low").
    ///   - sessionsCompleted: Sessions completed in the current block.
    /// - Returns: Suggested break duration in seconds.
    func suggestBreakDuration(lastSessionQuality: String, sessionsCompleted: Int) -> TimeInterval {
        let type = suggestBreakType(sessionsCompleted: sessionsCompleted)
        var duration = type.defaultDuration

        // Quality-based adjustment
        switch lastSessionQuality {
        case "low":
            // Longer break after a tough session — help the user recover
            duration += 120 // +2 minutes
        case "medium":
            // Slight bump for moderate sessions
            duration += 60  // +1 minute
        case "high":
            // Excellent focus — standard break is fine
            break
        default:
            break
        }

        // Fatigue adjustment: after many sessions, nudge toward longer breaks
        if sessionsCompleted >= 6 {
            duration += 120
        } else if sessionsCompleted >= 4 {
            duration += 60
        }

        return duration
    }

    /// Resets all block and session counters.
    ///
    /// Call when the user is "done for now" or starts a fresh focus block.
    func reset() {
        breakTimer?.invalidate()
        breakTimer = nil
        isOnBreak = false
        breakTimeRemaining = 0
        breakProgress = 0
        breakDuration = 0
        totalBreaksTaken = 0
        completedSessionsInBlock = 0
        sessionsUntilLongBreak = KairoTheme.SessionPreset.longBreakInterval
    }

    // MARK: - Timer Management

    /// Creates and schedules the 1-second repeating timer.
    private func startTimer() {
        breakTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self else {
                    timer.invalidate()
                    return
                }
                self.timerTick()
            }
        }

        // Keep firing during scroll and other tracking modes
        if let timer = breakTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    /// Processes a single timer tick: decrements remaining time, updates progress.
    private func timerTick() {
        guard isOnBreak else {
            breakTimer?.invalidate()
            breakTimer = nil
            return
        }

        breakTimeRemaining = max(0, breakTimeRemaining - 1)

        if breakDuration > 0 {
            breakProgress = max(0, min(1, 1.0 - (breakTimeRemaining / breakDuration)))
        }

        if breakTimeRemaining <= 0 {
            breakTimer?.invalidate()
            breakTimer = nil
            isOnBreak = false
            breakProgress = 1
            onBreakComplete?()
        }
    }
}
