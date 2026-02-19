import Foundation
import SwiftUI
import CoreData
import Combine

// MARK: - SessionPhase

/// The current phase of a focus session lifecycle.
///
/// Tracks the full session journey from idle through focus, breaks,
/// and completion. Used by the coordinator and bound by the session view.
enum SessionPhase: String, Equatable {
    /// No session active — ready to configure and start.
    case idle
    /// 3-2-1 countdown before focus begins.
    case preparing
    /// Active focus session in progress.
    case focusing
    /// Session paused by the user.
    case paused
    /// Break between focus blocks (Pomodoro-style).
    case onBreak
    /// Session completed — showing results.
    case completed
}

// MARK: - BreakState

/// Tracks break timing for multi-session blocks.
struct BreakState: Equatable {
    /// Duration of the current break in seconds.
    let duration: TimeInterval
    /// Remaining seconds in the break.
    var remaining: TimeInterval
    /// Which session number in the current block (1-indexed).
    let sessionNumber: Int

    /// Progress from 0.0 (just started) to 1.0 (break over).
    var progress: Double {
        guard duration > 0 else { return 1 }
        return max(0, min(1, 1.0 - (remaining / duration)))
    }

    /// Formatted remaining time for display.
    var remainingDisplay: String { remaining.timerDisplay }
}

// MARK: - SessionCoordinator

/// Central coordinator that orchestrates a focus session across all Kairo subsystems.
///
/// Bridges FocusEngine, SoundManager, DistractionDetector, HapticEngine,
/// NotificationManager, RuleEngine, InsightGenerator, and WidgetDataProvider
/// into a single coherent session lifecycle. Views bind to published state;
/// the coordinator handles all inter-system communication.
///
/// Lifecycle:
/// ```
/// idle → preparing → focusing ↔ paused → completed
///                          ↓
///                       onBreak → (next session or done)
/// ```
@MainActor
final class SessionCoordinator: ObservableObject {

    // MARK: - Published State

    /// Current phase of the session lifecycle.
    @Published private(set) var phase: SessionPhase = .idle

    /// The session type for the current or upcoming session.
    @Published var selectedSessionType: KairoTheme.SessionType = .work

    /// The duration in minutes for the current or upcoming session.
    @Published var selectedDurationMinutes: Int = KairoTheme.SessionPreset.defaultDuration

    /// Break state when in the `.onBreak` phase.
    @Published private(set) var breakState: BreakState?

    /// Number of sessions completed in the current block (for break scheduling).
    @Published private(set) var sessionsInBlock: Int = 0

    /// Whether to show the sound picker sheet.
    @Published var showSoundPicker: Bool = false

    /// Whether to show the completion screen overlay.
    @Published var showCompletionScreen: Bool = false

    /// Whether to show the distraction return overlay.
    @Published var showDistractionOverlay: Bool = false
    @Published var lastAwayDuration: TimeInterval = 0

    /// The latest pre-session insight from InsightGenerator.
    @Published var currentInsight: Insight?

    /// RuleEngine's suggested duration in minutes for the current context.
    @Published private(set) var suggestedDurationMinutes: Int = 25

    /// RuleEngine's contextual message for the session start screen.
    @Published private(set) var contextualMessage: String = ""

    /// Predicted quality for the upcoming session.
    @Published private(set) var predictedQuality: FocusQuality = .medium

    // MARK: - Dependencies

    private let focusEngine: FocusEngine
    private let soundManager: SoundManager
    private let distractionDetector: DistractionDetector
    private let hapticEngine: HapticEngine
    private let notificationManager: NotificationManager
    private let ruleEngine: RuleEngine
    private let insightGenerator: InsightGenerator
    private let widgetDataProvider: WidgetDataProvider
    private let persistenceController: PersistenceController

    // MARK: - Derived Stores

    private lazy var sessionStore: SessionStore = {
        SessionStore(context: persistenceController.container.viewContext)
    }()

    private lazy var dailyScoreCalculator: DailyScoreCalculator = {
        DailyScoreCalculator(context: persistenceController.container.viewContext)
    }()

    // MARK: - Internal State

    private var breakTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var backgroundEntryDate: Date?
    private var backgroundObserver: Any?
    private var foregroundObserver: Any?

    // MARK: - Init

    init(
        focusEngine: FocusEngine,
        soundManager: SoundManager,
        distractionDetector: DistractionDetector,
        hapticEngine: HapticEngine,
        notificationManager: NotificationManager,
        ruleEngine: RuleEngine,
        insightGenerator: InsightGenerator,
        widgetDataProvider: WidgetDataProvider,
        persistenceController: PersistenceController
    ) {
        self.focusEngine = focusEngine
        self.soundManager = soundManager
        self.distractionDetector = distractionDetector
        self.hapticEngine = hapticEngine
        self.notificationManager = notificationManager
        self.ruleEngine = ruleEngine
        self.insightGenerator = insightGenerator
        self.widgetDataProvider = widgetDataProvider
        self.persistenceController = persistenceController

        setupEngineCallbacks()
        setupLifecycleObservers()
        refreshSuggestions()
    }

    deinit {
        if let obs = backgroundObserver {
            NotificationCenter.default.removeObserver(obs)
        }
        if let obs = foregroundObserver {
            NotificationCenter.default.removeObserver(obs)
        }
        breakTimer?.invalidate()
    }

    // MARK: - Suggestion Refresh

    /// Rebuilds suggestions from the RuleEngine using current context.
    ///
    /// Called on init, after each session completes, and when the user
    /// returns to the idle state.
    func refreshSuggestions() {
        let context = buildSessionContext()

        let suggestedSeconds = ruleEngine.suggestSessionLength(for: context)
        suggestedDurationMinutes = max(10, Int(suggestedSeconds / 60))
        selectedDurationMinutes = suggestedDurationMinutes

        let suggestedType = ruleEngine.suggestSessionType(for: context)
        if let type = KairoTheme.SessionType(rawValue: suggestedType) {
            selectedSessionType = type
        }

        contextualMessage = ruleEngine.generateSessionMessage(for: context)

        let prediction = ruleEngine.predictQuality(for: context)
        predictedQuality = prediction.quality

        currentInsight = insightGenerator.generateSessionPreview(
            suggestedDuration: suggestedSeconds,
            predictedQuality: prediction.quality,
            context: context
        )
    }

    // MARK: - Session Lifecycle

    /// Starts a new focus session with the currently selected type and duration.
    ///
    /// Orchestrates across all subsystems: configures the engine, starts ambient
    /// sound, begins distraction monitoring, plays the session-start haptic,
    /// and schedules a completion notification as a background fallback.
    func startSession() {
        guard phase == .idle || phase == .completed else { return }

        // Reset completion state
        showCompletionScreen = false
        showDistractionOverlay = false

        // Configure engine
        focusEngine.configure(
            duration: selectedDurationMinutes,
            type: selectedSessionType
        )

        // Prepare haptic engine
        hapticEngine.prepare()

        // Start the engine (enters preparing → focusing)
        focusEngine.startSession()
        phase = .preparing

        // Start ambient sound if not silence
        if soundManager.selectedSound != .silence {
            soundManager.play()
        }

        // Start distraction monitoring
        distractionDetector.startMonitoring()

        // Play countdown haptics
        hapticEngine.playCountdown()

        // Schedule completion notification (background fallback)
        let durationSeconds = TimeInterval(selectedDurationMinutes * 60)
        // Add ~3s for the preparing countdown
        notificationManager.scheduleSessionComplete(
            in: durationSeconds + 3,
            sessionType: selectedSessionType.displayName,
            duration: selectedDurationMinutes
        )
    }

    /// Starts a session continuing from a break (uses existing block count).
    func startNextSessionInBlock() {
        breakTimer?.invalidate()
        breakTimer = nil
        breakState = nil

        // Refresh suggestions for the next session
        refreshSuggestions()
        startSession()
    }

    /// Pauses the active session.
    ///
    /// Pauses the engine and sound, records a manual pause distraction,
    /// notifies the detector, and plays a warning haptic.
    func pauseSession() {
        guard phase == .focusing else { return }

        focusEngine.pause()
        soundManager.pause()
        distractionDetector.recordDistraction(type: .manualPause)
        distractionDetector.sessionDidPause()
        hapticEngine.play(.warning)

        phase = .paused
    }

    /// Resumes a paused session.
    ///
    /// Resumes engine, sound, and distraction detector. Plays a subtle haptic.
    func resumeSession() {
        guard phase == .paused else { return }

        focusEngine.resume()
        soundManager.resume()
        distractionDetector.sessionDidResume()
        hapticEngine.play(.breakComplete)

        phase = .focusing
    }

    /// Stops the session early. Delegates to the engine's stop logic
    /// which determines completed vs abandoned based on 50% threshold.
    func stopSession() {
        guard phase == .focusing || phase == .paused else { return }
        focusEngine.stop()
    }

    /// Hard-cancels the session with no completion record (e.g. during preparing).
    func cancelSession() {
        focusEngine.cancel()
        teardownSessionSubsystems()
        phase = .idle
        refreshSuggestions()
    }

    /// Marks the session as abandoned if < 50% complete, otherwise completed.
    /// Called by the UI "give up" action.
    func abandonSession() {
        guard phase == .focusing || phase == .paused else { return }
        focusEngine.stop()
    }

    // MARK: - Break Management

    /// Transitions to a break period after a completed session.
    ///
    /// Uses the RuleEngine to determine break duration based on the session
    /// count in the current block and the quality of the last session.
    ///
    /// - Parameter quality: Quality of the just-completed session.
    func startBreak(quality: FocusQuality) {
        let breakDuration = ruleEngine.suggestBreakLength(
            sessionCount: sessionsInBlock,
            quality: quality
        )

        breakState = BreakState(
            duration: breakDuration,
            remaining: breakDuration,
            sessionNumber: sessionsInBlock
        )

        phase = .onBreak
        hapticEngine.play(.breakStart)

        // Schedule break-end notification
        let content = "Your break is over — ready for session \(sessionsInBlock + 1)?"
        scheduleBreakEndNotification(in: breakDuration, message: content)

        // Start break countdown timer
        startBreakTimer()
    }

    /// Ends the current break and returns to idle for the next session.
    func endBreak() {
        breakTimer?.invalidate()
        breakTimer = nil
        breakState = nil
        cancelBreakEndNotification()

        hapticEngine.play(.breakComplete)
        phase = .idle
        refreshSuggestions()
    }

    /// Skips the break and immediately prepares the next session.
    func skipBreak() {
        endBreak()
    }

    // MARK: - Completion Handling

    /// Called internally when FocusEngine signals session completion.
    ///
    /// Calculates the final focus score with distraction penalty, saves to Core Data,
    /// updates widget data, plays the completion haptic, generates post-session
    /// insights, and transitions to the completion state.
    private func handleSessionCompleted(session: FocusSession) {
        teardownSessionSubsystems()

        sessionsInBlock += 1

        // Recalculate daily score
        dailyScoreCalculator.calculateAndSave()

        // Update widget data
        updateWidgetDataAfterSession()

        // Play celebration haptic
        hapticEngine.play(.sessionComplete)

        // Cancel streak reminder (user focused today)
        notificationManager.cancelStreakReminder()

        // Check milestones
        checkAndRecordMilestones()

        // Update custom goal progress
        let sessionMinutes = Int(session.actualDuration) / 60
        CustomGoalStore().recordSessionAndSync(sessionMinutes: max(1, sessionMinutes))

        phase = .completed
        showCompletionScreen = true
    }

    /// Called internally when FocusEngine signals session abandonment.
    private func handleSessionAbandoned(session: FocusSession) {
        teardownSessionSubsystems()

        // Still recalculate daily score (abandoned sessions lower it)
        dailyScoreCalculator.calculateAndSave()
        updateWidgetDataAfterSession()

        hapticEngine.play(.warning)

        // Still count toward goals — any focus time matters
        let sessionMinutes = Int(session.actualDuration) / 60
        if sessionMinutes > 0 {
            CustomGoalStore().recordSessionAndSync(sessionMinutes: sessionMinutes)
        }

        phase = .completed
        showCompletionScreen = true
    }

    /// Resets the coordinator to idle after viewing the completion screen.
    func resetToIdle() {
        showCompletionScreen = false
        focusEngine.resetForNewSession()
        phase = .idle
        refreshSuggestions()
    }

    /// Resets the session block counter (e.g. when the user is done for now).
    func resetBlock() {
        sessionsInBlock = 0
    }

    // MARK: - Engine Callbacks

    /// Wires FocusEngine callbacks to coordinator methods.
    private func setupEngineCallbacks() {
        focusEngine.onSessionCompleted = { [weak self] session in
            self?.handleSessionCompleted(session: session)
        }

        focusEngine.onSessionAbandoned = { [weak self] session in
            self?.handleSessionAbandoned(session: session)
        }

        focusEngine.onStateChanged = { [weak self] newState in
            self?.handleEngineStateChange(newState)
        }
    }

    /// Maps FocusEngine state transitions to coordinator phase updates.
    private func handleEngineStateChange(_ state: TimerState) {
        switch state {
        case .preparing:
            phase = .preparing
        case .focusing:
            phase = .focusing
        case .paused:
            phase = .paused
        case .completed, .abandoned:
            // Handled by the specific completion/abandonment callbacks
            break
        case .idle:
            if phase != .onBreak && phase != .completed {
                phase = .idle
            }
        case .onBreak:
            break
        }
    }

    // MARK: - Subsystem Teardown

    /// Stops all session-related subsystems (sound, distraction monitoring, notifications).
    private func teardownSessionSubsystems() {
        soundManager.stop()
        distractionDetector.stopMonitoring()
        notificationManager.cancelSessionComplete()
    }

    // MARK: - Break Timer

    /// Starts a 1-second interval timer to count down the break.
    private func startBreakTimer() {
        breakTimer?.invalidate()

        breakTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self, var currentBreak = self.breakState else {
                    timer.invalidate()
                    return
                }

                currentBreak.remaining = max(0, currentBreak.remaining - 1)
                self.breakState = currentBreak

                if currentBreak.remaining <= 0 {
                    timer.invalidate()
                    self.breakTimer = nil
                    self.endBreak()
                }
            }
        }

        if let timer = breakTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    // MARK: - Break Notifications

    /// Schedules a local notification for when the break ends.
    private func scheduleBreakEndNotification(in interval: TimeInterval, message: String) {
        guard notificationManager.isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Break's Over ⏱️"
        content.body = message
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, interval),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "kairo_break_end",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Cancels the pending break-end notification.
    private func cancelBreakEndNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["kairo_break_end"]
        )
    }

    // MARK: - App Lifecycle

    /// Registers for background/foreground notifications to manage
    /// the distraction overlay when the user leaves during a session.
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

    /// Tracks background entry for the distraction overlay.
    private func handleDidEnterBackground() {
        guard phase == .focusing || phase == .paused else { return }
        backgroundEntryDate = Date()
    }

    /// Shows the distraction overlay if the user was away for more than 3 seconds.
    private func handleWillEnterForeground() {
        guard phase == .focusing || phase == .paused else { return }

        if let bgEntry = backgroundEntryDate {
            let awayDuration = Date().timeIntervalSince(bgEntry)
            lastAwayDuration = awayDuration
            if awayDuration > 3 {
                showDistractionOverlay = true
                hapticEngine.play(.distraction)
            }
        }
        backgroundEntryDate = nil
    }

    /// Dismisses the distraction overlay (called by the view).
    func dismissDistractionOverlay() {
        showDistractionOverlay = false
    }

    // MARK: - Widget Update

    /// Pushes current session metrics to the widget data provider.
    private func updateWidgetDataAfterSession() {
        let context = persistenceController.container.viewContext
        let store = SessionStore(context: context)
        let todaySessions = store.fetchToday()
        let completed = todaySessions.filter { $0.isCompleted }

        let totalMinutes = completed.reduce(0) { $0 + Int($1.actualDuration) / 60 }
        let avgScore = completed.isEmpty
            ? 0
            : Int(completed.reduce(Float(0)) { $0 + $1.focusScore } / Float(completed.count))
        let bestHour = completed.isEmpty
            ? nil
            : completed.max(by: { $0.focusScore < $1.focusScore })?.startedAt.hour

        // Fetch streak
        let streakRequest = FocusStreak.fetchRequest()
        streakRequest.predicate = NSPredicate(format: "isActive == YES")
        streakRequest.fetchLimit = 1
        let streak = (try? context.fetch(streakRequest))?.first
        let streakDays = Int(streak?.currentLength ?? 0)

        widgetDataProvider.updateFocusData(
            totalMinutes: totalMinutes,
            score: avgScore,
            sessions: completed.count,
            streak: streakDays,
            bestHour: bestHour
        )
    }

    // MARK: - Milestones

    /// Checks for session-count and streak milestones after a completed session.
    private func checkAndRecordMilestones() {
        let context = persistenceController.container.viewContext
        let store = SessionStore(context: context)
        let totalCompleted = store.fetchCompleted(last: 3650).count // all time

        // Session count milestones
        let sessionMilestones = [10, 25, 50, 100]
        if sessionMilestones.contains(totalCompleted) {
            if let milestone = insightGenerator.generateMilestoneInsight(
                type: .sessionCount,
                value: totalCompleted
            ) {
                currentInsight = milestone
            }
        }

        // Streak milestones
        let streakRequest = FocusStreak.fetchRequest()
        streakRequest.predicate = NSPredicate(format: "isActive == YES")
        streakRequest.fetchLimit = 1
        if let streak = (try? context.fetch(streakRequest))?.first {
            let days = Int(streak.currentLength)
            let streakMilestones = [3, 7, 14, 30]
            if streakMilestones.contains(days) {
                if let milestone = insightGenerator.generateMilestoneInsight(
                    type: .streakDays,
                    value: days
                ) {
                    currentInsight = milestone
                }
            }
        }

        // Total minutes milestones
        let allSessions = store.fetchCompleted(last: 3650)
        let totalMinutes = allSessions.reduce(0) { $0 + Int($1.actualDuration) / 60 }
        let minuteMilestones = [500, 1000, 2500, 5000]
        if minuteMilestones.contains(totalMinutes) {
            if let milestone = insightGenerator.generateMilestoneInsight(
                type: .totalMinutes,
                value: totalMinutes
            ) {
                currentInsight = milestone
            }
        }
    }

    // MARK: - Context Builder

    /// Builds a `SessionContext` from current app state for RuleEngine queries.
    private func buildSessionContext() -> SessionContext {
        let context = persistenceController.container.viewContext
        let store = SessionStore(context: context)

        let todaySessions = store.fetchToday()
        let completedToday = todaySessions.filter { $0.isCompleted }

        let recentSessions = store.fetchCompleted(last: 7)
        let allRecentStarted = store.fetchSessions(
            from: Calendar.current.date(byAdding: .day, value: -7, to: Date())!,
            to: Date()
        )
        let rollingRate = allRecentStarted.isEmpty
            ? 0.8
            : Double(recentSessions.count) / Double(allRecentStarted.count)

        let lastSession = store.fetchAll(limit: 1).first
        let lastAbandoned = lastSession?.isAbandoned ?? false
        let lastQuality: FocusQuality? = lastSession.flatMap {
            FocusQuality(rating: $0.qualityRating)
        }

        let streakRequest = FocusStreak.fetchRequest()
        streakRequest.predicate = NSPredicate(format: "isActive == YES")
        streakRequest.fetchLimit = 1
        let streak = (try? context.fetch(streakRequest))?.first
        let streakDays = streak?.isCurrentlyValid == true ? Int(streak!.currentLength) : 0

        return SessionContext.now(
            streak: streakDays,
            lastAbandoned: lastAbandoned,
            sessionsToday: completedToday.count,
            lastQuality: lastQuality,
            completionRate: rollingRate
        )
    }
}
