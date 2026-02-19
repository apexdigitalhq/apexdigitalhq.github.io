import SwiftUI

/// The main focus session screen — pre-session setup, active timer, breaks, and completion.
///
/// Wired to `SessionCoordinator` for full end-to-end session orchestration.
/// Displays different UI states based on the coordinator's `phase`:
/// - **idle**: Duration picker, session type selector, RuleEngine suggestion, start button
/// - **preparing**: 3-2-1 countdown with haptic feedback
/// - **focusing**: Large progress ring, countdown timer, mini sound bar, pause/stop controls
/// - **paused**: Dimmed ring, resume/stop controls
/// - **onBreak**: Break countdown, session count indicator, skip button
/// - **completed**: Delegates to SessionCompletionView overlay
struct FocusSessionView: View {

    @EnvironmentObject private var coordinator: SessionCoordinator
    @EnvironmentObject private var engine: FocusEngine
    @EnvironmentObject private var soundManager: SoundManager

    // MARK: - Local State

    @State private var ringScale: CGFloat = 1.0
    @State private var showControls = false
    @State private var breathePulse = false
    @State private var customDurationSheet = false
    @State private var customMinutes: Int = 25
    @State private var zenMode = false
    @State private var zenPeek = false

    // MARK: - Body

    var body: some View {
        ZStack {
            KairoColors.backgroundAdaptive
                .ignoresSafeArea()

            // Completion overlay
            if coordinator.showCompletionScreen, let session = engine.completedSession {
                completionOverlay(session: session)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                mainContent
                    .transition(.opacity)
            }

            // Focus Shield overlay is now rendered at MainTabView level
            // to cover the tab bar. See FocusShieldOverlay.swift.
        }
        .sheet(isPresented: $coordinator.showSoundPicker) {
            SoundPickerView()
        }
        .sheet(isPresented: $customDurationSheet) {
            customDurationPicker
        }
        .onAppear {
            coordinator.refreshSuggestions()
            withAnimation(KairoTheme.Animation.standard.delay(0.2)) {
                showControls = true
            }
        }
        .onChange(of: coordinator.phase) { _, newPhase in
            handlePhaseAnimation(newPhase)
            // Keep screen awake during active sessions
            if newPhase == .focusing || newPhase == .preparing || newPhase == .paused {
                UIApplication.shared.isIdleTimerDisabled = true
            } else {
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
    }

    // MARK: - Main Content Router

    @ViewBuilder
    private var mainContent: some View {
        switch coordinator.phase {
        case .idle:
            preSessionView
        case .preparing:
            preparingView
        case .focusing, .paused:
            activeSessionView
        case .onBreak:
            breakView
        case .completed:
            // Handled by the completion overlay in the ZStack
            EmptyView()
        }
    }

    // MARK: - Pre-Session View

    private var preSessionView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: KairoTheme.Spacing.lg) {
                Spacer().frame(height: KairoTheme.Spacing.md)

                // Insight card
                if let insight = coordinator.currentInsight {
                    insightCard(insight)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Contextual message
                if !coordinator.contextualMessage.isEmpty {
                    Text(coordinator.contextualMessage)
                        .font(KairoTypography.body)
                        .foregroundColor(KairoColors.mutedAdaptive)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, KairoTheme.Spacing.lg)
                }

                // Session type picker
                sessionTypePicker

                // Duration picker
                durationPicker

                // Sound selector row
                soundRow

                Spacer().frame(height: KairoTheme.Spacing.md)

                // Start button
                if showControls {
                    startButton
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer().frame(height: KairoTheme.Spacing.xxl)
            }
            .padding(.horizontal, KairoTheme.Spacing.md)
        }
    }

    // MARK: - Insight Card

    private func insightCard(_ insight: Insight) -> some View {
        HStack(spacing: KairoTheme.Spacing.sm) {
            Text(insight.emoji)
                .font(.system(size: 28))

            VStack(alignment: .leading, spacing: KairoTheme.Spacing.xxs) {
                Text(insight.title)
                    .font(KairoTypography.label)
                    .foregroundColor(KairoColors.primaryAdaptive)

                Text(insight.message)
                    .font(KairoTypography.bodySmall)
                    .foregroundColor(KairoColors.mutedAdaptive)
                    .lineLimit(3)
            }
        }
        .padding(KairoTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KairoColors.surfaceAdaptive)
        .cornerRadius(KairoTheme.Radius.card)
        .shadow(
            color: KairoTheme.Shadow.card.color,
            radius: KairoTheme.Shadow.card.radius,
            y: KairoTheme.Shadow.card.y
        )
    }

    // MARK: - Session Type Picker

    private var sessionTypePicker: some View {
        VStack(alignment: .leading, spacing: KairoTheme.Spacing.xs) {
            Text("SESSION TYPE")
                .font(KairoTypography.labelSmall)
                .foregroundColor(KairoColors.mutedAdaptive)
                .tracking(1.5)

            HStack(spacing: KairoTheme.Spacing.xs) {
                ForEach(KairoTheme.SessionType.allCases) { type in
                    Button(action: {
                        withAnimation(KairoTheme.Animation.quick) {
                            coordinator.selectedSessionType = type
                        }
                    }) {
                        VStack(spacing: KairoTheme.Spacing.xxs) {
                            Image(systemName: type.iconName)
                                .font(.system(size: 18, weight: .medium))

                            Text(type.displayName)
                                .font(KairoTypography.caption)
                        }
                        .foregroundColor(
                            coordinator.selectedSessionType == type
                                ? .white
                                : KairoColors.mutedAdaptive
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, KairoTheme.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: KairoTheme.Radius.medium)
                                .fill(
                                    coordinator.selectedSessionType == type
                                        ? type.color
                                        : KairoColors.surfaceAdaptive
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Duration Picker

    private var durationPicker: some View {
        VStack(alignment: .leading, spacing: KairoTheme.Spacing.xs) {
            HStack {
                Text("DURATION")
                    .font(KairoTypography.labelSmall)
                    .foregroundColor(KairoColors.mutedAdaptive)
                    .tracking(1.5)

                Spacer()

                if coordinator.suggestedDurationMinutes != coordinator.selectedDurationMinutes {
                    Button(action: {
                        withAnimation(KairoTheme.Animation.quick) {
                            coordinator.selectedDurationMinutes = coordinator.suggestedDurationMinutes
                        }
                    }) {
                        Text("Suggested: \(coordinator.suggestedDurationMinutes) min")
                            .font(KairoTypography.caption)
                            .foregroundColor(coordinator.selectedSessionType.color)
                    }
                }
            }

            HStack(spacing: KairoTheme.Spacing.xs) {
                ForEach(KairoTheme.SessionPreset.durations, id: \.self) { minutes in
                    durationPresetButton(minutes: minutes)
                }

                // Custom button
                Button(action: {
                    customMinutes = coordinator.selectedDurationMinutes
                    customDurationSheet = true
                }) {
                    VStack(spacing: KairoTheme.Spacing.xxs) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 16, weight: .medium))

                        Text("Custom")
                            .font(KairoTypography.caption)
                    }
                    .foregroundColor(
                        !KairoTheme.SessionPreset.durations.contains(coordinator.selectedDurationMinutes)
                            ? .white
                            : KairoColors.mutedAdaptive
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, KairoTheme.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: KairoTheme.Radius.medium)
                            .fill(
                                !KairoTheme.SessionPreset.durations.contains(coordinator.selectedDurationMinutes)
                                    ? coordinator.selectedSessionType.color
                                    : KairoColors.surfaceAdaptive
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func durationPresetButton(minutes: Int) -> some View {
        let isSelected = coordinator.selectedDurationMinutes == minutes
        return Button(action: {
            withAnimation(KairoTheme.Animation.quick) {
                coordinator.selectedDurationMinutes = minutes
            }
        }) {
            Text("\(minutes)")
                .font(KairoTypography.heading3)
                .foregroundColor(isSelected ? .white : KairoColors.primaryAdaptive)
                .frame(maxWidth: .infinity)
                .padding(.vertical, KairoTheme.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: KairoTheme.Radius.medium)
                        .fill(isSelected
                              ? coordinator.selectedSessionType.color
                              : KairoColors.surfaceAdaptive)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sound Row

    private var soundRow: some View {
        Button(action: {
            coordinator.showSoundPicker = true
        }) {
            HStack(spacing: KairoTheme.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(soundManager.selectedSound.color.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: soundManager.selectedSound.iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(soundManager.selectedSound.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Ambient Sound")
                        .font(KairoTypography.label)
                        .foregroundColor(KairoColors.primaryAdaptive)

                    Text(soundManager.selectedSound.displayName)
                        .font(KairoTypography.bodySmall)
                        .foregroundColor(KairoColors.mutedAdaptive)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(KairoColors.mutedAdaptive)
            }
            .padding(KairoTheme.Spacing.md)
            .background(KairoColors.surfaceAdaptive)
            .cornerRadius(KairoTheme.Radius.card)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Start Button

    private var startButton: some View {
        Button(action: {
            coordinator.startSession()
        }) {
            HStack(spacing: KairoTheme.Spacing.xs) {
                Image(systemName: "play.fill")
                    .font(.system(size: 16, weight: .semibold))

                Text("Start \(coordinator.selectedDurationMinutes)-Minute Session")
                    .font(KairoTypography.heading3)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, KairoTheme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: KairoTheme.Radius.large)
                    .fill(coordinator.selectedSessionType.color)
            )
            .shadow(
                color: KairoTheme.Shadow.button.color,
                radius: KairoTheme.Shadow.button.radius,
                y: KairoTheme.Shadow.button.y
            )
        }
        .padding(.horizontal, KairoTheme.Spacing.md)
    }

    // MARK: - Preparing View

    private var preparingView: some View {
        VStack(spacing: KairoTheme.Spacing.xl) {
            Spacer()

            // Countdown number
            Text("\(engine.preparingCountdown)")
                .font(KairoTypography.countdownDisplay)
                .foregroundColor(KairoColors.primaryAdaptive)
                .contentTransition(.numericText())
                .animation(KairoTheme.Animation.timerPulse, value: engine.preparingCountdown)

            Text("Get Ready")
                .font(KairoTypography.heading2)
                .foregroundColor(KairoColors.mutedAdaptive)

            Spacer()

            Button(action: {
                coordinator.cancelSession()
            }) {
                Text("Cancel")
                    .font(KairoTypography.bodyLarge)
                    .foregroundColor(KairoColors.mutedAdaptive)
            }
            .padding(.bottom, KairoTheme.Spacing.xxl)
        }
    }

    // MARK: - Active Session View

    private var activeSessionView: some View {
        ZStack {
            VStack(spacing: 0) {
                // Top: Session type badge + distraction indicator
                HStack {
                    sessionTypeBadge
                    Spacer()
                    if engine.distractionCount > 0 {
                        distractionBadge
                    }
                }
                .padding(.horizontal, KairoTheme.Spacing.md)
                .padding(.top, KairoTheme.Spacing.lg)
                .opacity(zenMode && !zenPeek ? 0 : 1)

                Spacer()

                // Center: Timer ring — fully hidden in zen mode
                timerRingSection
                    .opacity(zenMode && !zenPeek ? 0 : 1.0)

                Spacer()

                // Mini sound bar
                if soundManager.selectedSound != .silence {
                    miniSoundBar
                        .padding(.horizontal, KairoTheme.Spacing.lg)
                        .padding(.bottom, KairoTheme.Spacing.md)
                        .opacity(zenMode && !zenPeek ? 0 : 1)
                }

                // Controls
                sessionControls
                    .padding(.bottom, KairoTheme.Spacing.xxl)
                    .opacity(zenMode && !zenPeek ? 0 : 1)
            }

            // Zen mode dark overlay — fully opaque so nothing bleeds through
            if zenMode && !zenPeek {
                Color.black
                    .ignoresSafeArea()
                    .allowsHitTesting(true)
                    .onTapGesture {
                        // Peek: briefly show full UI
                        withAnimation(.easeOut(duration: 0.3)) {
                            zenPeek = true
                        }
                        // Auto-dim again after 3 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            if coordinator.phase == .focusing {
                                withAnimation(.easeIn(duration: 1.0)) {
                                    zenPeek = false
                                }
                            }
                        }
                    }

                // Faint centered timer on top of the dark overlay
                VStack(spacing: KairoTheme.Spacing.xs) {
                    Text(engine.remainingDisplay)
                        .font(KairoTypography.timerDisplay)
                        .foregroundColor(.white.opacity(0.15))
                        .monospacedDigit()
                        .contentTransition(.numericText())

                    Text("tap to peek")
                        .font(KairoTypography.caption)
                        .foregroundColor(.white.opacity(0.08))
                }
                .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 1.5), value: zenMode)
        .animation(.easeInOut(duration: 0.5), value: zenPeek)
        .onAppear {
            // Activate zen mode if we appear while already focusing
            // (e.g. tab switch from Home after quick-start)
            if coordinator.phase == .focusing && !zenMode {
                scheduleZenMode()
            }
        }
        .onChange(of: coordinator.phase) { _, newPhase in
            if newPhase == .focusing {
                scheduleZenMode()
            } else {
                // Exit zen mode when not focusing
                zenMode = false
                zenPeek = false
            }
        }
        .onChange(of: coordinator.showDistractionOverlay) { _, showOverlay in
            if !showOverlay && coordinator.phase == .focusing {
                // Re-enter zen mode after dismissing Focus Shield
                scheduleZenMode()
            }
        }
    }

    // MARK: - Session Type Badge

    private var sessionTypeBadge: some View {
        HStack(spacing: KairoTheme.Spacing.xs) {
            Image(systemName: coordinator.selectedSessionType.iconName)
                .font(.system(size: 14, weight: .semibold))

            Text(coordinator.selectedSessionType.displayName)
                .font(KairoTypography.label)

            Text("·")
                .foregroundColor(KairoColors.mutedAdaptive)

            Text(coordinator.phase == .paused ? "Paused" : "Focusing")
                .font(KairoTypography.label)
                .foregroundColor(
                    coordinator.phase == .paused
                        ? KairoColors.warningAdaptive
                        : KairoColors.successAdaptive
                )
        }
        .foregroundColor(coordinator.selectedSessionType.color)
        .padding(.horizontal, KairoTheme.Spacing.md)
        .padding(.vertical, KairoTheme.Spacing.xs)
        .background(
            Capsule()
                .fill(coordinator.selectedSessionType.color.opacity(0.12))
        )
    }

    // MARK: - Distraction Badge

    private var distractionBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))

            Text("\(engine.distractionCount)")
                .font(KairoTypography.labelSmall)
        }
        .foregroundColor(KairoColors.warningAdaptive)
        .padding(.horizontal, KairoTheme.Spacing.sm)
        .padding(.vertical, KairoTheme.Spacing.xxs)
        .background(
            Capsule()
                .fill(KairoColors.warningAdaptive.opacity(0.12))
        )
    }

    // MARK: - Timer Ring Section

    private var timerRingSection: some View {
        ZStack {
            ProgressRing(
                progress: engine.progress,
                fillColor: ringColor
            )
            .frame(
                width: KairoTheme.TimerRing.size,
                height: KairoTheme.TimerRing.size
            )
            .scaleEffect(ringScale)

            VStack(spacing: KairoTheme.Spacing.xxs) {
                Text(engine.remainingDisplay)
                    .font(KairoTypography.timerDisplay)
                    .foregroundColor(KairoColors.primaryAdaptive)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.linear(duration: 0.1), value: engine.remainingDisplay)

                if coordinator.phase == .paused {
                    Text("PAUSED")
                        .font(KairoTypography.labelSmall)
                        .foregroundColor(KairoColors.warningAdaptive)
                        .tracking(2)
                }
            }
        }
        .scaleEffect(breathePulse ? 1.01 : 1.0)
        .animation(
            coordinator.phase == .focusing
                ? .easeInOut(duration: 4).repeatForever(autoreverses: true)
                : .default,
            value: breathePulse
        )
        .onAppear {
            if coordinator.phase == .focusing {
                breathePulse = true
            }
        }
        .onChange(of: coordinator.phase) { _, newPhase in
            breathePulse = (newPhase == .focusing)
        }
    }

    // MARK: - Mini Sound Bar

    private var miniSoundBar: some View {
        Button(action: {
            coordinator.showSoundPicker = true
        }) {
            HStack(spacing: KairoTheme.Spacing.xs) {
                Image(systemName: soundManager.selectedSound.iconName)
                    .font(.system(size: 14))
                    .foregroundColor(soundManager.selectedSound.color)

                Text(soundManager.selectedSound.displayName)
                    .font(KairoTypography.caption)
                    .foregroundColor(KairoColors.mutedAdaptive)

                Spacer()

                // Volume indicator
                Image(systemName: volumeIcon)
                    .font(.system(size: 12))
                    .foregroundColor(KairoColors.mutedAdaptive)
            }
            .padding(.horizontal, KairoTheme.Spacing.md)
            .padding(.vertical, KairoTheme.Spacing.xs)
            .background(
                Capsule()
                    .fill(KairoColors.surfaceAdaptive)
            )
        }
        .buttonStyle(.plain)
    }

    private var volumeIcon: String {
        if soundManager.volume <= 0 { return "speaker.slash.fill" }
        if soundManager.volume < 0.33 { return "speaker.fill" }
        if soundManager.volume < 0.66 { return "speaker.wave.1.fill" }
        return "speaker.wave.2.fill"
    }

    // MARK: - Session Controls

    private var sessionControls: some View {
        Group {
            if coordinator.phase == .focusing {
                focusingControls
            } else if coordinator.phase == .paused {
                pausedControls
            }
        }
    }

    private var focusingControls: some View {
        HStack(spacing: KairoTheme.Spacing.xl) {
            controlButton(
                icon: "stop.fill",
                label: "Stop",
                color: KairoColors.mutedAdaptive,
                action: { coordinator.stopSession() }
            )

            controlButton(
                icon: "pause.fill",
                label: "Pause",
                color: coordinator.selectedSessionType.color,
                isPrimary: true,
                action: { coordinator.pauseSession() }
            )
        }
    }

    private var pausedControls: some View {
        HStack(spacing: KairoTheme.Spacing.xl) {
            controlButton(
                icon: "stop.fill",
                label: "Stop",
                color: KairoColors.mutedAdaptive,
                action: { coordinator.stopSession() }
            )

            controlButton(
                icon: "play.fill",
                label: "Resume",
                color: coordinator.selectedSessionType.color,
                isPrimary: true,
                action: { coordinator.resumeSession() }
            )
        }
    }

    // MARK: - Control Button

    private func controlButton(
        icon: String,
        label: String,
        color: Color,
        isPrimary: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: KairoTheme.Spacing.xs) {
                ZStack {
                    Circle()
                        .fill(isPrimary ? color : color.opacity(0.12))
                        .frame(width: 64, height: 64)
                        .shadow(
                            color: isPrimary ? color.opacity(0.3) : .clear,
                            radius: isPrimary ? 8 : 0,
                            y: isPrimary ? 2 : 0
                        )

                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(isPrimary ? .white : color)
                }

                Text(label)
                    .font(KairoTypography.caption)
                    .foregroundColor(KairoColors.mutedAdaptive)
            }
        }
    }

    // MARK: - Break View

    private var breakView: some View {
        VStack(spacing: KairoTheme.Spacing.lg) {
            Spacer()

            // Break icon
            ZStack {
                Circle()
                    .fill(KairoColors.successAdaptive.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(KairoColors.successAdaptive)
            }

            Text("Break Time")
                .font(KairoTypography.heading1)
                .foregroundColor(KairoColors.primaryAdaptive)

            if let breakState = coordinator.breakState {
                // Break countdown
                Text(breakState.remainingDisplay)
                    .font(KairoTypography.timerDisplay)
                    .foregroundColor(KairoColors.successAdaptive)
                    .monospacedDigit()
                    .contentTransition(.numericText())

                // Session counter
                Text("Session \(breakState.sessionNumber) of \(KairoTheme.SessionPreset.longBreakInterval) complete")
                    .font(KairoTypography.body)
                    .foregroundColor(KairoColors.mutedAdaptive)

                // Break progress ring (small)
                ProgressRing(
                    progress: breakState.progress,
                    lineWidth: 6,
                    fillColor: KairoColors.successAdaptive,
                    glowEnabled: false
                )
                .frame(width: 60, height: 60)
            }

            Spacer()

            // Skip break button
            VStack(spacing: KairoTheme.Spacing.sm) {
                Button(action: {
                    coordinator.startNextSessionInBlock()
                }) {
                    Label("Start Next Session", systemImage: "play.fill")
                        .font(KairoTypography.heading3)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, KairoTheme.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: KairoTheme.Radius.large)
                                .fill(coordinator.selectedSessionType.color)
                        )
                }

                Button(action: {
                    coordinator.endBreak()
                    coordinator.resetBlock()
                }) {
                    Text("I'm Done for Now")
                        .font(KairoTypography.bodyLarge)
                        .foregroundColor(KairoColors.mutedAdaptive)
                }
            }
            .padding(.horizontal, KairoTheme.Spacing.lg)
            .padding(.bottom, KairoTheme.Spacing.xxl)
        }
    }

    // MARK: - Completion Overlay

    private func completionOverlay(session: FocusSession) -> some View {
        SessionCompletionView(
            session: session,
            onStartBreak: {
                let quality = FocusQuality(rating: session.qualityRating) ?? .medium
                coordinator.startBreak(quality: quality)
            },
            onStartAnother: {
                coordinator.resetToIdle()
                coordinator.startSession()
            },
            onDone: {
                coordinator.resetToIdle()
                coordinator.resetBlock()
            }
        )
    }

    // MARK: - Focus Shield (Distraction Overlay)

    private var distractionOverlay: some View {
        let awaySeconds = Int(coordinator.lastAwayDuration)
        let penalty = min(awaySeconds / 10, 15) // 1% per 10 seconds, max 15%

        return ZStack {
            Color.black
                .ignoresSafeArea(.all)

            ScrollView(showsIndicators: false) {
                VStack(spacing: KairoTheme.Spacing.md) {
                    Spacer().frame(height: 60)

                    // Warning icon
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.12))
                            .frame(width: 110, height: 110)

                        Image(systemName: "shield.slash.fill")
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(.red.opacity(0.9))
                    }

                    Text("Focus Broken")
                        .font(KairoTypography.heading1)
                        .foregroundColor(.white)

                    // Away duration
                    VStack(spacing: KairoTheme.Spacing.xxs) {
                        Text("You were away for")
                            .font(KairoTypography.body)
                            .foregroundColor(.white.opacity(0.6))

                        Text(awaySeconds < 60 ? "\(awaySeconds)s" : "\(awaySeconds / 60)m \(awaySeconds % 60)s")
                            .font(KairoTypography.timerDisplay)
                            .foregroundColor(.red.opacity(0.9))
                            .monospacedDigit()
                    }

                    // Penalty info
                    if penalty > 0 {
                        HStack(spacing: KairoTheme.Spacing.xs) {
                            Image(systemName: "arrow.down.right")
                                .font(.system(size: 14, weight: .bold))
                            Text("-\(penalty)% focus score")
                                .font(KairoTypography.label)
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal, KairoTheme.Spacing.md)
                        .padding(.vertical, KairoTheme.Spacing.xs)
                        .background(
                            Capsule().fill(Color.orange.opacity(0.12))
                        )
                    }

                    // Distraction count
                    if engine.distractionCount > 1 {
                        Text("Distraction #\(engine.distractionCount) this session")
                            .font(KairoTypography.caption)
                            .foregroundColor(.white.opacity(0.4))
                    }

                    Spacer().frame(height: KairoTheme.Spacing.xl)

                    // Motivational message — fixed height, no layout competition
                    Text(focusShieldMessage(distractionCount: engine.distractionCount))
                        .font(KairoTypography.bodySmall)
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, KairoTheme.Spacing.lg)

                    Spacer().frame(height: KairoTheme.Spacing.md)

                    // Return button
                    Button(action: {
                        coordinator.dismissDistractionOverlay()
                    }) {
                        HStack(spacing: KairoTheme.Spacing.xs) {
                            Image(systemName: "shield.checkered")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Recommit to Focus")
                                .font(KairoTypography.heading3)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, KairoTheme.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: KairoTheme.Radius.large)
                                .fill(coordinator.selectedSessionType.color)
                        )
                    }

                    // Give up option
                    Button(action: {
                        coordinator.dismissDistractionOverlay()
                        coordinator.stopSession()
                    }) {
                        Text("End Session")
                            .font(KairoTypography.bodySmall)
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(.bottom, 100)
                }
                .padding(.horizontal, KairoTheme.Spacing.xl)
                .frame(minHeight: UIScreen.main.bounds.height)
            }
        }
        .ignoresSafeArea(.all)
    }

    /// Rotating motivational messages for the focus shield.
    private func focusShieldMessage(distractionCount: Int) -> String {
        let messages: [String]
        if distractionCount <= 1 {
            messages = [
                "Every time you resist checking your phone, your focus muscle gets stronger.",
                "The urge to check passes in 10 seconds. You're stronger than the impulse.",
                "Instagram will still be there after your session. Your focus won't wait."
            ]
        } else if distractionCount <= 3 {
            messages = [
                "Multiple distractions compound. Each one costs more than the last.",
                "Your brain needs 23 minutes to refocus after a distraction. Protect your time.",
                "Notifications are other people's priorities. This session is yours."
            ]
        } else {
            messages = [
                "Consider starting fresh with a shorter session you can fully commit to.",
                "Struggling today? Try a 10-minute session. Completion beats duration.",
                "Put your phone face-down after pressing this button. Trust the process."
            ]
        }
        return messages.randomElement() ?? messages[0]
    }

    // MARK: - Custom Duration Picker

    private var customDurationPicker: some View {
        NavigationStack {
            VStack(spacing: KairoTheme.Spacing.lg) {
                Text("Custom Duration")
                    .font(KairoTypography.heading2)
                    .foregroundColor(KairoColors.primaryAdaptive)

                Picker("Minutes", selection: $customMinutes) {
                    ForEach(Array(stride(from: 5, through: 120, by: 5)), id: \.self) { minutes in
                        Text("\(minutes) min").tag(minutes)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 200)

                Button(action: {
                    coordinator.selectedDurationMinutes = customMinutes
                    customDurationSheet = false
                }) {
                    Text("Set \(customMinutes) Minutes")
                        .font(KairoTypography.heading3)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, KairoTheme.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: KairoTheme.Radius.large)
                                .fill(coordinator.selectedSessionType.color)
                        )
                }
                .padding(.horizontal, KairoTheme.Spacing.lg)
            }
            .padding(.vertical, KairoTheme.Spacing.lg)
            .background(KairoColors.backgroundAdaptive)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        customDurationSheet = false
                    }
                    .foregroundColor(KairoColors.accentAdaptive)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Computed Helpers

    private var ringColor: Color {
        switch coordinator.phase {
        case .paused:    return KairoColors.warningAdaptive
        case .preparing: return KairoColors.mutedAdaptive
        default:         return coordinator.selectedSessionType.color
        }
    }

    // MARK: - Zen Mode Scheduling

    /// Schedules zen mode activation after a short delay.
    /// Safe to call multiple times — checks phase before activating.
    private func scheduleZenMode() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if coordinator.phase == .focusing && !coordinator.showDistractionOverlay {
                withAnimation(.easeIn(duration: 1.5)) {
                    zenMode = true
                    zenPeek = false
                }
            }
        }
    }

    // MARK: - Phase Animations

    private func handlePhaseAnimation(_ phase: SessionPhase) {
        switch phase {
        case .focusing:
            withAnimation(KairoTheme.Animation.sessionStart) {
                ringScale = 1.0
            }
        case .preparing:
            withAnimation(KairoTheme.Animation.sessionStart) {
                ringScale = 0.92
            }
        case .paused:
            withAnimation(KairoTheme.Animation.timerPulse) {
                ringScale = 0.97
            }
        case .idle:
            showControls = false
            withAnimation(KairoTheme.Animation.standard.delay(0.2)) {
                showControls = true
            }
        default:
            ringScale = 1.0
        }
    }
}

// MARK: - Preview

#Preview("Focus Session — Idle") {
    let engine = FocusEngine(context: PersistenceController.preview.container.viewContext)
    let coordinator = SessionCoordinator(
        focusEngine: engine,
        soundManager: SoundManager.shared,
        distractionDetector: DistractionDetector(),
        hapticEngine: HapticEngine(),
        notificationManager: NotificationManager.shared,
        ruleEngine: RuleEngine(),
        insightGenerator: InsightGenerator(),
        widgetDataProvider: WidgetDataProvider(),
        persistenceController: PersistenceController.preview
    )

    FocusSessionView()
        .environmentObject(coordinator)
        .environmentObject(engine)
        .environmentObject(SoundManager.shared)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
