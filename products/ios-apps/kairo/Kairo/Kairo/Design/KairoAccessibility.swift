import SwiftUI

// MARK: - KairoAccessibilityIdentifier

/// Test identifiers for all key UI elements.
///
/// Used for both UI testing (`accessibilityIdentifier`) and
/// Xcode Instruments automation. Every interactive or informational
/// element that tests need to find should have an entry here.
enum KairoAccessibilityIdentifier: String {

    // MARK: Home

    case homeGreeting            = "home_greeting"
    case homeScoreDisplay        = "home_score_display"
    case homeScoreBar            = "home_score_bar"
    case homeSessionCount        = "home_session_count"
    case homeFocusTime           = "home_focus_time"
    case homeStreakBadge         = "home_streak_badge"
    case homeQuickStart          = "home_quick_start"
    case homeWeeklyChart         = "home_weekly_chart"
    case homeInsightCarousel     = "home_insight_carousel"
    case homeModelReadiness      = "home_model_readiness"

    // MARK: Focus Session

    case startButton             = "session_start_button"
    case pauseButton             = "session_pause_button"
    case resumeButton            = "session_resume_button"
    case stopButton              = "session_stop_button"
    case timerDisplay            = "session_timer_display"
    case progressRing            = "session_progress_ring"
    case sessionTypePicker       = "session_type_picker"
    case durationPicker          = "session_duration_picker"
    case soundSelector           = "session_sound_selector"
    case distractionBadge        = "session_distraction_badge"
    case preparingCountdown      = "session_preparing_countdown"

    // MARK: Completion

    case completionScore         = "completion_score"
    case completionQuality       = "completion_quality"
    case completionDuration      = "completion_duration"
    case completionStartBreak    = "completion_start_break"
    case completionStartAnother  = "completion_start_another"
    case completionDone          = "completion_done"

    // MARK: Break

    case breakTimer              = "break_timer"
    case breakSkip               = "break_skip"
    case breakSessionCounter     = "break_session_counter"

    // MARK: Settings

    case settingsRoot            = "settings_root"
    case settingsNotifications   = "settings_notifications"
    case settingsHaptics         = "settings_haptics"
    case settingsAppearance      = "settings_appearance"
    case settingsExport          = "settings_export"

    // MARK: Shared / Generic

    case scoreDisplay            = "score_display"
    case streakDisplay           = "streak_display"
    case insightCard             = "insight_card"
    case tabBar                  = "tab_bar"
}

// MARK: - AccessibilityModifier

/// Applies consistent accessibility labels, hints, and test identifiers
/// to any view in one shot.
///
/// Usage:
/// ```swift
/// Text("87").modifier(AccessibilityModifier(
///     label: "Focus score: 87 out of 100",
///     hint: "Your average focus quality today",
///     identifier: .homeScoreDisplay
/// ))
/// ```
struct AccessibilityModifier: ViewModifier {

    /// VoiceOver label read aloud.
    let label: String

    /// VoiceOver hint providing additional context.
    var hint: String?

    /// Test automation identifier.
    var identifier: KairoAccessibilityIdentifier?

    /// Accessibility traits (e.g. `.isHeader`, `.updatesFrequently`).
    var traits: AccessibilityTraits = []

    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(traits)
            .accessibilityIdentifier(identifier?.rawValue ?? "")
    }
}

// MARK: - Focus Score Accessibility

extension View {

    /// Announces focus score with human-readable tier label.
    ///
    /// Example VoiceOver: *"Focus score: 87 out of 100. Locked In."*
    /// - Parameter score: Integer focus score 0–100.
    func focusScoreAccessibility(score: Int) -> some View {
        let tier = scoreTierLabel(for: score)
        return self
            .accessibilityLabel("Focus score: \(score) out of 100, \(tier)")
            .accessibilityIdentifier(KairoAccessibilityIdentifier.scoreDisplay.rawValue)
            .accessibilityAddTraits(.updatesFrequently)
    }

    /// Announces timer state for VoiceOver.
    ///
    /// Example: *"25 minutes remaining of 50 minute session"*
    /// - Parameters:
    ///   - remaining: Seconds remaining.
    ///   - total: Total session duration in seconds.
    func timerAccessibility(remaining: TimeInterval, total: TimeInterval) -> some View {
        let remainMin = Int(remaining) / 60
        let totalMin = Int(total) / 60
        let remainSec = Int(remaining) % 60

        let timeText: String
        if remainMin > 0 {
            timeText = "\(remainMin) minute\(remainMin == 1 ? "" : "s")"
                + (remainSec > 0 ? " \(remainSec) second\(remainSec == 1 ? "" : "s")" : "")
        } else {
            timeText = "\(remainSec) second\(remainSec == 1 ? "" : "s")"
        }

        return self
            .accessibilityLabel("\(timeText) remaining of \(totalMin) minute session")
            .accessibilityIdentifier(KairoAccessibilityIdentifier.timerDisplay.rawValue)
            .accessibilityAddTraits(.updatesFrequently)
    }

    /// Announces streak count for VoiceOver.
    ///
    /// Example: *"Current streak: 7 days"*
    /// - Parameter days: Number of consecutive focus days.
    func streakAccessibility(days: Int) -> some View {
        self
            .accessibilityLabel("Current streak: \(days) day\(days == 1 ? "" : "s")")
            .accessibilityIdentifier(KairoAccessibilityIdentifier.streakDisplay.rawValue)
    }

    /// Announces session quality for VoiceOver.
    ///
    /// Example: *"Session quality: High"*
    /// - Parameter quality: Quality tier string ("High", "Medium", "Low").
    func sessionQualityAccessibility(quality: String) -> some View {
        self
            .accessibilityLabel("Session quality: \(quality)")
            .accessibilityIdentifier(KairoAccessibilityIdentifier.completionQuality.rawValue)
    }
}

// MARK: - Score Tier Label

/// Maps a numeric score to a human-readable tier for VoiceOver.
private func scoreTierLabel(for score: Int) -> String {
    switch score {
    case 90...100: return "Locked In"
    case 70..<90:  return "Strong Focus"
    case 50..<70:  return "Getting There"
    case 30..<50:  return "Needs Work"
    default:       return "Just Starting"
    }
}

// MARK: - Dynamic Type Support

extension View {

    /// Ensures text scales with Dynamic Type while clamping to a sensible range.
    ///
    /// Prevents tiny or absurdly large text in extreme accessibility sizes
    /// while still respecting the user's preference.
    /// - Parameters:
    ///   - min: Minimum scale factor (default 0.7).
    ///   - max: Maximum number of lines before truncation (default 3).
    func kairoDynamicType(minScale: CGFloat = 0.7, maxLines: Int = 3) -> some View {
        self
            .minimumScaleFactor(minScale)
            .lineLimit(maxLines)
            .dynamicTypeSize(...DynamicTypeSize.accessibility3)
    }

    /// Applies a fixed accessibility size range for elements that must
    /// not grow beyond a certain point (e.g., timer digits, score numbers).
    func kairoFixedDynamicType() -> some View {
        self
            .dynamicTypeSize(.large ... .xxxLarge)
    }
}

// MARK: - Reduce Motion Helpers

extension View {

    /// Conditionally applies animation only when Reduce Motion is off.
    ///
    /// When Reduce Motion is enabled, the change happens instantly.
    /// - Parameters:
    ///   - animation: The animation to apply.
    ///   - value: The value that triggers the animation.
    func kairoAnimation<V: Equatable>(
        _ animation: Animation,
        value: V
    ) -> some View {
        self.modifier(ReduceMotionAnimationModifier(animation: animation, value: value))
    }

    /// Wraps a transition so it's skipped under Reduce Motion.
    /// - Parameter transition: The transition to apply.
    func kairoTransition(_ transition: AnyTransition) -> some View {
        self.modifier(ReduceMotionTransitionModifier(transition: transition))
    }
}

/// Modifier that respects `accessibilityReduceMotion` for animations.
private struct ReduceMotionAnimationModifier<V: Equatable>: ViewModifier {
    let animation: Animation
    let value: V

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

/// Modifier that respects `accessibilityReduceMotion` for transitions.
private struct ReduceMotionTransitionModifier: ViewModifier {
    let transition: AnyTransition

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content.transition(.opacity)
        } else {
            content.transition(transition)
        }
    }
}

// MARK: - Accessibility Convenience

extension View {

    /// Shorthand for applying a `KairoAccessibilityIdentifier` as a test identifier.
    func kairoIdentifier(_ id: KairoAccessibilityIdentifier) -> some View {
        self.accessibilityIdentifier(id.rawValue)
    }

    /// Marks this view as a semantic group for VoiceOver, read as one unit.
    /// - Parameters:
    ///   - label: Combined label for the group.
    ///   - identifier: Optional test identifier.
    func kairoAccessibilityGroup(
        label: String,
        identifier: KairoAccessibilityIdentifier? = nil
    ) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityIdentifier(identifier?.rawValue ?? "")
    }
}
