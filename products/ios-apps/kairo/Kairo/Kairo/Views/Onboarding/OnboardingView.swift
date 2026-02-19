import SwiftUI

// MARK: - Onboarding Page Model

private struct OnboardingPage: Identifiable {
    let id: Int
    let icon: String
    let title: String
    let subtitle: String
    let accentColor: Color
}

// MARK: - OnboardingView

/// Premium swipeable onboarding shown on first launch.
/// Sets `hasSeenOnboarding` in AppStorage on completion.
struct OnboardingView: View {

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0
    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0
    @State private var textOffset: CGFloat = 30
    @State private var textOpacity: Double = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            id: 0,
            icon: "brain.head.profile",
            title: "Focus Smarter",
            subtitle: "Kairo learns your patterns and adapts to help you achieve deeper, more productive focus sessions.",
            accentColor: KairoColors.accentAdaptive
        ),
        OnboardingPage(
            id: 1,
            icon: "lock.shield.fill",
            title: "Stay Private",
            subtitle: "All your data stays on your device. No accounts, no cloud, no tracking. Your focus is your business.",
            accentColor: KairoColors.successAdaptive
        ),
        OnboardingPage(
            id: 2,
            icon: "chart.line.uptrend.xyaxis",
            title: "Track Growth",
            subtitle: "Watch your focus improve over time with beautiful insights, streaks, and daily scores.",
            accentColor: Color(hex: 0x3498DB)
        ),
        OnboardingPage(
            id: 3,
            icon: "arrow.right.circle.fill",
            title: "Get Started",
            subtitle: "Your first focus session is waiting. Let's build a habit that sticks.",
            accentColor: KairoColors.accentAdaptive
        )
    ]

    private var isLastPage: Bool { currentPage == pages.count - 1 }

    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button
                skipButton

                // Page content
                TabView(selection: $currentPage) {
                    ForEach(pages) { page in
                        pageView(for: page)
                            .tag(page.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(KairoTheme.Animation.standard, value: currentPage)

                // Bottom controls
                bottomControls
                    .padding(.bottom, KairoTheme.Spacing.xxl)
            }
        }
        .onAppear {
            animatePageIn()
        }
        .onChange(of: currentPage) { _, _ in
            animatePageIn()
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                KairoColors.backgroundAdaptive,
                KairoColors.backgroundAdaptive.opacity(0.95),
                pages[currentPage].accentColor.opacity(0.08)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .animation(KairoTheme.Animation.standard, value: currentPage)
    }

    // MARK: - Skip Button

    private var skipButton: some View {
        HStack {
            Spacer()
            if !isLastPage {
                Button(action: completeOnboarding) {
                    Text("Skip")
                        .font(KairoTypography.label)
                        .foregroundColor(KairoColors.mutedAdaptive)
                        .padding(.horizontal, KairoTheme.Spacing.md)
                        .padding(.vertical, KairoTheme.Spacing.xs)
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, KairoTheme.Spacing.md)
        .padding(.top, KairoTheme.Spacing.sm)
        .frame(height: 44)
    }

    // MARK: - Page View

    private func pageView(for page: OnboardingPage) -> some View {
        VStack(spacing: KairoTheme.Spacing.xl) {
            Spacer()

            // Icon with glow
            ZStack {
                // Glow ring
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                page.accentColor.opacity(0.25),
                                page.accentColor.opacity(0.05),
                                .clear
                            ],
                            center: .center,
                            startRadius: 40,
                            endRadius: 120
                        )
                    )
                    .frame(width: 240, height: 240)

                // Icon circle
                Circle()
                    .fill(page.accentColor.opacity(0.12))
                    .frame(width: 140, height: 140)
                    .overlay(
                        Image(systemName: page.icon)
                            .font(.system(size: 56, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [page.accentColor, page.accentColor.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .scaleEffect(currentPage == page.id ? iconScale : 0.8)
                    .opacity(currentPage == page.id ? iconOpacity : 0.5)
            }

            // Text content
            VStack(spacing: KairoTheme.Spacing.sm) {
                Text(page.title)
                    .font(KairoTypography.heading1)
                    .foregroundColor(KairoColors.primaryAdaptive)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(KairoTypography.bodyLarge)
                    .foregroundColor(KairoColors.mutedAdaptive)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, KairoTheme.Spacing.xl)
            }
            .offset(y: currentPage == page.id ? textOffset : 30)
            .opacity(currentPage == page.id ? textOpacity : 0)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: KairoTheme.Spacing.lg) {
            // Page indicators
            pageIndicators

            // Action button
            actionButton
                .padding(.horizontal, KairoTheme.Spacing.xxl)
        }
    }

    private var pageIndicators: some View {
        HStack(spacing: KairoTheme.Spacing.xs) {
            ForEach(0..<pages.count, id: \.self) { index in
                Capsule()
                    .fill(index == currentPage
                        ? pages[currentPage].accentColor
                        : KairoColors.mutedAdaptive.opacity(0.3)
                    )
                    .frame(
                        width: index == currentPage ? 24 : 8,
                        height: 8
                    )
                    .animation(KairoTheme.Animation.standard, value: currentPage)
            }
        }
    }

    private var actionButton: some View {
        Button(action: {
            if isLastPage {
                completeOnboarding()
            } else {
                withAnimation(KairoTheme.Animation.standard) {
                    currentPage += 1
                }
            }
        }) {
            HStack(spacing: KairoTheme.Spacing.xs) {
                Text(isLastPage ? "Begin First Session" : "Continue")
                    .font(KairoTypography.heading3)

                if !isLastPage {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, KairoTheme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: KairoTheme.Radius.large)
                    .fill(
                        LinearGradient(
                            colors: [
                                pages[currentPage].accentColor,
                                pages[currentPage].accentColor.opacity(0.8)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .shadow(
                color: pages[currentPage].accentColor.opacity(0.3),
                radius: 12,
                y: 4
            )
        }
        .animation(KairoTheme.Animation.standard, value: currentPage)
    }

    // MARK: - Actions

    private func completeOnboarding() {
        withAnimation(KairoTheme.Animation.sessionStart) {
            hasSeenOnboarding = true
        }
    }

    private func animatePageIn() {
        // Reset
        iconScale = 0.5
        iconOpacity = 0
        textOffset = 30
        textOpacity = 0

        // Animate icon
        withAnimation(KairoTheme.Animation.sessionStart.delay(0.1)) {
            iconScale = 1.0
            iconOpacity = 1.0
        }

        // Animate text
        withAnimation(KairoTheme.Animation.standard.delay(0.25)) {
            textOffset = 0
            textOpacity = 1.0
        }
    }
}

// MARK: - Preview

#Preview("Onboarding") {
    OnboardingView()
}

#Preview("Onboarding - Dark") {
    OnboardingView()
        .preferredColorScheme(.dark)
}
