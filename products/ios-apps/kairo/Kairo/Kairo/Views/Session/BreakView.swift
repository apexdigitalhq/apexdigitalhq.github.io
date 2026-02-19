import SwiftUI

// MARK: - BreakView

/// The break screen displayed between focus sessions.
///
/// Shows a calming countdown timer with progress ring, motivational messages,
/// session block progress, and actions to skip or extend the break.
/// Designed as a standalone view that overlays the session screen
/// when `breakManager.isOnBreak == true`.
///
/// Uses softer colors (reduced opacity from `KairoColors`) and slower
/// animations to create visual contrast with the high-intensity focus screen.
struct BreakView: View {

    /// The break manager driving timer state.
    @ObservedObject var breakManager: BreakManager

    /// Total sessions completed in the current block (for the progress indicator).
    let sessionsInBlock: Int

    /// Called when the user taps "Skip Break" — the parent handles the transition.
    var onSkipBreak: () -> Void

    /// Called when the user taps "Start Next Session" after the break ends.
    var onStartNextSession: () -> Void

    /// Called when the user is done for now.
    var onDone: () -> Void

    // MARK: - Local State

    /// Index into the motivational messages array, rotated every 8 seconds.
    @State private var messageIndex: Int = 0

    /// Controls the entrance animation on appear.
    @State private var isVisible: Bool = false

    /// Gentle breathing pulse on the break icon.
    @State private var breathePulse: Bool = false

    /// Timer that rotates motivational messages.
    @State private var messageTimer: Timer?

    // MARK: - Constants

    /// Motivational messages shown on a rotating cycle during breaks.
    private let breakMessages: [(text: String, emoji: String)] = [
        ("Stretch your legs", "🦵"),
        ("Hydrate!", "💧"),
        ("Rest your eyes", "👀"),
        ("Take a deep breath", "🌬️"),
        ("Look out the window", "🪟"),
        ("Roll your shoulders", "🧘"),
        ("Stand up and move", "🚶"),
        ("You're doing great", "⭐"),
        ("Clear your mind", "🧠"),
        ("Relax your jaw", "😌")
    ]

    /// Size of the break countdown ring.
    private let ringSize: CGFloat = 220

    // MARK: - Body

    var body: some View {
        ZStack {
            // Calming background gradient
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top: Break type badge
                breakTypeBadge
                    .padding(.top, KairoTheme.Spacing.xl)

                Spacer()

                // Center: Timer ring + countdown
                timerSection

                // Motivational message
                motivationalMessage
                    .padding(.top, KairoTheme.Spacing.lg)

                // Session block indicator
                sessionBlockIndicator
                    .padding(.top, KairoTheme.Spacing.md)

                Spacer()

                // Bottom: Action buttons
                actionButtons
                    .padding(.bottom, KairoTheme.Spacing.xxl)
            }
            .padding(.horizontal, KairoTheme.Spacing.md)
        }
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.95)
        .onAppear {
            withAnimation(KairoAnimation.smooth.delay(0.1)) {
                isVisible = true
            }
            withAnimation(KairoAnimation.breathe) {
                breathePulse = true
            }
            startMessageRotation()
        }
        .onDisappear {
            messageTimer?.invalidate()
            messageTimer = nil
        }
    }

    // MARK: - Background

    /// Softer gradient for the calming break atmosphere.
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                breakTypeColor.opacity(0.08),
                KairoColors.backgroundAdaptive,
                KairoColors.backgroundAdaptive
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Break Type Badge

    /// Pill badge showing the current break type and icon.
    private var breakTypeBadge: some View {
        HStack(spacing: KairoTheme.Spacing.xs) {
            Image(systemName: breakManager.currentBreakType.icon)
                .font(.system(size: 14, weight: .semibold))

            Text(breakManager.currentBreakType.displayName)
                .font(KairoTypography.label)
        }
        .foregroundColor(breakTypeColor)
        .padding(.horizontal, KairoTheme.Spacing.md)
        .padding(.vertical, KairoTheme.Spacing.xs)
        .background(
            Capsule()
                .fill(breakTypeColor.opacity(0.12))
        )
    }

    // MARK: - Timer Section

    /// Central countdown ring with large timer display.
    private var timerSection: some View {
        ZStack {
            // Progress ring (counting down — fills as break completes)
            ProgressRing(
                progress: breakManager.breakProgress,
                lineWidth: 10,
                trackColor: breakTypeColor.opacity(0.12),
                fillColor: breakTypeColor.opacity(0.7),
                glowEnabled: false
            )
            .frame(width: ringSize, height: ringSize)

            VStack(spacing: KairoTheme.Spacing.xs) {
                // Break icon with gentle pulse
                Image(systemName: breakManager.currentBreakType.icon)
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(breakTypeColor.opacity(0.6))
                    .scaleEffect(breathePulse ? 1.05 : 1.0)

                // Countdown timer
                Text(breakManager.breakTimeRemaining.timerDisplay)
                    .font(KairoTypography.timerDisplaySmall)
                    .foregroundColor(KairoColors.primaryAdaptive)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.linear(duration: 0.1), value: breakManager.breakTimeRemaining)

                // Break type subtitle
                Text(breakManager.currentBreakType.subtitle)
                    .font(KairoTypography.caption)
                    .foregroundColor(KairoColors.mutedAdaptive)
            }
        }
    }

    // MARK: - Motivational Message

    /// Rotating motivational messages with smooth transitions.
    private var motivationalMessage: some View {
        let message = breakMessages[messageIndex % breakMessages.count]

        return HStack(spacing: KairoTheme.Spacing.xs) {
            Text(message.emoji)
                .font(.system(size: 24))

            Text(message.text)
                .font(KairoTypography.bodyLarge)
                .foregroundColor(KairoColors.primaryAdaptive.opacity(0.8))
        }
        .padding(.horizontal, KairoTheme.Spacing.lg)
        .padding(.vertical, KairoTheme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: KairoTheme.Radius.full)
                .fill(KairoColors.surfaceAdaptive.opacity(0.8))
        )
        .id(messageIndex) // Force view identity change for transition
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .trailing)),
            removal: .opacity.combined(with: .move(edge: .leading))
        ))
        .animation(KairoAnimation.smooth, value: messageIndex)
    }

    // MARK: - Session Block Indicator

    /// Visual dots showing progress through the session block.
    private var sessionBlockIndicator: some View {
        VStack(spacing: KairoTheme.Spacing.xs) {
            // Dot indicators
            HStack(spacing: KairoTheme.Spacing.xs) {
                ForEach(0..<KairoTheme.SessionPreset.longBreakInterval, id: \.self) { index in
                    Circle()
                        .fill(index < sessionsInBlock
                              ? breakTypeColor
                              : breakTypeColor.opacity(0.2))
                        .frame(width: 10, height: 10)
                }
            }

            // Label
            Text(sessionBlockLabel)
                .font(KairoTypography.bodySmall)
                .foregroundColor(KairoColors.mutedAdaptive)
        }
    }

    /// Descriptive label for the block progress.
    private var sessionBlockLabel: String {
        let remaining = breakManager.sessionsUntilLongBreak
        if remaining == 0 || breakManager.currentBreakType == .long {
            return "Block complete — enjoy your long break!"
        }
        let sessionWord = remaining == 1 ? "session" : "sessions"
        return "\(remaining) \(sessionWord) until long break"
    }

    // MARK: - Action Buttons

    /// Bottom action area with skip, extend, and done controls.
    private var actionButtons: some View {
        VStack(spacing: KairoTheme.Spacing.sm) {
            // Extend button — adds 2 minutes
            Button(action: {
                withAnimation(KairoAnimation.quick) {
                    breakManager.extendBreak(by: 120)
                }
            }) {
                HStack(spacing: KairoTheme.Spacing.xs) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .medium))

                    Text("Extend +2 min")
                        .font(KairoTypography.heading3)
                }
                .foregroundColor(breakTypeColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, KairoTheme.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: KairoTheme.Radius.large)
                        .fill(breakTypeColor.opacity(0.12))
                )
            }

            // Skip break button
            Button(action: {
                withAnimation(KairoAnimation.smooth) {
                    isVisible = false
                }
                // Small delay so the fade-out animation plays
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onSkipBreak()
                }
            }) {
                HStack(spacing: KairoTheme.Spacing.xs) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14, weight: .medium))

                    Text("Skip Break")
                        .font(KairoTypography.bodyLarge)
                }
                .foregroundColor(KairoColors.mutedAdaptive)
                .frame(maxWidth: .infinity)
                .padding(.vertical, KairoTheme.Spacing.sm)
            }

            // Done for now
            Button(action: {
                withAnimation(KairoAnimation.smooth) {
                    isVisible = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onDone()
                }
            }) {
                Text("I'm Done for Now")
                    .font(KairoTypography.body)
                    .foregroundColor(KairoColors.mutedAdaptive.opacity(0.7))
            }
        }
        .padding(.horizontal, KairoTheme.Spacing.md)
    }

    // MARK: - Helpers

    /// The accent color for the current break type.
    private var breakTypeColor: Color {
        switch breakManager.currentBreakType {
        case .short: return KairoColors.successAdaptive
        case .long:  return Color(hex: 0x9B59B6) // Calming purple
        }
    }

    /// Starts a timer that rotates motivational messages every 8 seconds.
    private func startMessageRotation() {
        messageIndex = Int.random(in: 0..<breakMessages.count)

        messageTimer = Timer.scheduledTimer(
            withTimeInterval: 8.0,
            repeats: true
        ) { _ in
            Task { @MainActor in
                withAnimation(KairoAnimation.smooth) {
                    messageIndex = (messageIndex + 1) % breakMessages.count
                }
            }
        }

        if let timer = messageTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
}

// MARK: - Preview

#Preview("Break View — Short") {
    let manager = BreakManager()

    BreakView(
        breakManager: manager,
        sessionsInBlock: 2,
        onSkipBreak: {},
        onStartNextSession: {},
        onDone: {}
    )
    .onAppear {
        manager.startBreak(type: .short)
    }
}

#Preview("Break View — Long") {
    let manager = BreakManager()

    BreakView(
        breakManager: manager,
        sessionsInBlock: 4,
        onSkipBreak: {},
        onStartNextSession: {},
        onDone: {}
    )
    .onAppear {
        manager.startBreak(type: .long)
    }
}
