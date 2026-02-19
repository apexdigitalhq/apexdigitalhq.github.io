import SwiftUI
import StoreKit

/// Full-screen paywall modal showcasing Kairo Pro features with StoreKit 2 purchase flow.
///
/// Premium dark design with teal accents. Features monthly and annual price cards,
/// a 7-day free trial CTA, and restore purchases link.
struct PaywallView: View {

    @EnvironmentObject private var storeManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPlan: PlanType = .annual
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var animateFeatures = false

    enum PlanType: String {
        case monthly
        case annual
    }

    // MARK: - Feature List

    private struct Feature: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let subtitle: String
    }

    private let features: [Feature] = [
        Feature(icon: "infinity", title: "Unlimited Sessions", subtitle: "No daily limit on focus sessions"),
        Feature(icon: "chart.line.uptrend.xyaxis", title: "Advanced Stats", subtitle: "Weekly & monthly analytics with AI insights"),
        Feature(icon: "waveform", title: "Custom Sounds", subtitle: "All 5 ambient soundscapes unlocked"),
        Feature(icon: "bolt.fill", title: "Priority Features", subtitle: "Early access to new capabilities"),
    ]

    // MARK: - Body

    var body: some View {
        ZStack {
            // Dark premium background
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Close button
                closeButton

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: KairoTheme.Spacing.lg) {
                        headerSection
                        featuresSection
                        pricingSection
                        ctaSection
                        restoreSection
                    }
                    .padding(.horizontal, KairoTheme.Spacing.lg)
                    .padding(.bottom, KairoTheme.Spacing.xxl)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                animateFeatures = true
            }
            // Pre-fetch products if not loaded
            if storeManager.products.isEmpty {
                Task { await storeManager.fetchProducts() }
            }
        }
        .alert("Purchase Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(storeManager.errorMessage ?? "Something went wrong. Please try again.")
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(hex: 0x0A0E27),
                Color(hex: 0x0F1B3D),
                Color(hex: 0x0A1628),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Close Button

    private var closeButton: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.trailing, KairoTheme.Spacing.md)
            .padding(.top, KairoTheme.Spacing.sm)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: KairoTheme.Spacing.sm) {
            // Crown icon
            ZStack {
                Circle()
                    .fill(tealAccent.opacity(0.15))
                    .frame(width: 72, height: 72)

                Circle()
                    .fill(tealAccent.opacity(0.08))
                    .frame(width: 96, height: 96)

                Image(systemName: "crown.fill")
                    .font(.system(size: 32))
                    .foregroundColor(tealAccent)
            }
            .padding(.top, KairoTheme.Spacing.sm)

            Text("Kairo Pro")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("Unlock your full focus potential")
                .font(KairoTypography.bodyLarge)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(spacing: KairoTheme.Spacing.sm) {
            ForEach(Array(features.enumerated()), id: \.element.id) { index, feature in
                featureRow(feature)
                    .opacity(animateFeatures ? 1 : 0)
                    .offset(y: animateFeatures ? 0 : 20)
                    .animation(
                        .easeOut(duration: 0.4).delay(Double(index) * 0.1),
                        value: animateFeatures
                    )
            }
        }
        .padding(.vertical, KairoTheme.Spacing.sm)
    }

    private func featureRow(_ feature: Feature) -> some View {
        HStack(spacing: KairoTheme.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: KairoTheme.Radius.small)
                    .fill(tealAccent.opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: feature.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(tealAccent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(KairoTypography.heading3)
                    .foregroundColor(.white)

                Text(feature.subtitle)
                    .font(KairoTypography.bodySmall)
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(tealAccent)
        }
        .padding(KairoTheme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: KairoTheme.Radius.medium)
                .fill(.white.opacity(0.04))
        )
    }

    // MARK: - Pricing

    private var pricingSection: some View {
        HStack(spacing: KairoTheme.Spacing.sm) {
            priceCard(
                plan: .monthly,
                title: "Monthly",
                price: storeManager.monthlyProduct?.displayPrice ?? "$4.99",
                period: "/month",
                badge: nil
            )

            priceCard(
                plan: .annual,
                title: "Annual",
                price: storeManager.annualProduct?.displayPrice ?? "$29.99",
                period: "/year",
                badge: "Save 50%"
            )
        }
    }

    private func priceCard(
        plan: PlanType,
        title: String,
        price: String,
        period: String,
        badge: String?
    ) -> some View {
        let isSelected = selectedPlan == plan

        return Button {
            withAnimation(KairoTheme.Animation.quick) {
                selectedPlan = plan
            }
        } label: {
            VStack(spacing: KairoTheme.Spacing.xs) {
                // Badge
                if let badge {
                    Text(badge)
                        .font(KairoTypography.labelSmall)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, KairoTheme.Spacing.xs)
                        .padding(.vertical, KairoTheme.Spacing.xxs)
                        .background(Capsule().fill(tealAccent))
                } else {
                    // Spacer for alignment
                    Text(" ")
                        .font(KairoTypography.labelSmall)
                        .padding(.vertical, KairoTheme.Spacing.xxs)
                        .opacity(0)
                }

                Text(title)
                    .font(KairoTypography.label)
                    .foregroundColor(.white.opacity(0.6))

                Text(price)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(period)
                    .font(KairoTypography.caption)
                    .foregroundColor(.white.opacity(0.4))

                // Monthly equivalent for annual
                if plan == .annual {
                    Text("≈ $2.50/mo")
                        .font(KairoTypography.caption)
                        .foregroundColor(tealAccent)
                        .padding(.top, 2)
                } else {
                    Text(" ")
                        .font(KairoTypography.caption)
                        .padding(.top, 2)
                        .opacity(0)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, KairoTheme.Spacing.md)
            .padding(.horizontal, KairoTheme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: KairoTheme.Radius.large)
                    .fill(isSelected ? tealAccent.opacity(0.12) : .white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: KairoTheme.Radius.large)
                    .stroke(isSelected ? tealAccent : .white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - CTA

    private var ctaSection: some View {
        VStack(spacing: KairoTheme.Spacing.sm) {
            Button {
                Task { await handlePurchase() }
            } label: {
                HStack(spacing: KairoTheme.Spacing.xs) {
                    if isPurchasing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Start 7-Day Free Trial")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, KairoTheme.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: KairoTheme.Radius.large)
                        .fill(
                            LinearGradient(
                                colors: [tealAccent, tealAccent.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .shadow(color: tealAccent.opacity(0.3), radius: 12, y: 4)
            }
            .disabled(isPurchasing)

            // Terms text
            Text("Cancel anytime. \(selectedPlan == .annual ? "Annual" : "Monthly") subscription renews automatically.")
                .font(KairoTypography.caption)
                .foregroundColor(.white.opacity(0.35))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Restore

    private var restoreSection: some View {
        VStack(spacing: KairoTheme.Spacing.md) {
            Button {
                Task { await storeManager.restorePurchases() }
            } label: {
                Text("Restore Purchases")
                    .font(KairoTypography.body)
                    .foregroundColor(.white.opacity(0.5))
                    .underline()
            }

            // Privacy callout
            HStack(spacing: KairoTheme.Spacing.xs) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 12))

                Text("No ads. No tracking. Your subscription funds privacy-first development.")
                    .font(KairoTypography.caption)
            }
            .foregroundColor(.white.opacity(0.3))
            .multilineTextAlignment(.center)
            .padding(.horizontal, KairoTheme.Spacing.md)
        }
        .padding(.top, KairoTheme.Spacing.sm)
    }

    // MARK: - Purchase Handler

    private func handlePurchase() async {
        let product: Product?
        switch selectedPlan {
        case .monthly: product = storeManager.monthlyProduct
        case .annual:  product = storeManager.annualProduct
        }

        guard let product else {
            storeManager.errorMessage = "Product not available. Please try again."
            showError = true
            return
        }

        isPurchasing = true
        let success = await storeManager.purchase(product)
        isPurchasing = false

        if success {
            dismiss()
        } else if storeManager.errorMessage != nil {
            showError = true
        }
    }

    // MARK: - Theme

    private var tealAccent: Color {
        Color(hex: 0x00D2C6)
    }
}

// MARK: - Preview

#Preview {
    PaywallView()
        .environmentObject(SubscriptionManager())
}
