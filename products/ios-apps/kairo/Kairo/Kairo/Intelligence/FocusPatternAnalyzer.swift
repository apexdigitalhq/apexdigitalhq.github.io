import Foundation
import SwiftUI

// MARK: - FocusFeatures

/// Feature vector extracted from a single session for pattern analysis and ML training.
///
/// Maps directly to the architecture's ML input features (Section 4.4):
/// hour_of_day, day_of_week, session_tag, rolling_completion_rate_7d,
/// sessions_today, last_session_quality, streak_length, avg_session_gap_hours.
struct FocusFeatures: Identifiable {

    let id = UUID()

    /// Hour the session started (0–23).
    let hourOfDay: Int

    /// ISO day of week (1 = Monday, 7 = Sunday).
    let dayOfWeek: Int

    /// Session type tag ("work", "study", "creative", "personal").
    let sessionTag: String

    /// Rolling 7-day completion rate at time of session (0.0–1.0).
    let rollingCompletionRate7d: Double

    /// Sessions already completed on the same day, prior to this one.
    let sessionsToday: Int

    /// Quality of the previous session (.high, .medium, .low), or nil if first.
    let lastSessionQuality: FocusQuality?

    /// Current streak length in days at time of session.
    let streakLength: Int

    /// Average gap in hours between consecutive sessions (rolling window).
    let avgSessionGapHours: Double

    /// Actual duration of the session in seconds (training label for regression).
    let actualDuration: TimeInterval

    /// Session quality outcome (training label for classification).
    let qualityOutcome: FocusQuality

    /// Completion ratio for this session (0.0–1.0).
    let completionRatio: Double

    // MARK: - Dictionary Export

    /// Exports features as a dictionary for Create ML `MLDataTable` construction.
    func asDictionary() -> [String: Any] {
        [
            "hour_of_day": hourOfDay,
            "day_of_week": dayOfWeek,
            "session_tag": sessionTag,
            "rolling_completion_rate_7d": rollingCompletionRate7d,
            "sessions_today": sessionsToday,
            "last_session_quality": lastSessionQuality?.rawValue ?? "none",
            "streak_length": streakLength,
            "avg_session_gap_hours": avgSessionGapHours,
            "actual_duration": actualDuration / 60.0,  // minutes for ML
            "quality_outcome": qualityOutcome.rawValue,
            "completion_ratio": completionRatio
        ]
    }
}

// MARK: - DailyPattern

/// Aggregated focus pattern for a single calendar day.
struct DailyPattern: Identifiable {

    let id = UUID()

    /// Calendar date (midnight-normalized).
    let date: Date

    /// Hour with the highest average quality that day (0–23), or nil if no sessions.
    let bestHour: Int?

    /// Hour with the lowest average quality that day (0–23), or nil if no sessions.
    let worstHour: Int?

    /// Average session duration in seconds across the day's sessions.
    let avgDuration: TimeInterval

    /// Average quality score (0.0–1.0) using `FocusQuality.numericValue`.
    let avgQuality: Double

    /// Total completed sessions that day.
    let sessionsCount: Int

    /// Total focus time in minutes.
    let totalFocusMinutes: Int

    /// Focus score for the day (0–100), if a `DailyScore` was computed.
    let focusScore: Float?
}

// MARK: - TrendDirection

/// Direction of a metric trend over a time window.
enum TrendDirection: String, CaseIterable {
    case improving = "improving"
    case declining = "declining"
    case stable    = "stable"

    /// Human-readable label.
    var displayName: String {
        switch self {
        case .improving: return "Improving"
        case .declining: return "Declining"
        case .stable:    return "Stable"
        }
    }

    /// SF Symbol for the trend direction.
    var iconName: String {
        switch self {
        case .improving: return "arrow.up.right"
        case .declining: return "arrow.down.right"
        case .stable:    return "arrow.right"
        }
    }

    /// Semantic color for the trend.
    var color: Color {
        switch self {
        case .improving: return KairoColors.successAdaptive
        case .declining: return KairoColors.accentAdaptive
        case .stable:    return KairoColors.warningAdaptive
        }
    }
}

// MARK: - WeeklyPattern

/// Aggregated focus pattern across a 7-day window.
struct WeeklyPattern: Identifiable {

    let id = UUID()

    /// ISO day of week with the highest average score (1–7).
    let bestDay: Int

    /// ISO day of week with the lowest average score (1–7).
    let worstDay: Int

    /// Average daily focus score for the week (0–100).
    let avgDailyScore: Double

    /// Trend direction over the week.
    let trend: TrendDirection

    /// Daily patterns for each day in the week (oldest first).
    let dailyPatterns: [DailyPattern]

    /// Total sessions completed across the week.
    let totalSessions: Int

    /// Total focus minutes across the week.
    let totalFocusMinutes: Int

    /// Human-readable best day name (e.g., "Tuesday").
    var bestDayName: String {
        dayName(for: bestDay)
    }

    /// Human-readable worst day name (e.g., "Friday").
    var worstDayName: String {
        dayName(for: worstDay)
    }

    private func dayName(for isoDay: Int) -> String {
        let names = ["", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        guard isoDay >= 1, isoDay <= 7 else { return "Unknown" }
        return names[isoDay]
    }
}

// MARK: - TimeWindow

/// A scored time window representing an optimal focus period.
struct TimeWindow: Identifiable {
    let id = UUID()

    /// Start hour (0–23).
    let start: Int

    /// End hour (0–23, exclusive).
    let end: Int

    /// Quality score for this window (0.0–1.0).
    let score: Double

    /// Formatted display string (e.g., "9:00 AM – 11:00 AM").
    var displayString: String {
        let startStr = hourString(start)
        let endStr = hourString(end)
        return "\(startStr) – \(endStr)"
    }

    private func hourString(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let period = hour < 12 ? "AM" : "PM"
        return "\(h):00 \(period)"
    }
}

// MARK: - FocusPatternAnalyzer

/// Extracts features, detects patterns, and analyzes trends from session history.
///
/// Serves two purposes:
/// 1. **Pre-ML analysis** — provides pattern insights via heuristics for Days 1–14.
/// 2. **Feature extraction** — prepares training data for Core ML models (Day 14+).
///
/// Tracks model readiness (30 sessions = 100%) and publishes the current
/// pattern state for UI binding.
final class FocusPatternAnalyzer: ObservableObject {

    // MARK: - Configuration

    /// Minimum completed sessions before Core ML model can activate.
    private let minimumSessionsForML: Int = 30

    /// Window size for rolling metrics.
    private let rollingWindow: Int = 7

    // MARK: - Published State

    /// The most recently computed `FocusPattern` entity (Core Data), if any.
    @Published var currentPattern: FocusPattern?

    /// Progress toward Core ML activation (0.0–1.0). Displayed as percentage in UI.
    @Published var modelReadinessPercent: Double = 0

    /// The most recently analyzed daily patterns.
    @Published private(set) var recentDailyPatterns: [DailyPattern] = []

    /// The most recently analyzed weekly pattern.
    @Published private(set) var recentWeeklyPattern: WeeklyPattern?

    // MARK: - Dependencies

    private let ruleEngine = RuleEngine()

    // MARK: - Pattern Analysis

    /// Analyzes an array of completed sessions and updates the given Core Data
    /// `FocusPattern` entity with discovered patterns.
    ///
    /// - Parameters:
    ///   - sessions: All completed `FocusSession` entities, sorted by date ascending.
    ///   - pattern: The `FocusPattern` Core Data entity to update.
    /// - Returns: The updated `FocusPattern`.
    @discardableResult
    func analyzePatterns(sessions: [FocusSession], into pattern: FocusPattern) -> FocusPattern {
        let completed = sessions.filter { $0.isCompleted }
        guard !completed.isEmpty else { return pattern }

        // -- Optimal duration (weighted average of recent sessions)
        let recentSessions = Array(completed.suffix(20))
        let weightedDuration = computeWeightedAverage(
            values: recentSessions.map { Double($0.actualDuration) / 60.0 },
            decayFactor: 0.95
        )
        pattern.optimalDuration = Float(weightedDuration)

        // -- Best time window
        let windows = detectOptimalTimeWindows(sessions: completed)
        if let bestWindow = windows.first {
            pattern.bestHourStart = Int16(bestWindow.start)
            pattern.bestHourEnd = Int16(bestWindow.end)
        }

        // -- Best day of week
        let dayScores = computeDayOfWeekScores(sessions: completed)
        if let bestDay = dayScores.max(by: { $0.value < $1.value }) {
            pattern.bestDayOfWeek = Int16(bestDay.key)
        }

        // -- Aggregate metrics
        let totalStarted = sessions.count
        let totalCompleted = completed.count
        pattern.avgCompletionRate = totalStarted > 0
            ? Float(totalCompleted) / Float(totalStarted)
            : 0

        // Sessions per day (over last 7 days)
        let last7Days = completed.filter {
            $0.startedAt.timeIntervalSinceNow > -7 * 24 * 3600
        }
        pattern.avgSessionsPerDay = Float(last7Days.count) / 7.0

        // -- Metadata
        pattern.dataPointCount = Int32(completed.count)
        pattern.updatedAt = Date()

        // -- Model readiness
        let readiness = computeModelReadiness(totalSessions: completed.count)
        pattern.ruleEngineActive = !readiness.isReady
        modelReadinessPercent = readiness.percentage

        currentPattern = pattern
        return pattern
    }

    // MARK: - Feature Extraction

    /// Extracts a `FocusFeatures` vector from a single session and its surrounding context.
    ///
    /// - Parameters:
    ///   - session: The `FocusSession` to extract features from.
    ///   - allSessions: All sessions for computing rolling metrics.
    ///   - streakLength: Current streak at time of session.
    /// - Returns: A `FocusFeatures` instance ready for ML training or analysis.
    func extractFeatures(
        from session: FocusSession,
        allSessions: [FocusSession],
        streakLength: Int = 0
    ) -> FocusFeatures {
        let sessionDate = session.startedAt

        // Rolling 7-day completion rate
        let windowStart = Calendar.current.date(byAdding: .day, value: -7, to: sessionDate)!
        let windowSessions = allSessions.filter {
            $0.startedAt >= windowStart && $0.startedAt < sessionDate
        }
        let windowCompleted = windowSessions.filter { $0.isCompleted }.count
        let rollingRate = windowSessions.isEmpty
            ? 0.8  // default assumption
            : Double(windowCompleted) / Double(windowSessions.count)

        // Sessions today before this one
        let dayStart = sessionDate.startOfDay
        let sessionsBeforeToday = allSessions.filter {
            $0.startedAt >= dayStart && $0.startedAt < sessionDate && $0.isCompleted
        }.count

        // Last session quality
        let previousSessions = allSessions.filter { $0.startedAt < sessionDate && $0.isCompleted }
        let lastQuality: FocusQuality? = previousSessions.last.map { ruleEngine.assessQuality($0) }

        // Average session gap
        let gaps = computeSessionGaps(sessions: allSessions.filter { $0.isCompleted })
        let avgGap = gaps.isEmpty ? 4.0 : gaps.reduce(0, +) / Double(gaps.count)

        return FocusFeatures(
            hourOfDay: sessionDate.hour,
            dayOfWeek: sessionDate.isoDayOfWeek,
            sessionTag: session.sessionType,
            rollingCompletionRate7d: rollingRate,
            sessionsToday: sessionsBeforeToday,
            lastSessionQuality: lastQuality,
            streakLength: streakLength,
            avgSessionGapHours: avgGap,
            actualDuration: TimeInterval(session.actualDuration),
            qualityOutcome: ruleEngine.assessQuality(session),
            completionRatio: session.completionRatio
        )
    }

    /// Extracts features from all sessions, ready for Create ML training.
    ///
    /// - Parameters:
    ///   - sessions: All `FocusSession` entities sorted by date ascending.
    ///   - streakLength: Current streak length.
    /// - Returns: Array of `FocusFeatures`.
    func extractTrainingData(
        from sessions: [FocusSession],
        streakLength: Int = 0
    ) -> [FocusFeatures] {
        let completed = sessions.filter { $0.isCompleted }
        return completed.map { session in
            extractFeatures(from: session, allSessions: sessions, streakLength: streakLength)
        }
    }

    // MARK: - Optimal Time Windows

    /// Detects the best focus time windows based on session quality distribution.
    ///
    /// Groups sessions by hour, computes average quality per hour, then finds
    /// contiguous windows of high-quality hours. Returns up to 3 windows sorted
    /// by score (best first).
    ///
    /// - Parameter sessions: Completed sessions to analyze.
    /// - Returns: Array of `TimeWindow` structs, best first.
    func detectOptimalTimeWindows(sessions: [FocusSession]) -> [TimeWindow] {
        guard !sessions.isEmpty else { return [] }

        // Score each hour (0–23) by average quality
        var hourScores: [Int: [Double]] = [:]
        for session in sessions where session.isCompleted {
            let hour = session.startedAt.hour
            let quality = ruleEngine.assessQuality(session).numericValue
            hourScores[hour, default: []].append(quality)
        }

        var avgByHour: [Int: Double] = [:]
        for (hour, scores) in hourScores {
            avgByHour[hour] = scores.reduce(0, +) / Double(scores.count)
        }

        // Find contiguous windows of above-average quality
        let globalAvg = avgByHour.values.isEmpty
            ? 0.5
            : avgByHour.values.reduce(0, +) / Double(avgByHour.values.count)

        var windows: [TimeWindow] = []
        var windowStart: Int?
        var windowScores: [Double] = []

        for hour in 0...23 {
            let score = avgByHour[hour] ?? 0
            if score >= globalAvg && score > 0.3 {
                if windowStart == nil {
                    windowStart = hour
                    windowScores = []
                }
                windowScores.append(score)
            } else {
                if let start = windowStart, !windowScores.isEmpty {
                    let avgScore = windowScores.reduce(0, +) / Double(windowScores.count)
                    windows.append(TimeWindow(
                        start: start,
                        end: hour,
                        score: avgScore
                    ))
                }
                windowStart = nil
                windowScores = []
            }
        }

        // Close any trailing window
        if let start = windowStart, !windowScores.isEmpty {
            let avgScore = windowScores.reduce(0, +) / Double(windowScores.count)
            windows.append(TimeWindow(
                start: start,
                end: 24,
                score: avgScore
            ))
        }

        // Sort by score descending, return top 3
        return Array(windows.sorted { $0.score > $1.score }.prefix(3))
    }

    // MARK: - Trend Calculation

    /// Calculates the trend direction from a series of scores over a window.
    ///
    /// Uses simple linear regression slope. A slope > threshold = improving,
    /// < -threshold = declining, otherwise stable.
    ///
    /// - Parameters:
    ///   - scores: Array of scores ordered chronologically (oldest first).
    ///   - window: Number of data points to consider (uses the most recent).
    /// - Returns: The `TrendDirection`.
    func calculateTrend(scores: [Double], window: Int = 7) -> TrendDirection {
        let data = Array(scores.suffix(window))
        guard data.count >= 3 else { return .stable }

        // Simple linear regression: slope = Σ((x - x̄)(y - ȳ)) / Σ((x - x̄)²)
        let n = Double(data.count)
        let xMean = (n - 1) / 2.0
        let yMean = data.reduce(0, +) / n

        var numerator: Double = 0
        var denominator: Double = 0
        for (i, y) in data.enumerated() {
            let xDiff = Double(i) - xMean
            numerator += xDiff * (y - yMean)
            denominator += xDiff * xDiff
        }

        guard denominator > 0 else { return .stable }
        let slope = numerator / denominator

        // Normalize slope relative to the mean to get a proportional threshold
        let normalizedSlope = yMean > 0 ? slope / yMean : slope

        // Threshold: ~5% per data point is significant
        let threshold = 0.03

        if normalizedSlope > threshold {
            return .improving
        } else if normalizedSlope < -threshold {
            return .declining
        }
        return .stable
    }

    // MARK: - Anomaly Detection

    /// Detects whether a session is anomalous compared to a baseline pattern.
    ///
    /// An anomaly is a session whose quality deviates more than 2 standard
    /// deviations from the baseline mean (either unusually good or bad).
    ///
    /// - Parameters:
    ///   - session: The session to check.
    ///   - baselineSessions: The baseline sessions to compare against.
    /// - Returns: `true` if the session is anomalous.
    func detectAnomaly(session: FocusSession, baselineSessions: [FocusSession]) -> Bool {
        let completed = baselineSessions.filter { $0.isCompleted }
        guard completed.count >= 5 else { return false }

        let scores = completed.map { Double($0.focusScore) }
        let mean = scores.reduce(0, +) / Double(scores.count)
        let variance = scores.reduce(0.0) { $0 + pow($1 - mean, 2) } / Double(scores.count)
        let stdDev = sqrt(variance)

        guard stdDev > 1.0 else { return false }  // too little variation

        let sessionScore = Double(session.focusScore)
        return abs(sessionScore - mean) > 2.0 * stdDev
    }

    // MARK: - Model Readiness

    /// Computes progress toward Core ML model activation.
    ///
    /// The architecture requires 30 completed sessions before the first
    /// model trains. This returns both a percentage and a ready flag.
    ///
    /// - Parameter totalSessions: Count of completed sessions.
    /// - Returns: A tuple of (percentage 0.0–1.0, isReady Bool).
    func computeModelReadiness(totalSessions: Int) -> (percentage: Double, isReady: Bool) {
        let percentage = min(1.0, Double(totalSessions) / Double(minimumSessionsForML))
        let isReady = totalSessions >= minimumSessionsForML
        return (percentage, isReady)
    }

    // MARK: - Daily Pattern Analysis

    /// Computes a `DailyPattern` for a specific date from its sessions.
    ///
    /// - Parameters:
    ///   - date: The calendar date to analyze.
    ///   - sessions: Sessions on that date.
    /// - Returns: A `DailyPattern` summarizing the day.
    func analyzeDailyPattern(date: Date, sessions: [FocusSession]) -> DailyPattern {
        let completed = sessions.filter { $0.isCompleted }

        guard !completed.isEmpty else {
            return DailyPattern(
                date: date.startOfDay,
                bestHour: nil,
                worstHour: nil,
                avgDuration: 0,
                avgQuality: 0,
                sessionsCount: 0,
                totalFocusMinutes: 0,
                focusScore: nil
            )
        }

        // Group by hour and compute average quality
        var hourQualities: [Int: [Double]] = [:]
        for session in completed {
            let hour = session.startedAt.hour
            let quality = ruleEngine.assessQuality(session).numericValue
            hourQualities[hour, default: []].append(quality)
        }

        let hourAverages = hourQualities.mapValues { $0.reduce(0, +) / Double($0.count) }
        let bestHour = hourAverages.max(by: { $0.value < $1.value })?.key
        let worstHour = hourAverages.min(by: { $0.value < $1.value })?.key

        let avgDuration = completed.reduce(0.0) { $0 + Double($1.actualDuration) } / Double(completed.count)
        let avgQuality = ruleEngine.averageQuality(for: completed)
        let totalMinutes = completed.reduce(0) { $0 + Int($1.actualDuration) / 60 }

        return DailyPattern(
            date: date.startOfDay,
            bestHour: bestHour,
            worstHour: worstHour,
            avgDuration: avgDuration,
            avgQuality: avgQuality,
            sessionsCount: completed.count,
            totalFocusMinutes: totalMinutes,
            focusScore: nil
        )
    }

    // MARK: - Weekly Pattern Analysis

    /// Computes a `WeeklyPattern` from the last 7 days of sessions.
    ///
    /// - Parameter sessions: All sessions within the 7-day window, sorted ascending.
    /// - Returns: A `WeeklyPattern` summarizing the week.
    func analyzeWeeklyPattern(sessions: [FocusSession]) -> WeeklyPattern {
        let calendar = Calendar.current
        let today = Date().startOfDay

        // Build daily patterns for the last 7 days
        var dailyPatterns: [DailyPattern] = []
        for dayOffset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let dayStart = date.startOfDay
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            let daySessions = sessions.filter {
                $0.startedAt >= dayStart && $0.startedAt < dayEnd
            }
            dailyPatterns.append(analyzeDailyPattern(date: date, sessions: daySessions))
        }

        // Best/worst day by quality
        let dayScores = computeDayOfWeekScores(sessions: sessions.filter { $0.isCompleted })
        let bestDay = dayScores.max(by: { $0.value < $1.value })?.key ?? 1
        let worstDay = dayScores.min(by: { $0.value < $1.value })?.key ?? 1

        // Average daily score
        let qualityScores = dailyPatterns.map { $0.avgQuality * 100 }
        let avgDailyScore = qualityScores.isEmpty
            ? 0
            : qualityScores.reduce(0, +) / Double(qualityScores.count)

        // Trend
        let trend = calculateTrend(scores: qualityScores)

        let totalSessions = dailyPatterns.reduce(0) { $0 + $1.sessionsCount }
        let totalMinutes = dailyPatterns.reduce(0) { $0 + $1.totalFocusMinutes }

        let weekly = WeeklyPattern(
            bestDay: bestDay,
            worstDay: worstDay,
            avgDailyScore: avgDailyScore,
            trend: trend,
            dailyPatterns: dailyPatterns,
            totalSessions: totalSessions,
            totalFocusMinutes: totalMinutes
        )

        recentDailyPatterns = dailyPatterns
        recentWeeklyPattern = weekly
        return weekly
    }

    // MARK: - Private Helpers

    /// Computes a weighted average where more recent values carry more weight.
    private func computeWeightedAverage(values: [Double], decayFactor: Double) -> Double {
        guard !values.isEmpty else { return 25.0 }

        var weightedSum: Double = 0
        var totalWeight: Double = 0
        var weight: Double = 1.0

        // Iterate from most recent to oldest
        for value in values.reversed() {
            weightedSum += value * weight
            totalWeight += weight
            weight *= decayFactor
        }

        return totalWeight > 0 ? weightedSum / totalWeight : 25.0
    }

    /// Computes average quality per ISO day of week (1=Mon, 7=Sun).
    private func computeDayOfWeekScores(sessions: [FocusSession]) -> [Int: Double] {
        var dayBuckets: [Int: [Double]] = [:]
        for session in sessions {
            let day = session.startedAt.isoDayOfWeek
            let quality = ruleEngine.assessQuality(session).numericValue
            dayBuckets[day, default: []].append(quality)
        }
        return dayBuckets.mapValues { $0.reduce(0, +) / Double($0.count) }
    }

    /// Computes the time gaps (in hours) between consecutive completed sessions.
    private func computeSessionGaps(sessions: [FocusSession]) -> [Double] {
        let sorted = sessions.sorted { $0.startedAt < $1.startedAt }
        guard sorted.count >= 2 else { return [] }

        var gaps: [Double] = []
        for i in 1..<sorted.count {
            let gap = sorted[i].startedAt.timeIntervalSince(sorted[i - 1].startedAt) / 3600.0
            // Cap at 48h to avoid vacation outliers skewing the average
            gaps.append(min(48.0, gap))
        }
        return gaps
    }
}
