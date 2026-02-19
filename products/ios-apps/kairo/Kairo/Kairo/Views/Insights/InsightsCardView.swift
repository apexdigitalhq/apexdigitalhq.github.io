import SwiftUI

// MARK: - InsightCard

/// A reusable card component that renders a single `Insight` with emoji, title,
/// message, and subtle color coding by `InsightType`.
///
/// Supports two layout modes:
/// - **compact** — condensed for carousels and widget-like contexts (2-line message cap)
/// - **expanded** — full detail view with unlimited text and larger padding
///
/// Usage:
/// ```swift
/// InsightCard(insight: myInsight, style: .compact) {
///     print("Card tapped")
/// }
/// ```
struct InsightCard: View {

    /// The insight data to display.
    let insight: Insight

    /// Visual density of the card.
    var style: Style = .compact

    /// Optional tap handler. When nil, the card is non-interactive.
    var onTap: (() -> Void)?

    // MARK: - Style

    /// Layout density variants for different embedding contexts.
    enum Style {
        /// Condensed layout for carousels and dashboards.
        case compact
        /// Full-width detail layout with unclamped text.
        case expanded
    }

    // MARK: - Body

    var body: some View {
        Button(action: { onTap?() }) {
            cardContent
        }
        .buttonStyle(InsightCardButtonStyle())
        .disabled(onTap == nil)
    }

    // MARK: - Card Content

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: KairoTheme.Spacing.sm) {
            // Header: emoji + title + type badge
            HStack(spacing: KairoTheme.Spacing.xs) {
                Text(insight.emoji)
                    .font(.system(size: emojiSize))

                VStack(alignment: .leading, spacing: 2) {
                    Text(insight.title)
                        .font(style == .expanded ? KairoTypography.heading3 : KairoTypography.label)
                        .foregroundColor(KairoColors.primaryAdaptive)
                        .lineLimit(1)

                    if style == .expanded {
                        Text(insight.type.displayName.uppercased())
                            .font(KairoTypography.caption)
                            .foregroundColor(accentColor.opacity(0.8))
                            .tracking(1.2)
                    }
                }

                Spacer()

                // Colored type indicator dot
                Circle()
                    .fill(accentColor)
                    .frame(width: 8, height: 8)
            }

            // Message body
            Text(insight.message)
                .font(style == .expanded ? KairoTypography.body : KairoTypography.bodySmall)
                .foregroundColor(KairoColors.mutedAdaptive)
                .lineLimit(style == .expanded ? nil : 3)
                .lineSpacing(style == .expanded ? 4 : 2)
                .fixedSize(horizontal: false, vertical: style == .expanded)

            // Timestamp in expanded mode
            if style == .expanded {
                HStack {
                    Spacer()
                    Text(insight.generatedAt, style: .relative)
                        .font(KairoTypography.caption)
                        .foregroundColor(KairoColors.mutedAdaptive.opacity(0.6))
                }
            }
        }
        .padding(style == .expanded ? KairoTheme.Spacing.lg : KairoTheme.Spacing.md)
        .frame(
            width: style == .compact ? compactCardWidth : nil,
            alignment: .leading
        )
        .background(cardBackground)
        .cornerRadius(KairoTheme.Radius.card)
        .overlay(
            RoundedRectangle(cornerRadius: KairoTheme.Radius.card)
                .strokeBorder(accentColor.opacity(0.12), lineWidth: 1)
        )
        .shadow(
            color: KairoTheme.Shadow.card.color,
            radius: KairoTheme.Shadow.card.radius,
            y: KairoTheme.Shadow.card.y
        )
    }

    // MARK: - Computed Properties

    /// The accent color derived from the insight's semantic type.
    private var accentColor: Color {
        switch insight.type {
        case .optimalTime:   return Color(hex: 0x3498DB)
        case .sessionLength: return KairoColors.accentAdaptive
        case .bestDay:       return Color(hex: 0x9B59B6)
        case .improvement:   return KairoColors.successAdaptive
        case .streak:        return Color.orange
        case .consistency:   return Color(hex: 0x1ABC9C)
        case .suggestion:    return KairoColors.warningAdaptive
        }
    }

    /// Background fill with a subtle tint of the type color.
    private var cardBackground: some ShapeStyle {
        KairoColors.surfaceAdaptive
    }

    /// Emoji font size scales with style.
    private var emojiSize: CGFloat {
        style == .expanded ? 32 : 24
    }

    /// Fixed width for compact cards in the carousel.
    private var compactCardWidth: CGFloat { 280 }
}

// MARK: - InsightCardButtonStyle

/// Provides a subtle scale-down press effect for tappable insight cards.
private struct InsightCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(KairoTheme.Animation.quick, value: configuration.isPressed)
    }
}

// MARK: - InsightCarousel

/// A horizontally scrolling carousel of `InsightCard` views with snap behavior
/// and page indicators.
///
/// Designed for embedding on the Home and Stats screens to surface the
/// latest 3–5 insights without overwhelming the layout.
///
/// Usage:
/// ```swift
/// InsightCarousel(insights: generator.latestInsights) { insight in
///     showInsightDetail(insight)
/// }
/// ```
struct InsightCarousel: View {

    /// Insights to display. Capped internally to 5.
    let insights: [Insight]

    /// Called when the user taps a card.
    var onTap: ((Insight) -> Void)?

    // MARK: - State

    @State private var currentPage: Int = 0

    // MARK: - Body

    var body: some View {
        if insights.isEmpty {
            emptyState
        } else {
            VStack(spacing: KairoTheme.Spacing.sm) {
                scrollContent
                pageIndicators
            }
        }
    }

    // MARK: - Scroll Content

    private var scrollContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: KairoTheme.Spacing.sm) {
                ForEach(Array(displayInsights.enumerated()), id: \.element.id) { index, insight in
                    InsightCard(insight: insight, style: .compact) {
                        onTap?(insight)
                    }
                    .id(index)
                }
            }
            .padding(.horizontal, KairoTheme.Spacing.md)
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: Binding(
            get: { currentPage },
            set: { if let v = $0 { currentPage = v } }
        ))
        .frame(height: compactCardHeight)
    }

    // MARK: - Page Indicators

    private var pageIndicators: some View {
        HStack(spacing: KairoTheme.Spacing.xxs) {
            ForEach(0..<displayInsights.count, id: \.self) { index in
                Circle()
                    .fill(
                        index == currentPage
                            ? KairoColors.accentAdaptive
                            : KairoColors.mutedAdaptive.opacity(0.3)
                    )
                    .frame(width: index == currentPage ? 8 : 6,
                           height: index == currentPage ? 8 : 6)
                    .animation(KairoTheme.Animation.quick, value: currentPage)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        HStack(spacing: KairoTheme.Spacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 20))
                .foregroundColor(KairoColors.mutedAdaptive.opacity(0.5))

            Text("Complete a few sessions to unlock insights")
                .font(KairoTypography.bodySmall)
                .foregroundColor(KairoColors.mutedAdaptive)
        }
        .padding(KairoTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KairoColors.surfaceAdaptive)
        .cornerRadius(KairoTheme.Radius.card)
    }

    // MARK: - Helpers

    /// Capped to 5 insights max.
    private var displayInsights: [Insight] {
        Array(insights.prefix(5))
    }

    /// Estimated height for the compact card + padding.
    private var compactCardHeight: CGFloat { 130 }
}

// MARK: - Previews

#Preview("Insight Card — Compact") {
    VStack(spacing: 16) {
        InsightCard(
            insight: Insight(
                type: .optimalTime,
                title: "Peak Focus Window",
                message: "Your highest-quality sessions happen between 9 AM – 11 AM. Schedule deep work then.",
                emoji: "⏰",
                priority: 2
            ),
            style: .compact
        )

        InsightCard(
            insight: Insight(
                type: .streak,
                title: "7-Day Streak!",
                message: "A full week without breaking the chain. That's real discipline.",
                emoji: "🏅",
                priority: 1
            ),
            style: .expanded
        )
    }
    .padding()
    .background(KairoColors.backgroundAdaptive)
}

#Preview("Insight Carousel") {
    InsightCarousel(insights: [
        Insight(type: .optimalTime, title: "Peak Focus", message: "9 AM – 11 AM is your zone.", emoji: "⏰", priority: 2),
        Insight(type: .streak, title: "5-Day Streak", message: "Keep the chain going.", emoji: "🔥", priority: 1),
        Insight(type: .suggestion, title: "Try 20 Min", message: "Shorter sessions, better quality.", emoji: "💡", priority: 3)
    ])
    .padding(.vertical)
    .background(KairoColors.backgroundAdaptive)
}
