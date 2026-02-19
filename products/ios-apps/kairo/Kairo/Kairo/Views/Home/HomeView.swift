import SwiftUI
import Charts
import CoreData

// MARK: - HomeView

/// CEO-briefing-style dashboard — the first tab the user sees.
///
/// Surfaces today's focus score, session count, total focus time, current streak,
/// a quick-start action, recent insights, the last 3 sessions, a 7-day bar chart,
/// and a model-readiness progress bar when under 30 completed sessions.
///
/// All data flows from Core Data via `@FetchRequest` and environment objects.
/// Pull-to-refresh recalculates the daily score and refreshes suggestions.
struct HomeView: View {

    // MARK: - Environment

    @EnvironmentObject private var coordinator: SessionCoordinator
    @EnvironmentObject private var insightGenerator: InsightGenerator
    @EnvironmentObject private var patternAnalyzer: FocusPatternAnalyzer
    @Environment(\.managedObjectContext) private var viewContext

    // MARK: - Fetch Requests

    /// Today's completed sessions.
    @FetchRequest private var todaySessions: FetchedResults<FocusSession>

    /// Active streak.
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \FocusStreak.lastActiveDate, ascending: false)],
        predicate: NSPredicate(format: "isActive == YES"),
        animation: .default
    )
    private var activeStreaks: FetchedResults<FocusStreak>

    /// All-time finished session count (for model readiness).
    @FetchRequest(
        sortDescriptors: [],
        predicate: NSPredicate(format: "status == %@ OR status == %@", "completed", "abandoned")
    )
    private var allCompletedSessions: FetchedResults<FocusSession>

    // MARK: - Local State

    @StateObject private var viewModel = HomeViewModel()
    @State private var showGreeting = false
    @State private var selectedTab: Int = 0
    @State private var coachingInsights: [CoachingInsight] = []
    @State private var showProgressDetail = false

    // MARK: - Init

    init() {
        let todayStart = Calendar.current.startOfDay(for: Date())
        let tomorrowStart = Calendar.current.date(byAdding: .day, value: 1, to: todayStart)!

        _todaySessions = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \FocusSession.startedAt, ascending: false)],
            predicate: NSPredicate(
                format: "startedAt >= %@ AND startedAt < %@ AND (status == %@ OR status == %@)",
                todayStart as NSDate,
                tomorrowStart as NSDate,
                "completed",
                "abandoned"
            ),
            animation: .default
        )
    }

    // MARK: - Computed

    /// Current streak day count.
    private var streakDays: Int {
        guard let streak = activeStreaks.first,
              streak.isCurrentlyValid else { return 0 }
        return Int(streak.currentLength)
    }

    /// Total focus minutes today.
    private var todayFocusMinutes: Int {
        todaySessions.reduce(0) { $0 + Int($1.actualDuration) / 60 }
    }

    /// Average focus score for today's sessions.
    private var todayAverageScore: Int {
        guard !todaySessions.isEmpty else { return 0 }
        let total = todaySessions.reduce(Float(0)) { $0 + $1.focusScore }
        return Int(total / Float(todaySessions.count))
    }

    @State private var showAllSessions = false

    /// Sessions to display — 3 by default, up to 10 when expanded.
    private var recentSessions: [FocusSession] {
        let limit = showAllSessions ? 10 : 3
        return Array(todaySessions.prefix(limit))
    }

    /// Model readiness percentage (0.0–1.0).
    private var modelReadiness: Double {
        let count = allCompletedSessions.count
        return min(1.0, Double(count) / 30.0)
    }

    /// Current coaching tier based on session count.
    /// Tier 0: < 10 sessions (learning only)
    /// Tier 1: 10-19 sessions (basic coaching)
    /// Tier 2: 20-29 sessions (intermediate coaching)
    /// Tier 3: 30+ sessions (full AI coach)
    private var coachingTier: Int {
        let count = allCompletedSessions.count
        if count >= 30 { return 3 }
        if count >= 20 { return 2 }
        if count >= 10 { return 1 }
        return 0
    }

    /// Next tier milestone session count.
    private var nextTierTarget: Int {
        switch coachingTier {
        case 0: return 10
        case 1: return 20
        case 2: return 30
        default: return 30
        }
    }

    /// Label for the current coaching tier.
    private var tierLabel: String {
        switch coachingTier {
        case 1: return "Basic Patterns"
        case 2: return "Intermediate Analysis"
        case 3: return "Full AI Coach"
        default: return "Learning"
        }
    }

    /// Whether to show the model readiness bar (always show, but style changes per tier).
    private var showModelReadiness: Bool {
        allCompletedSessions.count < 30
    }

    /// Greeting based on time of day.
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<21: return "Good Evening"
        default:      return "Night Owl Mode"
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: KairoTheme.Spacing.lg) {
                    // Greeting header
                    greetingHeader
                        .padding(.top, KairoTheme.Spacing.sm)

                    // Hero score card
                    heroScoreCard

                    // Quick start section
                    quickStartSection

                    // Today's insights
                    insightsSection

                    // Weekly mini chart
                    weeklyChartSection

                    // Recent sessions
                    recentSessionsSection

                    // Model readiness + progressive coaching (tappable)
                    modelReadinessSection
                        .onTapGesture { showProgressDetail = true }
                        .sheet(isPresented: $showProgressDetail) {
                            PatternProgressView(
                                sessionCount: allCompletedSessions.count,
                                coachingTier: coachingTier,
                                modelReadiness: modelReadiness
                            )
                        }

                    // Show coaching insights from Tier 1+ (10 sessions)
                    if coachingTier >= 1 {
                        focusCoachSection
                    }

                    Spacer().frame(height: KairoTheme.Spacing.xxl)
                }
                .padding(.horizontal, KairoTheme.Spacing.md)
            }
            .background(KairoColors.backgroundAdaptive.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                viewModel.refresh()
                coordinator.refreshSuggestions()
                refreshCoachingInsights()
            }
            .onAppear {
                viewModel.refresh()
                refreshCoachingInsights()
                withAnimation(KairoTheme.Animation.standard.delay(0.1)) {
                    showGreeting = true
                }
            }
        }
    }

    // MARK: - Greeting Header

    private var greetingHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: KairoTheme.Spacing.xxs) {
                Text(greeting)
                    .font(KairoTypography.heading1)
                    .foregroundColor(KairoColors.primaryAdaptive)

                Text(Date(), format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(KairoTypography.body)
                    .foregroundColor(KairoColors.mutedAdaptive)
            }
            .opacity(showGreeting ? 1 : 0)
            .offset(y: showGreeting ? 0 : 8)

            Spacer()

            // Streak badge
            if streakDays > 0 {
                streakPill
            }
        }
    }

    /// Compact streak indicator pill.
    private var streakPill: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 14))
                .foregroundColor(.orange)

            Text("\(streakDays)")
                .font(KairoTypography.label)
                .foregroundColor(.orange)
        }
        .padding(.horizontal, KairoTheme.Spacing.sm)
        .padding(.vertical, KairoTheme.Spacing.xxs)
        .background(
            Capsule()
                .fill(Color.orange.opacity(0.12))
        )
    }

    // MARK: - Hero Score Card

    private var heroScoreCard: some View {
        VStack(spacing: KairoTheme.Spacing.md) {
            // Today's score — big and prominent
            VStack(spacing: KairoTheme.Spacing.xxs) {
                Text("TODAY'S FOCUS SCORE")
                    .font(KairoTypography.labelSmall)
                    .foregroundColor(KairoColors.mutedAdaptive)
                    .tracking(1.5)

                Text("\(todayAverageScore)")
                    .font(KairoTypography.scoreLarge)
                    .foregroundColor(KairoColors.scoreColor(for: Float(todayAverageScore)))
                    .contentTransition(.numericText())

                // Score bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(KairoColors.mutedAdaptive.opacity(0.12))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(KairoColors.scoreColor(for: Float(todayAverageScore)))
                            .frame(
                                width: geo.size.width * CGFloat(todayAverageScore) / 100.0,
                                height: 6
                            )
                            .animation(KairoTheme.Animation.scoreReveal, value: todayAverageScore)
                    }
                }
                .frame(height: 6)
                .padding(.horizontal, KairoTheme.Spacing.xl)
            }

            Divider()
                .foregroundColor(KairoColors.mutedAdaptive.opacity(0.15))

            // Stat row: sessions, time, streak
            HStack(spacing: 0) {
                heroStat(
                    icon: "checkmark.circle.fill",
                    value: "\(todaySessions.count)",
                    label: "Sessions",
                    color: KairoColors.successAdaptive
                )

                heroStatDivider

                heroStat(
                    icon: "clock.fill",
                    value: todayFocusMinutes.minutesDisplay,
                    label: "Focus Time",
                    color: KairoColors.accentAdaptive
                )

                heroStatDivider

                heroStat(
                    icon: "flame.fill",
                    value: "\(streakDays) day\(streakDays == 1 ? "" : "s")",
                    label: "Streak",
                    color: .orange
                )
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

    /// Individual stat column for the hero card.
    private func heroStat(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: KairoTheme.Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)

            Text(value)
                .font(KairoTypography.statValue)
                .foregroundColor(KairoColors.primaryAdaptive)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(label)
                .font(KairoTypography.caption)
                .foregroundColor(KairoColors.mutedAdaptive)
        }
        .frame(maxWidth: .infinity)
    }

    /// Thin vertical divider between hero stats.
    private var heroStatDivider: some View {
        Rectangle()
            .fill(KairoColors.mutedAdaptive.opacity(0.12))
            .frame(width: 1, height: 44)
    }

    // MARK: - Quick Start Section

    private var quickStartSection: some View {
        Button(action: {
            // Small delay lets the tab switch complete before session starts
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                coordinator.startSession()
            }
        }) {
            HStack(spacing: KairoTheme.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(coordinator.selectedSessionType.color.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: "play.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(coordinator.selectedSessionType.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Start Focus Session")
                        .font(KairoTypography.heading3)
                        .foregroundColor(KairoColors.primaryAdaptive)

                    Text("\(coordinator.suggestedDurationMinutes) min · \(coordinator.selectedSessionType.displayName)")
                        .font(KairoTypography.bodySmall)
                        .foregroundColor(KairoColors.mutedAdaptive)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(KairoColors.mutedAdaptive)
            }
            .padding(KairoTheme.Spacing.md)
            .background(KairoColors.surfaceAdaptive)
            .cornerRadius(KairoTheme.Radius.card)
            .shadow(
                color: KairoTheme.Shadow.card.color,
                radius: KairoTheme.Shadow.card.radius,
                y: KairoTheme.Shadow.card.y
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Insights Section

    private var insightsSection: some View {
        let insights = insightGenerator.latestInsights.isEmpty
            ? insightGenerator.starterTips()
            : insightGenerator.latestInsights
        let title = insightGenerator.latestInsights.isEmpty
            ? "Focus Tips"
            : "Today's Insights"

        return VStack(alignment: .leading, spacing: KairoTheme.Spacing.xs) {
            sectionHeader(title: title, icon: "sparkles")

            InsightCarousel(insights: insights)
        }
    }

    // MARK: - Weekly Chart Section

    private var weeklyChartSection: some View {
        VStack(alignment: .leading, spacing: KairoTheme.Spacing.xs) {
            sectionHeader(title: "This Week", icon: "chart.bar.fill")

            weeklyMiniChart
        }
    }

    /// Compact 7-day bar chart built with Swift Charts.
    private var weeklyMiniChart: some View {
        Group {
            if viewModel.weeklyTrend.isEmpty || viewModel.weeklyTrend.allSatisfy({ $0.isEmpty }) {
                chartEmptyState
            } else {
                Chart(viewModel.weeklyTrend) { point in
                    BarMark(
                        x: .value("Day", point.dayLabel),
                        y: .value("Score", point.score)
                    )
                    .foregroundStyle(
                        KairoColors.scoreColor(for: point.score).gradient
                    )
                    .cornerRadius(KairoTheme.Radius.small / 2)
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(KairoColors.mutedAdaptive.opacity(0.2))
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text("\(v)")
                                    .font(KairoTypography.caption)
                                    .foregroundColor(KairoColors.mutedAdaptive)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                Text(label)
                                    .font(KairoTypography.caption)
                                    .foregroundColor(KairoColors.mutedAdaptive)
                            }
                        }
                    }
                }
                .frame(height: 140)
            }
        }
        .padding(KairoTheme.Spacing.md)
        .background(KairoColors.surfaceAdaptive)
        .cornerRadius(KairoTheme.Radius.card)
        .shadow(
            color: KairoTheme.Shadow.card.color,
            radius: KairoTheme.Shadow.card.radius,
            y: KairoTheme.Shadow.card.y
        )
    }

    /// Placeholder when there's no chart data yet.
    private var chartEmptyState: some View {
        VStack(spacing: KairoTheme.Spacing.xs) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 28))
                .foregroundColor(KairoColors.mutedAdaptive.opacity(0.4))

            Text("Complete sessions to see your weekly chart")
                .font(KairoTypography.bodySmall)
                .foregroundColor(KairoColors.mutedAdaptive)
                .multilineTextAlignment(.center)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Recent Sessions Section

    @ViewBuilder
    private var recentSessionsSection: some View {
        if !todaySessions.isEmpty {
            VStack(alignment: .leading, spacing: KairoTheme.Spacing.xs) {
                HStack {
                    sectionHeader(title: "Recent Sessions", icon: "clock.fill")
                    Spacer()
                    if todaySessions.count > 3 {
                        Text("\(todaySessions.count) total")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(KairoColors.mutedAdaptive)
                    }
                }

                VStack(spacing: 0) {
                    ForEach(recentSessions) { session in
                        compactSessionRow(session)

                        if session.id != recentSessions.last?.id {
                            Divider()
                                .padding(.horizontal, 8)
                        }
                    }

                    // Show More / Show Less bar
                    if todaySessions.count > 3 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showAllSessions.toggle()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(showAllSessions ? "Show Less" : "Show More")
                                    .font(.system(size: 13, weight: .semibold))
                                Image(systemName: showAllSessions ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(KairoColors.accentAdaptive)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                KairoColors.accentAdaptive.opacity(0.06)
                            )
                            .cornerRadius(8)
                        }
                        .padding(.top, 6)
                    }
                }
                .padding(KairoTheme.Spacing.md)
                .background(KairoColors.surfaceAdaptive)
                .cornerRadius(KairoTheme.Radius.card)
                .shadow(
                    color: KairoTheme.Shadow.card.color,
                    radius: KairoTheme.Shadow.card.radius,
                    y: KairoTheme.Shadow.card.y
                )
            }
        }
    }

    /// A compact row for a single recent session.
    private func compactSessionRow(_ session: FocusSession) -> some View {
        let typeInfo = KairoTheme.SessionType(rawValue: session.sessionType) ?? .work

        return HStack(spacing: KairoTheme.Spacing.sm) {
            // Type icon
            ZStack {
                Circle()
                    .fill(typeInfo.color.opacity(0.12))
                    .frame(width: 36, height: 36)

                Image(systemName: typeInfo.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(typeInfo.color)
            }

            // Time and duration
            VStack(alignment: .leading, spacing: 2) {
                Text(session.startedAt.shortTimeString)
                    .font(KairoTypography.label)
                    .foregroundColor(KairoColors.primaryAdaptive)

                Text(TimeInterval(session.actualDuration).humanReadable)
                    .font(KairoTypography.caption)
                    .foregroundColor(KairoColors.mutedAdaptive)
            }

            Spacer()

            // Quality badge
            qualityBadge(for: session)

            // Score pill
            Text("\(Int(session.focusScore))")
                .font(KairoTypography.scoreSmall)
                .foregroundColor(.white)
                .frame(width: 38, height: 26)
                .background(KairoColors.scoreColor(for: session.focusScore))
                .clipShape(Capsule())
        }
        .padding(.vertical, KairoTheme.Spacing.xxs)
    }

    /// Small quality badge (High/Med/Low).
    private func qualityBadge(for session: FocusSession) -> some View {
        let quality = FocusQuality(rating: session.qualityRating) ?? .medium
        return Text(quality.displayName)
            .font(KairoTypography.caption)
            .foregroundColor(quality.color)
            .padding(.horizontal, KairoTheme.Spacing.xs)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(quality.color.opacity(0.12))
            )
    }

    // MARK: - Focus Coach Section

    @ViewBuilder
    private var focusCoachSection: some View {
        if !coachingInsights.isEmpty {
            VStack(alignment: .leading, spacing: KairoTheme.Spacing.xs) {
                sectionHeader(title: "Your Focus Coach", icon: "brain.head.profile")

                CoachingInsightCarousel(insights: coachingInsights)
            }
        }
    }

    // MARK: - Model Readiness Section

    private var modelReadinessSection: some View {
        VStack(alignment: .leading, spacing: KairoTheme.Spacing.sm) {
            HStack(spacing: KairoTheme.Spacing.xs) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: 0x9B59B6))

                Text("Teaching Kairo Your Patterns")
                    .font(KairoTypography.label)
                    .foregroundColor(KairoColors.primaryAdaptive)

                Spacer()

                Text(tierLabel)
                    .font(KairoTypography.caption)
                    .foregroundColor(Color(hex: 0x9B59B6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color(hex: 0x9B59B6).opacity(0.12))
                    )
            }

            // Tiered progress bar with milestones
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 6)
                        .fill(KairoColors.mutedAdaptive.opacity(0.12))
                        .frame(height: 8)

                    // Fill
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0x9B59B6), KairoColors.accentAdaptive],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * modelReadiness, height: 8)
                        .animation(KairoTheme.Animation.scoreReveal, value: modelReadiness)

                    // Tier milestone markers at 10 and 20
                    ForEach([10, 20], id: \.self) { milestone in
                        let position = geo.size.width * Double(milestone) / 30.0
                        Circle()
                            .fill(allCompletedSessions.count >= milestone
                                  ? Color(hex: 0x9B59B6)
                                  : KairoColors.mutedAdaptive.opacity(0.3))
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(KairoColors.surfaceAdaptive, lineWidth: 2)
                            )
                            .position(x: position, y: 4)
                    }
                }
            }
            .frame(height: 12)

            // Tier labels
            HStack {
                Text("10")
                    .font(.system(size: 10, weight: coachingTier >= 1 ? .bold : .regular))
                    .foregroundColor(coachingTier >= 1 ? Color(hex: 0x9B59B6) : KairoColors.mutedAdaptive)

                Spacer()

                Text("20")
                    .font(.system(size: 10, weight: coachingTier >= 2 ? .bold : .regular))
                    .foregroundColor(coachingTier >= 2 ? Color(hex: 0x9B59B6) : KairoColors.mutedAdaptive)

                Spacer()

                Text("30")
                    .font(.system(size: 10, weight: coachingTier >= 3 ? .bold : .regular))
                    .foregroundColor(coachingTier >= 3 ? Color(hex: 0x9B59B6) : KairoColors.mutedAdaptive)
            }
            .padding(.horizontal, 4)

            // Status text
            if coachingTier == 0 {
                Text("\(allCompletedSessions.count) of 10 sessions until basic coaching unlocks")
                    .font(KairoTypography.caption)
                    .foregroundColor(KairoColors.mutedAdaptive)
            } else if coachingTier == 1 {
                Text("Basic coaching active — \(20 - allCompletedSessions.count) more sessions to unlock intermediate analysis")
                    .font(KairoTypography.caption)
                    .foregroundColor(KairoColors.mutedAdaptive)
            } else if coachingTier == 2 {
                Text("Intermediate analysis active — \(30 - allCompletedSessions.count) more to unlock full AI coach")
                    .font(KairoTypography.caption)
                    .foregroundColor(KairoColors.mutedAdaptive)
            }
        }
        .padding(KairoTheme.Spacing.md)
        .background(KairoColors.surfaceAdaptive)
        .cornerRadius(KairoTheme.Radius.card)
        .shadow(
            color: KairoTheme.Shadow.card.color,
            radius: KairoTheme.Shadow.card.radius,
            y: KairoTheme.Shadow.card.y
        )
    }

    // MARK: - Coaching Refresh

    /// Loads coaching insights when 10+ sessions are available (Tier 1+).
    private func refreshCoachingInsights() {
        guard coachingTier >= 1 else { return }

        // Fetch the latest focus pattern
        let patternRequest: NSFetchRequest<FocusPattern> = FocusPattern.fetchRequest()
        patternRequest.sortDescriptors = [NSSortDescriptor(keyPath: \FocusPattern.updatedAt, ascending: false)]
        patternRequest.fetchLimit = 1

        guard let pattern = try? viewContext.fetch(patternRequest).first else { return }

        // Build session summaries from the last 30 days
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let sessionRequest: NSFetchRequest<FocusSession> = FocusSession.fetchRequest()
        sessionRequest.predicate = NSPredicate(
            format: "startedAt >= %@ AND (status == %@ OR status == %@)",
            thirtyDaysAgo as NSDate,
            "completed",
            "abandoned"
        )
        sessionRequest.sortDescriptors = [NSSortDescriptor(keyPath: \FocusSession.startedAt, ascending: false)]
        sessionRequest.fetchLimit = 100

        guard let sessions = try? viewContext.fetch(sessionRequest) else { return }

        let summaries = sessions.map { session in
            SessionSummary(
                date: session.startedAt,
                duration: TimeInterval(session.actualDuration),
                quality: FocusQuality(rating: session.qualityRating) ?? .medium,
                type: session.sessionType
            )
        }

        coachingInsights = insightGenerator.generateCoachingInsights(
            from: pattern,
            recentSessions: summaries,
            tier: coachingTier
        )
    }

    // MARK: - Section Header

    /// Reusable section header with icon and title.
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: KairoTheme.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(KairoColors.accentAdaptive)

            Text(title)
                .font(KairoTypography.heading3)
                .foregroundColor(KairoColors.primaryAdaptive)
        }
    }
}

// MARK: - HomeViewModel

/// Backing view model for HomeView that loads weekly trend data.
///
/// Separated from the view to keep heavy Core Data queries off the main render path.
/// Publishes the weekly trend for the mini chart.
final class HomeViewModel: ObservableObject {

    /// The last 7 days of daily score points for the mini chart.
    @Published var weeklyTrend: [DailyScorePoint] = []

    private let calculator = DailyScoreCalculator()

    /// Recalculates today's score and reloads the weekly trend.
    func refresh() {
        calculator.calculateAndSave(for: Date())
        weeklyTrend = calculator.weeklyTrend()
    }
}

// MARK: - Previews

#Preview("Home View") {
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

    HomeView()
        .environment(\.managedObjectContext, context)
        .environmentObject(coordinator)
        .environmentObject(InsightGenerator())
        .environmentObject(FocusPatternAnalyzer())
        .environmentObject(engine)
}
