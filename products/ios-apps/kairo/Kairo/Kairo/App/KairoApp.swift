import SwiftUI
import CoreData
import UserNotifications

/// Kairo app entry point — initializes all subsystems and wires dependency injection.
///
/// Every manager is created once in `init()` and shared between the
/// `SessionCoordinator` and the SwiftUI environment. Singletons
/// (`SoundManager.shared`, `NotificationManager.shared`) are referenced
/// directly. Handles first-launch setup, notification registration,
/// and widget data updates on scene phase transitions.
@main
struct KairoApp: App {

    // MARK: - App Delegate

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // MARK: - Core Data

    private let persistenceController = PersistenceController.shared

    // MARK: - Shared Managers

    /// All managers are created in `init()` and injected via `@StateObject`.
    /// The coordinator receives the same instances so everything stays in sync.
    @StateObject private var focusEngine: FocusEngine
    @StateObject private var distractionDetector: DistractionDetector
    @StateObject private var hapticEngine: HapticEngine
    @StateObject private var ruleEngine: RuleEngine
    @StateObject private var patternAnalyzer: FocusPatternAnalyzer
    @StateObject private var insightGenerator: InsightGenerator
    @StateObject private var subscriptionManager: SubscriptionManager
    @StateObject private var sessionCoordinator: SessionCoordinator

    // MARK: - Singleton References

    /// SoundManager and NotificationManager have `private init()` singletons.
    /// Injected as `@ObservedObject`-compatible environment objects.
    private let soundManager = SoundManager.shared
    private let notificationManager = NotificationManager.shared

    /// WidgetDataProvider is a plain class (no ObservableObject) — held by ref.
    private let widgetDataProvider = WidgetDataProvider()

    // MARK: - Scene Phase

    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Init

    init() {
        let context = PersistenceController.shared.container.viewContext

        // Create all shared instances once
        let engine = FocusEngine(context: context)
        let detector = DistractionDetector()
        let haptics = HapticEngine()
        let rules = RuleEngine()
        let analyzer = FocusPatternAnalyzer()
        let insights = InsightGenerator()
        let subscriptions = SubscriptionManager()

        // Build coordinator with the same shared instances
        let coordinator = SessionCoordinator(
            focusEngine: engine,
            soundManager: SoundManager.shared,
            distractionDetector: detector,
            hapticEngine: haptics,
            notificationManager: NotificationManager.shared,
            ruleEngine: rules,
            insightGenerator: insights,
            widgetDataProvider: WidgetDataProvider(),
            persistenceController: PersistenceController.shared
        )

        // Wire StateObjects
        _focusEngine = StateObject(wrappedValue: engine)
        _distractionDetector = StateObject(wrappedValue: detector)
        _hapticEngine = StateObject(wrappedValue: haptics)
        _ruleEngine = StateObject(wrappedValue: rules)
        _patternAnalyzer = StateObject(wrappedValue: analyzer)
        _insightGenerator = StateObject(wrappedValue: insights)
        _subscriptionManager = StateObject(wrappedValue: subscriptions)
        _sessionCoordinator = StateObject(wrappedValue: coordinator)
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(focusEngine)
                .environmentObject(soundManager)
                .environmentObject(notificationManager)
                .environmentObject(distractionDetector)
                .environmentObject(hapticEngine)
                .environmentObject(ruleEngine)
                .environmentObject(patternAnalyzer)
                .environmentObject(insightGenerator)
                .environmentObject(subscriptionManager)
                .environmentObject(sessionCoordinator)
                .onAppear {
                    performFirstLaunchSetup()
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
    }

    // MARK: - First Launch

    /// Runs once on every app launch: registers notification categories,
    /// records install date, prepares haptics, and requests notification
    /// permission if this is the first time.
    private func performFirstLaunchSetup() {
        notificationManager.registerCategories()
        recordInstallDateIfNeeded()
        hapticEngine.prepare()

        Task {
            await notificationManager.requestPermissionIfNeeded()
        }
    }

    /// Records the install date on very first launch for reverse trial tracking.
    private func recordInstallDateIfNeeded() {
        let key = "kairo_install_date"
        if UserDefaults.standard.object(forKey: key) == nil {
            UserDefaults.standard.set(Date(), forKey: key)
        }
    }

    // MARK: - Scene Phase

    /// Updates widget data when the app transitions between foreground/background.
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            Task { await notificationManager.refreshAuthorizationStatus() }
            notificationManager.clearDelivered()

        case .background:
            updateWidgetData()
            persistenceController.save()

        case .inactive:
            break

        @unknown default:
            break
        }
    }

    // MARK: - Deep Links

    /// Handles deep links from widgets and notifications.
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "kairo" else { return }

        switch url.host {
        case "start":
            // Start a focus session from widget tap
            if sessionCoordinator.phase == .idle {
                sessionCoordinator.startSession()
            }
        default:
            break
        }
    }

    /// Collects today's metrics and pushes them to the widget extension
    /// via the shared app group UserDefaults.
    private func updateWidgetData() {
        let context = persistenceController.container.viewContext
        let sessionStore = SessionStore(context: context)
        let todaySessions = sessionStore.fetchToday()
        let completed = todaySessions.filter { $0.isCompleted }

        let totalMinutes = completed.reduce(0) { $0 + Int($1.actualDuration) / 60 }
        let avgScore = completed.isEmpty
            ? 0
            : Int(completed.reduce(Float(0)) { $0 + $1.focusScore } / Float(completed.count))
        let bestHour = completed.isEmpty
            ? nil
            : completed.max(by: { $0.focusScore < $1.focusScore })?.startedAt.hour

        let streakRequest = FocusStreak.fetchRequest()
        streakRequest.predicate = NSPredicate(format: "isActive == YES")
        streakRequest.fetchLimit = 1
        let streak = (try? context.fetch(streakRequest))?.first
        let streakDays = Int(streak?.currentLength ?? 0)

        widgetDataProvider.updateFocusData(
            totalMinutes: totalMinutes,
            score: avgScore,
            sessions: completed.count,
            streak: streakDays,
            bestHour: bestHour
        )

        // Streak widget data — last 7 days completion flags
        let last7Days = Date.lastDays(7).map { day in
            let dayStart = day.startOfDay
            let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!
            return sessionStore.fetchSessions(from: dayStart, to: dayEnd)
                .contains { $0.isCompleted }
        }

        widgetDataProvider.updateStreakData(
            current: streakDays,
            longest: Int(streak?.longestLength ?? 0),
            last7Days: last7Days
        )
    }
}
