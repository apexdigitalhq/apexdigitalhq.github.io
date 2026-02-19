import SwiftUI

/// Full-screen Focus Shield overlay shown when the user leaves the app during a focus session.
///
/// Rendered at the MainTabView level (above the TabView) so it covers the tab bar completely.
struct FocusShieldOverlay: View {

    @EnvironmentObject private var coordinator: SessionCoordinator
    @EnvironmentObject private var engine: FocusEngine

    /// Cached motivational message — set once on appear, never re-computed.
    @State private var motivationalMessage: String = ""

    var body: some View {
        let awaySeconds = Int(coordinator.lastAwayDuration)
        let penalty = min(awaySeconds / 10, 15)

        ZStack {
            Color.black
                .ignoresSafeArea(.all)

            VStack(spacing: KairoTheme.Spacing.md) {
                Spacer()

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

                Spacer()

                // Motivational message — cached, no animation
                Text(motivationalMessage)
                    .font(KairoTypography.bodySmall)
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, KairoTheme.Spacing.lg)
                    .animation(nil, value: motivationalMessage)
                    .drawingGroup()

                Spacer().frame(height: KairoTheme.Spacing.sm)

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
                .padding(.bottom, KairoTheme.Spacing.xxl)
            }
            .padding(.horizontal, KairoTheme.Spacing.xl)
        }
        .ignoresSafeArea(.all)
        .animation(nil, value: coordinator.showDistractionOverlay)
        .onAppear {
            // Set message once — prevents flickering from randomElement on re-renders
            motivationalMessage = focusShieldMessage(distractionCount: engine.distractionCount)
        }
    }

    // MARK: - Messages

    private func focusShieldMessage(distractionCount: Int) -> String {
        let messages: [String]
        if distractionCount <= 1 {
            messages = [
                "Every time you resist checking your phone, your focus muscle gets stronger.",
                "The urge to check passes in 10 seconds. You're stronger than the impulse.",
                "Instagram will still be there. Your goals won't wait.",
                "Your future self is counting on this moment right now.",
                "Deep work is a superpower. You're building it right now.",
                "One focused hour beats five distracted hours. Keep going.",
                "You chose to focus. That decision alone sets you apart.",
                "The best ideas come when you give your brain space to think.",
                "Discipline is choosing between what you want now and what you want most.",
                "This session is an investment in yourself. Don't sell it short.",
                "Every second here compounds. Every second scrolling doesn't.",
                "Nobody ever regretted a completed focus session. Not once.",
                "Your phone has infinite patience. It will wait for you.",
                "The people you admire? They sat through this discomfort too.",
                "You're not missing anything out there. You're building something in here.",
                "Scrolling is borrowing happiness from tomorrow. Focus is investing it.",
                "That app was designed to steal your attention. Don't let it win.",
                "Right now, you're in the top 1% of people who actually commit.",
                "10 minutes of deep focus > 2 hours of half-attention. Stay locked in.",
                "Your brain is literally rewiring for excellence right now. Let it.",
                "The discomfort you feel? That's growth. Lean into it.",
                "You didn't open this app to quit. You opened it to win.",
                "Atomic focus today. Atomic results tomorrow.",
                "The world rewards the focused. Be unreasonably focused.",
                "This moment is the gap between who you are and who you want to be.",
                "Distraction is easy. That's exactly why focus is valuable.",
                "What you do in the next 5 minutes defines your next 5 years.",
                "Your attention is the most valuable currency you own. Spend it wisely.",
                "Champions aren't built in comfort. They're built in moments like this.",
                "You are one uninterrupted session away from a breakthrough."
            ]
        } else if distractionCount <= 3 {
            messages = [
                "Multiple distractions compound. Each one costs more than the last.",
                "Your brain needs 23 minutes to refocus after a distraction. Protect your time.",
                "Notifications are other people's priorities. This session is yours.",
                "Every distraction is a choice. Choose yourself right now.",
                "You're closer to the end than the beginning. Push through.",
                "Imagine how good you'll feel when this session is complete.",
                "The phone is a tool, not a leash. You control it.",
                "Boredom is your brain's signal that deep focus is about to begin.",
                "Winners aren't distracted. They're locked in. Like you, right now.",
                "That notification? It can wait. Your growth can't.",
                "You've already proven you can start. Now prove you can finish.",
                "Second chances are rare. This is yours. Take it seriously.",
                "Each time you come back, you're training your willpower. It's working.",
                "Think of this as a rep at the gym. The hard ones build the most muscle.",
                "The difference between good and great? Not checking your phone.",
                "Plot twist: nothing happened on social media in the last 3 minutes.",
                "Your competitors aren't checking their phones right now. Neither should you.",
                "Two distractions down. Zero more to go. Lock in.",
                "Fun fact: the average person wastes 2.5 hours daily on their phone. Not you.",
                "Mediocrity is comfortable. Excellence requires exactly this kind of discomfort.",
                "You're stronger than an algorithm designed to hook you. Prove it.",
                "Ask yourself: will checking that app move your life forward? Thought so.",
                "Every comeback starts with a decision. This is yours.",
                "You're not behind. You're building. Stay in construction mode.",
                "The next 10 minutes are a gift to future you. Don't unwrap it early.",
                "Distractions are tests. You're about to pass this one.",
                "Refocusing after a slip takes more strength than never slipping. Respect.",
                "Your focus session is a promise to yourself. Keep your word.",
                "Nobody built anything great between app switches. Go deep.",
                "Imagine explaining to your future self why you quit. Uncomfortable, right?"
            ]
        } else {
            messages = [
                "Consider starting fresh with a shorter session you can fully commit to.",
                "Struggling today? Try a 10-minute session. Completion beats duration.",
                "Put your phone face-down after pressing this button. Trust the process.",
                "Bad sessions still build the habit. You showed up — that matters.",
                "Even professional athletes have off days. Reset and refocus.",
                "Progress isn't linear. What matters is you're still here trying.",
                "Take three deep breaths. Then recommit for just 5 more minutes.",
                "Every master was once a disaster. Consistency wins over perfection.",
                "Your brain is rewiring right now. Resistance means it's working.",
                "Tough sessions build mental toughness. This is the training.",
                "Honestly? The fact that you keep coming back says everything about you.",
                "Lower the bar, raise the consistency. Try 5 minutes of pure focus.",
                "Turn on Do Not Disturb. Remove the temptation. Then try again.",
                "Some days the win is just not quitting entirely. Today might be that day.",
                "Move your phone to another room. Seriously. Then press the button.",
                "You're fighting millions of dollars of attention engineering. Be patient with yourself.",
                "The streak doesn't matter. The habit does. You're building it right now.",
                "Coffee break? Stretch? Sometimes a reset is the smartest strategy.",
                "Thomas Edison failed 10,000 times. You've been distracted like 4 times. Relax.",
                "Here's a secret: starting over is not failure. Giving up is.",
                "Try the Pomodoro trick — just 5 more minutes, then reassess.",
                "Your willpower is a muscle. It's tired today, but it's getting stronger.",
                "Airplane mode exists for a reason. This is that reason.",
                "Real talk: you're still here. Most people would've quit by now.",
                "The best time to build focus was yesterday. The second best time is now.",
                "Grace > guilt. Be kind to yourself, then get back to it.",
                "What if this session is the one that changes everything? Don't leave now.",
                "Rough session? Tomorrow you'll barely remember it. But the habit will remain.",
                "You're not failing. You're practicing. And practice makes permanent.",
                "Close your eyes. Take one breath. Open them. Now finish what you started."
            ]
        }
        return messages.randomElement() ?? messages[0]
    }
}
