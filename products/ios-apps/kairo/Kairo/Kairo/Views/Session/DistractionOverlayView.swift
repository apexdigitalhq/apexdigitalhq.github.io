import SwiftUI

// MARK: - DistractionOverlayView

/// Full-screen overlay displayed when the user returns from a distraction during a focus session.
///
/// Appears with a smooth blur + fade animation when the app re-enters the foreground.
/// Shows how long the user was away, their session progress so far, and the total
/// distraction count. Provides two clear actions: resume focusing or end the session.
///
/// **Auto-dismiss behavior**: If the user was away for less than 30 seconds, the overlay
/// automatically dismisses after a brief moment — treating the interruption as a
/// quick glance rather than a real distraction.
///
/// Usage:
/// ```swift
/// DistractionOverlayView(
///     isPresented: $showOverlay,
///     timeAway: 45.0,
///     sessionProgress: 0.62,
///     distractionCount: 2,
///     onResume: { engine.resume() },
///     onEnd: { engine.stop() }
/// )
/// ```
struct DistractionOverlayView: View {

    // MARK: - Bindings & Properties

    /// Controls overlay visibility. Set to `false` to dismiss.
    @Binding var isPresented: Bool

    /// How long the user was away from the app (seconds).
    let timeAway: TimeInterval

    /// Current session completion progress (0.0–1.0).
    let sessionProgress: Double

    /// Total distraction count this session (including this one).
    let distractionCount: Int

    /// Called when the user taps "Resume Focus".
    let onResume: () -> Void

    /// Called when the user taps "End Session".
    let onEnd: () -> Void

    // MARK: - Animation State

    @State private var showContent = false
    @State private var blurRadius: CGFloat = 0
    @State private var progressAnimated: Double = 0
    @State private var autoDismissing = false

    // MARK: - Constants

    /// Threshold below which the distraction is auto-dismissed.
    private let autoDismissThreshold: TimeInterval = 30.0

    /// Delay before auto-dismiss animation begins (seconds).
    private let autoDismissDelay: TimeInterval = 1.2

    // MARK: - Computed

    /// Whether this was a brief interruption that should auto-dismiss.
    private var isBriefInterruption: Bool {
        timeAway < autoDismissThreshold
    }

    /// Session progress as a percentage string (e.g. "62%").
    private var progressPercentage: String {
        "\(Int(sessionProgress * 100))%"
    }

    /// Human-readable time away string.
    private var timeAwayDisplay: String {
        let seconds = Int(timeAway)
        if seconds < 60 {
            return "\(seconds)s"
        }
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        if remainingSeconds == 0 {
            return "\(minutes)m"
        }
        return "\(minutes)m \(remainingSeconds)s"
    }

    /// Color for the progress ring based on completion percentage.
    private var progressColor: Color {
        if sessionProgress >= 0.75 { return KairoColors.successAdaptive }
        if sessionProgress >= 0.50 { return KairoColors.accentAdaptive }
        if sessionProgress >= 0.25 { return KairoColors.warningAdaptive }
        return KairoColors.mutedAdaptive
    }

    /// Contextual subtitle based on how long the user was away.
    private var subtitleText: String {
        if isBriefInterruption {
            return "Quick check — no worries!"
        }
        if timeAway > 300 {
            return "You were away for a while. Ready to refocus?"
        }
        if timeAway > 60 {
            return "Let's get back in the zone."
        }
        return "You stepped away briefly."
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Blur backdrop
            backgroundLayer

            // Content card
            if showContent && !autoDismissing {
                contentCard
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.92)),
                        removal: .opacity.combined(with: .scale(scale: 0.95))
                    ))
            }
        }
        .ignoresSafeArea()
        .onAppear(perform: handleAppear)
    }

    // MARK: - Background Layer

    private var backgroundLayer: some View {
        Color.black.opacity(showContent ? 0.4 : 0)
            .background(.ultraThinMaterial.opacity(showContent ? 1 : 0))
            .animation(KairoTheme.Animation.standard, value: showContent)
    }

    // MARK: - Content Card

    private var contentCard: some View {
        VStack(spacing: KairoTheme.Spacing.lg) {
            Spacer()

            VStack(spacing: KairoTheme.Spacing.lg) {
                // Header
                headerSection

                // Progress ring
                progressSection

                // Stats row
                statsSection

                // Subtitle
                Text(subtitleText)
                    .font(KairoTypography.body)
                    .foregroundStyle(KairoColors.mutedAdaptive)
                    .multilineTextAlignment(.center)

                // Action buttons
                buttonSection
            }
            .padding(KairoTheme.Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: KairoTheme.Radius.card)
                    .fill(KairoColors.surfaceAdaptive)
                    .shadow(
                        color: KairoTheme.Shadow.card.color,
                        radius: KairoTheme.Shadow.card.radius,
                        y: KairoTheme.Shadow.card.y
                    )
            )
            .padding(.horizontal, KairoTheme.Spacing.md)

            Spacer()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: KairoTheme.Spacing.xs) {
            Text("Welcome back! 🎯")
                .font(KairoTypography.heading1)
                .foregroundStyle(KairoColors.primaryAdaptive)

            Text("Away for \(timeAwayDisplay)")
                .font(KairoTypography.bodyLarge)
                .foregroundStyle(KairoColors.mutedAdaptive)
        }
    }

    // MARK: - Progress Ring

    private var progressSection: some View {
        ZStack {
            // Track
            Circle()
                .stroke(
                    KairoColors.mutedAdaptive.opacity(KairoTheme.TimerRing.trackOpacity),
                    lineWidth: 8
                )

            // Progress arc
            Circle()
                .trim(from: 0, to: progressAnimated)
                .stroke(
                    progressColor,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Percentage label
            VStack(spacing: KairoTheme.Spacing.xxs) {
                Text(progressPercentage)
                    .font(KairoTypography.scoreMedium)
                    .foregroundStyle(KairoColors.primaryAdaptive)

                Text("complete")
                    .font(KairoTypography.labelSmall)
                    .foregroundStyle(KairoColors.mutedAdaptive)
            }
        }
        .frame(width: 120, height: 120)
    }

    // MARK: - Stats Row

    private var statsSection: some View {
        HStack(spacing: KairoTheme.Spacing.xl) {
            statItem(
                icon: "arrow.uturn.left",
                value: "\(distractionCount)",
                label: distractionCount == 1 ? "distraction" : "distractions"
            )

            Divider()
                .frame(height: 32)

            statItem(
                icon: "clock",
                value: timeAwayDisplay,
                label: "away"
            )
        }
    }

    /// A single stat item with icon, value, and label.
    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: KairoTheme.Spacing.xxs) {
            Image(systemName: icon)
                .font(KairoTypography.body)
                .foregroundStyle(KairoColors.mutedAdaptive)

            Text(value)
                .font(KairoTypography.statValue)
                .foregroundStyle(KairoColors.primaryAdaptive)

            Text(label)
                .font(KairoTypography.labelSmall)
                .foregroundStyle(KairoColors.mutedAdaptive)
        }
    }

    // MARK: - Buttons

    private var buttonSection: some View {
        VStack(spacing: KairoTheme.Spacing.sm) {
            // Primary: Resume Focus
            Button(action: handleResume) {
                HStack(spacing: KairoTheme.Spacing.xs) {
                    Image(systemName: "play.fill")
                        .font(KairoTypography.body)
                    Text("Resume Focus")
                        .font(KairoTypography.heading3)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, KairoTheme.Spacing.sm)
                .background(KairoColors.accentAdaptive)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: KairoTheme.Radius.medium))
            }

            // Secondary: End Session
            Button(action: handleEnd) {
                Text("End Session")
                    .font(KairoTypography.body)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, KairoTheme.Spacing.sm)
                    .foregroundStyle(KairoColors.mutedAdaptive)
            }
        }
    }

    // MARK: - Actions

    /// Handles the overlay appearing — triggers animations and auto-dismiss logic.
    private func handleAppear() {
        // Animate in
        withAnimation(KairoTheme.Animation.sessionStart) {
            showContent = true
        }

        // Animate the progress ring
        withAnimation(KairoTheme.Animation.scoreReveal.delay(0.3)) {
            progressAnimated = sessionProgress
        }

        // Auto-dismiss for brief interruptions
        if isBriefInterruption {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(autoDismissDelay))
                withAnimation(KairoTheme.Animation.standard) {
                    autoDismissing = true
                }
                try? await Task.sleep(for: .seconds(0.3))
                isPresented = false
                onResume()
            }
        }
    }

    /// Dismisses the overlay and resumes the session.
    private func handleResume() {
        withAnimation(KairoTheme.Animation.standard) {
            showContent = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            isPresented = false
            onResume()
        }
    }

    /// Dismisses the overlay and ends the session.
    private func handleEnd() {
        withAnimation(KairoTheme.Animation.standard) {
            showContent = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            isPresented = false
            onEnd()
        }
    }
}

// MARK: - Preview

#Preview("Distraction Overlay — Long Absence") {
    ZStack {
        Color.blue.opacity(0.3).ignoresSafeArea()

        DistractionOverlayView(
            isPresented: .constant(true),
            timeAway: 185,
            sessionProgress: 0.62,
            distractionCount: 3,
            onResume: {},
            onEnd: {}
        )
    }
}

#Preview("Distraction Overlay — Brief Check") {
    ZStack {
        Color.blue.opacity(0.3).ignoresSafeArea()

        DistractionOverlayView(
            isPresented: .constant(true),
            timeAway: 12,
            sessionProgress: 0.85,
            distractionCount: 1,
            onResume: {},
            onEnd: {}
        )
    }
}
