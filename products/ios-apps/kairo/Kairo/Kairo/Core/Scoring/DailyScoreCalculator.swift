import Foundation
import CoreData

/// Calculates daily focus scores from completed sessions and persists via ScoreStore.
///
/// **Weighted Formula (normalized 0–100):**
/// ```
/// total_focus_time × 0.4
/// + avg_session_score × 0.3
/// + sessions_completed × 0.2
/// + streak_bonus × 0.1
/// ```
final class DailyScoreCalculator {

    private let sessionStore: SessionStore
    private let scoreStore: ScoreStore
    private let context: NSManagedObjectContext

    // MARK: - Normalization Ceilings

    /// Maximum daily focus minutes before the time component saturates at 1.0.
    private let maxDailyFocusMinutes: Float = 240  // 4 hours

    /// Maximum sessions per day before the count component saturates at 1.0.
    private let maxDailySessions: Float = 8

    /// Maximum streak days before the bonus component saturates at 1.0.
    private let maxStreakDays: Float = 30

    // MARK: - Weights

    private let weightFocusTime: Float     = 0.4
    private let weightAvgScore: Float      = 0.3
    private let weightSessionCount: Float  = 0.2
    private let weightStreak: Float        = 0.1

    // MARK: - Init

    init(
        context: NSManagedObjectContext = PersistenceController.shared.container.viewContext
    ) {
        self.context = context
        self.sessionStore = SessionStore(context: context)
        self.scoreStore = ScoreStore(context: context)
    }

    // MARK: - Calculate & Save

    /// Calculates the daily score for a given date from all sessions that day,
    /// saves it to Core Data, and returns the resulting `DailyScore`.
    @discardableResult
    func calculateAndSave(for date: Date = Date()) -> DailyScore {
        let dayStart = date.startOfDay
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!

        let sessions = sessionStore.fetchSessions(from: dayStart, to: dayEnd)
        // Include both completed and abandoned sessions (abandoned have partial scores)
        let completed = sessions.filter { $0.status == "completed" || $0.status == "abandoned" }

        // -- Component 1: Total Focus Time (normalized against ceiling)
        let totalFocusMinutes = completed.reduce(Float(0)) { $0 + Float($1.actualDuration) / 60.0 }
        let focusTimeNormalized = min(totalFocusMinutes / maxDailyFocusMinutes, 1.0)

        // -- Component 2: Average Session Score (already 0–100, normalize to 0–1)
        let avgSessionScore: Float = completed.isEmpty
            ? 0
            : completed.reduce(Float(0)) { $0 + $1.focusScore } / Float(completed.count) / 100.0

        // -- Component 3: Sessions Completed (normalized against ceiling)
        let sessionCountNormalized = min(Float(completed.count) / maxDailySessions, 1.0)

        // -- Component 4: Streak Bonus (normalized against ceiling)
        let streakLength = fetchCurrentStreakLength()
        let streakNormalized = min(Float(streakLength) / maxStreakDays, 1.0)

        // -- Weighted Sum → 0–1 range → scale to 0–100
        let rawScore = focusTimeNormalized * weightFocusTime
            + avgSessionScore * weightAvgScore
            + sessionCountNormalized * weightSessionCount
            + streakNormalized * weightStreak

        let finalScore = min(max(rawScore * 100.0, 0), 100)

        // -- Determine dominant session type
        let typeCounts = Dictionary(grouping: completed, by: \.sessionType)
        let dominantType = typeCounts.max(by: { $0.value.count < $1.value.count })?.key ?? "work"

        // -- Determine best hour
        let hourCounts = Dictionary(grouping: completed, by: { $0.startedAt.hour })
        let bestHour = hourCounts.max(by: { $0.value.count < $1.value.count })?.key ?? 0

        // -- Persist
        let dailyScore = scoreStore.fetchOrCreate(for: dayStart)
        dailyScore.focusScore = finalScore
        dailyScore.totalFocusMinutes = Int32(totalFocusMinutes)
        dailyScore.sessionsStarted = Int16(sessions.count)
        dailyScore.sessionsCompleted = Int16(completed.count)
        dailyScore.completionRate = sessions.isEmpty ? 0 : Float(completed.count) / Float(sessions.count)
        dailyScore.qualityFactor = avgSessionScore
        dailyScore.consistencyFactor = focusTimeNormalized
        dailyScore.dominantType = dominantType
        dailyScore.bestHour = Int16(bestHour)

        scoreStore.save()

        return dailyScore
    }

    // MARK: - Weekly Trend

    /// Returns the last 7 daily scores (oldest first).
    /// Missing days are filled with zero-score placeholders.
    func weeklyTrend() -> [DailyScorePoint] {
        let days = Date.lastDays(7)
        let existingScores = scoreStore.fetchScores(last: 7)

        return days.map { day in
            let match = existingScores.first { $0.date.isSameDay(as: day) }
            return DailyScorePoint(
                date: day,
                score: match?.focusScore ?? 0,
                sessionsCompleted: Int(match?.sessionsCompleted ?? 0),
                totalFocusMinutes: Int(match?.totalFocusMinutes ?? 0)
            )
        }
    }

    /// Returns aggregated stats for the last 7 days.
    func weeklyStats() -> WeeklyStats {
        let trend = weeklyTrend()
        let totalMinutes = trend.reduce(0) { $0 + $1.totalFocusMinutes }
        let totalSessions = trend.reduce(0) { $0 + $1.sessionsCompleted }
        let activeDays = trend.filter { $0.sessionsCompleted > 0 }
        let avgSessionLength = totalSessions > 0 ? totalMinutes / totalSessions : 0
        let bestStreak = longestConsecutiveStreak(in: trend)

        return WeeklyStats(
            totalFocusMinutes: totalMinutes,
            totalSessions: totalSessions,
            avgSessionMinutes: avgSessionLength,
            bestStreak: bestStreak,
            activeDays: activeDays.count,
            trend: trend
        )
    }

    // MARK: - Helpers

    private func fetchCurrentStreakLength() -> Int {
        let request = FocusStreak.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FocusStreak.currentLength, ascending: false)]
        request.fetchLimit = 1

        let streak = (try? context.fetch(request))?.first
        return Int(streak?.currentLength ?? 0)
    }

    private func longestConsecutiveStreak(in points: [DailyScorePoint]) -> Int {
        var maxStreak = 0
        var current = 0
        for point in points {
            if point.sessionsCompleted > 0 {
                current += 1
                maxStreak = max(maxStreak, current)
            } else {
                current = 0
            }
        }
        return maxStreak
    }
}

// MARK: - Data Types

/// A single data point in the weekly trend.
struct DailyScorePoint: Identifiable {
    let id = UUID()
    let date: Date
    let score: Float
    let sessionsCompleted: Int
    let totalFocusMinutes: Int

    var dayLabel: String { date.shortDayName }
    var isEmpty: Bool { sessionsCompleted == 0 }
}

/// Aggregated stats for a week.
struct WeeklyStats {
    let totalFocusMinutes: Int
    let totalSessions: Int
    let avgSessionMinutes: Int
    let bestStreak: Int
    let activeDays: Int
    let trend: [DailyScorePoint]
}
