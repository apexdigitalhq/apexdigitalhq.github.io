import Foundation
import SwiftUI
import CoreData
import UserNotifications

// MARK: - FocusEngine

/// The core timer engine for Kairo focus sessions.
///
/// Manages the complete session lifecycle with a precise state machine:
///   idle → preparing (3-2-1) → focusing ↔ paused → completed | abandoned
///
/// Time tracking uses wall-clock differentials — never tick accumulation —
/// so the display stays accurate even when timers fire late or the app
/// returns from background.
@MainActor
final class FocusEngine: ObservableObject {

    // MARK: - Published State

    /// Current state of the session state machine.
    @Published private(set) var state: TimerState = .idle

    /// Seconds remaining in the focus session (wall-clock derived).
    @Published private(set) var remainingSeconds: TimeInterval = 0

    /// Total session duration in seconds (set during configuration).
    @Published private(set) var totalSeconds: TimeInterval = 0

    /// Countdown value during the preparing state (3, 2, 1).
    @Published private(set) var preparingCountdown: Int = 3

    /// Number of times the user paused this session.
    @Published private(set) var pauseCount: Int = 0

    /// Number of distractions detected (app background, pickups, etc.).
    @Published private(set) var distractionCount: Int = 0

    // MARK: - Computed Properties

    /// Progress from 0.0 (just started) to 1.0 (complete).
    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return max(0, min(1, 1.0 - (remainingSeconds / totalSeconds)))
    }

    /// Seconds of focus time elapsed so far.
    var elapsedSeconds: TimeInterval {
        totalSeconds - remainingSeconds
    }

    /// Convenience: whether any session-related state is active.
    var isActive: Bool { state.isActive }

    /// Formatted remaining time for display (e.g. "18:45").
    var remainingDisplay: String { remainingSeconds.timerDisplay }

    // MARK: - Session Info

    /// The session type chosen by the user.
    private(set) var sessionType: KairoTheme.SessionType = .work

    /// The active Core Data session (non-nil while focusing/paused).
    private(set) var currentSession: FocusSession?

    /// The most recently completed or abandoned session, for the completion view.
    private(set) var completedSession: FocusSession?

    // MARK: - Internal Timing

    /// Display-refresh timer (~10 Hz for smooth ring animation).
    private var displayTimer: Timer?

    /// Wall-clock instant when focus actually began (after preparing).
    private var focusStartDate: Date?

    /// Wall-clock instant when the current pause began.
    private var pauseStartDate: Date?

    /// Accumulated pause duration across all pauses in this session.
    private var totalPausedDuration: TimeInterval = 0

    /// Wall-clock instant when the app entered background (for distraction tracking).
    private var backgroundEntryDate: Date?

    /// Task handle for the preparing countdown, so we can cancel it.
    private var preparingTask: Task<Void, Never>?

    // MARK: - Observers

    private var backgroundObserver: Any?
    private var foregroundObserver: Any?

    // MARK: - Core Data

    private let context: NSManagedObjectContext
    private let sessionStore: SessionStore

    // MARK: - Callbacks

    /// Fires when a session completes successfully.
    var onSessionCompleted: ((FocusSession) -> Void)?

    /// Fires when a session is abandoned (< 50% completion).
    var onSessionAbandoned: ((FocusSession) -> Void)?

    /// Fires on every state transition.
    var onStateChanged: ((TimerState) -> Void)?

    // MARK: - Init

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
        self.sessionStore = SessionStore(context: context)
        setupLifecycleObservers()
    }

    deinit {
        if let obs = backgroundObserver {
            NotificationCenter.default.removeObserver(obs)
        }
        if let obs = foregroundObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    // MARK: - Configuration

    /// Set the session parameters before starting. Only effective while idle.
    func configure(duration: Int, type: KairoTheme.SessionType) {
        guard state == .idle else { return }
        totalSeconds = TimeInterval(duration * 60)
        remainingSeconds = totalSeconds
        sessionType = type
    }

    // MARK: - Session Controls

    /// Begin a new focus session. Enters the 3-2-1 preparing state first.
    func startSession() {
        guard state == .idle else { return }

        // Reset per-session counters
        pauseCount = 0
        distractionCount = 0
        totalPausedDuration = 0
        completedSession = nil
        preparingCountdown = 3

        transition(to: .preparing)
        startPreparingCountdown()
    }

    /// Pause an active focus session.
    func pause() {
        guard state == .focusing else { return }
        pauseStartDate = Date()
        pauseCount += 1
        stopDisplayTimer()
        transition(to: .paused)
    }

    /// Resume a paused session.
    func resume() {
        guard state == .paused else { return }

        // Accumulate the pause duration
        if let pauseStart = pauseStartDate {
            totalPausedDuration += Date().timeIntervalSince(pauseStart)
        }
        pauseStartDate = nil

        startDisplayTimer()
        transition(to: .focusing)
    }

    /// Stop the session. If ≥50% complete → completed; otherwise → abandoned.
    func stop() {
        guard state == .focusing || state == .paused else { return }

        // If paused, close out the current pause window
        if state == .paused, let pauseStart = pauseStartDate {
            totalPausedDuration += Date().timeIntervalSince(pauseStart)
            pauseStartDate = nil
        }

        let actualFocus = computeActualFocusDuration()
        let completionRatio = totalSeconds > 0 ? actualFocus / totalSeconds : 0

        if completionRatio >= 0.5 {
            finalizeSession(actualDuration: actualFocus, completed: true)
        } else {
            finalizeSession(actualDuration: actualFocus, completed: false)
        }
    }

    /// Hard cancel — discard everything and return to idle. No Core Data record for abandoned < preparing.
    func cancel() {
        preparingTask?.cancel()
        preparingTask = nil
        stopDisplayTimer()
        cancelBackgroundNotification()

        // If a session was created (past preparing), mark it abandoned
        if let session = currentSession {
            let actualFocus = computeActualFocusDuration()
            session.endedAt = Date()
            session.actualDuration = Int32(max(0, actualFocus))
            session.status = "abandoned"
            session.qualityRating = "low"
            session.focusScore = 0
            sessionStore.save()
        }

        currentSession = nil
        resetToIdle()
    }

    /// After viewing the completion screen, reset the engine for a new session.
    func resetForNewSession() {
        completedSession = nil
        resetToIdle()
    }

    // MARK: - Preparing Countdown

    private func startPreparingCountdown() {
        preparingTask = Task { @MainActor [weak self] in
            guard let self else { return }

            for i in stride(from: 3, through: 1, by: -1) {
                guard !Task.isCancelled, self.state == .preparing else { return }
                self.preparingCountdown = i
                try? await Task.sleep(for: .seconds(1))
            }

            guard !Task.isCancelled, self.state == .preparing else { return }
            self.beginFocusing()
        }
    }

    // MARK: - Focus Phase

    private func beginFocusing() {
        focusStartDate = Date()
        remainingSeconds = totalSeconds

        // Persist the session to Core Data
        let session = FocusSession.create(
            in: context,
            type: sessionType.rawValue,
            targetDuration: Int32(totalSeconds)
        )
        currentSession = session
        sessionStore.save()

        // Notification fallback for when the app is backgrounded
        scheduleCompletionNotification()

        // Start the display refresh timer
        startDisplayTimer()

        transition(to: .focusing)
    }

    // MARK: - Display Timer

    private func startDisplayTimer() {
        stopDisplayTimer()

        // 10 Hz — smooth ring animation without burning the CPU
        displayTimer = Timer.scheduledTimer(
            withTimeInterval: 0.1,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        // Keep firing while the user scrolls or interacts
        if let timer = displayTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    private func stopDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = nil
    }

    /// Called ~10× per second. Recomputes remaining time from the wall clock.
    private func tick() {
        guard state == .focusing, let focusStart = focusStartDate else { return }

        let elapsed = Date().timeIntervalSince(focusStart) - totalPausedDuration
        remainingSeconds = max(0, totalSeconds - elapsed)

        if remainingSeconds <= 0 {
            // Natural completion — the user focused for the full duration
            finalizeSession(actualDuration: totalSeconds, completed: true)
        }
    }

    // MARK: - Session Finalization

    private func finalizeSession(actualDuration: TimeInterval, completed: Bool) {
        stopDisplayTimer()
        cancelBackgroundNotification()

        guard let session = currentSession else {
            resetToIdle()
            return
        }

        // Populate the session record
        session.endedAt = Date()
        session.actualDuration = Int32(max(0, actualDuration))
        session.status = completed ? "completed" : "abandoned"
        session.pauseCount = Int16(pauseCount)
        session.distractionCount = Int16(distractionCount)
        session.qualityRating = computeQualityRating(
            actualDuration: actualDuration,
            targetDuration: totalSeconds,
            pauseCount: pauseCount,
            distractionCount: distractionCount
        )
        session.focusScore = computeSessionFocusScore(session: session)
        sessionStore.save()

        // Expose for the completion view
        completedSession = session
        currentSession = nil
        remainingSeconds = 0

        let targetState: TimerState = completed ? .completed : .abandoned
        transition(to: targetState)

        if completed {
            updateStreak()
            onSessionCompleted?(session)
        } else {
            onSessionAbandoned?(session)
        }
    }

    // MARK: - Reset

    private func resetToIdle() {
        state = .idle
        remainingSeconds = 0
        totalSeconds = 0
        pauseCount = 0
        distractionCount = 0
        totalPausedDuration = 0
        focusStartDate = nil
        pauseStartDate = nil
        backgroundEntryDate = nil
        currentSession = nil
        preparingTask = nil
        onStateChanged?(.idle)
    }

    // MARK: - State Transition + Haptics

    private func transition(to newState: TimerState) {
        let old = state
        state = newState
        onStateChanged?(newState)

        // Contextual haptic feedback
        switch newState {
        case .preparing:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .focusing where old == .preparing:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .focusing where old == .paused:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .paused:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .completed:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .abandoned:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        default:
            break
        }
    }

    // MARK: - Duration Computation

    private func computeActualFocusDuration() -> TimeInterval {
        guard let focusStart = focusStartDate else { return 0 }
        let wallElapsed = Date().timeIntervalSince(focusStart)
        return max(0, wallElapsed - totalPausedDuration)
    }

    // MARK: - Quality Assessment

    /// Matches the architecture's rule-based quality assessment.
    private func computeQualityRating(
        actualDuration: TimeInterval,
        targetDuration: TimeInterval,
        pauseCount: Int,
        distractionCount: Int
    ) -> String {
        guard targetDuration > 0 else { return "low" }

        let completionRatio = actualDuration / targetDuration
        let distractionRate = Double(distractionCount) / max(1, actualDuration / 60.0)

        if completionRatio >= 0.9 && distractionRate < 0.5 { return "high" }
        if completionRatio >= 0.7 && distractionRate < 1.0 { return "medium" }
        return "low"
    }

    /// Focus score per the architecture formula:
    ///   quality = completionRatio × distractionPenalty
    ///   distractionPenalty = 1.0 - (pauseCount × 0.05) - (distractionCount × 0.03), floor 0.5
    private func computeSessionFocusScore(session: FocusSession) -> Float {
        let target = max(Float(1), Float(session.targetDuration))
        let completionRatio = min(1.0, Float(session.actualDuration) / target)

        let penalty = max(0.5,
            1.0 - (Float(session.pauseCount) * 0.05)
                - (Float(session.distractionCount) * 0.03)
        )

        return min(100, completionRatio * penalty * 100)
    }

    // MARK: - Streak Update

    private func updateStreak() {
        let request = FocusStreak.fetchRequest()
        request.fetchLimit = 1

        let streak: FocusStreak
        if let existing = (try? context.fetch(request))?.first {
            streak = existing
        } else {
            streak = FocusStreak.createNew(in: context)
        }

        streak.recordActivity()
        try? context.save()
    }

    // MARK: - App Lifecycle (Background / Foreground)

    private func setupLifecycleObservers() {
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleDidEnterBackground()
            }
        }

        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleWillEnterForeground()
            }
        }
    }

    private func handleDidEnterBackground() {
        guard state == .focusing else { return }
        backgroundEntryDate = Date()
        stopDisplayTimer()

        // Log the distraction
        distractionCount += 1
        if let session = currentSession {
            let _ = DistractionEvent.create(
                in: context,
                session: session,
                type: .appBackground
            )
            sessionStore.save()
        }
    }

    private func handleWillEnterForeground() {
        guard state == .focusing else { return }
        backgroundEntryDate = nil

        // Recompute from the wall clock — the timer kept "running"
        if let focusStart = focusStartDate {
            let elapsed = Date().timeIntervalSince(focusStart) - totalPausedDuration
            remainingSeconds = max(0, totalSeconds - elapsed)

            if remainingSeconds <= 0 {
                finalizeSession(actualDuration: totalSeconds, completed: true)
                return
            }
        }

        startDisplayTimer()
    }

    // MARK: - Local Notifications (Background Fallback)

    private func scheduleCompletionNotification() {
        guard remainingSeconds > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Session Complete! 🎯"
        content.body = "Your \(Int(totalSeconds / 60))-minute \(sessionType.displayName.lowercased()) session is done. Great focus!"
        content.sound = .default
        content.categoryIdentifier = "SESSION_COMPLETE"

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, remainingSeconds),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "kairo_session_end",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func cancelBackgroundNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["kairo_session_end"]
        )
    }
}
