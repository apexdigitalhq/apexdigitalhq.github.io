import SwiftUI

// MARK: - CoachingInsightCard

/// A premium card component for displaying a single `CoachingInsight`.
///
/// Renders the coaching advice with:
/// - Category emoji + title header
/// - Main advice text
/// - Expandable "Why this works" science section
/// - Highlighted "Try this:" action step
///
/// Designed to match Kairo's clean, premium aesthetic using the existing
/// `KairoTheme`, `KairoColors`, and `KairoTypography` design tokens.
struct CoachingInsightCard: View {

    let insight: CoachingInsight

    @State private var isExpanded = false

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: KairoTheme.Spacing.sm) {
            // Header: emoji + title + category badge
            headerSection

            // Main advice text
            Text(insight.advice)
                .font(KairoTypography.bodySmall)
                .foregroundColor(KairoColors.primaryAdaptive.opacity(0.85))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            // Action step — highlighted
            actionStepSection

            // Expandable science section
            scienceSection
        }
        .padding(KairoTheme.Spacing.md)
        .background(KairoColors.surfaceAdaptive)
        .cornerRadius(KairoTheme.Radius.card)
        .overlay(
            RoundedRectangle(cornerRadius: KairoTheme.Radius.card)
                .strokeBorder(insight.category.color.opacity(0.15), lineWidth: 1)
        )
        .shadow(
            color: KairoTheme.Shadow.card.color,
            radius: KairoTheme.Shadow.card.radius,
            y: KairoTheme.Shadow.card.y
        )
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: KairoTheme.Spacing.xs) {
            Text(insight.emoji)
                .font(.system(size: 24))

            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(KairoTypography.heading3)
                    .foregroundColor(KairoColors.primaryAdaptive)
                    .lineLimit(2)

                Text(insight.category.displayName.uppercased())
                    .font(KairoTypography.caption)
                    .foregroundColor(insight.category.color)
                    .tracking(1.2)
            }

            Spacer()

            // Category color indicator
            Circle()
                .fill(insight.category.color)
                .frame(width: 8, height: 8)
        }
    }

    // MARK: - Action Step

    private var actionStepSection: some View {
        HStack(alignment: .top, spacing: KairoTheme.Spacing.xs) {
            Image(systemName: "arrow.right.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(insight.category.color)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text("Try this:")
                    .font(KairoTypography.label)
                    .foregroundColor(insight.category.color)

                Text(insight.actionStep)
                    .font(KairoTypography.bodySmall)
                    .foregroundColor(KairoColors.primaryAdaptive.opacity(0.9))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(KairoTheme.Spacing.sm)
        .background(insight.category.color.opacity(0.06))
        .cornerRadius(KairoTheme.Radius.small)
    }

    // MARK: - Science Section

    private var scienceSection: some View {
        VStack(alignment: .leading, spacing: KairoTheme.Spacing.xxs) {
            Button(action: {
                withAnimation(KairoTheme.Animation.standard) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: KairoTheme.Spacing.xxs) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 12))
                        .foregroundColor(KairoColors.mutedAdaptive)

                    Text("Why this works")
                        .font(KairoTypography.caption)
                        .foregroundColor(KairoColors.mutedAdaptive)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(KairoColors.mutedAdaptive)

                    Spacer()
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(insight.science)
                    .font(KairoTypography.caption)
                    .foregroundColor(KairoColors.mutedAdaptive.opacity(0.8))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, KairoTheme.Spacing.md)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - CoachingInsightCarousel

/// A vertically stacked list of coaching insight cards for the home screen.
///
/// Shows 2-3 coaching insights with a "Your Focus Coach" header.
/// Designed to replace the model readiness section once the user
/// reaches 30+ completed sessions.
struct CoachingInsightCarousel: View {

    let insights: [CoachingInsight]

    @State private var currentIndex = 0

    var body: some View {
        if insights.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: KairoTheme.Spacing.xs) {
                // Show 2-3 cards in a vertical stack
                ForEach(Array(displayInsights.enumerated()), id: \.element.id) { _, insight in
                    CoachingInsightCard(insight: insight)
                }
            }
        }
    }

    private var displayInsights: [CoachingInsight] {
        Array(insights.prefix(3))
    }
}

// MARK: - Previews

#Preview("Coaching Insight Card") {
    ScrollView {
        VStack(spacing: 16) {
            CoachingInsightCard(
                insight: CoachingInsight(
                    category: .timing,
                    title: "Beat the Afternoon Dip",
                    advice: "Your afternoon sessions are noticeably weaker than your mornings. The post-lunch dip isn't laziness — it's your circadian rhythm. Your body temperature drops 7-8 hours after waking, reducing alertness naturally.",
                    science: "Circadian rhythm research shows a natural alertness trough in the early afternoon, driven by the postprandial dip in core body temperature (Monk, 2005).",
                    actionStep: "Take a 10-minute walk or splash cold water on your wrists before your next afternoon session.",
                    emoji: "🌤️",
                    priority: 1
                )
            )

            CoachingInsightCard(
                insight: CoachingInsight(
                    category: .deepWork,
                    title: "Push Into Flow State",
                    advice: "With your high completion rate and quality, you're ready for the next level: flow. Flow state — that effortless, time-vanishing focus — requires clear goals, immediate feedback, and a challenge-skill balance.",
                    science: "Csikszentmihalyi's flow state research identifies three prerequisites: clear goals, immediate feedback, and a challenge-skill ratio near 1:1.",
                    actionStep: "Before your next session, define a crystal-clear goal, turn off all notifications, and pick a task that stretches you slightly.",
                    emoji: "🌊",
                    priority: 2
                )
            )

            CoachingInsightCard(
                insight: CoachingInsight(
                    category: .brainScience,
                    title: "Your Phone Is Stealing 10% of Your Brain",
                    advice: "Having your phone in the same room — even face down, even powered off — reduces your cognitive capacity by up to 10%. Your brain is spending resources suppressing the urge to check it.",
                    science: "Ward et al. (2017) at University of Texas found that smartphone proximity alone reduces available cognitive capacity, even when the phone is off.",
                    actionStep: "Put your phone in a different room before your next session. Not face down. Not on silent. In another room.",
                    emoji: "📱",
                    priority: 1
                )
            )
        }
        .padding()
    }
    .background(KairoColors.backgroundAdaptive)
}

#Preview("Coaching Carousel") {
    ScrollView {
        CoachingInsightCarousel(insights: [
            CoachingInsight(
                category: .timing,
                title: "Beat the Afternoon Dip",
                advice: "Your afternoon sessions are weaker. The post-lunch dip is your circadian rhythm, not laziness.",
                science: "Circadian research shows a natural alertness trough in the early afternoon.",
                actionStep: "Take a 10-minute walk before your next afternoon session.",
                emoji: "🌤️",
                priority: 1
            ),
            CoachingInsight(
                category: .brainScience,
                title: "Your Phone Costs 10% Brain Power",
                advice: "Even having your phone nearby reduces cognitive capacity. Physical distance is the only fix.",
                science: "Ward et al. (2017) found smartphone proximity alone reduces cognitive capacity.",
                actionStep: "Put your phone in another room for your next session.",
                emoji: "📱",
                priority: 1
            )
        ])
        .padding()
    }
    .background(KairoColors.backgroundAdaptive)
}
