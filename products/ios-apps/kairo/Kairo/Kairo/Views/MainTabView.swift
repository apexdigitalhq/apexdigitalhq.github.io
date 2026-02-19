import SwiftUI
import CoreData

// MARK: - MainTabView

/// Root tab navigation for Kairo with 4 tabs: Home, Focus, Stats, Settings.
///
/// Home is the default landing tab — a CEO-briefing dashboard.
/// History has been folded into the Stats/Home views.
/// Custom tab bar styling uses KairoColors with a streak badge on the Home tab.
struct MainTabView: View {

    @State private var selectedTab: Tab = .home
    @EnvironmentObject private var coordinator: SessionCoordinator
    @Environment(\.managedObjectContext) private var viewContext

    // Fetch active streak for badge display
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \FocusStreak.lastActiveDate, ascending: false)],
        predicate: NSPredicate(format: "isActive == YES"),
        animation: .default
    )
    private var activeStreaks: FetchedResults<FocusStreak>

    // MARK: - Tab Definition

    /// The four primary navigation destinations.
    enum Tab: String, CaseIterable {
        case home     = "Home"
        case focus    = "Focus"
        case schedule = "Schedule"
        case stats    = "Stats"
        case settings = "Settings"

        /// Default SF Symbol for the tab.
        var icon: String {
            switch self {
            case .home:     return "house.fill"
            case .focus:    return "timer"
            case .schedule: return "calendar"
            case .stats:    return "chart.bar.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }

    // MARK: - Streak Badge

    /// Current active streak length (0 if none or expired).
    private var currentStreakDays: Int {
        guard let streak = activeStreaks.first,
              streak.isCurrentlyValid else {
            return 0
        }
        return Int(streak.currentLength)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                // Home Tab — dashboard
                HomeView()
                    .tabItem {
                        Label(Tab.home.rawValue, systemImage: Tab.home.icon)
                    }
                    .tag(Tab.home)
                    .badge(currentStreakDays > 0 ? "\(currentStreakDays)🔥" : nil)

                // Focus Tab — session screen
                FocusSessionView()
                    .tabItem {
                        Label(Tab.focus.rawValue, systemImage: Tab.focus.icon)
                    }
                    .tag(Tab.focus)

                // Schedule Tab — in-app calendar
                KairoCalendarView()
                    .tabItem {
                        Label(Tab.schedule.rawValue, systemImage: Tab.schedule.icon)
                    }
                    .tag(Tab.schedule)

                // Stats Tab — weekly overview + history
                StatsView()
                    .tabItem {
                        Label(Tab.stats.rawValue, systemImage: Tab.stats.icon)
                    }
                    .tag(Tab.stats)

                // Settings Tab
                SettingsView()
                    .tabItem {
                        Label(Tab.settings.rawValue, systemImage: Tab.settings.icon)
                    }
                    .tag(Tab.settings)
            }
            .tint(KairoColors.accentAdaptive)
            .onChange(of: coordinator.phase) { _, newPhase in
                if newPhase == .preparing || newPhase == .focusing {
                    selectedTab = .focus
                }
            }
            .onAppear {
                configureTabBarAppearance()
            }

            // Focus Shield overlay — rendered ABOVE TabView to cover the tab bar
            if coordinator.showDistractionOverlay {
                FocusShieldOverlay()
                    .environmentObject(coordinator)
                    .zIndex(999)
            }
        }
    }

    // MARK: - Tab Bar Styling

    /// Applies KairoColors to the UITabBar appearance for a cohesive look.
    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        // Background — frosted surface
        appearance.backgroundColor = UIColor(KairoColors.surfaceAdaptive.opacity(0.95))
        appearance.backgroundEffect = UIBlurEffect(style: .systemThinMaterial)

        // Selected item attributes
        let selectedAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: UIColor(KairoColors.accentAdaptive)
        ]

        // Normal (unselected) item attributes
        let normalAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: UIColor(KairoColors.mutedAdaptive)
        ]

        // Apply to all layout styles
        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.selected.titleTextAttributes = selectedAttributes
        itemAppearance.selected.iconColor = UIColor(KairoColors.accentAdaptive)
        itemAppearance.normal.titleTextAttributes = normalAttributes
        itemAppearance.normal.iconColor = UIColor(KairoColors.mutedAdaptive)

        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        // Shadow separator line
        appearance.shadowColor = UIColor(KairoColors.mutedAdaptive.opacity(0.15))

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Previews

#Preview("Main Tabs") {
    let context = PersistenceController.preview.container.viewContext
    let engine = FocusEngine(context: context)
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

    MainTabView()
        .environment(\.managedObjectContext, context)
        .environmentObject(SubscriptionManager())
        .environmentObject(coordinator)
        .environmentObject(engine)
        .environmentObject(SoundManager.shared)
        .environmentObject(NotificationManager.shared)
        .environmentObject(InsightGenerator())
        .environmentObject(FocusPatternAnalyzer())
}

#Preview("Main Tabs — Dark") {
    let context = PersistenceController.preview.container.viewContext
    let engine = FocusEngine(context: context)
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

    MainTabView()
        .environment(\.managedObjectContext, context)
        .environmentObject(SubscriptionManager())
        .environmentObject(coordinator)
        .environmentObject(engine)
        .environmentObject(SoundManager.shared)
        .environmentObject(NotificationManager.shared)
        .environmentObject(InsightGenerator())
        .environmentObject(FocusPatternAnalyzer())
        .preferredColorScheme(.dark)
}
