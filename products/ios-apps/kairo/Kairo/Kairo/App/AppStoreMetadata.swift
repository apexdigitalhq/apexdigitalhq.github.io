import Foundation

// MARK: - AppStoreMetadata

/// App Store listing content as structured data.
///
/// This enum serves as the single source of truth for all App Store Connect
/// metadata fields. Reference these values during submission rather than
/// re-drafting copy each time.
///
/// All string lengths are validated against Apple's limits:
/// - App name: 30 characters
/// - Subtitle: 30 characters
/// - Description: 4000 characters
/// - Keywords: 100 characters
/// - Promotional text: 170 characters
/// - What's New: 4000 characters
enum AppStoreMetadata {

    // MARK: - Identity

    /// App name displayed on the App Store (30 chars max).
    static let appName = "Kairo — Adaptive Focus"

    /// Subtitle shown below the app name (30 chars max).
    static let subtitle = "Smart Timer That Learns You"

    // MARK: - Category

    /// Primary App Store category.
    static let primaryCategory = "Productivity"

    /// Secondary App Store category.
    static let secondaryCategory = "Lifestyle"

    // MARK: - Description

    /// Full App Store description (4000 chars max).
    ///
    /// Optimized for:
    /// 1. Privacy-first positioning (key differentiator)
    /// 2. Feature highlights above the fold
    /// 3. Social proof language without fake reviews
    /// 4. ASO keyword integration
    static let description = """
    Kairo is the focus timer that actually learns how you work — and keeps \
    every byte of data on your device.

    FOCUS SMARTER, NOT HARDER
    Most timers just count down. Kairo watches how you focus, detects \
    distractions, and adapts session lengths to match your natural rhythm. \
    The more you use it, the smarter it gets.

    YOUR DATA NEVER LEAVES YOUR DEVICE
    Zero accounts. Zero cloud sync. Zero tracking. Kairo runs entirely \
    on-device using Core ML — your focus patterns, scores, and habits \
    are yours alone. We can't see them even if we wanted to.

    ADAPTIVE SESSIONS
    • Smart duration suggestions based on your focus history
    • Session types: Work, Study, Creative, Personal
    • Automatic break scheduling with Pomodoro-style blocks
    • Real-time focus score that reflects actual engagement

    DISTRACTION DETECTION
    Kairo uses device motion to detect phone pickups during sessions. \
    Every distraction is logged — not to shame you, but to help you \
    understand your patterns and improve over time.

    AMBIENT SOUNDSCAPES
    Choose from rain, coffee shop, white noise, and more to set the \
    mood for deep work. Each sound is designed to fade into the \
    background and keep you in flow.

    INSIGHTS THAT MATTER
    • Daily focus score with tier breakdowns
    • 7-day trend charts
    • Streak tracking to build consistency
    • Pattern analysis: best times, optimal durations, session quality
    • Smart suggestions powered by your own data

    BUILT FOR FOCUS, NOT ENGAGEMENT
    No social feeds. No leaderboards. No dark patterns. Kairo exists \
    to help you focus, then get out of your way. The app succeeds when \
    you stop looking at your phone.

    Requires iOS 17+. No subscription required for core features.
    """

    // MARK: - Keywords

    /// Comma-separated keyword string (100 chars max, optimized for ASO).
    ///
    /// Strategy: mix high-volume terms (focus,timer,productivity) with
    /// long-tail differentiators (adaptive,on-device,privacy).
    static let keywords = "focus,timer,pomodoro,productivity,concentration,study,deep work,adaptive,privacy,mindful"

    // MARK: - What's New

    /// Version 1.0 release notes.
    static let whatsNew = """
    Welcome to Kairo 1.0 — your adaptive focus companion.

    • Adaptive focus sessions that learn your rhythm
    • Real-time focus scoring with distraction detection
    • 4 session types: Work, Study, Creative, Personal
    • Ambient soundscapes for deep concentration
    • Daily insights, weekly trends, and streak tracking
    • Smart break scheduling
    • 100% on-device — no accounts, no tracking, no cloud

    This is just the beginning. Kairo gets smarter with every session.
    """

    // MARK: - Promotional Text

    /// Promotional text (170 chars max). Can be updated without a new build.
    static let promotionalText = "Focus smarter with an adaptive timer that learns your rhythm. 100% private — all data stays on your device. No accounts. No tracking."

    // MARK: - URLs

    /// Privacy policy URL (required for App Store submission).
    static let privacyPolicyURL = "https://apexdigitalhq.github.io/kairo-privacy.html"

    /// Support URL for user help and feedback.
    static let supportURL = "https://kairo.app/support"

    /// Marketing website URL.
    static let marketingURL = "https://kairo.app"

    // MARK: - Screenshot Captions

    /// Captions for each App Store screenshot (in order).
    ///
    /// These appear overlaid on screenshots in the listing.
    /// Keep them short, benefit-driven, and scannable.
    static let screenshotCaptions: [String] = [
        "Your daily focus score at a glance",
        "Adaptive sessions that learn your rhythm",
        "Real-time distraction detection",
        "Ambient sounds for deep concentration",
        "Weekly trends and smart insights",
        "100% private — all data on your device"
    ]

    // MARK: - Age Rating

    /// Content rating: 4+ (no objectionable content).
    static let ageRating = "4+"

    // MARK: - Copyright

    /// Copyright notice for the App Store listing.
    static let copyright = "© 2025 Kairo"

    // MARK: - Validation

    /// Validates all metadata fields against Apple's character limits.
    ///
    /// Call during development to catch copy that's too long before submission.
    /// - Returns: Array of validation error messages (empty = all good).
    static func validate() -> [String] {
        var errors: [String] = []

        if appName.count > 30 {
            errors.append("App name exceeds 30 chars (\(appName.count))")
        }
        if subtitle.count > 30 {
            errors.append("Subtitle exceeds 30 chars (\(subtitle.count))")
        }
        if description.count > 4000 {
            errors.append("Description exceeds 4000 chars (\(description.count))")
        }
        if keywords.count > 100 {
            errors.append("Keywords exceed 100 chars (\(keywords.count))")
        }
        if promotionalText.count > 170 {
            errors.append("Promotional text exceeds 170 chars (\(promotionalText.count))")
        }
        if whatsNew.count > 4000 {
            errors.append("What's New exceeds 4000 chars (\(whatsNew.count))")
        }

        return errors
    }
}
