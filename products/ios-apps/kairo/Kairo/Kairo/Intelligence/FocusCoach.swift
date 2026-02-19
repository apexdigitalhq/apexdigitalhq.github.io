import Foundation
import SwiftUI

// MARK: - CoachingCategory

/// Categories of personalized coaching the FocusCoach can deliver.
enum CoachingCategory: String, CaseIterable {
    case timing         // When to focus
    case duration       // How long to focus
    case energy         // Energy management
    case environment    // Distraction control
    case recovery       // Bouncing back from bad sessions
    case habits         // Building consistency
    case deepWork       // Achieving flow state
    case brainScience   // Understanding your brain

    var displayName: String {
        switch self {
        case .timing:       return "Timing"
        case .duration:     return "Duration"
        case .energy:       return "Energy"
        case .environment:  return "Environment"
        case .recovery:     return "Recovery"
        case .habits:       return "Habits"
        case .deepWork:     return "Deep Work"
        case .brainScience: return "Brain Science"
        }
    }

    var color: Color {
        switch self {
        case .timing:       return Color(hex: 0x3498DB)
        case .duration:     return KairoColors.accentAdaptive
        case .energy:       return Color(hex: 0xF39C12)
        case .environment:  return Color(hex: 0x1ABC9C)
        case .recovery:     return Color(hex: 0x9B59B6)
        case .habits:       return Color.orange
        case .deepWork:     return Color(hex: 0xE74C3C)
        case .brainScience: return Color(hex: 0x2980B9)
        }
    }
}

// MARK: - CoachingInsight

/// A single science-backed coaching insight with actionable advice.
///
/// Designed to feel like advice from a knowledgeable focus coach — confident,
/// direct, and backed by real neuroscience research.
struct CoachingInsight: Identifiable {
    let id = UUID()
    let category: CoachingCategory
    let title: String        // Short headline
    let advice: String       // 2-3 sentences of real, actionable advice
    let science: String      // 1 sentence explaining the neuroscience WHY
    let actionStep: String   // One specific thing to do
    let emoji: String
    let priority: Int        // 1-5
}

// MARK: - FocusCoach

/// Personalized focus coaching engine powered by user data and neuroscience.
///
/// Analyzes a user's `FocusPattern` and recent `SessionSummary` data to detect
/// specific behavioral patterns (afternoon slumps, attention span issues,
/// inconsistent scheduling, etc.) and returns 3-5 targeted, science-backed
/// coaching insights.
///
/// Each tip references real research — from Huberman's work on circadian rhythms
/// to Csikszentmihalyi's flow state research to Ward et al.'s smartphone proximity studies.
///
/// Usage:
/// ```swift
/// let coach = FocusCoach()
/// let insights = coach.analyze(pattern: focusPattern, sessions: recentSessions)
/// ```
final class FocusCoach {

    // MARK: - Analysis Entry Point

    /// Analyzes the user's focus data and returns 3-5 personalized coaching insights.
    ///
    /// Coaching depth scales with tier:
    /// - **Tier 1 (10-19 sessions):** Basic patterns — general tips, energy, brain science
    /// - **Tier 2 (20-29 sessions):** Intermediate — chronotype, schedule, duration analysis
    /// - **Tier 3 (30+ sessions):** Full AI coach — all pattern detection, deep personalization
    ///
    /// - Parameters:
    ///   - pattern: The user's aggregated focus pattern from Core Data.
    ///   - sessions: Recent session summaries (last 7-30 days).
    ///   - tier: Coaching tier (1 = basic, 2 = intermediate, 3 = full). Defaults to 3.
    /// - Returns: Array of 3-5 `CoachingInsight` values sorted by priority.
    func analyze(pattern: FocusPattern, sessions: [SessionSummary], tier: Int = 3) -> [CoachingInsight] {
        var insights: [CoachingInsight] = []
        let detected = detectPatterns(pattern: pattern, sessions: sessions, tier: tier)

        // Generate insights for each detected pattern
        for pattern in detected {
            if let insight = generateInsight(for: pattern) {
                insights.append(insight)
            }
        }

        // Always include one brain science / general tip for variety
        let hasBrainScience = detected.contains(where: {
            if case .brainScienceTip = $0 { return true }
            return false
        })
        if !hasBrainScience && insights.count < 5 {
            if let tip = generateInsight(for: .brainScienceTip) {
                insights.append(tip)
            }
        }

        // Sort by priority and cap at 5
        insights.sort { $0.priority < $1.priority }
        return Array(insights.prefix(5))
    }

    // MARK: - Pattern Detection

    /// Behavioral patterns detected from user data.
    private enum DetectedPattern {
        case afternoonSlump
        case shortAttentionSpan
        case inconsistentSchedule
        case weekendWarrior
        case streakBuilder(days: Int)
        case qualityPlateau
        case morningPerson
        case nightOwl
        case sessionLengthMismatch(actualMinutes: Int)
        case highPerformer
        case lowEnergy
        case overworking
        case brainScienceTip
    }

    /// Analyzes the user's data to detect behavioral patterns.
    /// Tier controls which patterns are detected:
    /// - Tier 1: basic (energy, brain science, short attention, low energy)
    /// - Tier 2: + chronotype, schedule consistency, duration mismatch
    /// - Tier 3: + everything (afternoon slump, weekend warrior, plateau, overworking, streaks)
    private func detectPatterns(
        pattern: FocusPattern,
        sessions: [SessionSummary],
        tier: Int = 3
    ) -> [DetectedPattern] {
        var detected: [DetectedPattern] = []

        let completionRate = Double(pattern.avgCompletionRate)
        let bestHourStart = Int(pattern.bestHourStart)
        let bestDay = Int(pattern.bestDayOfWeek)
        let optimalDuration = Int(pattern.optimalDuration)
        let sessionsPerDay = Double(pattern.avgSessionsPerDay)

        // --- Afternoon slump (Tier 3 only) ---
        guard tier >= 3 else {
            // For tiers 1-2, skip to simpler patterns below
            return detectBasicPatterns(
                tier: tier,
                completionRate: completionRate,
                bestHourStart: bestHourStart,
                sessionsPerDay: sessionsPerDay,
                optimalDuration: optimalDuration,
                bestDay: bestDay,
                sessions: sessions,
                pattern: pattern
            )
        }

        // --- Afternoon slump ---
        let afternoonSessions = sessions.filter {
            Calendar.current.component(.hour, from: $0.date) >= 13
        }
        let morningSessions = sessions.filter {
            let h = Calendar.current.component(.hour, from: $0.date)
            return h >= 6 && h < 13
        }
        if !afternoonSessions.isEmpty && !morningSessions.isEmpty {
            let pmQuality = afternoonSessions.map { $0.quality.numericValue }.reduce(0, +)
                / Double(afternoonSessions.count)
            let amQuality = morningSessions.map { $0.quality.numericValue }.reduce(0, +)
                / Double(morningSessions.count)
            if pmQuality < amQuality * 0.75 {
                detected.append(.afternoonSlump)
            }
        }

        // --- Short attention span ---
        if completionRate < 0.6 {
            detected.append(.shortAttentionSpan)
        }

        // --- Inconsistent schedule ---
        if sessions.count >= 5 {
            let hours = sessions.map { Calendar.current.component(.hour, from: $0.date) }
            let avgHour = Double(hours.reduce(0, +)) / Double(hours.count)
            let variance = hours.map { pow(Double($0) - avgHour, 2) }.reduce(0, +)
                / Double(hours.count)
            if variance > 16.0 { // std dev > 4 hours
                detected.append(.inconsistentSchedule)
            }
        }

        // --- Weekend warrior ---
        if bestDay >= 6 { // Saturday or Sunday
            let weekdaySessions = sessions.filter {
                let d = Calendar.current.component(.weekday, from: $0.date)
                return d >= 2 && d <= 6 // Mon-Fri (Calendar weekday: 1=Sun,2=Mon...7=Sat)
            }
            let weekendSessions = sessions.filter {
                let d = Calendar.current.component(.weekday, from: $0.date)
                return d == 1 || d == 7
            }
            if weekdaySessions.count > 0 && weekendSessions.count > 0 {
                let wdQuality = weekdaySessions.map { $0.quality.numericValue }.reduce(0, +)
                    / Double(weekdaySessions.count)
                let weQuality = weekendSessions.map { $0.quality.numericValue }.reduce(0, +)
                    / Double(weekendSessions.count)
                if weQuality > wdQuality * 1.2 {
                    detected.append(.weekendWarrior)
                }
            }
        }

        // --- Streak awareness (use data point count as proxy) ---
        let dataPoints = Int(pattern.dataPointCount)
        if dataPoints > 50 {
            detected.append(.streakBuilder(days: dataPoints))
        }

        // --- Quality plateau ---
        if sessions.count >= 10 {
            let firstHalf = Array(sessions.prefix(sessions.count / 2))
            let secondHalf = Array(sessions.suffix(sessions.count / 2))
            let firstAvg = firstHalf.map { $0.quality.numericValue }.reduce(0, +)
                / Double(firstHalf.count)
            let secondAvg = secondHalf.map { $0.quality.numericValue }.reduce(0, +)
                / Double(secondHalf.count)
            let diff = abs(secondAvg - firstAvg)
            if diff < 0.05 && firstAvg < 0.8 {
                detected.append(.qualityPlateau)
            }
        }

        // --- Chronotype ---
        if bestHourStart >= 5 && bestHourStart <= 9 {
            detected.append(.morningPerson)
        } else if bestHourStart >= 20 || bestHourStart <= 4 {
            detected.append(.nightOwl)
        }

        // --- Session length mismatch ---
        let abandonedSessions = sessions.filter { $0.quality == .low }
        if abandonedSessions.count >= 3 {
            let avgAbandonedDuration = abandonedSessions.map { $0.duration }.reduce(0, +)
                / Double(abandonedSessions.count)
            let actualMinutes = Int(avgAbandonedDuration / 60)
            if actualMinutes > 0 && actualMinutes < optimalDuration {
                detected.append(.sessionLengthMismatch(actualMinutes: actualMinutes))
            }
        }

        // --- High performer ---
        if completionRate >= 0.85 {
            let qualityValues = sessions.map { $0.quality.numericValue }
            let avgQuality = qualityValues.isEmpty ? 0
                : qualityValues.reduce(0, +) / Double(qualityValues.count)
            if avgQuality >= 0.7 {
                detected.append(.highPerformer)
            }
        }

        // --- Low energy / many low quality sessions ---
        let lowQualityRatio = sessions.isEmpty ? 0
            : Double(sessions.filter { $0.quality == .low }.count) / Double(sessions.count)
        if lowQualityRatio > 0.4 {
            detected.append(.lowEnergy)
        }

        // --- Overworking ---
        if sessionsPerDay > 6 {
            detected.append(.overworking)
        }

        // Ensure at least 3 results by adding brain science
        if detected.count < 3 {
            detected.append(.brainScienceTip)
        }

        return detected
    }

    /// Simplified pattern detection for Tiers 1-2.
    private func detectBasicPatterns(
        tier: Int,
        completionRate: Double,
        bestHourStart: Int,
        sessionsPerDay: Double,
        optimalDuration: Int,
        bestDay: Int,
        sessions: [SessionSummary],
        pattern: FocusPattern
    ) -> [DetectedPattern] {
        var detected: [DetectedPattern] = []

        // TIER 1 (10+ sessions): Basic patterns
        // Short attention span
        if completionRate < 0.6 {
            detected.append(.shortAttentionSpan)
        }

        // Low energy detection
        let lowQualityRatio = sessions.isEmpty ? 0
            : Double(sessions.filter { $0.quality == .low }.count) / Double(sessions.count)
        if lowQualityRatio > 0.4 {
            detected.append(.lowEnergy)
        }

        // High performer
        if completionRate >= 0.85 {
            let qualityValues = sessions.map { $0.quality.numericValue }
            let avgQuality = qualityValues.isEmpty ? 0
                : qualityValues.reduce(0, +) / Double(qualityValues.count)
            if avgQuality >= 0.7 {
                detected.append(.highPerformer)
            }
        }

        // Always include brain science at tier 1
        detected.append(.brainScienceTip)

        // TIER 2 (20+ sessions): Add chronotype, schedule, duration
        if tier >= 2 {
            // Chronotype
            if bestHourStart >= 5 && bestHourStart <= 9 {
                detected.append(.morningPerson)
            } else if bestHourStart >= 20 || bestHourStart <= 4 {
                detected.append(.nightOwl)
            }

            // Inconsistent schedule
            if sessions.count >= 5 {
                let hours = sessions.map { Calendar.current.component(.hour, from: $0.date) }
                let avgHour = Double(hours.reduce(0, +)) / Double(hours.count)
                let variance = hours.map { pow(Double($0) - avgHour, 2) }.reduce(0, +)
                    / Double(hours.count)
                if variance > 16.0 {
                    detected.append(.inconsistentSchedule)
                }
            }

            // Session length mismatch
            let abandonedSessions = sessions.filter { $0.quality == .low }
            if abandonedSessions.count >= 3 {
                let avgAbandonedDuration = abandonedSessions.map { $0.duration }.reduce(0, +)
                    / Double(abandonedSessions.count)
                let actualMinutes = Int(avgAbandonedDuration / 60)
                if actualMinutes > 0 && actualMinutes < optimalDuration {
                    detected.append(.sessionLengthMismatch(actualMinutes: actualMinutes))
                }
            }
        }

        // Ensure at least 3
        if detected.count < 3 {
            detected.append(.brainScienceTip)
        }

        return detected
    }

    // MARK: - Insight Generation

    /// Generates a coaching insight for a detected pattern.
    private func generateInsight(for pattern: DetectedPattern) -> CoachingInsight? {
        switch pattern {
        case .afternoonSlump:
            return afternoonSlumpTips.randomElement()
        case .shortAttentionSpan:
            return shortAttentionTips.randomElement()
        case .inconsistentSchedule:
            return inconsistentScheduleTips.randomElement()
        case .weekendWarrior:
            return weekendWarriorTips.randomElement()
        case .streakBuilder(let days):
            return streakBuilderTips(dataPoints: days).randomElement()
        case .qualityPlateau:
            return qualityPlateauTips.randomElement()
        case .morningPerson:
            return morningPersonTips.randomElement()
        case .nightOwl:
            return nightOwlTips.randomElement()
        case .sessionLengthMismatch(let minutes):
            return sessionMismatchTips(actualMinutes: minutes).randomElement()
        case .highPerformer:
            return highPerformerTips.randomElement()
        case .lowEnergy:
            return lowEnergyTips.randomElement()
        case .overworking:
            return overworkingTips.randomElement()
        case .brainScienceTip:
            return brainScienceTips.randomElement()
        }
    }

    // MARK: - Advice Banks (8-10+ tips per category)

    // =========================================================================
    // TIMING — Afternoon Slump
    // =========================================================================

    private var afternoonSlumpTips: [CoachingInsight] {
        [
            CoachingInsight(
                category: .timing,
                title: "Beat the Afternoon Dip",
                advice: "Your afternoon sessions are noticeably weaker than your mornings. The post-lunch dip isn't laziness — it's your circadian rhythm. Your body temperature drops 7-8 hours after waking, reducing alertness naturally.",
                science: "Circadian rhythm research shows a natural alertness trough in the early afternoon, driven by the postprandial dip in core body temperature (Monk, 2005).",
                actionStep: "Take a 10-minute walk or splash cold water on your wrists before your next afternoon session.",
                emoji: "🌤️",
                priority: 1
            ),
            CoachingInsight(
                category: .energy,
                title: "Lunch Is Sabotaging Your Focus",
                advice: "Heavy carb-loaded lunches spike blood sugar, then crash it 30 minutes later — right when you're trying to focus. Your afternoon quality drops because your brain is running on fumes after the insulin response.",
                science: "Glycemic index research shows high-GI meals cause rapid blood glucose spikes followed by crashes that impair cognitive function (Benton et al., 2003).",
                actionStep: "Switch to a protein-and-fat-heavy lunch (grilled chicken, avocado, nuts) and watch your 2 PM focus sharpen.",
                emoji: "🥗",
                priority: 2
            ),
            CoachingInsight(
                category: .timing,
                title: "Ride Your Ultradian Rhythm",
                advice: "Your brain works in 90-minute cycles of high and low alertness throughout the day. Your afternoon slump likely coincides with a natural trough. Instead of fighting it, schedule a brief rest during the low point and focus during the next peak.",
                science: "Peretz Lavie's ultradian rhythm research demonstrated ~90-minute cycles of alternating high and low alertness across the waking day.",
                actionStep: "After lunch, set a 20-minute rest timer (no screens), then start your focus session at the natural upswing.",
                emoji: "🌊",
                priority: 2
            ),
            CoachingInsight(
                category: .energy,
                title: "The Cold Water Reset",
                advice: "When afternoon drowsiness hits, your nervous system needs a wake-up signal. Cold exposure activates your sympathetic nervous system and triggers a norepinephrine release — the same neurotransmitter responsible for alertness and focus.",
                science: "Cold water exposure increases norepinephrine by up to 530% (Šrámek et al., 2000), dramatically boosting alertness and attention.",
                actionStep: "Run cold water over your wrists and the back of your neck for 30 seconds before your afternoon session.",
                emoji: "💧",
                priority: 2
            ),
            CoachingInsight(
                category: .timing,
                title: "Strategic Caffeine Timing",
                advice: "If you drink coffee in the morning, the crash hits right around 1-3 PM — exactly when you're trying to focus again. Your adenosine receptors rebound and you hit a wall. Time your caffeine to support your afternoon, not just your morning.",
                science: "Adenosine receptor rebound after caffeine clearance causes a predictable energy crash 4-6 hours post-consumption (Fredholm et al., 1999).",
                actionStep: "Delay your coffee until 90 minutes after waking, or have a small green tea at 1 PM for sustained, gentler alertness.",
                emoji: "☕",
                priority: 3
            ),
            CoachingInsight(
                category: .energy,
                title: "Afternoon Sunlight Trick",
                advice: "Your circadian clock has a second sensitivity window in the afternoon. Getting 10 minutes of outdoor light between 2-4 PM signals your brain to stay alert and also helps calibrate your sleep timing for that night.",
                science: "Andrew Huberman's research at Stanford shows afternoon sunlight exposure helps maintain the cortisol-melatonin cycle, preventing premature evening drowsiness.",
                actionStep: "Step outside for 10 minutes of direct sunlight between 2-4 PM before your next focus block.",
                emoji: "☀️",
                priority: 3
            ),
            CoachingInsight(
                category: .timing,
                title: "Flip Your Hard/Easy Tasks",
                advice: "You're fighting biology by tackling complex work in the afternoon. Your prefrontal cortex — the part that handles hard thinking — is depleted by afternoon. Save deep analytical work for morning and use afternoon for more routine or creative tasks.",
                science: "Prefrontal cortex glucose depletion follows a predictable daily pattern, with maximum capacity in the first 2-4 hours after waking (Baumeister & Tierney, 2011).",
                actionStep: "Tomorrow, move your hardest task to your first focus session and schedule administrative or creative work for post-lunch.",
                emoji: "🔄",
                priority: 2
            ),
            CoachingInsight(
                category: .energy,
                title: "The 5-Minute Movement Reset",
                advice: "Five minutes of movement — even just walking up stairs or doing jumping jacks — floods your brain with BDNF and increases blood flow by 15-20%. This is the fastest way to break out of afternoon fog without chemicals.",
                science: "Brief exercise bouts increase Brain-Derived Neurotrophic Factor (BDNF) and cerebral blood flow, restoring cognitive function (Ratey, 2008).",
                actionStep: "Before your next afternoon session, do 5 minutes of any movement that raises your heart rate slightly.",
                emoji: "🏃",
                priority: 2
            ),
            CoachingInsight(
                category: .timing,
                title: "The Second Wind Is Real",
                advice: "Your alertness naturally rises again around 4-6 PM as core body temperature peaks. If afternoon is a dead zone, consider a split schedule: strong morning block, genuine rest 1-3 PM, then a second focus sprint in the late afternoon.",
                science: "Core body temperature follows a sinusoidal pattern with a secondary peak in late afternoon, correlating with improved cognitive performance (Valdez, 2019).",
                actionStep: "Try scheduling a 4:30-5:30 PM focus block this week and compare the quality to your 1-2 PM sessions.",
                emoji: "🔋",
                priority: 3
            ),
            CoachingInsight(
                category: .energy,
                title: "Breathing for Alertness",
                advice: "When you feel the afternoon slump, your breathing naturally becomes slower and shallower. A 2-minute cyclic hyperventilation pattern (fast inhale, passive exhale) shifts your nervous system into alertness mode without caffeine.",
                science: "Deliberate cyclic hyperventilation increases adrenaline and alertness by shifting the autonomic balance toward sympathetic activation (Wim Hof method research, Kox et al., 2014).",
                actionStep: "Try 25 rapid breaths (in through nose, out through mouth) followed by a 15-second hold before your next afternoon session.",
                emoji: "🌬️",
                priority: 3
            )
        ]
    }

    // =========================================================================
    // DURATION — Short Attention Span
    // =========================================================================

    private var shortAttentionTips: [CoachingInsight] {
        [
            CoachingInsight(
                category: .duration,
                title: "Build Focus Like a Muscle",
                advice: "Your completion rate suggests sessions may be too long for where your focus is right now — and that's okay. Attention is a skill, not a trait. Start shorter and build up progressively, adding 5 minutes every few days.",
                science: "Neuroplasticity research shows that sustained attention circuits strengthen with practice — the prefrontal cortex literally grows new connections (Lazar et al., 2005).",
                actionStep: "Drop your session length by 10 minutes this week. Complete every session. Next week, add 5 minutes back.",
                emoji: "💪",
                priority: 1
            ),
            CoachingInsight(
                category: .duration,
                title: "The Pomodoro Ramp-Up",
                advice: "The classic Pomodoro is 25 minutes, but if you're abandoning sessions, that's too long right now. Start with a 10-minute 'micro-pomodoro' — it's almost impossible to fail. Success creates confidence, and confidence extends focus.",
                science: "Self-efficacy theory (Bandura, 1977) shows that small successes build confidence, which directly improves performance on subsequent attempts.",
                actionStep: "Set your next 3 sessions to just 10 minutes each. Complete all three, then increase to 15.",
                emoji: "🍅",
                priority: 1
            ),
            CoachingInsight(
                category: .duration,
                title: "Completion > Duration",
                advice: "A completed 15-minute session trains your brain better than an abandoned 45-minute one. Every time you quit early, your brain learns that quitting is an option. Every time you finish, you reinforce the 'I follow through' neural pathway.",
                science: "The Zeigarnik effect shows that incomplete tasks create cognitive tension, while completed tasks provide a dopamine reward that reinforces the behavior (Zeigarnik, 1927).",
                actionStep: "For the next week, set sessions to a length you're 100% confident you can finish. Build from there.",
                emoji: "✅",
                priority: 1
            ),
            CoachingInsight(
                category: .duration,
                title: "Remove the Escape Hatch",
                advice: "If you know you can quit anytime, your brain will look for reasons to. Commit to the session fully — tell yourself 'I will sit here for X minutes no matter what.' Even if focus wavers, staying in the chair trains endurance.",
                science: "Implementation intentions — specific if-then plans — increase follow-through by 2-3x compared to general goals (Gollwitzer, 1999).",
                actionStep: "Before starting your next session, say out loud: 'I will stay focused for exactly [X] minutes, no exceptions.'",
                emoji: "🔒",
                priority: 2
            ),
            CoachingInsight(
                category: .duration,
                title: "The Boredom Barrier",
                advice: "Most people don't quit because the task is hard — they quit because they hit boredom. Boredom arrives around the 8-12 minute mark for untrained attention. If you push through it, focus often returns stronger on the other side.",
                science: "Research on the 'attention reset' phenomenon shows that focus follows a U-shaped curve — dipping mid-session before recovering (Thomson et al., 2015).",
                actionStep: "When you feel the urge to quit, check the time. If you're between 8-15 minutes in, just wait 3 more minutes. The urge will pass.",
                emoji: "🎢",
                priority: 2
            ),
            CoachingInsight(
                category: .duration,
                title: "Pre-Session Planning Matters",
                advice: "Sessions fail when you don't know exactly what to work on. Decision fatigue during the session itself burns willpower that should go to focus. Decide your task before starting — even write it on a sticky note.",
                science: "Decision fatigue depletes the same mental resources used for sustained attention (Vohs et al., 2008). Pre-deciding removes this tax.",
                actionStep: "Before each session, write down one sentence: 'During this session, I will ___.' Then start.",
                emoji: "📝",
                priority: 2
            ),
            CoachingInsight(
                category: .duration,
                title: "Your Phone Is the Problem",
                advice: "If you're checking your phone during sessions, that's the #1 reason for low completion. Each phone check isn't just a 30-second distraction — it takes 23 minutes to fully regain deep focus afterward. Your session is effectively over.",
                science: "Gloria Mark's UC Irvine research found it takes an average of 23 minutes and 15 seconds to return to the original task after an interruption.",
                actionStep: "Put your phone in another room — not just face down, physically out of reach — for your next session.",
                emoji: "📵",
                priority: 1
            ),
            CoachingInsight(
                category: .duration,
                title: "Gamify Your Completion",
                advice: "Your brain responds to variable rewards more than constant ones. Track your completion streaks — 3 in a row, 5 in a row, 10 in a row. Each completed session should feel like a win, because neurologically, it is one.",
                science: "Variable ratio reinforcement schedules produce the highest engagement rates in behavioral psychology (Skinner, 1957). Streaks tap into this mechanism.",
                actionStep: "Aim for 5 consecutive completed sessions this week, regardless of length. Celebrate when you hit it.",
                emoji: "🎮",
                priority: 3
            ),
            CoachingInsight(
                category: .habits,
                title: "The Two-Minute Start",
                advice: "The hardest part of any focus session is the first 2 minutes. Your brain is resisting the transition from 'free mode' to 'focus mode.' Commit to just 2 minutes — after that, continuing is almost always easier than stopping.",
                science: "Behavioral activation research shows that starting a task reduces resistance exponentially — motivation follows action, not the other way around (Martell et al., 2010).",
                actionStep: "When you feel resistance, commit to just 120 seconds. Set a stopwatch. Most of the time, you'll keep going.",
                emoji: "⏱️",
                priority: 2
            ),
            CoachingInsight(
                category: .duration,
                title: "Track Your Natural Limit",
                advice: "You have a current natural attention span — the point where focus consistently breaks down. That's not a weakness, it's your training baseline. Like a runner who can only do 2 miles, you don't start with a marathon. You build from what's real.",
                science: "Progressive overload — a principle from exercise science — applies equally to cognitive endurance training (Ericsson, 1993).",
                actionStep: "Check your average session duration before abandoning. Set your next session to that exact duration. Complete it, then add 2 minutes.",
                emoji: "📏",
                priority: 2
            )
        ]
    }

    // =========================================================================
    // TIMING — Inconsistent Schedule
    // =========================================================================

    private var inconsistentScheduleTips: [CoachingInsight] {
        [
            CoachingInsight(
                category: .habits,
                title: "Anchor Your Focus Time",
                advice: "Your sessions happen at wildly different times — and your brain never quite knows when to be ready. Consistent timing trains your circadian system to prime focus chemicals (cortisol, norepinephrine) before you even sit down.",
                science: "Circadian entrainment research shows that consistent behavioral cues synchronize neurotransmitter release cycles (Czeisler et al., 1999).",
                actionStep: "Pick one time slot this week and do all your focus sessions within a 1-hour window of that time.",
                emoji: "⚓",
                priority: 1
            ),
            CoachingInsight(
                category: .timing,
                title: "Same Time, Same Brain State",
                advice: "Your brain is a pattern machine. When you focus at the same time daily, your neural circuits start preparing in advance — priming working memory, suppressing distractions, and releasing focus neurotransmitters before you even begin.",
                science: "Temporal conditioning in neuroscience shows the brain anticipates recurring demands and pre-allocates resources (Nobre & van Ede, 2018).",
                actionStep: "Set a daily recurring alarm for your focus session. Same time, every day, for 7 days straight.",
                emoji: "🧠",
                priority: 1
            ),
            CoachingInsight(
                category: .habits,
                title: "Stack It on an Existing Habit",
                advice: "Random timing fails because it requires a decision each time — 'when should I focus today?' Decision fatigue kills consistency. Instead, attach your session to something you already do: after morning coffee, after lunch, right after commute.",
                science: "Habit stacking leverages existing neural pathways as triggers, dramatically reducing the willpower needed to start (Clear, 2018; Fogg, 2020).",
                actionStep: "Identify your most consistent daily habit and immediately follow it with a focus session tomorrow.",
                emoji: "📚",
                priority: 2
            ),
            CoachingInsight(
                category: .timing,
                title: "Your Body Has a Schedule",
                advice: "Even if your calendar is chaotic, your body isn't. Your cortisol, dopamine, and adenosine follow a reliable 24-hour cycle. Working with this cycle — not against it — means more focus with less effort.",
                science: "The suprachiasmatic nucleus (SCN) maintains a consistent ~24-hour cycle of neurotransmitter release regardless of behavioral variability (Reppert & Weaver, 2002).",
                actionStep: "Note when you naturally feel most alert this week (don't try to change anything). Then anchor your sessions to that window.",
                emoji: "🕰️",
                priority: 2
            ),
            CoachingInsight(
                category: .habits,
                title: "The Calendar Block Hack",
                advice: "If your focus time is flexible, it's vulnerable. Treat it like a meeting — block it on your calendar, set a reminder, and protect it from interruptions. People who time-block their deep work produce 4x more output.",
                science: "Cal Newport's research on deep work scheduling shows that protected time blocks correlate with significantly higher knowledge-worker productivity.",
                actionStep: "Block 'Focus Session' on your calendar for the same time tomorrow. Set it as a recurring event.",
                emoji: "📅",
                priority: 2
            ),
            CoachingInsight(
                category: .habits,
                title: "Reduce Decision Points",
                advice: "Every time you decide 'should I focus now?', you spend willpower. The goal is to make focusing as automatic as brushing teeth — zero decisions required. A consistent trigger + time eliminates this entirely.",
                science: "Ego depletion research shows that making decisions draws from the same limited pool as self-control (Baumeister et al., 1998).",
                actionStep: "Create a 'focus trigger' — a specific song, drink, or action you always do before starting. Train your brain to associate it with focus mode.",
                emoji: "🔁",
                priority: 3
            ),
            CoachingInsight(
                category: .timing,
                title: "Don't Optimize, Standardize",
                advice: "Trying to find the 'perfect time' each day is worse than a consistent 'good enough' time. A predictable 3 PM session you never skip beats a theoretical 9 AM session you only do twice a week.",
                science: "Behavioral consistency trumps optimal timing in habit research — frequency of execution is the strongest predictor of habit formation (Lally et al., 2010).",
                actionStep: "Pick a 'good enough' time that works 5+ days per week. Commit to it for 2 weeks without trying to optimize.",
                emoji: "🎯",
                priority: 2
            ),
            CoachingInsight(
                category: .habits,
                title: "Use Environmental Cues",
                advice: "Your brain links locations and objects to behaviors. If you always focus in the same spot, your environment becomes a trigger. Your brain starts shifting into focus mode the moment you sit down in 'the chair.'",
                science: "Context-dependent memory and behavioral cueing show that physical environments activate associated cognitive states (Godden & Baddeley, 1975).",
                actionStep: "Designate one specific spot — same chair, same desk — as your 'focus zone.' Use it only for focus sessions.",
                emoji: "🪑",
                priority: 3
            )
        ]
    }

    // =========================================================================
    // ENVIRONMENT — Weekend Warrior
    // =========================================================================

    private var weekendWarriorTips: [CoachingInsight] {
        [
            CoachingInsight(
                category: .environment,
                title: "Your Weekday Problem Is Environment",
                advice: "You focus better on weekends, which tells me it's not a discipline problem — it's an environment problem. Weekdays likely have more interruptions, more meetings, more noise. The fix isn't willpower — it's workspace design.",
                science: "Open-plan office research shows that visual and auditory distractions reduce cognitive performance by 15-28% (Banbury & Berry, 2005).",
                actionStep: "Identify the top 3 weekday distractions (Slack, open office, meetings) and block at least one during tomorrow's focus time.",
                emoji: "🏢",
                priority: 1
            ),
            CoachingInsight(
                category: .environment,
                title: "Create a Weekday 'Focus Bubble'",
                advice: "On weekends, you naturally have more control over your time and space. Recreate that on weekdays: noise-canceling headphones, closed door or 'do not disturb' status, phone silenced. Your brain needs the same conditions to perform.",
                science: "Cognitive load theory shows that environmental distractions consume working memory capacity that should be allocated to the primary task (Sweller, 1988).",
                actionStep: "Put on noise-canceling headphones and set Slack/Teams to DND before your next weekday focus session.",
                emoji: "🫧",
                priority: 1
            ),
            CoachingInsight(
                category: .environment,
                title: "Protect Your Weekday Mornings",
                advice: "Most weekday distractions pile up after 10 AM — emails, meetings, questions. Your morning window (before others fully wake up or log in) is sacred. Grab it before the world takes it from you.",
                science: "Research on 'maker's schedule vs manager's schedule' (Paul Graham) shows creative workers need uninterrupted blocks that are best placed at day boundaries.",
                actionStep: "Set your first focus session to start 30 minutes before your official workday begins. Guard this block ruthlessly.",
                emoji: "🛡️",
                priority: 2
            ),
            CoachingInsight(
                category: .habits,
                title: "Weekday Ritual = Weekend Results",
                advice: "Your weekend success isn't magic — it's the absence of friction. Build a weekday pre-focus ritual (2-3 minutes) that transitions your brain from 'reactive mode' to 'proactive mode.' Same ritual, every time, regardless of the day.",
                science: "Pre-performance routines reduce anxiety and improve performance by providing a consistent cognitive transition (Singer, 2002).",
                actionStep: "Before each weekday session: close all tabs, put on your headphones, take 3 deep breaths. This becomes your 'switching on' ritual.",
                emoji: "⚡",
                priority: 2
            ),
            CoachingInsight(
                category: .environment,
                title: "Batch Your Distractions",
                advice: "Don't check email/Slack/messages between focus sessions — batch them. Check once before your first session and once after. This gives you the same communication-free zone you naturally have on weekends.",
                science: "Batching communication reduced stress by 50% and improved daily productivity in a study at the University of British Columbia (Kushlev & Dunn, 2015).",
                actionStep: "Tomorrow, check messages at 9 AM and 12 PM only. Keep your focus sessions communication-free.",
                emoji: "📦",
                priority: 2
            ),
            CoachingInsight(
                category: .environment,
                title: "The Notification Audit",
                advice: "You probably have 20+ apps sending notifications on weekdays. Each one is a cognitive interrupt — even if you don't act on it, your brain spends 3-5 seconds processing and deciding. That fragmentation compounds across hours.",
                science: "A Carnegie Mellon study found that even brief interruptions of 2-3 seconds double the error rate on subsequent tasks (Altmann et al., 2014).",
                actionStep: "Go to Settings → Notifications right now and disable everything except calls and texts during work hours.",
                emoji: "🔕",
                priority: 1
            ),
            CoachingInsight(
                category: .environment,
                title: "Change Your Weekday Location",
                advice: "If your weekend focus happens in a different physical space than weekday work, that's a huge clue. Your brain may associate your desk with shallow work, meetings, and reactivity. Try a different spot for deep focus — even a different chair.",
                science: "Context-dependent cognition shows that changing physical environments can shift the brain's default processing mode (Smith & Vela, 2001).",
                actionStep: "Try doing your weekday focus session in a different room, a café, or even just a different corner of your office.",
                emoji: "🔄",
                priority: 3
            ),
            CoachingInsight(
                category: .habits,
                title: "Tell People You're Unavailable",
                advice: "On weekends, nobody expects instant responses. On weekdays, they do — unless you tell them otherwise. Proactively communicate your focus blocks. 'I'm offline 9-10 AM for deep work' sets expectations and removes guilt.",
                science: "Social accountability research shows that publicly stated commitments increase follow-through by up to 65% (Cialdini, 2006).",
                actionStep: "Send a message to your team tomorrow morning: 'I'll be offline for deep work from [time] to [time]. I'll respond after.'",
                emoji: "💬",
                priority: 2
            )
        ]
    }

    // =========================================================================
    // HABITS — Streak Builder
    // =========================================================================

    private func streakBuilderTips(dataPoints: Int) -> [CoachingInsight] {
        [
            CoachingInsight(
                category: .habits,
                title: "Protect Your Momentum",
                advice: "You've built a serious focus practice. At this point, the biggest risk isn't quitting — it's burnout. Sustainable performers take strategic rest days. One planned day off won't break your habit; forcing through exhaustion will.",
                science: "Deliberate rest periods enhance performance through consolidation — neural pathways strengthen during recovery, not just during practice (Walker, 2017).",
                actionStep: "Schedule one 'active rest' day per week — light tasks only, no intense focus blocks. Your brain needs it.",
                emoji: "🧘",
                priority: 2
            ),
            CoachingInsight(
                category: .habits,
                title: "Identity > Motivation",
                advice: "After \(dataPoints)+ sessions, you're past needing motivation. You're someone who focuses daily — it's identity now, not willpower. The danger is 'what-the-hell effect' if you miss one day. Missing once is an accident; missing twice is a new habit.",
                science: "Identity-based habit formation (Clear, 2018) shows that behavioral change sticks when it becomes part of self-concept rather than relying on external motivation.",
                actionStep: "If you miss a day, your one rule is: never miss twice in a row. Get a session in the next day, even if it's 5 minutes.",
                emoji: "🪞",
                priority: 2
            ),
            CoachingInsight(
                category: .deepWork,
                title: "Level Up Your Sessions",
                advice: "Consistency is locked in — now it's time for quality. You've been running; now learn to sprint. Try progressive overload: increase session length by 5 minutes, tackle a harder task, or add a 'no-break' challenge once a week.",
                science: "Deliberate practice theory (Ericsson, 1993) distinguishes between mindless repetition and purposeful challenge — only the latter produces mastery.",
                actionStep: "This week, make one session 10 minutes longer than usual and attempt a task slightly above your comfort zone.",
                emoji: "📈",
                priority: 3
            ),
            CoachingInsight(
                category: .habits,
                title: "The Seinfeld Strategy",
                advice: "Jerry Seinfeld's productivity method: put an X on the calendar every day you write. After a few days, you have a chain — and the only rule is 'don't break the chain.' The visual streak becomes its own motivator.",
                science: "Visual progress tracking activates the brain's reward system through the goal gradient effect — we accelerate effort as we see progress toward a milestone (Kivetz et al., 2006).",
                actionStep: "Open your calendar app and mark every focus day with a ✅. Let the visual chain motivate you.",
                emoji: "📆",
                priority: 3
            ),
            CoachingInsight(
                category: .habits,
                title: "Vary Your Session Types",
                advice: "Long streaks with the same routine get stale. Your brain craves novelty within structure. Mix up session types — work, study, creative — or try different environments. The streak stays intact; the experience stays fresh.",
                science: "Contextual interference research shows that varied practice conditions improve long-term skill retention more than blocked, repetitive practice (Shea & Morgan, 1979).",
                actionStep: "Try a creative or personal focus session today instead of your usual type. Same commitment, different flavor.",
                emoji: "🎨",
                priority: 3
            ),
            CoachingInsight(
                category: .habits,
                title: "Teach What You've Learned",
                advice: "At your level, you know things about focus that most people don't. Teaching others what you've learned — even informally — reinforces your own commitment and deepens your understanding of your process.",
                science: "The protégé effect shows that teaching material to others significantly improves the teacher's own retention and performance (Nestojko et al., 2014).",
                actionStep: "Share one focus tip you've personally validated with a friend or colleague this week.",
                emoji: "🎓",
                priority: 4
            ),
            CoachingInsight(
                category: .habits,
                title: "Minimum Viable Session",
                advice: "Even streak masters have bad days. The key is your 'minimum viable session' — the absolute lowest bar that still counts. For you, that might be 5-10 minutes. On exhausted days, this keeps the chain alive without burning you out.",
                science: "Implementation intentions with a 'plan B' minimum increase habit persistence by reducing all-or-nothing thinking (Gollwitzer & Sheeran, 2006).",
                actionStep: "Define your minimum viable session right now: ___ minutes. This is your bad-day floor. Non-negotiable.",
                emoji: "🔑",
                priority: 2
            ),
            CoachingInsight(
                category: .energy,
                title: "Watch for Overtraining Signs",
                advice: "Just like athletes overtrain muscles, you can overtrain focus. Signs: dreading sessions, declining quality despite effort, irritability. If you notice these, it's not laziness — it's your brain asking for recovery.",
                science: "Cognitive fatigue follows patterns similar to physical overtraining — performance declines despite maintained effort, requiring active recovery (Van Cutsem et al., 2017).",
                actionStep: "If quality has dropped 3 sessions in a row, take a full day off from structured focus. Walk, read, do something unstructured.",
                emoji: "⚠️",
                priority: 2
            )
        ]
    }

    // =========================================================================
    // DEEP WORK — Quality Plateau
    // =========================================================================

    private var qualityPlateauTips: [CoachingInsight] {
        [
            CoachingInsight(
                category: .deepWork,
                title: "You've Hit a Plateau",
                advice: "Your quality has been stable but isn't climbing. This happens when your sessions become routine — comfortable but not challenging. To grow, you need deliberate practice: increase difficulty, change environment, or add constraints.",
                science: "Anders Ericsson's deliberate practice framework shows that improvement stops when practice becomes automatic — only purposeful challenge drives further gains.",
                actionStep: "This week, pick one session and add a constraint: no music, 10 minutes longer, or a harder task than usual.",
                emoji: "🏔️",
                priority: 1
            ),
            CoachingInsight(
                category: .deepWork,
                title: "Change One Variable",
                advice: "Your brain has adapted to your current routine — which means it's running on autopilot. That's great for consistency, but autopilot doesn't improve quality. Change one variable: time of day, location, session length, or task type.",
                science: "The brain's habituation response reduces the neural resources allocated to familiar stimuli and routines (Thompson & Spencer, 1966).",
                actionStep: "Move your focus session to a completely different time or location tomorrow. Just for one day. Observe what changes.",
                emoji: "🔬",
                priority: 2
            ),
            CoachingInsight(
                category: .deepWork,
                title: "The 4% Rule of Flow",
                advice: "Flow state — that effortless deep focus — requires a task that's roughly 4% harder than your current ability. Too easy and you're bored. Too hard and you're anxious. You need the sweet spot that stretches you without breaking you.",
                science: "Mihaly Csikszentmihalyi's flow research identifies the challenge-skill balance as the primary trigger for flow states (Csikszentmihalyi, 1990).",
                actionStep: "Before your next session, ask: 'Is this task slightly harder than what's comfortable?' If not, add a challenge layer.",
                emoji: "🎯",
                priority: 2
            ),
            CoachingInsight(
                category: .deepWork,
                title: "Eliminate Micro-Distractions",
                advice: "Plateaus often hide micro-distractions you've normalized — browser tabs, a noisy environment, or even thoughts about what's next. These fragment your attention without you realizing it. A 'deep work audit' can reveal hidden quality killers.",
                science: "Attentional residue research shows that even brief mental detours to other tasks leave performance-degrading cognitive residue (Leroy, 2009).",
                actionStep: "For your next session, close every app except the one you're working in. Every. Single. One.",
                emoji: "🧹",
                priority: 1
            ),
            CoachingInsight(
                category: .deepWork,
                title: "Progressive Session Overload",
                advice: "Like weightlifting, focus needs progressive overload to improve. If you always do 25-minute sessions, your brain never needs to push beyond that. Once a week, attempt a session that's 50% longer than your usual — even if quality dips, you're training capacity.",
                science: "Cognitive endurance training follows similar adaptation principles to physical training — progressive overload drives capacity increases (Ericsson, 1993).",
                actionStep: "Schedule one 'stretch session' this week at 1.5x your normal duration. Expect it to be hard — that's the point.",
                emoji: "🏋️",
                priority: 2
            ),
            CoachingInsight(
                category: .environment,
                title: "Novel Environments Break Plateaus",
                advice: "Your brain processes familiar environments on autopilot. A new location — café, library, park bench — forces your brain into a heightened state of awareness. This 'environmental novelty' effect can boost creative output by 15-20%.",
                science: "Environmental novelty increases dopamine release in the mesocortical pathway, enhancing cognitive flexibility and creative problem-solving (Costa et al., 2014).",
                actionStep: "Do at least one focus session this week in a place you've never worked before.",
                emoji: "🗺️",
                priority: 3
            ),
            CoachingInsight(
                category: .deepWork,
                title: "Add a Focus Ritual",
                advice: "Elite performers — athletes, musicians, surgeons — use pre-performance rituals to trigger peak states. Create a 2-minute pre-session ritual (same music, same breath pattern, same drink) that signals your brain: it's time to go deep.",
                science: "Pre-performance routines reduce cognitive interference and prime task-relevant neural circuits through Pavlovian conditioning (Cotterill, 2010).",
                actionStep: "Design a 2-minute ritual: breathe for 30 sec, put on headphones, open one app, start. Do this identically before every session.",
                emoji: "🎭",
                priority: 3
            ),
            CoachingInsight(
                category: .deepWork,
                title: "End Sessions at Peak Focus",
                advice: "Counterintuitively, ending a session while you're still in flow — not after you've burnt out — creates a positive association that pulls you back next time. Hemingway did this: he stopped writing mid-sentence so the next day started easy.",
                science: "The Hemingway technique leverages the Zeigarnik effect and positive affect transfer — stopping during engagement creates eagerness to resume (Hemingway, via Zeigarnik, 1927).",
                actionStep: "In your next session, stop 5 minutes before your timer ends, right when focus feels strongest. Notice how you feel about the next session.",
                emoji: "✂️",
                priority: 3
            ),
            CoachingInsight(
                category: .deepWork,
                title: "Track What You Actually Did",
                advice: "Plateaus persist when you don't know what's holding you back. After each session, write one line: what you accomplished and what distracted you. After a week, patterns will emerge that tell you exactly where quality leaks.",
                science: "Self-monitoring is one of the strongest predictors of behavioral change — awareness alone shifts performance (Korotitsch & Nelson-Gray, 1999).",
                actionStep: "After your next 3 sessions, write one sentence each: 'I focused on ___, and my biggest distraction was ___.''",
                emoji: "📓",
                priority: 2
            )
        ]
    }

    // =========================================================================
    // TIMING — Morning Person
    // =========================================================================

    private var morningPersonTips: [CoachingInsight] {
        [
            CoachingInsight(
                category: .timing,
                title: "You're a Morning Focuser",
                advice: "Your best sessions cluster in the morning — your brain's prefrontal cortex is most active 2-4 hours after waking. This is your biological prime time for deep work. Protect it ruthlessly from meetings, emails, and other people's agendas.",
                science: "Prefrontal cortex activity peaks 2-4 hours after waking when cortisol levels are optimally elevated for cognitive performance (Scheer & Buijs, 1999).",
                actionStep: "Block your morning peak hours on your calendar as 'deep work' — no meetings, no email, no exceptions.",
                emoji: "🌅",
                priority: 2
            ),
            CoachingInsight(
                category: .energy,
                title: "Morning Sunlight = Better Focus",
                advice: "Getting bright light in your eyes within 30 minutes of waking triggers a cortisol pulse that sets your entire day's alertness curve. Skip it, and you start the day in a cognitive fog that no amount of coffee fully fixes.",
                science: "Morning light exposure sets the timing of the cortisol awakening response, which regulates alertness and cognitive function for the next 12-16 hours (Huberman, Stanford Neuroscience).",
                actionStep: "Spend 5-10 minutes outside within 30 minutes of waking tomorrow. No sunglasses. Direct (not dangerous) sunlight.",
                emoji: "☀️",
                priority: 2
            ),
            CoachingInsight(
                category: .timing,
                title: "Do Hard Things First",
                advice: "Your willpower and decision-making capacity are highest in the morning. Every decision you make throughout the day drains this finite resource. Put your hardest, most important focus work first — before your brain spends its best energy on trivia.",
                science: "Ego depletion research shows that self-control and complex decision-making draw from a limited daily resource pool (Baumeister et al., 2007).",
                actionStep: "Identify the single most important task for tomorrow. Make it the focus of your first session of the day.",
                emoji: "⚔️",
                priority: 2
            ),
            CoachingInsight(
                category: .energy,
                title: "Delay Your Coffee",
                advice: "Drinking coffee immediately after waking interferes with your natural cortisol peak — you're adding stimulation when your body is already providing it. Wait 90-120 minutes. When cortisol naturally dips, caffeine becomes dramatically more effective.",
                science: "Cortisol peaks 30-45 minutes after waking. Caffeine consumed during this window blocks adenosine receptors that are already suppressed, reducing its effectiveness (Miller, 2015).",
                actionStep: "Push your first coffee to 90 minutes after waking. Use that natural cortisol peak for your first focus session instead.",
                emoji: "☕",
                priority: 3
            ),
            CoachingInsight(
                category: .timing,
                title: "Guard Against Email First Thing",
                advice: "Checking email first thing in the morning is the biggest focus killer for morning people. It shifts you from proactive mode to reactive mode — your brain starts working on other people's priorities instead of your own deep work.",
                science: "Reactive task switching first thing in the morning creates 'attentional residue' that degrades cognitive performance for hours afterward (Leroy, 2009).",
                actionStep: "Don't open email or Slack until after your first focus session. Let your first hour be 100% yours.",
                emoji: "📧",
                priority: 1
            ),
            CoachingInsight(
                category: .timing,
                title: "Your Morning Peak Has a Timer",
                advice: "Your morning focus advantage lasts about 3-4 hours after waking. After that, cognitive resources start declining. Make sure your most demanding work lands squarely in this window — don't waste it on easy tasks.",
                science: "The 'morning morality effect' and related research shows a consistent decline in executive function and self-regulation as the day progresses (Kouchaki & Smith, 2014).",
                actionStep: "Map your next 3 days: are your hardest tasks in your first 3 hours? If not, rearrange.",
                emoji: "⏳",
                priority: 2
            ),
            CoachingInsight(
                category: .habits,
                title: "The Morning Launch Sequence",
                advice: "Create a non-negotiable morning sequence that ends with your focus session. Wake → hydrate → sunlight → movement → focus. This chain becomes automatic within 2 weeks — no decisions required, your body just does it.",
                science: "Habit chaining links new behaviors to established routines, reducing the cognitive cost of initiation (Duhigg, 2012; Fogg, 2020).",
                actionStep: "Write down your morning sequence on a sticky note and follow it exactly for the next 5 days.",
                emoji: "🚀",
                priority: 3
            ),
            CoachingInsight(
                category: .energy,
                title: "Protein First, Carbs Later",
                advice: "A protein-heavy breakfast sustains blood glucose for 3-4 hours — keeping your brain fueled through your morning peak. Carb-heavy breakfasts (toast, cereal, juice) spike and crash within 90 minutes, right when you should be peaking.",
                science: "Protein-rich meals produce a slower, more sustained glucose curve compared to high-glycemic breakfasts, maintaining cognitive function longer (Hoyland et al., 2009).",
                actionStep: "Try eggs, Greek yogurt, or nuts for breakfast tomorrow instead of bread/cereal. Note your 10-11 AM focus level.",
                emoji: "🥚",
                priority: 3
            )
        ]
    }

    // =========================================================================
    // TIMING — Night Owl
    // =========================================================================

    private var nightOwlTips: [CoachingInsight] {
        [
            CoachingInsight(
                category: .timing,
                title: "Own Your Night Owl Nature",
                advice: "Your data shows you focus best late in the day. This isn't a flaw — it's your chronotype. About 25% of people are genetically wired for evening productivity. Stop fighting your biology and optimize for it instead.",
                science: "Chronotype research shows that evening types have delayed circadian rhythms controlled by PER3 gene variants — it's genetic, not behavioral (Archer et al., 2003).",
                actionStep: "Stop scheduling deep work in the morning. Move your most important tasks to your natural evening peak.",
                emoji: "🌙",
                priority: 2
            ),
            CoachingInsight(
                category: .energy,
                title: "Light Management for Night Owls",
                advice: "As a night owl, bright artificial light in the evening can further delay your sleep onset — making morning meetings even harder. Use warm, dim lighting after 8 PM and blue-light filters on all screens during evening focus sessions.",
                science: "Blue light suppresses melatonin production by up to 50%, further shifting circadian timing in evening-type individuals (Chang et al., 2015).",
                actionStep: "Turn on Night Shift / blue-light filter on all devices after 8 PM. Use warm-toned ambient lighting.",
                emoji: "💡",
                priority: 3
            ),
            CoachingInsight(
                category: .timing,
                title: "The Night Owl Advantage",
                advice: "Late-night sessions have one massive advantage: zero interruptions. No emails, no messages, no one asking for your time. This distraction-free environment is why your quality peaks at night — lean into it for deep, complex work.",
                science: "Reduced social interruptions during non-standard hours significantly increase flow state probability (Mark et al., 2008).",
                actionStep: "Reserve your most intellectually demanding task for your evening focus session when the world is quiet.",
                emoji: "🦉",
                priority: 2
            ),
            CoachingInsight(
                category: .energy,
                title: "Protect Your Sleep",
                advice: "The biggest risk for night owls is sacrificing sleep for focus. Your brain consolidates learning and clears metabolic waste during sleep. Cutting sleep short for an extra session is a net negative — you lose more the next day than you gain tonight.",
                science: "The glymphatic system clears toxic metabolites from the brain exclusively during sleep. Sleep deprivation impairs next-day cognitive performance by 20-30% (Xie et al., 2013).",
                actionStep: "Set a hard stop time for focus sessions — no later than 90 minutes before your target bedtime.",
                emoji: "😴",
                priority: 1
            ),
            CoachingInsight(
                category: .timing,
                title: "Strategic Napping",
                advice: "If your schedule requires early mornings despite being a night owl, a 20-minute nap between 1-3 PM can restore 2-3 hours of cognitive function. Longer naps cause sleep inertia — keep it short and set an alarm.",
                science: "NASA's nap studies found that a 26-minute nap improved pilot performance by 34% and alertness by 54% (Rosekind et al., 1995).",
                actionStep: "Try a 20-minute nap after lunch today. Set an alarm, close your eyes, and don't worry about actually sleeping — rest alone helps.",
                emoji: "⏰",
                priority: 3
            ),
            CoachingInsight(
                category: .habits,
                title: "Design Your Evening Transition",
                advice: "Your challenge isn't finding focus — it's transitioning into it after a full day. Create an evening 'switching on' ritual: make a specific drink, put on specific music, sit in your focus spot. This tells your brain: playtime is over, it's go time.",
                science: "Ritualized transitions activate task-relevant neural circuits and suppress the default mode network, accelerating the shift to focused attention (Hobson et al., 2018).",
                actionStep: "Create your evening focus ritual tonight: same drink, same music, same spot. Do it the same way every night.",
                emoji: "🫖",
                priority: 2
            ),
            CoachingInsight(
                category: .energy,
                title: "Evening Exercise Boost",
                advice: "Moderate exercise in the late afternoon (4-7 PM) boosts evening cognitive performance more than morning exercise for night owls. Your body temperature peaks later — exercise during this window amplifies the effect.",
                science: "Exercise timing interacts with chronotype — evening types show greater cognitive benefits from PM exercise due to aligned circadian body temperature peaks (Facer-Childs & Brandstaetter, 2015).",
                actionStep: "Try a 20-30 minute workout between 5-7 PM before your evening focus sessions this week.",
                emoji: "🏃",
                priority: 3
            ),
            CoachingInsight(
                category: .timing,
                title: "Batch Your Mornings Differently",
                advice: "Since mornings aren't your peak, don't waste them fighting for focus. Use mornings for low-cognitive tasks: email, meetings, admin, errands. Save your cognitive heavy lifting for evening when your brain actually wants to engage.",
                science: "Cognitive resource allocation aligns with circadian peaks — forcing off-peak deep work wastes energy and produces inferior results (Wieth & Zacks, 2011).",
                actionStep: "Reorganize tomorrow: morning for communication and admin, evening for your most important deep work.",
                emoji: "📋",
                priority: 2
            )
        ]
    }

    // =========================================================================
    // DURATION — Session Length Mismatch
    // =========================================================================

    private func sessionMismatchTips(actualMinutes: Int) -> [CoachingInsight] {
        [
            CoachingInsight(
                category: .duration,
                title: "Your Real Attention Span Is \(actualMinutes) Min",
                advice: "Your data shows you consistently lose focus around the \(actualMinutes)-minute mark. That's not failure — that's your current baseline. Set your sessions to \(actualMinutes) minutes, complete them successfully, then gradually extend by 2-3 minutes per week.",
                science: "Attention span varies individually and is trainable — current baseline represents the point where the default mode network begins overriding task-positive networks (Esterman & Rothlein, 2019).",
                actionStep: "Set your next session to exactly \(actualMinutes) minutes. Complete it fully. That's a win.",
                emoji: "📊",
                priority: 1
            ),
            CoachingInsight(
                category: .duration,
                title: "The Gradual Extension Method",
                advice: "You abandon sessions when they exceed your natural attention span. The fix: set sessions to \(actualMinutes) minutes for 5 days, then add 3 minutes. Repeat. In a month, you'll have naturally extended your focus capacity by 15-20 minutes.",
                science: "Graded exposure therapy principles apply to attention training — gradually increasing demands builds tolerance without triggering avoidance (Wolpe, 1958, adapted).",
                actionStep: "Week 1: \(actualMinutes) min sessions. Week 2: \(actualMinutes + 3) min. Week 3: \(actualMinutes + 6) min. Stick to this progression.",
                emoji: "📐",
                priority: 1
            ),
            CoachingInsight(
                category: .duration,
                title: "Insert a Micro-Break",
                advice: "If \(actualMinutes) minutes is your wall, try a 60-second micro-break at the \(max(5, actualMinutes - 3))-minute mark — stand, stretch, breathe — then resume. This can extend your session by 50% without feeling like a grind.",
                science: "Brief interruptions to sustained attention tasks can paradoxically improve performance by preventing habituation of the attention system (Ariga & Lleras, 2011).",
                actionStep: "In your next session, set a quiet alarm at \(max(5, actualMinutes - 3)) minutes. Stand for 60 seconds, then sit back down and continue.",
                emoji: "⏸️",
                priority: 2
            ),
            CoachingInsight(
                category: .duration,
                title: "Match Duration to Energy",
                advice: "Your attention span isn't fixed — it fluctuates throughout the day. You might sustain \(actualMinutes + 10) minutes in the morning but only \(max(5, actualMinutes - 5)) in the afternoon. Adjust session length to match your current energy, not a fixed number.",
                science: "Cognitive resource models show that sustained attention capacity varies with circadian phase, sleep quality, and prior cognitive load (Kahneman, 1973).",
                actionStep: "Try this: morning sessions at \(actualMinutes + 5) min, afternoon at \(actualMinutes) min. Track which feels more completable.",
                emoji: "🔋",
                priority: 2
            ),
            CoachingInsight(
                category: .duration,
                title: "Split Long Tasks Into Rounds",
                advice: "If you need more than \(actualMinutes) minutes on a task, split it into rounds: \(actualMinutes) minutes on, 5 off, \(actualMinutes) minutes on. This respects your natural rhythm while still accumulating deep work time.",
                science: "The Pomodoro Technique's effectiveness comes from working within natural attention cycles rather than fighting them (Cirillo, 2006).",
                actionStep: "For your next big task, plan 3 rounds of \(actualMinutes) minutes with 5-minute breaks between each.",
                emoji: "🔄",
                priority: 2
            ),
            CoachingInsight(
                category: .duration,
                title: "Celebrate the \(actualMinutes)-Min Win",
                advice: "Every completed \(actualMinutes)-minute session is a victory. Your brain needs the dopamine reward of completion more than it needs an extra 10 minutes of forced focus. Reward yourself after each completed session — your brain will start craving more.",
                science: "The dopamine reward prediction system reinforces behaviors that lead to successful outcomes, making them more likely to be repeated (Schultz, 2015).",
                actionStep: "After your next completed session, do something you enjoy for 2 minutes — check something fun, eat a snack, step outside. Train the reward loop.",
                emoji: "🏆",
                priority: 2
            ),
            CoachingInsight(
                category: .duration,
                title: "Quality Beats Quantity",
                advice: "\(actualMinutes) minutes of genuine deep focus produces more meaningful output than 60 minutes of distracted half-attention. Your current span isn't limiting you — distracted people are fooling themselves. You're honest about what works.",
                science: "Research on effective work hours shows that most knowledge workers produce only 2-4 hours of truly focused output per day, regardless of hours spent (Newport, 2016).",
                actionStep: "Set today's goal in terms of output, not time. What will you complete in your \(actualMinutes) minutes?",
                emoji: "💎",
                priority: 3
            ),
            CoachingInsight(
                category: .brainScience,
                title: "Why Your Brain Quits at \(actualMinutes) Min",
                advice: "Around \(actualMinutes) minutes, your brain's default mode network starts winning the tug-of-war against your task-positive network. It's literally your brain switching from 'focused outward' to 'focused inward' (daydreaming). Understanding this makes it feel less like failure.",
                science: "The default mode network (DMN) competes with the task-positive network for dominance — sustained focus requires active suppression of the DMN, which fatigues over time (Raichle, 2015).",
                actionStep: "When you feel your mind start to wander, notice it without judgment. That's your DMN activating. Take a breath and re-engage for 2 more minutes.",
                emoji: "🧠",
                priority: 3
            )
        ]
    }

    // =========================================================================
    // ENERGY — High Performer Tips
    // =========================================================================

    private var highPerformerTips: [CoachingInsight] {
        [
            CoachingInsight(
                category: .deepWork,
                title: "Push Into Flow State",
                advice: "With your high completion rate and quality, you're ready for the next level: flow. Flow state — that effortless, time-vanishing focus — requires clear goals, immediate feedback, and a challenge-skill balance. Optimize for these three triggers.",
                science: "Csikszentmihalyi's flow state research identifies three prerequisites: clear goals, immediate feedback, and a challenge-skill ratio near 1:1 (Csikszentmihalyi, 1990).",
                actionStep: "Before your next session, define a crystal-clear goal, turn off all notifications, and pick a task that stretches you slightly.",
                emoji: "🌊",
                priority: 2
            ),
            CoachingInsight(
                category: .deepWork,
                title: "You're Ready for 90-Min Blocks",
                advice: "Your focus endurance is strong. Try upgrading to 90-minute blocks — a full ultradian cycle. This gives you time to settle in, hit flow, and do meaningful work before the break. It's the format that top performers and writers swear by.",
                science: "The basic rest-activity cycle (BRAC) operates in ~90-minute ultradian rhythms — a full cycle allows for complete cognitive engagement and natural disengagement (Kleitman, 1963).",
                actionStep: "Try one 90-minute session this week. No breaks, no phone, one task. See how it feels compared to shorter sessions.",
                emoji: "⏱️",
                priority: 3
            ),
            CoachingInsight(
                category: .energy,
                title: "Protect Your Recovery",
                advice: "High performers are at highest risk for burnout because they push harder and recover less. Your brain needs idle time to consolidate learning and creative processing. Schedule recovery as deliberately as you schedule focus.",
                science: "The default mode network — active during rest — is essential for memory consolidation, creative insight, and self-referential processing (Andrews-Hanna, 2012).",
                actionStep: "After your best focus session today, take 15 minutes of genuine rest — no screens, no tasks. Let your brain process.",
                emoji: "🧘",
                priority: 2
            ),
            CoachingInsight(
                category: .habits,
                title: "Document Your Focus System",
                advice: "You've developed a working system. Write it down — your timing, environment, rituals, what works and what doesn't. This protects you from regression during stressful periods and gives you a playbook to return to when things get chaotic.",
                science: "Metacognitive awareness — knowing your own cognitive patterns — is one of the strongest predictors of sustained high performance (Flavell, 1979).",
                actionStep: "Spend 10 minutes writing your 'focus playbook' — the exact conditions that produce your best sessions.",
                emoji: "📖",
                priority: 3
            ),
            CoachingInsight(
                category: .deepWork,
                title: "Try Single-Tasking Sprints",
                advice: "You're consistent enough to try the ultimate challenge: absolute single-tasking. One browser tab, one application, one task, zero switches for the entire session. This level of focus is rare and produces exceptional output.",
                science: "Task switching costs — even between related tasks — reduce productivity by up to 40% (Monsell, 2003). Eliminating switches entirely maximizes throughput.",
                actionStep: "In your next session, close every application except the one you need. One tab, one task, zero switching.",
                emoji: "🎯",
                priority: 2
            ),
            CoachingInsight(
                category: .deepWork,
                title: "The 'Shutdown Complete' Ritual",
                advice: "Cal Newport's shutdown ritual — saying 'shutdown complete' after reviewing your task list — creates a clean cognitive break between work and rest. Without it, your brain keeps working in the background, degrading both your rest and your next focus session.",
                science: "Open loops in working memory consume cognitive resources even during rest — explicit closure frees these resources (Newport, 2016; Zeigarnik, 1927).",
                actionStep: "After your last session today, review tomorrow's tasks, close your workspace, and say 'shutdown complete.' Mean it.",
                emoji: "🔐",
                priority: 3
            ),
            CoachingInsight(
                category: .energy,
                title: "Sleep Is Your Secret Weapon",
                advice: "At your level, the biggest performance lever isn't another productivity hack — it's sleep quality. One extra hour of sleep can improve cognitive performance by 15-20%. Seven to nine hours in a cool, dark room is the most powerful focus enhancer that exists.",
                science: "Sleep deprivation impairs prefrontal cortex function — the exact brain region required for focused work — by 20-30% per lost hour (Van Dongen et al., 2003).",
                actionStep: "Try going to bed 30 minutes earlier this week. Track whether your first session of each day improves.",
                emoji: "🛏️",
                priority: 2
            ),
            CoachingInsight(
                category: .deepWork,
                title: "Aim for Fewer, Deeper Sessions",
                advice: "More sessions doesn't mean more output. Try reducing your daily sessions by one but making the remaining ones 20% longer and more focused. Depth beats breadth for complex, creative, or analytical work.",
                science: "Depth of processing, not duration of exposure, determines long-term memory encoding and creative output (Craik & Lockhart, 1972).",
                actionStep: "This week, try 3 deep sessions per day instead of 4+ shorter ones. Put all your intensity into fewer blocks.",
                emoji: "🕳️",
                priority: 3
            )
        ]
    }

    // =========================================================================
    // ENERGY — Low Energy Tips
    // =========================================================================

    private var lowEnergyTips: [CoachingInsight] {
        [
            CoachingInsight(
                category: .energy,
                title: "Your Brain Is Running on Empty",
                advice: "A high proportion of your sessions are low quality. Before we fix your focus, we need to fix your fuel. Your brain uses 20% of your body's energy despite being 2% of your weight. Are you eating, sleeping, and hydrating enough to power it?",
                science: "The brain consumes ~20% of the body's total energy budget, primarily from glucose. Even mild dehydration (1-2%) significantly impairs cognitive function (Adan, 2012).",
                actionStep: "Before your next session: drink a full glass of water, eat something with protein, and check — did you sleep 7+ hours last night?",
                emoji: "⚡",
                priority: 1
            ),
            CoachingInsight(
                category: .energy,
                title: "The Sleep-Focus Connection",
                advice: "If you're consistently getting low-quality sessions, the first thing to examine is sleep. Losing just one hour of sleep reduces your cognitive performance by the equivalent of a 0.05% blood alcohol level. You're trying to focus while cognitively impaired.",
                science: "Moderate sleep restriction (6h vs 8h) produces cognitive deficits equivalent to mild alcohol intoxication (Williamson & Feyer, 2000).",
                actionStep: "Track your sleep hours this week alongside session quality. Bet you'll see a direct correlation.",
                emoji: "😴",
                priority: 1
            ),
            CoachingInsight(
                category: .energy,
                title: "Move Before You Focus",
                advice: "Even 5 minutes of brisk walking before a focus session increases cerebral blood flow by 15% and releases BDNF — a protein that's essentially fertilizer for your brain's focus circuits. It's the most reliable energy hack that exists.",
                science: "Acute exercise increases BDNF (Brain-Derived Neurotrophic Factor) and cerebral perfusion, enhancing subsequent cognitive performance (Winter et al., 2007).",
                actionStep: "Walk briskly for 5 minutes — outside if possible — immediately before your next session.",
                emoji: "🚶",
                priority: 1
            ),
            CoachingInsight(
                category: .energy,
                title: "Hydration Is Non-Negotiable",
                advice: "Even 1-2% dehydration — which you can have without feeling thirsty — reduces attention and working memory by 10-15%. Most people are mildly dehydrated all day. Drink water before you feel thirsty, especially before focus sessions.",
                science: "Mild dehydration (1-2% body weight loss) significantly impairs attention, immediate memory, and psychomotor function (Ganio et al., 2011).",
                actionStep: "Drink a full glass of water 15 minutes before every focus session. Keep water visible on your desk during sessions.",
                emoji: "💧",
                priority: 1
            ),
            CoachingInsight(
                category: .energy,
                title: "The Blood Sugar Focus Trap",
                advice: "Low blood sugar makes focus impossible — your prefrontal cortex is the first brain region to suffer during glucose dips. But sugar isn't the answer (it crashes). Protein and complex carbs provide steady fuel for 2-3 hours of sustained focus.",
                science: "The prefrontal cortex is disproportionately affected by low blood glucose because it has the highest metabolic demand (Gailliot et al., 2007).",
                actionStep: "Eat a handful of nuts or some cheese 20 minutes before your next session. Avoid candy, juice, or energy drinks.",
                emoji: "🥜",
                priority: 2
            ),
            CoachingInsight(
                category: .energy,
                title: "Check Your Breathing",
                advice: "Shallow chest breathing — common when stressed or sedentary — reduces oxygen to the brain by 10-15%. Most desk workers breathe poorly without realizing it. Slow, deep belly breaths before focusing literally fuels your brain.",
                science: "Diaphragmatic breathing increases vagal tone and cerebral oxygenation, improving cognitive function and reducing stress (Ma et al., 2017).",
                actionStep: "Before your next session: 6 slow breaths — 4 seconds in through the nose, 6 seconds out. Feel your belly expand.",
                emoji: "🌬️",
                priority: 2
            ),
            CoachingInsight(
                category: .energy,
                title: "Stress Is Draining Your Focus Tank",
                advice: "Chronic stress keeps your cortisol elevated, which actively impairs the prefrontal cortex — the brain region responsible for focus. If you're stressed about something outside of work, that background anxiety is stealing focus resources.",
                science: "Chronic cortisol elevation impairs prefrontal cortex function and hippocampal memory consolidation (Lupien et al., 2009).",
                actionStep: "If something is worrying you, write it down before starting your session. Externalizing worry frees working memory for focus.",
                emoji: "📋",
                priority: 2
            ),
            CoachingInsight(
                category: .environment,
                title: "Temperature Check",
                advice: "Room temperature directly affects cognitive performance. 72°F (22°C) is the sweet spot. Too warm and you get sluggish — your body diverts energy to cooling. Too cold and your body diverts energy to warming. Either way, your brain loses.",
                science: "Seppänen et al. (2006) found that cognitive performance peaks at 22°C and declines 2% per degree above 25°C.",
                actionStep: "Check your room temperature. If it's above 75°F or below 65°F, adjust before your next session.",
                emoji: "🌡️",
                priority: 3
            )
        ]
    }

    // =========================================================================
    // ENERGY — Overworking Tips
    // =========================================================================

    private var overworkingTips: [CoachingInsight] {
        [
            CoachingInsight(
                category: .recovery,
                title: "More Sessions ≠ More Progress",
                advice: "You're averaging over 6 sessions per day. After 3-4 quality sessions, returns diminish rapidly — each subsequent session produces less output than the one before. You're working harder, not smarter. Cut sessions, increase quality.",
                science: "Cal Newport's research shows most knowledge workers can sustain only 3-4 hours of genuine deep work per day, regardless of total hours worked.",
                actionStep: "Cap yourself at 4 sessions tomorrow. Make each one count. Compare your output to a 6+ session day.",
                emoji: "📉",
                priority: 1
            ),
            CoachingInsight(
                category: .recovery,
                title: "Rest Is Productive",
                advice: "Your brain does critical work during rest: consolidating memories, clearing metabolic waste, and making creative connections. By never resting, you're blocking these processes. Strategic rest doesn't reduce your output — it multiplies it.",
                science: "The default mode network (DMN) — active during rest — is essential for memory consolidation and creative insight generation (Immordino-Yang et al., 2012).",
                actionStep: "Take a 20-minute walk today with no podcasts, no music, no phone. Let your brain process freely.",
                emoji: "🧠",
                priority: 1
            ),
            CoachingInsight(
                category: .recovery,
                title: "The Law of Diminishing Focus",
                advice: "Your first focus session of the day is your best. The second is good. The third is decent. After that, you're running on willpower fumes. Each session drains your prefrontal cortex — and it doesn't fully recharge until you sleep.",
                science: "Sequential depletion of prefrontal cortex resources follows a logarithmic decay curve — each effort draws from a diminishing pool (Baumeister & Tierney, 2011).",
                actionStep: "Put your most important task in Session 1 tomorrow. Accept that Session 5+ will be lower quality.",
                emoji: "📊",
                priority: 2
            ),
            CoachingInsight(
                category: .recovery,
                title: "Schedule Your Off Time",
                advice: "You're disciplined about scheduling focus, but are you scheduling recovery? Without explicit downtime, your brain never gets the all-clear signal to rest. Unstructured time should be intentional, not accidental.",
                science: "Deliberate recovery periods enhance subsequent performance through neural restoration and reduced allostatic load (Sonnentag et al., 2017).",
                actionStep: "Block 2 hours of 'no-focus' time on your calendar tomorrow. No sessions, no productivity — genuinely relax.",
                emoji: "📅",
                priority: 2
            ),
            CoachingInsight(
                category: .recovery,
                title: "Watch for Burnout Signals",
                advice: "Burnout sneaks up on high-achievers. Early signs: sessions feel like obligation rather than achievement, quality drops despite effort, you feel wired but tired. If you notice two or more of these, your brain is waving a red flag.",
                science: "The Maslach Burnout Inventory identifies three stages: emotional exhaustion, depersonalization, and reduced personal accomplishment — all preceded by overwork (Maslach et al., 2001).",
                actionStep: "Honest check: do you enjoy your focus sessions, or dread them? If the answer has shifted recently, take 2 days fully off.",
                emoji: "🚨",
                priority: 1
            ),
            CoachingInsight(
                category: .recovery,
                title: "Quality Over Quantity",
                advice: "Three exceptional focus sessions produce more meaningful output than six mediocre ones. Each additional session has diminishing returns — you're spending 2x the time for maybe 20% more output. Cut the fat, keep the muscle.",
                science: "Pareto's principle applies to cognitive work — roughly 80% of valuable output comes from 20% of focused effort in optimal conditions.",
                actionStep: "Track which 2-3 sessions tomorrow produce the most valuable output. Those are your keepers. The rest can go.",
                emoji: "💎",
                priority: 2
            ),
            CoachingInsight(
                category: .recovery,
                title: "Active Recovery Between Sessions",
                advice: "If you must do 5+ sessions, at least recover properly between them. A 15-minute break with movement (walk, stretch) and zero screens restores significantly more cognitive function than scrolling your phone for 5 minutes.",
                science: "Active recovery with physical movement and screen-free rest restores prefrontal cortex glucose availability faster than passive screen-based breaks (Rhee & Kim, 2016).",
                actionStep: "Between your next two sessions, take a 15-minute walk outside. No phone. Compare the second session's quality to normal.",
                emoji: "🚶",
                priority: 2
            ),
            CoachingInsight(
                category: .habits,
                title: "Define 'Enough'",
                advice: "Without a clear definition of 'done for the day,' you'll always feel like you should do more. Set a daily focus target in advance — when you hit it, stop. This prevents the slow creep of overwork that leads to burnout.",
                science: "Goal-setting theory shows that specific, bounded targets produce higher satisfaction and sustainable performance than open-ended effort (Locke & Latham, 2002).",
                actionStep: "Set your target now: ___ sessions or ___ minutes per day. When you hit it, stop. Period.",
                emoji: "✅",
                priority: 2
            )
        ]
    }

    // =========================================================================
    // BRAIN SCIENCE — General Tips
    // =========================================================================

    private var brainScienceTips: [CoachingInsight] {
        [
            CoachingInsight(
                category: .brainScience,
                title: "Your Phone Is Stealing 10% of Your Brain",
                advice: "Having your phone in the same room — even face down, even powered off — reduces your cognitive capacity by up to 10%. Your brain is spending resources suppressing the urge to check it. The only fix is physical distance.",
                science: "Ward et al. (2017) at University of Texas found that smartphone proximity alone reduces available cognitive capacity, even when the phone is off.",
                actionStep: "Put your phone in a different room before your next session. Not face down. Not on silent. In another room.",
                emoji: "📱",
                priority: 1
            ),
            CoachingInsight(
                category: .brainScience,
                title: "The 23-Minute Recovery Tax",
                advice: "Every time you check your phone, glance at a notification, or switch tabs during a focus session, it takes an average of 23 minutes to fully regain deep focus. That means a single 30-second distraction can effectively end a short session.",
                science: "Gloria Mark's research at UC Irvine found an average of 23 minutes and 15 seconds to return to the original task after an interruption.",
                actionStep: "Before your next session, close every notification source. Every tab. Every app. Leave only what you need.",
                emoji: "⏳",
                priority: 1
            ),
            CoachingInsight(
                category: .brainScience,
                title: "Dopamine and Focus Are Linked",
                advice: "Dopamine isn't just about pleasure — it's the neurotransmitter that controls your ability to sustain attention on a single task. Chronic social media use depletes dopamine sensitivity, making focus physically harder. A 'dopamine detox' before focus sessions helps.",
                science: "Chronic dopamine overstimulation from social media leads to receptor downregulation, reducing the brain's ability to sustain focus on less stimulating tasks (Volkow et al., 2011).",
                actionStep: "For 30 minutes before your focus session, avoid all dopamine hits: no social media, no news, no short-form video. Let your brain recalibrate.",
                emoji: "🧪",
                priority: 2
            ),
            CoachingInsight(
                category: .brainScience,
                title: "Your Brain Literally Grows From Focus",
                advice: "Every time you sustain attention, you're physically growing the neural connections in your prefrontal cortex. Focus training is brain training — MRI studies show measurable increases in gray matter density after just 8 weeks of attention practice.",
                science: "Mindfulness-based attention training increases cortical thickness in the prefrontal cortex and anterior cingulate cortex (Lazar et al., 2005).",
                actionStep: "Think of each focus session as a gym workout for your brain. Even hard sessions are building your capacity.",
                emoji: "🧠",
                priority: 3
            ),
            CoachingInsight(
                category: .brainScience,
                title: "The Anterior Cingulate Is Your Focus Muscle",
                advice: "There's a specific brain region — the anterior cingulate cortex (ACC) — that detects conflicts between what you should be doing and what you want to do (like checking your phone). Training this region through practice makes resisting distractions easier over time.",
                science: "The ACC monitors for response conflicts and signals the need for cognitive control. Its activation strengthens with practice (Botvinick et al., 2001).",
                actionStep: "When you notice the urge to switch tasks, pause and label it: 'That's my ACC detecting a conflict. I'm going to stay.' This strengthens the circuit.",
                emoji: "💪",
                priority: 3
            ),
            CoachingInsight(
                category: .brainScience,
                title: "Working Memory Is Tiny",
                advice: "You can only hold 3-4 pieces of information in working memory at once. That's why multitasking fails — you're not doing two things at once, you're rapidly switching and losing information each time. Focus works because it respects this biological limit.",
                science: "Cowan's (2001) revision of Miller's number shows working memory capacity is 3-4 items, not the commonly cited 7±2.",
                actionStep: "Before your next session, write down the 3 key things you need to accomplish. Don't try to hold them in your head.",
                emoji: "📝",
                priority: 2
            ),
            CoachingInsight(
                category: .brainScience,
                title: "Adenosine: The Tiredness Chemical",
                advice: "Adenosine builds up in your brain every hour you're awake, creating increasing pressure to sleep. After 14+ hours awake, focus becomes genuinely hard because adenosine is saturating your receptors. Caffeine blocks adenosine — but only masks the fatigue.",
                science: "Adenosine accumulation in the basal forebrain progressively inhibits cholinergic neurons responsible for cortical arousal and attention (Porkka-Heiskanen et al., 1997).",
                actionStep: "If you've been awake for 14+ hours, accept that focus will be limited. Do easier tasks or call it a night.",
                emoji: "💤",
                priority: 3
            ),
            CoachingInsight(
                category: .brainScience,
                title: "Neuroplasticity Requires Sleep",
                advice: "Everything you focused on today gets consolidated during sleep. Your hippocampus replays the day's learning and transfers it to long-term cortical storage. Skip sleep, and yesterday's focused work is partially lost.",
                science: "Sleep-dependent memory consolidation transfers hippocampal memories to neocortical long-term storage through sharp-wave ripple reactivation (Diekelmann & Born, 2010).",
                actionStep: "Tonight, aim for 7-8 hours. Your brain is going to spend that time making today's focus permanent.",
                emoji: "🌙",
                priority: 2
            ),
            CoachingInsight(
                category: .recovery,
                title: "Bad Sessions Are Data, Not Failure",
                advice: "A session where you couldn't focus isn't wasted — it's information. Your brain needs variability to calibrate. Research shows that inconsistent practice actually strengthens neural pathways more than perfect repetition. The bad sessions are part of the process.",
                science: "Interleaved and variable practice enhances long-term retention and transfer more than constant, blocked practice (Rohrer & Taylor, 2007).",
                actionStep: "After a bad session, write down what went wrong. Don't retry immediately — take a 5-minute screen-free break, then adjust one variable.",
                emoji: "📊",
                priority: 2
            ),
            CoachingInsight(
                category: .recovery,
                title: "The Default Mode Network Reset",
                advice: "After an abandoned session, don't immediately retry. Take 5 minutes with zero screens — stare out a window, walk, breathe. This activates your default mode network, which paradoxically prepares your brain for the next focus attempt.",
                science: "The default mode network (DMN) performs essential maintenance during idle periods — self-referential processing, memory consolidation, and attentional resource restoration (Raichle et al., 2001).",
                actionStep: "After a failed session: 5 minutes of window-gazing or walking. No phone. Then return refreshed.",
                emoji: "🔄",
                priority: 2
            ),
            CoachingInsight(
                category: .brainScience,
                title: "Norepinephrine Controls Your Alertness",
                advice: "Norepinephrine is the neurotransmitter that keeps you alert and focused. It's released by the locus coeruleus and follows a U-curve — too little and you're drowsy, too much and you're anxious. Moderate stress + interest = the sweet spot.",
                science: "The Yerkes-Dodson law describes the inverted-U relationship between arousal (norepinephrine) and performance — moderate levels are optimal (Yerkes & Dodson, 1908).",
                actionStep: "If you're feeling too relaxed to focus, add mild urgency — set a timer shorter than comfortable. Too anxious? Breathe slowly for 1 minute first.",
                emoji: "⚖️",
                priority: 3
            ),
            CoachingInsight(
                category: .environment,
                title: "Ambient Noise Beats Silence",
                advice: "Moderate ambient noise (~70 dB, like a coffee shop) actually improves creative thinking by inducing a slightly elevated level of processing. Total silence can make your brain too comfortable, while loud noise overwhelms it.",
                science: "Ravi Mehta's research at the University of Illinois found that moderate ambient noise enhances creative cognition by promoting abstract processing.",
                actionStep: "Try using Kairo's ambient sounds or a coffee shop noise app during your next creative focus session.",
                emoji: "🎵",
                priority: 3
            )
        ]
    }
}
