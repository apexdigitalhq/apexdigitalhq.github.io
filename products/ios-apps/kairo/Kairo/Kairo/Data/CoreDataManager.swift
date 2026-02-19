import Foundation
import CoreData
import Combine

/// Central data layer that bridges Core Data with the rest of the Kairo app.
///
/// Provides a unified, `ObservableObject`-based interface for session CRUD,
/// daily score management, streak tracking, and focus pattern updates.
/// Delegates entity-level operations to `SessionStore`, `ScoreStore`, and
/// `PatternStore` while adding higher-level coordination logic (streak
/// management, score recalculation, pattern sync).
///
/// Usage:
/// ```swift
/// let manager = CoreDataManager()
/// let session = manager.saveSession(startedAt: Date(), ...)
/// manager.updateStreak()
/// manager.recalculateTodayScore()
/// ```
///
/// All operations execute on `@MainActor` using the shared view context.
@MainActor
final class CoreDataManager: ObservableObject {

    // MARK: - Singleton

    /// Shared instance for app-wide access.
    static let shared = CoreDataManager()

    // MARK: - Published State

    /// Total completed sessions today, updated after saves.
    @Published private(set) var todayCompletedCount: Int = 0

    /// Current active streak length in days.
    @Published private(set) var currentStreakDays: Int = 0

    /// Today's focus score (0–100), if computed.
    @Published private(set) var todayFocusScore: Float = 0

    // MARK: - Dependencies

    private let context: NSManagedObjectContext
    private let sessionStore: SessionStore
    private let scoreStore: ScoreStore
    private let patternStore: PatternStore
    private let scoreCalculator: DailyScoreCalculator

    // MARK: - Init

    /// Creates a `CoreDataManager` using the given managed object context.
    ///
    /// - Parameter context: The Core Data context to operate on.
    ///   Defaults to `PersistenceController.shared.container.viewContext`.
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
        self.sessionStore = SessionStore(context: context)
        self.scoreStore = ScoreStore(context: context)
        self.patternStore = PatternStore(context: context)
        self.scoreCalculator = DailyScoreCalculator(context: context)

        refreshPublishedState()
    }

    // MARK: - Session CRUD

    /// Creates and persists a new `FocusSession` entity with the given parameters.
    ///
    /// - Parameters:
    ///   - startedAt: When the session began.
    ///   - endedAt: When the session ended (nil if still active).
    ///   - targetDuration: Planned duration in seconds.
    ///   - actualDuration: Actual focus duration in seconds.
    ///   - sessionType: Type tag — "work", "study", "creative", "personal".
    ///   - status: Completion status — "completed", "abandoned", "active".
    ///   - soundscape: Selected ambient sound, or nil for silence.
    ///   - pauseCount: Number of manual pauses during the session.
    ///   - distractionCount: Number of detected distractions.
    ///   - qualityRating: Assessed quality — "high", "medium", "low".
    ///   - focusScore: Computed focus score (0–100).
    ///   - notes: Optional user notes.
    /// - Returns: The newly created `FocusSession` entity.
    @discardableResult
    func saveSession(
        startedAt: Date,
        endedAt: Date?,
        targetDuration: Int32,
        actualDuration: Int32,
        sessionType: String = "work",
        status: String = "completed",
        soundscape: String? = nil,
        pauseCount: Int16 = 0,
        distractionCount: Int16 = 0,
        qualityRating: String = "medium",
        focusScore: Float = 0,
        notes: String? = nil
    ) -> FocusSession {
        let session = FocusSession(context: context)
        session.id = UUID()
        session.startedAt = startedAt
        session.endedAt = endedAt
        session.targetDuration = targetDuration
        session.actualDuration = actualDuration
        session.sessionType = sessionType
        session.status = status
        session.soundscape = soundscape
        session.pauseCount = pauseCount
        session.distractionCount = distractionCount
        session.qualityRating = qualityRating
        session.focusScore = focusScore
        session.notes = notes
        session.createdAt = Date()

        saveContext()
        refreshPublishedState()
        return session
    }

    /// Fetches all sessions that started today, regardless of status.
    ///
    /// - Returns: Array of `FocusSession` entities sorted by start time ascending.
    func fetchTodaySessions() -> [FocusSession] {
        sessionStore.fetchToday()
    }

    /// Fetches all sessions from the last 7 calendar days.
    ///
    /// - Returns: Array of `FocusSession` entities sorted by start time ascending.
    func fetchSessionsForWeek() -> [FocusSession] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date().startOfDay) ?? Date()
        return sessionStore.fetchSessions(from: weekAgo, to: Date())
    }

    /// Fetches all sessions, optionally limited.
    ///
    /// - Parameter limit: Maximum number of sessions to return.
    ///   Pass `nil` for all sessions.
    /// - Returns: Array of `FocusSession` entities, most recent first.
    func fetchAllSessions(limit: Int? = nil) -> [FocusSession] {
        sessionStore.fetchAll(limit: limit)
    }

    /// Deletes a session and its associated distraction events from Core Data.
    ///
    /// After deletion, recalculates the daily score for the session's date
    /// and refreshes published state.
    ///
    /// - Parameter session: The `FocusSession` entity to delete.
    func deleteSession(_ session: FocusSession) {
        let sessionDate = session.startedAt
        sessionStore.delete(session)

        // Recalculate score for the day the deleted session belonged to
        scoreCalculator.calculateAndSave(for: sessionDate)
        refreshPublishedState()
    }

    // MARK: - Score CRUD

    /// Creates or updates a `DailyScore` entity for the given date.
    ///
    /// If a score already exists for the date, it is updated in place.
    /// Otherwise, a new entity is created.
    ///
    /// - Parameters:
    ///   - date: The calendar date for the score (midnight-normalized).
    ///   - completionRate: Session completion rate (0.0–1.0).
    ///   - qualityFactor: Average quality factor (0.0–1.0).
    ///   - consistencyFactor: Consistency factor (0.0–1.0).
    ///   - focusScore: Overall focus score (0–100).
    ///   - sessionsStarted: Number of sessions started that day.
    ///   - sessionsCompleted: Number of sessions completed.
    ///   - totalFocusMinutes: Total focus time in minutes.
    ///   - bestHour: Hour with the highest quality sessions (0–23).
    ///   - dominantType: Most-used session type that day.
    /// - Returns: The created or updated `DailyScore` entity.
    @discardableResult
    func saveDailyScore(
        date: Date = Date(),
        completionRate: Float = 0,
        qualityFactor: Float = 0,
        consistencyFactor: Float = 0,
        focusScore: Float = 0,
        sessionsStarted: Int16 = 0,
        sessionsCompleted: Int16 = 0,
        totalFocusMinutes: Int32 = 0,
        bestHour: Int16 = 0,
        dominantType: String = "work"
    ) -> DailyScore {
        let score = scoreStore.fetchOrCreate(for: date)
        score.completionRate = completionRate
        score.qualityFactor = qualityFactor
        score.consistencyFactor = consistencyFactor
        score.focusScore = focusScore
        score.sessionsStarted = sessionsStarted
        score.sessionsCompleted = sessionsCompleted
        score.totalFocusMinutes = totalFocusMinutes
        score.bestHour = bestHour
        score.dominantType = dominantType

        saveContext()
        refreshPublishedState()
        return score
    }

    /// Fetches today's daily score, if one has been computed.
    ///
    /// - Returns: The `DailyScore` for today, or `nil` if no sessions were recorded.
    func fetchTodayScore() -> DailyScore? {
        scoreStore.fetchScore(for: Date())
    }

    /// Fetches daily scores for the last 7 calendar days.
    ///
    /// - Returns: Array of `DailyScore` entities sorted by date ascending.
    func fetchScoresForWeek() -> [DailyScore] {
        scoreStore.fetchScores(last: 7)
    }

    /// Recalculates and saves today's daily score from the current session data.
    ///
    /// Delegates to `DailyScoreCalculator` which applies the weighted formula:
    /// `focusTime × 0.4 + avgScore × 0.3 + sessionCount × 0.2 + streakBonus × 0.1`.
    ///
    /// - Returns: The recalculated `DailyScore` entity.
    @discardableResult
    func recalculateTodayScore() -> DailyScore {
        let score = scoreCalculator.calculateAndSave()
        refreshPublishedState()
        return score
    }

    // MARK: - Streak Management

    /// Updates the focus streak based on today's session activity.
    ///
    /// If today has at least one completed session, marks today as active
    /// on the streak entity (extending or resetting as needed). Creates
    /// a new streak if none exists.
    func updateStreak() {
        let todaySessions = fetchTodaySessions()
        let hasQualifyingSession = todaySessions.contains { $0.isCompleted }

        guard hasQualifyingSession else { return }

        let request = FocusStreak.fetchRequest()
        request.fetchLimit = 1

        do {
            let streak: FocusStreak
            if let existing = try context.fetch(request).first {
                streak = existing
            } else {
                streak = FocusStreak.createNew(in: context)
            }

            streak.recordActivity()
            saveContext()
            currentStreakDays = Int(streak.currentLength)
        } catch {
            logError("Failed to update streak", error)
        }
    }

    /// Returns the current active streak length in days.
    ///
    /// If the streak has lapsed (last activity > 1 day ago), returns 0.
    ///
    /// - Returns: Current streak length, or 0 if no active streak.
    func getCurrentStreak() -> Int {
        do {
            let request = FocusStreak.fetchRequest()
            request.predicate = NSPredicate(format: "isActive == YES")
            request.fetchLimit = 1

            guard let streak = try context.fetch(request).first else { return 0 }
            return streak.isCurrentlyValid ? Int(streak.currentLength) : 0
        } catch {
            logError("Failed to fetch current streak", error)
            return 0
        }
    }

    /// Returns the all-time longest streak in days.
    ///
    /// - Returns: Longest streak ever recorded, or 0 if no history.
    func getLongestStreak() -> Int {
        do {
            let request = FocusStreak.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \FocusStreak.longestLength, ascending: false)
            ]
            request.fetchLimit = 1

            guard let streak = try context.fetch(request).first else { return 0 }
            return Int(streak.longestLength)
        } catch {
            logError("Failed to fetch longest streak", error)
            return 0
        }
    }

    /// Returns a boolean array indicating whether the user completed at least
    /// one session on each of the last 7 calendar days.
    ///
    /// Index 0 = 6 days ago, Index 6 = today.
    ///
    /// - Returns: Array of 7 booleans, oldest first.
    func getLast7DaysActivity() -> [Bool] {
        let days = Date.lastDays(7)
        return days.map { day in
            let dayStart = day.startOfDay
            let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            let daySessions = sessionStore.fetchSessions(from: dayStart, to: dayEnd)
            return daySessions.contains { $0.isCompleted }
        }
    }

    // MARK: - Pattern Update

    /// Updates the `FocusPattern` entity using results from the analyzer.
    ///
    /// Fetches all completed sessions, runs them through the analyzer's
    /// pattern detection, and persists the updated pattern to Core Data.
    ///
    /// - Parameter analyzer: The `FocusPatternAnalyzer` that performs the analysis.
    func updateFocusPattern(from analyzer: FocusPatternAnalyzer) {
        let pattern = patternStore.fetchOrCreate()

        let allSessions = sessionStore.fetchAll()
        let completed = allSessions.filter { $0.isCompleted }

        guard !completed.isEmpty else { return }

        analyzer.analyzePatterns(sessions: completed, into: pattern)
        saveContext()
    }

    // MARK: - Convenience Queries

    /// Returns the total number of completed sessions across all time.
    func totalCompletedSessionCount() -> Int {
        let request = FocusSession.fetchRequest()
        request.predicate = NSPredicate(format: "status == %@", "completed")
        do {
            return try context.count(for: request)
        } catch {
            logError("Failed to count completed sessions", error)
            return 0
        }
    }

    /// Returns total focus minutes today.
    func todayFocusMinutes() -> Int {
        let sessions = fetchTodaySessions().filter { $0.isCompleted }
        return sessions.reduce(0) { $0 + Int($1.actualDuration) / 60 }
    }

    /// Returns the user's `FocusPattern`, creating a default if none exists.
    func fetchFocusPattern() -> FocusPattern {
        patternStore.fetchOrCreate()
    }

    /// Returns the active `FocusStreak` entity, or nil if none exists.
    func fetchActiveStreak() -> FocusStreak? {
        let request = FocusStreak.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    // MARK: - Private Helpers

    /// Refreshes all published state properties from the current data.
    private func refreshPublishedState() {
        let todayCompleted = fetchTodaySessions().filter { $0.isCompleted }
        todayCompletedCount = todayCompleted.count

        currentStreakDays = getCurrentStreak()

        if let score = fetchTodayScore() {
            todayFocusScore = score.focusScore
        } else {
            todayFocusScore = 0
        }
    }

    /// Saves the managed object context, logging any errors.
    private func saveContext() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            logError("Core Data save failed", error)
        }
    }

    /// Logs an error to the console in debug builds.
    private func logError(_ message: String, _ error: Error) {
        #if DEBUG
        print("[CoreDataManager] \(message): \(error.localizedDescription)")
        #endif
    }
}
