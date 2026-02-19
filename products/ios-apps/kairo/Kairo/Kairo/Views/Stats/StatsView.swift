import SwiftUI
import Charts

// MARK: - StatsView

/// Weekly overview with bar chart of daily scores and stat cards.
/// Requires iOS 16+ for Swift Charts.
struct StatsView: View {

    @StateObject private var viewModel = StatsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: KairoTheme.Spacing.lg) {
                    weeklyScoreChart
                    statsGrid
                    weeklyInsight
                }
                .padding(.horizontal, KairoTheme.Spacing.md)
                .padding(.top, KairoTheme.Spacing.sm)
                .padding(.bottom, KairoTheme.Spacing.xxl)
            }
            .navigationTitle("Stats")
            .background(KairoColors.backgroundAdaptive.ignoresSafeArea())
            .onAppear { viewModel.load() }
        }
    }

    // MARK: - Weekly Score Chart

    private var weeklyScoreChart: some View {
        VStack(alignment: .leading, spacing: KairoTheme.Spacing.sm) {
            Text("Weekly Focus")
                .font(KairoTypography.heading3)
                .foregroundColor(KairoColors.primaryAdaptive)

            if viewModel.trend.isEmpty || viewModel.trend.allSatisfy({ $0.isEmpty }) {
                chartEmptyState
            } else {
                chart
            }
        }
        .kairoCard()
    }

    private var chart: some View {
        Chart(viewModel.trend) { point in
            BarMark(
                x: .value("Day", point.dayLabel),
                y: .value("Score", point.score)
            )
            .foregroundStyle(barGradient(for: point.score))
            .cornerRadius(KairoTheme.Radius.small / 2)
            .annotation(position: .top, spacing: 4) {
                if point.score > 0 {
                    Text("\(Int(point.score))")
                        .font(KairoTypography.caption)
                        .foregroundColor(KairoColors.mutedAdaptive)
                }
            }
        }
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                    .foregroundStyle(KairoColors.mutedAdaptive.opacity(0.3))
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
        .frame(height: 200)
        .padding(.top, KairoTheme.Spacing.xs)
    }

    private var chartEmptyState: some View {
        VStack(spacing: KairoTheme.Spacing.sm) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 32))
                .foregroundColor(KairoColors.mutedAdaptive.opacity(0.4))

            Text("Complete sessions to see your weekly chart")
                .font(KairoTypography.bodySmall)
                .foregroundColor(KairoColors.mutedAdaptive)
                .multilineTextAlignment(.center)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }

    /// Gradient color for chart bars based on score value.
    private func barGradient(for score: Float) -> some ShapeStyle {
        KairoColors.scoreColor(for: score).gradient
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: KairoTheme.Spacing.sm),
                GridItem(.flexible(), spacing: KairoTheme.Spacing.sm)
            ],
            spacing: KairoTheme.Spacing.sm
        ) {
            StatCard(
                icon: "clock.fill",
                title: "Focus Time",
                value: viewModel.totalFocusDisplay,
                color: KairoColors.accentAdaptive
            )

            StatCard(
                icon: "timer",
                title: "Avg Session",
                value: viewModel.avgSessionDisplay,
                color: Color(hex: 0x3498DB)
            )

            StatCard(
                icon: "flame.fill",
                title: "Best Streak",
                value: "\(viewModel.stats?.bestStreak ?? 0) days",
                color: Color(hex: 0xE67E22)
            )

            StatCard(
                icon: "checkmark.circle.fill",
                title: "Sessions",
                value: "\(viewModel.stats?.totalSessions ?? 0)",
                color: KairoColors.successAdaptive
            )
        }
    }

    // MARK: - Weekly Insight

    @ViewBuilder
    private var weeklyInsight: some View {
        if let stats = viewModel.stats, stats.totalSessions > 0 {
            VStack(alignment: .leading, spacing: KairoTheme.Spacing.xs) {
                Text("Weekly Insight")
                    .font(KairoTypography.heading3)
                    .foregroundColor(KairoColors.primaryAdaptive)

                Text(viewModel.insightText)
                    .font(KairoTypography.body)
                    .foregroundColor(KairoColors.mutedAdaptive)
                    .lineSpacing(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .kairoCard()
        }
    }
}

// MARK: - StatCard

/// A single stat card with icon, title, and value.
struct StatCard: View {

    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: KairoTheme.Spacing.xs) {
            HStack(spacing: KairoTheme.Spacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)

                Text(title)
                    .font(KairoTypography.label)
                    .foregroundColor(KairoColors.mutedAdaptive)
            }

            Text(value)
                .font(KairoTypography.statValue)
                .foregroundColor(KairoColors.primaryAdaptive)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .kairoCard()
    }
}

// MARK: - StatsViewModel

final class StatsViewModel: ObservableObject {

    @Published var trend: [DailyScorePoint] = []
    @Published var stats: WeeklyStats?

    private let calculator = DailyScoreCalculator()

    func load() {
        // Recalculate today's score first
        calculator.calculateAndSave(for: Date())

        stats = calculator.weeklyStats()
        trend = stats?.trend ?? []
    }

    var totalFocusDisplay: String {
        guard let s = stats else { return "0 min" }
        return s.totalFocusMinutes.minutesDisplay
    }

    var avgSessionDisplay: String {
        guard let s = stats else { return "0 min" }
        return s.avgSessionMinutes.minutesDisplay
    }

    var insightText: String {
        guard let s = stats else { return "" }

        if s.activeDays == 0 {
            return "Start your first session to get weekly insights!"
        }

        var parts: [String] = []

        // Activity summary
        parts.append("You focused for \(s.totalFocusMinutes.minutesDisplay) across \(s.totalSessions) session\(s.totalSessions == 1 ? "" : "s") this week.")

        // Streak
        if s.bestStreak >= 3 {
            parts.append("Your best streak was \(s.bestStreak) consecutive days — great consistency! 🔥")
        } else if s.bestStreak > 0 {
            parts.append("Try to focus on consecutive days to build momentum.")
        }

        // Trend analysis
        let recentScores = trend.suffix(3).map { $0.score }
        let olderScores = trend.prefix(4).map { $0.score }
        let recentAvg = recentScores.isEmpty ? Float(0) : recentScores.reduce(0, +) / Float(recentScores.count)
        let olderAvg = olderScores.isEmpty ? Float(0) : olderScores.reduce(0, +) / Float(olderScores.count)

        if recentAvg > olderAvg + 5 {
            parts.append("Your scores are trending up — keep it going! 📈")
        } else if recentAvg < olderAvg - 5 {
            parts.append("Your recent scores dipped — try shorter sessions to rebuild. 💪")
        }

        return parts.joined(separator: " ")
    }
}

// MARK: - Previews

#Preview("Stats View") {
    StatsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
