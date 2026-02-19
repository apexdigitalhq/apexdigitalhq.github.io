import SwiftUI

/// Root view — routes between onboarding and main app.
///
/// Shows `OnboardingView` on first launch, then transitions
/// to `MainTabView` once onboarding is completed.
struct ContentView: View {

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        Group {
            if hasSeenOnboarding {
                MainTabView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(KairoTheme.Animation.sessionStart, value: hasSeenOnboarding)
    }
}

// MARK: - Preview

#Preview("Content View — First Launch") {
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

    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(SubscriptionManager())
        .environmentObject(coordinator)
        .environmentObject(engine)
        .environmentObject(SoundManager.shared)
        .onAppear {
            UserDefaults.standard.set(false, forKey: "hasSeenOnboarding")
        }
}

#Preview("Content View — Returning User") {
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

    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(SubscriptionManager())
        .environmentObject(coordinator)
        .environmentObject(engine)
        .environmentObject(SoundManager.shared)
        .onAppear {
            UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        }
}
