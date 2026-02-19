import SwiftUI

// MARK: - SessionCompletionView

/// Revamped celebratory session completion screen with full system integration.
///
/// Displays session duration, focus score, quality rating with color coding,
/// distraction count, and streak update. Includes a post-session insight card,
/// confetti-like celebration animation for high scores (> 85), and three action
/// buttons: "Start Break", "New Session", and "Done".
///
/// Smooth entry animation scales up from center with staggered reveals.
struct SessionCompletionView: View {

    /// The completed or abandoned `FocusSession` entity.
    let session: FocusSession

    /// Called when the user chooses to start a break.
    var onStartBreak: (() -> Void)?

    /// Called when the user starts a new session immediately.
    var onStartAnother: (() -> Void)?

    /// Called when the user is finished.
    var onDone: (() -> Void)?

    // MARK: - Environment

    @EnvironmentObject private var insightGenerator: InsightGenerator
    @EnvironmentObject private var coordinator: SessionCoordinator

    // MARK: - Animation State

    @State private var showHero = false
    @State private var heroScale: CGFloat = 0.3
    @State private var showStats = false
    @State private var animatedScore: Float = 0
    @State private var showInsight = false
    @State private var showButtons = false
    @State private var streakLength: Int32 = 0
    @State private var showShareSheet = false

    // Confetti particles
    @State private var confettiParticles: [ConfettiParticle] = []
    @State private var confettiActive = false

    // MARK: - Computed

    private var isCompleted: Bool { session.isCompleted }

    private var sessionTypeInfo: KairoTheme.SessionType {
        KairoTheme.SessionType(rawValue: session.sessionType) ?? .work
    }

    private var scoreColor: Color {
        KairoColors.scoreColor(for: session.focusScore)
    }

    private var quality: FocusQuality {
        FocusQuality(rating: session.qualityRating) ?? .medium
    }

    private var shouldCelebrate: Bool {
        isCompleted && session.focusScore > 85
    }

    /// Suggested break duration in minutes from RuleEngine.
    private var suggestedBreakMinutes: Int {
        let seconds = coordinator.breakState?.duration ?? TimeInterval(KairoTheme.SessionPreset.shortBreak * 60)
        return max(1, Int(seconds / 60))
    }

    /// Post-session insight generated from the completed session data.
    private var postSessionInsight: Insight? {
        coordinator.currentInsight
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            KairoColors.backgroundAdaptive
                .ignoresSafeArea()

            // Confetti layer
            if shouldCelebrate {
                confettiOverlay
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: KairoTheme.Spacing.lg) {
                    Spacer().frame(height: KairoTheme.Spacing.xl)

                    // Hero icon
                    heroSection

                    // Header text
                    headerSection

                    // Stats card
                    if showStats {
                        statsCard
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity
                            ))
                    }

                    // Streak badge
                    if showStats && streakLength > 0 {
                        streakBadge
                            .transition(.scale.combined(with: .opacity))
                    }

                    // Post-session insight
                    if showInsight, let insight = postSessionInsight {
                        InsightCard(insight: insight, style: .expanded)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    Spacer().frame(height: KairoTheme.Spacing.sm)

                    // Action buttons
                    if showButtons {
                        actionButtons
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    Spacer().frame(height: KairoTheme.Spacing.xl)
                }
                .padding(.horizontal, KairoTheme.Spacing.lg)
            }
        }
        .onAppear { runEntryAnimations() }
        .sheet(isPresented: $showShareSheet) {
            shareSheet
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(heroGlowColor.opacity(0.08))
                .frame(width: 140, height: 140)
                .scaleEffect(showHero ? 1.0 : 0.5)
                .opacity(showHero ? 1 : 0)

            // Inner ring
            Circle()
                .fill(heroGlowColor.opacity(0.15))
                .frame(width: 110, height: 110)
                .scaleEffect(showHero ? 1.0 : 0.6)
                .opacity(showHero ? 1 : 0)

            // Icon
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "flag.fill")
                .font(.system(size: 56, weight: .medium))
                .foregroundStyle(heroGlowColor)
                .scaleEffect(heroScale)
                .opacity(showHero ? 1 : 0)
        }
        .animation(KairoTheme.Animation.sessionStart, value: showHero)
    }

    private var heroGlowColor: Color {
        isCompleted ? KairoColors.successAdaptive : KairoColors.warningAdaptive
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: KairoTheme.Spacing.xs) {
            Text(isCompleted ? "Session Complete!" : "Session Ended")
                .font(KairoTypography.heading1)
                .foregroundColor(KairoColors.primaryAdaptive)

            HStack(spacing: KairoTheme.Spacing.xxs) {
                Image(systemName: quality.iconName)
                    .font(.system(size: 14))
                Text("\(quality.displayName) Quality")
                    .font(KairoTypography.bodyLarge)
            }
            .foregroundColor(quality.color)
        }
        .opacity(showHero ? 1 : 0)
        .offset(y: showHero ? 0 : 10)
        .animation(KairoTheme.Animation.standard.delay(0.3), value: showHero)
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        VStack(spacing: KairoTheme.Spacing.lg) {
            // Focus score — hero number
            VStack(spacing: KairoTheme.Spacing.xxs) {
                Text("FOCUS SCORE")
                    .font(KairoTypography.labelSmall)
                    .foregroundColor(KairoColors.mutedAdaptive)
                    .tracking(1.5)

                Text("\(Int(animatedScore))")
                    .font(KairoTypography.scoreLarge)
                    .foregroundColor(scoreColor)
                    .contentTransition(.numericText())

                // Score bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(KairoColors.mutedAdaptive.opacity(0.15))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(scoreColor)
                            .frame(
                                width: geo.size.width * CGFloat(animatedScore / 100),
                                height: 6
                            )
                    }
                }
                .frame(height: 6)
                .padding(.horizontal, KairoTheme.Spacing.xl)
            }

            Divider()
                .foregroundColor(KairoColors.mutedAdaptive.opacity(0.2))

            // Stat grid
            HStack(spacing: 0) {
                statItem(
                    icon: "clock.fill",
                    value: TimeInterval(session.actualDuration).humanReadable,
                    label: "Duration",
                    color: sessionTypeInfo.color
                )

                verticalDivider

                statItem(
                    icon: quality.iconName,
                    value: quality.displayName,
                    label: "Quality",
                    color: quality.color
                )

                verticalDivider

                statItem(
                    icon: "exclamationmark.triangle.fill",
                    value: "\(session.distractionCount)",
                    label: session.distractionCount == 1 ? "Distraction" : "Distractions",
                    color: session.distractionCount == 0
                        ? KairoColors.successAdaptive
                        : KairoColors.warningAdaptive
                )
            }

            // Pauses row
            if session.pauseCount > 0 {
                HStack(spacing: KairoTheme.Spacing.xs) {
                    Image(systemName: "pause.circle")
                        .font(.system(size: 13))
                        .foregroundColor(KairoColors.mutedAdaptive)

                    Text("Paused \(session.pauseCount) time\(session.pauseCount == 1 ? "" : "s")")
                        .font(KairoTypography.bodySmall)
                        .foregroundColor(KairoColors.mutedAdaptive)
                }
            }
        }
        .padding(KairoTheme.Spacing.lg)
        .background(KairoColors.surfaceAdaptive)
        .cornerRadius(KairoTheme.Radius.card)
        .shadow(
            color: KairoTheme.Shadow.card.color,
            radius: KairoTheme.Shadow.card.radius,
            y: KairoTheme.Shadow.card.y
        )
    }

    private func statItem(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: KairoTheme.Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)

            Text(value)
                .font(KairoTypography.statValue)
                .foregroundColor(KairoColors.primaryAdaptive)

            Text(label)
                .font(KairoTypography.caption)
                .foregroundColor(KairoColors.mutedAdaptive)
        }
        .frame(maxWidth: .infinity)
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(KairoColors.mutedAdaptive.opacity(0.15))
            .frame(width: 1, height: 50)
    }

    // MARK: - Streak Badge

    private var streakBadge: some View {
        HStack(spacing: KairoTheme.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: "flame.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(streakLength)-Day Streak")
                    .font(KairoTypography.heading3)
                    .foregroundColor(KairoColors.primaryAdaptive)

                Text(streakEncouragement)
                    .font(KairoTypography.bodySmall)
                    .foregroundColor(KairoColors.mutedAdaptive)
            }

            Spacer()

            Image(systemName: streakBadgeIcon)
                .font(.system(size: 24))
                .foregroundColor(.orange.opacity(0.7))
        }
        .padding(KairoTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: KairoTheme.Radius.card)
                .fill(Color.orange.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: KairoTheme.Radius.card)
                        .strokeBorder(Color.orange.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private var streakEncouragement: String {
        switch streakLength {
        case 1:       return "Great start! Come back tomorrow."
        case 2...6:   return "Building momentum!"
        case 7...13:  return "One full week — impressive!"
        case 14...29: return "Two weeks strong 💪"
        case 30...99: return "A whole month of focus!"
        default:      return "Legendary consistency 🔥"
        }
    }

    private var streakBadgeIcon: String {
        switch streakLength {
        case 1...6:   return "shield.fill"
        case 7...29:  return "medal.fill"
        case 30...99: return "crown.fill"
        default:      return "trophy.fill"
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: KairoTheme.Spacing.sm) {
            // Start Break — primary CTA
            if isCompleted {
                Button(action: { onStartBreak?() }) {
                    HStack(spacing: KairoTheme.Spacing.xs) {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 16, weight: .semibold))

                        Text("Start \(suggestedBreakMinutes)-Min Break")
                            .font(KairoTypography.heading3)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, KairoTheme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: KairoTheme.Radius.large)
                            .fill(KairoColors.successAdaptive)
                    )
                    .shadow(
                        color: KairoTheme.Shadow.button.color,
                        radius: KairoTheme.Shadow.button.radius,
                        y: KairoTheme.Shadow.button.y
                    )
                }
            }

            // New Session — secondary CTA
            Button(action: { onStartAnother?() }) {
                HStack(spacing: KairoTheme.Spacing.xs) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .semibold))

                    Text("New Session")
                        .font(KairoTypography.heading3)
                }
                .foregroundColor(sessionTypeInfo.color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, KairoTheme.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: KairoTheme.Radius.large)
                        .strokeBorder(sessionTypeInfo.color.opacity(0.4), lineWidth: 1.5)
                )
            }

            // Bottom row: Share + Done
            HStack(spacing: KairoTheme.Spacing.md) {
                // Share
                Button(action: { showShareSheet = true }) {
                    HStack(spacing: KairoTheme.Spacing.xxs) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .medium))

                        Text("Share")
                            .font(KairoTypography.label)
                    }
                    .foregroundColor(KairoColors.mutedAdaptive)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, KairoTheme.Spacing.sm)
                }

                // Done
                Button(action: { onDone?() }) {
                    Text("Done")
                        .font(KairoTypography.bodyLarge)
                        .foregroundColor(KairoColors.mutedAdaptive)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, KairoTheme.Spacing.sm)
                }
            }
        }
    }

    // MARK: - Share Sheet

    /// Generates a share-friendly text summary of the session.
    private var shareSheet: some View {
        let shareText = buildShareText()

        return ShareLink(item: shareText) {
            Label("Share Focus Stats", systemImage: "square.and.arrow.up")
                .font(KairoTypography.heading3)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, KairoTheme.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: KairoTheme.Radius.large)
                        .fill(sessionTypeInfo.color)
                )
        }
        .padding(KairoTheme.Spacing.lg)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    /// Builds a plain-text summary for sharing.
    private func buildShareText() -> String {
        let duration = TimeInterval(session.actualDuration).humanReadable
        let score = Int(session.focusScore)
        let type = sessionTypeInfo.displayName

        var lines: [String] = [
            "🎯 Kairo Focus Session",
            "",
            "📊 Score: \(score)/100 (\(quality.displayName))",
            "⏱️ Duration: \(duration)",
            "💼 Type: \(type)",
        ]

        if session.distractionCount == 0 {
            lines.append("✅ Zero distractions!")
        } else {
            lines.append("⚠️ Distractions: \(session.distractionCount)")
        }

        if streakLength > 1 {
            lines.append("🔥 Streak: \(streakLength) days")
        }

        lines.append("")
        lines.append("Focus smarter with Kairo ⏳")

        return lines.joined(separator: "\n")
    }

    // MARK: - Confetti Overlay

    /// Lightweight confetti animation — colored circles floating upward.
    private var confettiOverlay: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(confettiParticles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .position(
                            x: particle.x * geo.size.width,
                            y: confettiActive
                                ? -particle.size
                                : geo.size.height + particle.size
                        )
                        .opacity(confettiActive ? 0 : particle.opacity)
                        .animation(
                            .easeOut(duration: particle.duration)
                                .delay(particle.delay),
                            value: confettiActive
                        )
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Entry Animations

    private func runEntryAnimations() {
        loadStreak()

        // Phase 1: Hero icon (immediate)
        withAnimation(KairoTheme.Animation.sessionStart) {
            showHero = true
            heroScale = 1.0
        }

        // Phase 2: Stats card
        withAnimation(KairoTheme.Animation.standard.delay(0.5)) {
            showStats = true
        }

        // Phase 3: Score count-up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(KairoTheme.Animation.scoreReveal) {
                animatedScore = session.focusScore
            }
        }

        // Phase 4: Insight card
        withAnimation(KairoTheme.Animation.standard.delay(1.0)) {
            showInsight = true
        }

        // Phase 5: Buttons
        withAnimation(KairoTheme.Animation.standard.delay(1.2)) {
            showButtons = true
        }

        // Phase 6: Confetti (if earned)
        if shouldCelebrate {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                generateConfettiParticles()
                withAnimation {
                    confettiActive = true
                }
            }
        }
    }

    // MARK: - Confetti Generation

    /// Creates randomized confetti particles for the celebration animation.
    private func generateConfettiParticles() {
        let colors: [Color] = [
            KairoColors.accentAdaptive,
            KairoColors.successAdaptive,
            .orange,
            Color(hex: 0x9B59B6),
            Color(hex: 0x3498DB),
            .yellow
        ]

        confettiParticles = (0..<24).map { _ in
            ConfettiParticle(
                x: CGFloat.random(in: 0.05...0.95),
                color: colors.randomElement() ?? .orange,
                size: CGFloat.random(in: 6...14),
                opacity: Double.random(in: 0.5...1.0),
                duration: Double.random(in: 1.8...3.5),
                delay: Double.random(in: 0...0.6)
            )
        }
    }

    // MARK: - Data Loading

    /// Fetches the current streak length from Core Data.
    private func loadStreak() {
        let request = FocusStreak.fetchRequest()
        request.fetchLimit = 1

        if let context = session.managedObjectContext,
           let streak = (try? context.fetch(request))?.first,
           streak.isCurrentlyValid {
            streakLength = streak.currentLength
        }
    }
}

// MARK: - ConfettiParticle

/// A single confetti particle with randomized visual properties.
private struct ConfettiParticle: Identifiable {
    let id = UUID()

    /// Horizontal position as a fraction of container width (0.0–1.0).
    let x: CGFloat

    /// Particle color.
    let color: Color

    /// Diameter in points.
    let size: CGFloat

    /// Opacity (0.0–1.0).
    let opacity: Double

    /// Animation duration in seconds.
    let duration: Double

    /// Delay before animation starts.
    let delay: Double
}

// MARK: - Previews

#Preview("Session Complete — High Score") {
    let context = PersistenceController.shared.container.viewContext
    let session = FocusSession.create(in: context, type: "work", targetDuration: 1500)
    session.actualDuration = 1500
    session.status = "completed"
    session.focusScore = 92
    session.qualityRating = "high"
    session.distractionCount = 0
    session.pauseCount = 0

    let coordinator = SessionCoordinator(
        focusEngine: FocusEngine(context: context),
        soundManager: SoundManager.shared,
        distractionDetector: DistractionDetector(),
        hapticEngine: HapticEngine(),
        notificationManager: NotificationManager.shared,
        ruleEngine: RuleEngine(),
        insightGenerator: InsightGenerator(),
        widgetDataProvider: WidgetDataProvider(),
        persistenceController: PersistenceController.shared
    )

    return SessionCompletionView(
        session: session,
        onStartBreak: {},
        onStartAnother: {},
        onDone: {}
    )
    .environmentObject(InsightGenerator())
    .environmentObject(coordinator)
}

#Preview("Session Abandoned") {
    let context = PersistenceController.shared.container.viewContext
    let session = FocusSession.create(in: context, type: "study", targetDuration: 3000)
    session.actualDuration = 1800
    session.status = "abandoned"
    session.focusScore = 52
    session.qualityRating = "medium"
    session.distractionCount = 3
    session.pauseCount = 2

    let coordinator = SessionCoordinator(
        focusEngine: FocusEngine(context: context),
        soundManager: SoundManager.shared,
        distractionDetector: DistractionDetector(),
        hapticEngine: HapticEngine(),
        notificationManager: NotificationManager.shared,
        ruleEngine: RuleEngine(),
        insightGenerator: InsightGenerator(),
        widgetDataProvider: WidgetDataProvider(),
        persistenceController: PersistenceController.shared
    )

    return SessionCompletionView(
        session: session,
        onStartAnother: {},
        onDone: {}
    )
    .environmentObject(InsightGenerator())
    .environmentObject(coordinator)
}
