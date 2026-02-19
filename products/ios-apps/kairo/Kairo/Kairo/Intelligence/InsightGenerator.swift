import Foundation
import SwiftUI

// MARK: - InsightType

/// Categories of focus insights the engine can produce.
///
/// Each type maps to a family of natural language templates and carries
/// semantic meaning for UI presentation (icon, color, grouping).
enum InsightType: String, CaseIterable {
    case optimalTime  = "optimal_time"
    case sessionLength = "session_length"
    case bestDay      = "best_day"
    case improvement  = "improvement"
    case streak       = "streak"
    case consistency  = "consistency"
    case suggestion   = "suggestion"

    /// Human-readable label for section headers.
    var displayName: String {
        switch self {
        case .optimalTime:   return "Optimal Time"
        case .sessionLength: return "Session Length"
        case .bestDay:       return "Best Day"
        case .improvement:   return "Improvement"
        case .streak:        return "Streak"
        case .consistency:   return "Consistency"
        case .suggestion:    return "Suggestion"
        }
    }
}

// MARK: - MilestoneType

/// Milestone categories that trigger celebratory insights.
enum MilestoneType: String, CaseIterable {
    case streakDays    = "streak_days"
    case sessionCount  = "session_count"
    case totalMinutes  = "total_minutes"
}

// MARK: - SessionSummary

/// Lightweight snapshot of a completed session for insight generation.
///
/// Decoupled from Core Data so the insight engine can operate on
/// pre-fetched data without touching the managed object context.
struct SessionSummary: Identifiable {

    let id = UUID()

    /// When the session started.
    let date: Date

    /// Actual duration in seconds.
    let duration: TimeInterval

    /// Assessed quality of the session.
    let quality: FocusQuality

    /// Session type tag ("work", "study", "creative", "personal").
    let type: String
}

// MARK: - Insight

/// A single human-readable insight generated from focus patterns.
///
/// Insights are self-contained — each carries its own copy, emoji, and
/// priority so the UI layer can render them without additional logic.
struct Insight: Identifiable {

    /// Unique identifier.
    let id: UUID

    /// Semantic category of this insight.
    let type: InsightType

    /// Short headline (≤ 50 chars) for card titles.
    let title: String

    /// Longer explanatory message (1–2 sentences).
    let message: String

    /// Leading emoji for visual weight.
    let emoji: String

    /// Display priority (1 = highest, 5 = lowest). Used for sort order
    /// and to cap the number of insights shown at once.
    let priority: Int

    /// Timestamp when this insight was produced.
    let generatedAt: Date

    init(
        type: InsightType,
        title: String,
        message: String,
        emoji: String,
        priority: Int,
        generatedAt: Date = Date()
    ) {
        self.id = UUID()
        self.type = type
        self.title = title
        self.message = message
        self.emoji = emoji
        self.priority = max(1, min(5, priority))
        self.generatedAt = generatedAt
    }
}

// MARK: - InsightGenerator

/// Natural language insight engine that turns raw focus patterns into
/// human-readable, prioritized observations.
///
/// Operates entirely on-device with no network calls. Maintains a bank
/// of 5+ templates per insight type and selects randomly to avoid
/// repetitive messaging. Published state allows SwiftUI views to bind
/// directly to the latest insights.
///
/// Usage:
/// ```swift
/// let generator = InsightGenerator()
/// let insights = generator.generateInsights(
///     from: pattern,
///     recentSessions: summaries
/// )
/// ```
final class InsightGenerator: ObservableObject {

    // MARK: - Published State

    /// The most recently generated set of insights, sorted by priority.
    @Published var latestInsights: [Insight] = []

    /// The most recently generated coaching insights (post-30 sessions).
    @Published var latestCoachingInsights: [CoachingInsight] = []

    // MARK: - Insight Generation (Core)

    /// Generates 3–5 prioritized insights from a focus pattern and recent sessions.
    ///
    /// Inspects the pattern for optimal time windows, session length trends,
    /// best days, consistency, and streaks, then selects the most relevant
    /// insights and caps the output to avoid overwhelming the user.
    ///
    /// - Parameters:
    ///   - pattern: The Core Data `FocusPattern` entity with aggregated metrics.
    ///   - recentSessions: Lightweight session summaries (last 7–14 days).
    /// - Returns: Array of 3–5 `Insight` values sorted by priority (best first).
    func generateInsights(
        from pattern: FocusPattern,
        recentSessions: [SessionSummary]
    ) -> [Insight] {
        var insights: [Insight] = []

        // — Optimal time insight —
        let startHour = Int(pattern.bestHourStart)
        let endHour = Int(pattern.bestHourEnd)
        if startHour != endHour {
            insights.append(buildOptimalTimeInsight(start: startHour, end: endHour))
        }

        // — Session length insight —
        let optimalMinutes = Int(pattern.optimalDuration)
        if optimalMinutes > 0 {
            insights.append(buildSessionLengthInsight(optimalMinutes: optimalMinutes))
        }

        // — Best day insight —
        let bestDay = Int(pattern.bestDayOfWeek)
        if bestDay >= 1 && bestDay <= 7 {
            insights.append(buildBestDayInsight(isoDay: bestDay))
        }

        // — Consistency insight —
        let completionRate = Double(pattern.avgCompletionRate)
        insights.append(buildConsistencyInsight(completionRate: completionRate))

        // — Improvement / suggestion based on recent quality —
        if !recentSessions.isEmpty {
            let qualityValues = recentSessions.map { $0.quality.numericValue }
            let avgQuality = qualityValues.reduce(0, +) / Double(qualityValues.count)

            if avgQuality >= 0.7 {
                insights.append(buildImprovementInsight(avgQuality: avgQuality, rising: true))
            } else if avgQuality < 0.4 {
                insights.append(buildSuggestionInsight(
                    avgQuality: avgQuality,
                    recentSessions: recentSessions
                ))
            } else {
                insights.append(buildImprovementInsight(avgQuality: avgQuality, rising: false))
            }
        }

        // Sort by priority (1 = best) and cap at 5
        insights.sort { $0.priority < $1.priority }
        let capped = Array(insights.prefix(5))

        latestInsights = capped
        return capped
    }

    // MARK: - Daily Summary

    /// Generates a single insight summarizing today's focus activity.
    ///
    /// - Parameters:
    ///   - sessionsCompleted: Number of sessions finished today.
    ///   - totalMinutes: Total focus minutes today.
    ///   - score: Focus score for the day (0.0–1.0).
    /// - Returns: A summary `Insight` with priority 2.
    func generateDailySummary(
        sessionsCompleted: Int,
        totalMinutes: Int,
        score: Double
    ) -> Insight {
        let templates: [(String, String, String)] = [
            (
                "Day in Review",
                "You completed \(sessionsCompleted) session\(sessionsCompleted == 1 ? "" : "s") totaling \(totalMinutes) minutes with a \(formattedPercent(score)) focus score.",
                "📊"
            ),
            (
                "Today's Focus",
                "\(totalMinutes) minutes of focused work across \(sessionsCompleted) session\(sessionsCompleted == 1 ? "" : "s"). Your focus score landed at \(formattedPercent(score)).",
                "🎯"
            ),
            (
                "Daily Wrap-Up",
                "\(sessionsCompleted) session\(sessionsCompleted == 1 ? "" : "s"), \(totalMinutes) min total — \(dailyScoreVerdict(score))",
                "✨"
            ),
            (
                "Focus Report",
                "Today you locked in for \(totalMinutes) minutes. \(sessionsCompleted) session\(sessionsCompleted == 1 ? "" : "s") completed at \(formattedPercent(score)) quality.",
                "📝"
            ),
            (
                "End of Day",
                "\(dailyEncouragement(sessionsCompleted: sessionsCompleted, score: score))",
                "🌙"
            )
        ]

        let (title, message, emoji) = templates.randomElement()!
        return Insight(
            type: .consistency,
            title: title,
            message: message,
            emoji: emoji,
            priority: 2
        )
    }

    // MARK: - Weekly Summary

    /// Generates a single insight summarizing the past 7 days of focus.
    ///
    /// - Parameters:
    ///   - dailyScores: Focus scores for each day (0.0–1.0), oldest first.
    ///   - totalSessions: Total sessions completed across the week.
    /// - Returns: A summary `Insight` with priority 1.
    func generateWeeklySummary(
        dailyScores: [Double],
        totalSessions: Int
    ) -> Insight {
        let avgScore = dailyScores.isEmpty
            ? 0.0
            : dailyScores.reduce(0, +) / Double(dailyScores.count)
        let activeDays = dailyScores.filter { $0 > 0 }.count
        let trend = computeSimpleTrend(dailyScores)

        let templates: [(String, String, String)] = [
            (
                "Weekly Review",
                "This week: \(totalSessions) sessions across \(activeDays) active day\(activeDays == 1 ? "" : "s"). Average focus score: \(formattedPercent(avgScore)). \(trendPhrase(trend))",
                "📅"
            ),
            (
                "Your Week in Focus",
                "\(activeDays) day\(activeDays == 1 ? "" : "s") of focus, \(totalSessions) total sessions. \(weeklyVerdict(avgScore: avgScore, trend: trend))",
                "🗓️"
            ),
            (
                "7-Day Snapshot",
                "Average score: \(formattedPercent(avgScore)) across \(activeDays) active day\(activeDays == 1 ? "" : "s"). You completed \(totalSessions) session\(totalSessions == 1 ? "" : "s") total. \(trendPhrase(trend))",
                "📈"
            ),
            (
                "Week at a Glance",
                "\(totalSessions) sessions this week with a \(formattedPercent(avgScore)) average. \(weeklyEncouragement(activeDays: activeDays, trend: trend))",
                "🔍"
            ),
            (
                "Focus Recap",
                "\(weeklyNarrative(activeDays: activeDays, totalSessions: totalSessions, avgScore: avgScore, trend: trend))",
                "🏅"
            )
        ]

        let (title, message, emoji) = templates.randomElement()!
        return Insight(
            type: .consistency,
            title: title,
            message: message,
            emoji: emoji,
            priority: 1
        )
    }

    // MARK: - Milestone Insights

    /// Generates a celebratory insight when the user hits a milestone.
    ///
    /// Recognized milestones:
    /// - **Streak days:** 3, 7, 14, 30
    /// - **Session count:** 10, 25, 50, 100
    ///
    /// Returns `nil` if the value doesn't match a recognized milestone.
    ///
    /// - Parameters:
    ///   - type: The milestone category.
    ///   - value: The numeric milestone value.
    /// - Returns: An `Insight` if the value is a recognized milestone, otherwise `nil`.
    func generateMilestoneInsight(type: MilestoneType, value: Int) -> Insight? {
        switch type {
        case .streakDays:
            return streakMilestoneInsight(days: value)
        case .sessionCount:
            return sessionCountMilestoneInsight(count: value)
        case .totalMinutes:
            return totalMinutesMilestoneInsight(minutes: value)
        }
    }

    // MARK: - Session Preview

    /// Generates a pre-session insight with predicted quality and duration context.
    ///
    /// Shown on the session start screen to set expectations and motivate.
    ///
    /// - Parameters:
    ///   - suggestedDuration: Recommended duration in seconds.
    ///   - predictedQuality: The engine's quality prediction for this session.
    ///   - context: Current session context (time, streak, etc.).
    /// - Returns: A preview `Insight` with priority 2.
    func generateSessionPreview(
        suggestedDuration: TimeInterval,
        predictedQuality: FocusQuality,
        context: SessionContext
    ) -> Insight {
        let minutes = Int(suggestedDuration / 60)
        let qualityLabel = predictedQuality.displayName.lowercased()

        let templates: [(String, String, String)] = [
            (
                "Session Preview",
                "\(minutes) minutes suggested. Conditions point toward \(qualityLabel) focus — \(previewContext(context)).",
                "🔮"
            ),
            (
                "Ready to Focus",
                "Based on your patterns, \(minutes) min at \(qualityLabel) quality looks likely. \(previewMotivation(predictedQuality)).",
                "⚡"
            ),
            (
                "Focus Forecast",
                "\(previewTimeSignal(context)) A \(minutes)-minute session should hit \(qualityLabel) quality today.",
                "🌤️"
            ),
            (
                "Your Next Session",
                "\(minutes) minutes is your sweet spot right now. Predicted quality: \(qualityLabel). \(previewStreakNote(context)).",
                "🎯"
            ),
            (
                "Session Intel",
                "Suggested: \(minutes) min. Quality outlook: \(qualityLabel). \(previewEncouragement(context, quality: predictedQuality)).",
                "🧠"
            )
        ]

        let (title, message, emoji) = templates.randomElement()!
        return Insight(
            type: .suggestion,
            title: title,
            message: message,
            emoji: emoji,
            priority: 2
        )
    }

    // MARK: - Coaching Insights (30+ Sessions)

    /// Generates personalized, science-backed coaching insights after 30+ sessions.
    ///
    /// Delegates to `FocusCoach` for deep behavioral pattern analysis and returns
    /// 3-5 targeted coaching insights with actionable advice and neuroscience backing.
    ///
    /// - Parameters:
    ///   - pattern: The Core Data `FocusPattern` entity with aggregated metrics.
    ///   - recentSessions: Lightweight session summaries (last 7-30 days).
    /// - Returns: Array of 3-5 `CoachingInsight` values sorted by priority.
    func generateCoachingInsights(
        from pattern: FocusPattern,
        recentSessions: [SessionSummary],
        tier: Int = 3
    ) -> [CoachingInsight] {
        let coach = FocusCoach()
        let insights = coach.analyze(pattern: pattern, sessions: recentSessions, tier: tier)
        latestCoachingInsights = insights
        return insights
    }

    // MARK: - Starter Focus Tips (New Users)

    /// Returns a rotating set of 3 focus tips for users with no session data.
    /// Provides immediate value and motivation before patterns are established.
    func starterTips() -> [Insight] {
        let allTips: [Insight] = [
            Insight(type: .suggestion, title: "Silence is Golden", message: "Put your phone on Do Not Disturb before starting. Even one notification can derail 20 minutes of focus.", emoji: "🔕", priority: 1),
            Insight(type: .suggestion, title: "Start Small", message: "New to focus sessions? Start with 15 minutes. Completing short sessions builds confidence and momentum.", emoji: "🌱", priority: 1),
            Insight(type: .suggestion, title: "One Task Only", message: "Pick ONE thing to work on before you start. Multitasking kills focus — single-tasking supercharges it.", emoji: "🎯", priority: 1),
            Insight(type: .suggestion, title: "Morning Advantage", message: "Your brain's willpower is highest in the morning. Schedule your hardest focus work before noon.", emoji: "🌅", priority: 2),
            Insight(type: .suggestion, title: "The 2-Minute Rule", message: "Before a session, spend 2 minutes clearing your desk and closing extra tabs. A clean space = a clear mind.", emoji: "🧹", priority: 2),
            Insight(type: .suggestion, title: "Hydrate First", message: "Drink a full glass of water before starting. Even mild dehydration reduces cognitive performance by 15%.", emoji: "💧", priority: 2),
            Insight(type: .suggestion, title: "Body Position Matters", message: "Sit upright with feet flat on the floor. Good posture increases alertness and focus by up to 25%.", emoji: "🪑", priority: 3),
            Insight(type: .suggestion, title: "Use Ambient Sound", message: "Light background noise (rain, café, lo-fi) can boost focus. Try Kairo's built-in ambient sounds.", emoji: "🎵", priority: 3),
            Insight(type: .suggestion, title: "The Power of Streaks", message: "Focus every day — even 10 minutes counts. Streaks create accountability and compound over time.", emoji: "🔥", priority: 2),
            Insight(type: .suggestion, title: "Reward Yourself", message: "After completing a focus session, give yourself a small reward. Your brain learns to associate focus with pleasure.", emoji: "🎁", priority: 3),
            Insight(type: .suggestion, title: "Block Temptation", message: "Close social media tabs and move your phone to another room. Out of sight, out of mind.", emoji: "🚫", priority: 1),
            Insight(type: .suggestion, title: "Energy Management", message: "Focus isn't about time management — it's about energy. Know when you're sharp and protect those hours.", emoji: "⚡", priority: 2)
        ]

        // Return 3 random tips each time
        return Array(allTips.shuffled().prefix(3))
    }

    // MARK: - Private — Insight Builders

    /// Builds an optimal time window insight from start/end hours.
    private func buildOptimalTimeInsight(start: Int, end: Int) -> Insight {
        let window = formatTimeWindow(start: start, end: end)
        let templates: [(String, String, String)] = [
            ("Peak Focus Window", "Your highest-quality sessions happen between \(window).", "⏰"),
            ("Your Best Hours", "Data shows \(window) is when you do your deepest work.", "🕐"),
            ("Golden Hours", "Focus quality peaks during \(window). Try to schedule deep work then.", "✨"),
            ("Optimal Timing", "Sessions between \(window) consistently score above average.", "📊"),
            ("When You're Sharpest", "\(window) is your cognitive sweet spot based on recent patterns.", "🧠")
        ]
        let (title, message, emoji) = templates.randomElement()!
        return Insight(type: .optimalTime, title: title, message: message, emoji: emoji, priority: 2)
    }

    /// Builds a session length insight from optimal duration.
    private func buildSessionLengthInsight(optimalMinutes: Int) -> Insight {
        let templates: [(String, String, String)] = [
            ("Ideal Session Length", "Your data suggests \(optimalMinutes)-minute sessions hit the quality sweet spot.", "⏱️"),
            ("Session Sweet Spot", "\(optimalMinutes) minutes is where completion rate and quality both peak for you.", "🎯"),
            ("Duration Insight", "Sessions around \(optimalMinutes) minutes tend to produce your best focus scores.", "📐"),
            ("Your Rhythm", "You perform best in \(optimalMinutes)-minute blocks. Consider adjusting your timer.", "🎵"),
            ("Length Matters", "At \(optimalMinutes) minutes, you balance depth and stamina. That's your zone.", "💡")
        ]
        let (title, message, emoji) = templates.randomElement()!
        return Insight(type: .sessionLength, title: title, message: message, emoji: emoji, priority: 3)
    }

    /// Builds a best-day insight from ISO day of week.
    private func buildBestDayInsight(isoDay: Int) -> Insight {
        let name = dayName(for: isoDay)
        let templates: [(String, String, String)] = [
            ("Strongest Day", "\(name) is your highest-performing focus day. Plan important work accordingly.", "📅"),
            ("Peak Day: \(name)", "Your average quality on \(name)s outperforms every other day of the week.", "🏆"),
            ("\(name) Focus", "History shows \(name) is when you lock in deepest. Use it wisely.", "⭐"),
            ("Best Day Detected", "\(name) sessions consistently rank top quality. Lean into it.", "🔥"),
            ("Day of the Week", "Your focus peaks on \(name)s — schedule your hardest tasks then.", "💪")
        ]
        let (title, message, emoji) = templates.randomElement()!
        return Insight(type: .bestDay, title: title, message: message, emoji: emoji, priority: 3)
    }

    /// Builds a consistency insight from completion rate.
    private func buildConsistencyInsight(completionRate: Double) -> Insight {
        let pct = formattedPercent(completionRate)
        if completionRate >= 0.85 {
            let templates: [(String, String, String)] = [
                ("Rock Solid", "Your \(pct) completion rate is exceptional. You finish what you start.", "💎"),
                ("Consistency King", "\(pct) of sessions completed — that's elite-level discipline.", "👑"),
                ("Follow-Through", "At \(pct) completion, your follow-through is one of your strongest traits.", "✅"),
                ("Reliable Focus", "\(pct) completion rate. You rarely leave a session unfinished.", "🔒"),
                ("Discipline Pays Off", "Completing \(pct) of sessions shows serious commitment.", "🏅")
            ]
            let (title, message, emoji) = templates.randomElement()!
            return Insight(type: .consistency, title: title, message: message, emoji: emoji, priority: 2)
        } else if completionRate >= 0.6 {
            let templates: [(String, String, String)] = [
                ("Room to Grow", "Your \(pct) completion rate is solid but has room to improve.", "📈"),
                ("Getting There", "\(pct) completion — try slightly shorter sessions to push that higher.", "🔧"),
                ("Consistency Check", "You're finishing \(pct) of sessions. Small tweaks could bump that up.", "⚙️"),
                ("Building Habits", "\(pct) completion shows progress. Shorter focused sessions often help.", "🌱"),
                ("Steady Progress", "At \(pct), you're on the right track. Consistency builds over time.", "📊")
            ]
            let (title, message, emoji) = templates.randomElement()!
            return Insight(type: .consistency, title: title, message: message, emoji: emoji, priority: 3)
        } else {
            let templates: [(String, String, String)] = [
                ("Start Smaller", "At \(pct) completion, shorter sessions might suit you better right now.", "🌱"),
                ("Recalibrate", "\(pct) completion suggests your sessions may be too long. Try 15–20 min.", "🔄"),
                ("Finish Line", "Completing \(pct) of sessions? Cut duration by 25% and rebuild from there.", "🎯"),
                ("Session Fit", "A \(pct) rate often means the session length doesn't match your energy.", "💡"),
                ("Shorter = Stronger", "With \(pct) completion, prioritize finishing over length. Start small.", "🪴")
            ]
            let (title, message, emoji) = templates.randomElement()!
            return Insight(type: .consistency, title: title, message: message, emoji: emoji, priority: 1)
        }
    }

    /// Builds an improvement insight based on average quality and direction.
    private func buildImprovementInsight(avgQuality: Double, rising: Bool) -> Insight {
        if rising {
            let templates: [(String, String, String)] = [
                ("Quality Rising", "Your recent sessions average \(formattedPercent(avgQuality)) quality — nicely above baseline.", "📈"),
                ("On the Up", "Focus quality is climbing. Recent average: \(formattedPercent(avgQuality)). Keep it up.", "🚀"),
                ("Strong Trend", "Your quality has been improving — \(formattedPercent(avgQuality)) average recently.", "💪"),
                ("Gaining Momentum", "\(formattedPercent(avgQuality)) average quality shows your habits are paying off.", "⬆️"),
                ("Leveling Up", "Recent quality at \(formattedPercent(avgQuality)). Whatever you're doing, it's working.", "✨")
            ]
            let (title, message, emoji) = templates.randomElement()!
            return Insight(type: .improvement, title: title, message: message, emoji: emoji, priority: 2)
        } else {
            let templates: [(String, String, String)] = [
                ("Holding Steady", "Average quality at \(formattedPercent(avgQuality)). Consistent — with room to push higher.", "➡️"),
                ("Steady State", "Your \(formattedPercent(avgQuality)) quality average is stable. A small push could make a difference.", "📊"),
                ("Plateau Detected", "Quality hovering at \(formattedPercent(avgQuality)). Try changing time of day or session length.", "🔍"),
                ("Maintenance Mode", "\(formattedPercent(avgQuality)) quality is your current baseline. Small experiments could move the needle.", "⚙️"),
                ("Stable Ground", "You're averaging \(formattedPercent(avgQuality)) quality. Solid foundation to build on.", "🏗️")
            ]
            let (title, message, emoji) = templates.randomElement()!
            return Insight(type: .improvement, title: title, message: message, emoji: emoji, priority: 3)
        }
    }

    /// Builds a suggestion insight when quality is low.
    private func buildSuggestionInsight(
        avgQuality: Double,
        recentSessions: [SessionSummary]
    ) -> Insight {
        let avgDurationMin = recentSessions.isEmpty
            ? 25
            : Int(recentSessions.map(\.duration).reduce(0, +) / Double(recentSessions.count) / 60)
        let suggestedMin = max(10, avgDurationMin - 5)

        let templates: [(String, String, String)] = [
            ("Try Shorter Sessions", "Quality is at \(formattedPercent(avgQuality)). Dropping to \(suggestedMin)-min sessions often helps.", "💡"),
            ("Adjust Your Approach", "Recent quality (\(formattedPercent(avgQuality))) suggests a change. Try a different time of day.", "🔄"),
            ("Focus Tune-Up", "At \(formattedPercent(avgQuality)) quality, consider \(suggestedMin)-min sessions with fewer distractions.", "🔧"),
            ("Experiment Time", "Quality dipped to \(formattedPercent(avgQuality)). Small changes — shorter sessions, morning hours — can help.", "🧪"),
            ("Reset & Rebuild", "A \(formattedPercent(avgQuality)) average is a signal to recalibrate. Start with \(suggestedMin) min and build up.", "🌱")
        ]

        let (title, message, emoji) = templates.randomElement()!
        return Insight(type: .suggestion, title: title, message: message, emoji: emoji, priority: 1)
    }

    // MARK: - Private — Milestone Builders

    /// Produces a streak milestone insight for recognized day counts.
    private func streakMilestoneInsight(days: Int) -> Insight? {
        let templates: [Int: [(String, String, String)]] = [
            3: [
                ("3-Day Streak!", "Three days running — the habit is forming. Don't break the chain.", "🔥"),
                ("Streak: 3 Days", "You've shown up three days in a row. That's how momentum starts.", "⚡"),
                ("Hat Trick", "3 consecutive focus days. The hardest part is starting — you're past it.", "🎩"),
                ("Triple Threat", "Day 3 in a row. Research says it takes 3 days to feel a new routine.", "💪"),
                ("Chain Started", "3 days locked in. Every day you add makes the next one easier.", "🔗")
            ],
            7: [
                ("One Week Streak!", "7 days straight — you've built a full week of focus.", "🏅"),
                ("7-Day Chain", "A full week without breaking the chain. That's real discipline.", "⛓️"),
                ("Week Warrior", "7 consecutive days of focus. You've turned this into a daily habit.", "🗓️"),
                ("Streak Level: Week", "One full week of daily focus. You're in the top tier of consistency.", "🌟"),
                ("The Magic Number", "7 days! A week-long streak is where habits start to stick.", "✨")
            ],
            14: [
                ("Two-Week Streak!", "14 days of daily focus — this isn't a streak, it's a lifestyle.", "🏆"),
                ("Fortnight Focus", "Two solid weeks. Your brain now expects focus sessions. Well done.", "🧠"),
                ("14-Day Milestone", "Half a month of consistent focus. The compound effect is kicking in.", "📈"),
                ("Streak: 14 Days", "Two weeks strong. Most people don't make it past 5 days.", "💎"),
                ("Unstoppable", "14 consecutive days. At this point, missing a day would feel wrong.", "🔥")
            ],
            30: [
                ("30-Day Streak!", "A full month of daily focus. You've built something permanent.", "👑"),
                ("Monthly Mastery", "30 days — science says you've officially formed a habit. Celebrate.", "🎉"),
                ("Streak Legend", "30 consecutive days of focus. That's commitment few achieve.", "🏅"),
                ("One Month Strong", "A 30-day chain. This isn't motivation anymore — it's identity.", "💪"),
                ("The 30-Day Mark", "You've focused every day for a month. This is who you are now.", "⭐")
            ]
        ]

        guard let pool = templates[days] else { return nil }
        let (title, message, emoji) = pool.randomElement()!
        return Insight(type: .streak, title: title, message: message, emoji: emoji, priority: 1)
    }

    /// Produces a session count milestone insight for recognized totals.
    private func sessionCountMilestoneInsight(count: Int) -> Insight? {
        let templates: [Int: [(String, String, String)]] = [
            10: [
                ("10 Sessions!", "Double digits — you've completed 10 focused sessions.", "🔟"),
                ("First 10 Done", "10 sessions in the books. You're building real data now.", "📊"),
                ("Milestone: 10", "Your 10th session is done. The first 10 are the hardest.", "🎯"),
                ("Ten and Counting", "10 completed sessions. Your focus patterns are taking shape.", "📐"),
                ("Double Digits", "Session #10 complete. Kairo is learning your rhythm.", "🧠")
            ],
            25: [
                ("25 Sessions!", "A quarter-hundred sessions of pure focus. Impressive.", "🥈"),
                ("25 and Strong", "25 sessions completed. You're well past the beginner phase.", "💪"),
                ("Silver Milestone", "25 sessions — your patterns are clear and your model is sharpening.", "📈"),
                ("Milestone: 25", "With 25 sessions, Kairo's suggestions are getting smarter for you.", "🔮"),
                ("Quarter Century", "25 focused sessions. That's serious accumulated deep work.", "⭐")
            ],
            50: [
                ("50 Sessions!", "Half a hundred — 50 completed focus sessions. That's dedication.", "🥇"),
                ("The Big 5-0", "50 sessions of focused work. You're in elite focus territory.", "🏆"),
                ("Gold Milestone", "50 sessions complete. Think about how much you've accomplished.", "✨"),
                ("Milestone: 50", "Session #50! Your focus data is rich and your patterns are locked in.", "📊"),
                ("Fifty Strong", "50 sessions down. At this point, focus is second nature.", "💎")
            ],
            100: [
                ("100 Sessions!", "Triple digits — 100 sessions of focused work. Extraordinary.", "💯"),
                ("The Century", "100 completed sessions. You've mastered the art of showing up.", "👑"),
                ("Centurion", "Session #100. Very few people reach this milestone. Be proud.", "🏅"),
                ("Milestone: 100", "One hundred focused sessions. The compound returns are immense.", "🚀"),
                ("100 Club", "Welcome to the 100 club. That's hundreds of hours of deep work.", "🎉")
            ]
        ]

        guard let pool = templates[count] else { return nil }
        let (title, message, emoji) = pool.randomElement()!
        return Insight(type: .streak, title: title, message: message, emoji: emoji, priority: 1)
    }

    /// Produces a total-minutes milestone insight.
    private func totalMinutesMilestoneInsight(minutes: Int) -> Insight? {
        let recognized = [500, 1000, 2500, 5000]
        guard recognized.contains(minutes) else { return nil }
        let hours = minutes / 60

        let templates: [(String, String, String)] = [
            ("\(hours)+ Hours Focused", "You've accumulated \(minutes) total minutes of deep focus. That's \(hours)+ hours of real work.", "⏳"),
            ("Time Well Spent", "\(minutes) minutes of focused work — every minute compounds into skill.", "🕐"),
            ("Focus Odometer", "Your lifetime focus time just hit \(minutes) minutes. Keep the meter running.", "📟"),
            ("Deep Work Bank", "\(hours) hours banked in your focus account. The dividends are real.", "🏦"),
            ("Minutes Milestone", "\(minutes) minutes of accumulated focus. That's \(hours) hours of undivided attention.", "⭐")
        ]

        let (title, message, emoji) = templates.randomElement()!
        return Insight(type: .streak, title: title, message: message, emoji: emoji, priority: 1)
    }

    // MARK: - Private — Formatting Helpers

    /// Formats a 0.0–1.0 value as a percentage string (e.g., "85%").
    private func formattedPercent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    /// Converts an ISO day number (1=Monday) to a name.
    private func dayName(for isoDay: Int) -> String {
        let names = ["", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        guard isoDay >= 1, isoDay <= 7 else { return "Unknown" }
        return names[isoDay]
    }

    /// Formats a time window as "9 AM – 11 AM".
    private func formatTimeWindow(start: Int, end: Int) -> String {
        "\(hourLabel(start)) – \(hourLabel(end))"
    }

    /// Converts 24h hour to "9 AM" / "2 PM" format.
    private func hourLabel(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let period = hour < 12 ? "AM" : "PM"
        return "\(h) \(period)"
    }

    // MARK: - Private — Summary Helpers

    /// Short verdict for a daily score.
    private func dailyScoreVerdict(_ score: Double) -> String {
        if score >= 0.8 { return "an excellent focus day." }
        if score >= 0.6 { return "a solid day of work." }
        if score >= 0.4 { return "a decent session day. Tomorrow can be stronger." }
        return "a tough day. Rest up and reset tomorrow."
    }

    /// Personalized encouragement for daily summaries.
    private func dailyEncouragement(sessionsCompleted: Int, score: Double) -> String {
        if sessionsCompleted == 0 {
            return "No sessions today — rest days count too. Come back refreshed."
        }
        if score >= 0.8 {
            return "Outstanding day — \(sessionsCompleted) high-quality session\(sessionsCompleted == 1 ? "" : "s"). You earned a good rest."
        }
        if score >= 0.5 {
            return "\(sessionsCompleted) session\(sessionsCompleted == 1 ? "" : "s") done. Solid progress — consistency matters most."
        }
        return "\(sessionsCompleted) session\(sessionsCompleted == 1 ? "" : "s") today. Every rep builds the habit, even the hard ones."
    }

    /// Computes a simple trend direction from an array of scores.
    private func computeSimpleTrend(_ scores: [Double]) -> TrendDirection {
        guard scores.count >= 3 else { return .stable }
        let firstHalf = Array(scores.prefix(scores.count / 2))
        let secondHalf = Array(scores.suffix(scores.count / 2))
        let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)
        let diff = secondAvg - firstAvg
        if diff > 0.05 { return .improving }
        if diff < -0.05 { return .declining }
        return .stable
    }

    /// Human phrase for a trend direction.
    private func trendPhrase(_ trend: TrendDirection) -> String {
        switch trend {
        case .improving: return "Your focus is trending upward."
        case .declining: return "Focus dipped this week — consider adjusting your routine."
        case .stable:    return "Your focus level is holding steady."
        }
    }

    /// Weekly verdict combining score and trend.
    private func weeklyVerdict(avgScore: Double, trend: TrendDirection) -> String {
        if avgScore >= 0.7 && trend == .improving {
            return "Strong week with momentum — keep pushing."
        }
        if avgScore >= 0.7 {
            return "High-quality week. Consistency is your superpower."
        }
        if trend == .declining {
            return "Scores slipped this week. A fresh start on Monday helps."
        }
        return "Steady week. Small improvements compound over time."
    }

    /// Weekly encouragement based on active days and trend.
    private func weeklyEncouragement(activeDays: Int, trend: TrendDirection) -> String {
        if activeDays >= 6 {
            return "Nearly every day active — that's elite consistency."
        }
        if activeDays >= 4 {
            return "More than half the week — solid commitment."
        }
        if trend == .improving {
            return "Trending up even with fewer days — quality over quantity."
        }
        return "Try adding one more focus day next week."
    }

    /// Full narrative for weekly recap.
    private func weeklyNarrative(
        activeDays: Int,
        totalSessions: Int,
        avgScore: Double,
        trend: TrendDirection
    ) -> String {
        let scoreLabel = formattedPercent(avgScore)
        if activeDays >= 5 && avgScore >= 0.7 {
            return "Exceptional week — \(activeDays) days, \(totalSessions) sessions, \(scoreLabel) average. You're in a groove."
        }
        if trend == .improving {
            return "\(totalSessions) sessions across \(activeDays) days with an upward trend (\(scoreLabel) avg). Building momentum."
        }
        return "\(activeDays) active days, \(totalSessions) sessions, \(scoreLabel) average. Every week is a chance to level up."
    }

    // MARK: - Private — Preview Helpers

    /// Contextual phrase for session preview based on time/streak.
    private func previewContext(_ context: SessionContext) -> String {
        if context.hour >= 8 && context.hour <= 11 {
            return "morning hours are in your favor"
        }
        if context.hour >= 13 && context.hour <= 15 {
            return "the post-lunch window can be tricky"
        }
        if context.currentStreak > 7 {
            return "your \(context.currentStreak)-day streak is adding momentum"
        }
        if context.sessionsToday >= 3 {
            return "this is session \(context.sessionsToday + 1) today — pace yourself"
        }
        return "current conditions look good"
    }

    /// Motivational phrase based on predicted quality.
    private func previewMotivation(_ quality: FocusQuality) -> String {
        switch quality {
        case .high:   return "Conditions are prime — lock in and do your best work"
        case .medium: return "Decent conditions — minimize distractions for a bump"
        case .low:    return "Keep it short and achievable — finishing matters most"
        }
    }

    /// Time-of-day signal phrase for preview.
    private func previewTimeSignal(_ context: SessionContext) -> String {
        if context.hour >= 6 && context.hour < 9 { return "Early bird advantage activated." }
        if context.hour >= 9 && context.hour <= 11 { return "Peak cognitive hours — great timing." }
        if context.hour >= 13 && context.hour <= 15 { return "Post-lunch window — keep it focused." }
        if context.hour >= 20 { return "Evening session — keep it light." }
        return "Good time for a session."
    }

    /// Streak note for session preview.
    private func previewStreakNote(_ context: SessionContext) -> String {
        if context.currentStreak > 7 {
            return "Day \(context.currentStreak) of your streak — don't break the chain"
        }
        if context.currentStreak > 0 {
            return "\(context.currentStreak)-day streak on the line"
        }
        return "Start a new streak today"
    }

    /// General encouragement for session preview.
    private func previewEncouragement(_ context: SessionContext, quality: FocusQuality) -> String {
        if context.lastSessionAbandoned {
            return "Fresh start — this one's yours"
        }
        if quality == .high && context.currentStreak > 3 {
            return "You're in peak form"
        }
        if context.sessionsToday == 0 {
            return "First session of the day — make it count"
        }
        return "Let's lock in"
    }
}
