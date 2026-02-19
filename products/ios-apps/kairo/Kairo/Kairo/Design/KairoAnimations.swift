import SwiftUI

// MARK: - KairoAnimation

/// Centralized animation definitions for consistent motion design across Kairo.
///
/// Every animation in the app should reference these tokens rather than
/// constructing ad-hoc animations inline. This guarantees uniform feel
/// and makes it trivial to adjust timing globally.
///
/// Usage:
/// ```swift
/// withAnimation(KairoAnimation.springBounce) { showCard = true }
/// view.animation(KairoAnimation.smooth, value: isExpanded)
/// ```
enum KairoAnimation {

    // MARK: - Core Animations

    /// Interactive spring — buttons, toggles, card presses.
    /// Snappy with a satisfying bounce.
    static var springBounce: Animation {
        .spring(response: 0.5, dampingFraction: 0.7)
    }

    /// Smooth state transition — expanding panels, tab switches, layout changes.
    static var smooth: Animation {
        .easeInOut(duration: 0.3)
    }

    /// Micro-interaction — selection highlights, icon swaps, quick feedback.
    static var quick: Animation {
        .easeOut(duration: 0.15)
    }

    /// Achievement celebration — score reveals, streak milestones, session completion.
    /// Lower damping gives a playful overshoot.
    static var celebration: Animation {
        .spring(response: 0.6, dampingFraction: 0.5)
    }

    /// Breathing pulse for active focus state.
    /// Slow, continuous, calming — like a visual metronome.
    static var breathe: Animation {
        .easeInOut(duration: 2.0).repeatForever(autoreverses: true)
    }

    /// View entrance — asymmetric spring that enters fast, settles slowly.
    static var slideIn: Animation {
        .spring(response: 0.45, dampingFraction: 0.75, blendDuration: 0.1)
    }

    /// Opacity-only fade for content swaps and overlays.
    static var fadeThrough: Animation {
        .easeInOut(duration: 0.2)
    }

    // MARK: - Parameterized Helpers

    /// Delayed spring entrance — stagger multiple items.
    /// - Parameter index: Item index in a list (multiplied by 0.05s).
    static func staggeredEntrance(index: Int) -> Animation {
        slideIn.delay(Double(index) * 0.05)
    }

    /// Score count-up reveal with customizable duration.
    /// - Parameter duration: How long the count-up takes.
    static func scoreReveal(duration: Double = 0.8) -> Animation {
        .easeOut(duration: duration)
    }
}

// MARK: - ConfettiModifier

/// Lightweight confetti/celebration effect using SwiftUI shapes only.
///
/// Spawns colored circles that float upward with random horizontal drift
/// and fade out. No SpriteKit, no external dependencies.
///
/// Apply via `.kairoConfetti(isActive:)`.
struct ConfettiModifier: ViewModifier {

    /// Whether confetti is currently emitting.
    let isActive: Bool

    /// Number of confetti particles.
    private let particleCount = 30

    /// Colors sampled from the Kairo palette.
    private let colors: [Color] = [
        KairoColors.accentLight,
        KairoColors.successLight,
        KairoColors.warningLight,
        Color(hex: 0x3498DB),
        Color(hex: 0x9B59B6),
        .orange
    ]

    @State private var particles: [ConfettiParticle] = []
    @State private var animate = false

    func body(content: Content) -> some View {
        content.overlay {
            if isActive {
                GeometryReader { geo in
                    ZStack {
                        ForEach(particles) { particle in
                            Circle()
                                .fill(particle.color)
                                .frame(width: particle.size, height: particle.size)
                                .scaleEffect(animate ? 0.2 : 1.0)
                                .opacity(animate ? 0 : 1)
                                .offset(
                                    x: animate
                                        ? particle.horizontalDrift
                                        : geo.size.width * particle.startX,
                                    y: animate
                                        ? -geo.size.height * particle.verticalTravel
                                        : geo.size.height * 0.5
                                )
                        }
                    }
                    .onAppear {
                        particles = generateParticles(in: geo.size)
                        withAnimation(.easeOut(duration: 1.8)) {
                            animate = true
                        }
                    }
                    .onChange(of: isActive) { _, newValue in
                        if newValue {
                            animate = false
                            particles = generateParticles(in: geo.size)
                            withAnimation(.easeOut(duration: 1.8)) {
                                animate = true
                            }
                        }
                    }
                }
                .allowsHitTesting(false)
            }
        }
    }

    /// Generate randomized confetti particles sized to the container.
    private func generateParticles(in size: CGSize) -> [ConfettiParticle] {
        (0..<particleCount).map { _ in
            ConfettiParticle(
                color: colors.randomElement() ?? .white,
                size: CGFloat.random(in: 4...10),
                startX: CGFloat.random(in: 0.1...0.9),
                horizontalDrift: CGFloat.random(in: -size.width * 0.4...size.width * 0.4),
                verticalTravel: CGFloat.random(in: 0.6...1.2)
            )
        }
    }
}

/// A single confetti particle's configuration.
private struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let size: CGFloat
    let startX: CGFloat
    let horizontalDrift: CGFloat
    let verticalTravel: CGFloat
}

// MARK: - PulseModifier

/// Breathing pulse effect for active focus state.
///
/// Creates a subtle scale+opacity pulse around the content, evoking
/// calm breathing rhythm. Automatically respects Reduce Motion.
///
/// Apply via `.kairoPulse(isActive:)`.
struct PulseModifier: ViewModifier {

    /// Whether the pulse animation is running.
    let isActive: Bool

    /// Pulse ring color — defaults to accent.
    var color: Color = KairoColors.accentAdaptive

    @State private var pulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .background {
                if isActive && !reduceMotion {
                    Circle()
                        .stroke(color.opacity(0.3), lineWidth: 2)
                        .scaleEffect(pulsing ? 1.15 : 1.0)
                        .opacity(pulsing ? 0 : 0.6)
                        .animation(
                            .easeInOut(duration: 2.0)
                                .repeatForever(autoreverses: false),
                            value: pulsing
                        )
                        .onAppear { pulsing = true }
                }
            }
            .onChange(of: isActive) { _, newValue in
                pulsing = newValue
            }
    }
}

// MARK: - ShimmerModifier

/// Loading shimmer for placeholder / skeleton states.
///
/// Draws a translucent gradient band that slides across the content,
/// giving a "loading" feel. Pure SwiftUI — no third-party libs.
///
/// Apply via `.kairoShimmer(isActive:)`.
struct ShimmerModifier: ViewModifier {

    /// Whether the shimmer animation is running.
    let isActive: Bool

    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay {
            if isActive {
                GeometryReader { geo in
                    let gradient = LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: max(0, phase - 0.2)),
                            .init(color: .white.opacity(0.25), location: phase),
                            .init(color: .clear, location: min(1, phase + 0.2))
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )

                    Rectangle()
                        .fill(gradient)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .onAppear {
                            guard !reduceMotion else { return }
                            withAnimation(
                                .linear(duration: 1.5)
                                    .repeatForever(autoreverses: false)
                            ) {
                                phase = 1.2
                            }
                        }
                }
                .allowsHitTesting(false)
                .clipShape(RoundedRectangle(cornerRadius: KairoTheme.Radius.medium))
            }
        }
    }
}

// MARK: - View Extensions

extension View {

    /// Adds a confetti celebration effect over this view.
    /// - Parameter isActive: Triggers the confetti burst when `true`.
    func kairoConfetti(isActive: Bool) -> some View {
        modifier(ConfettiModifier(isActive: isActive))
    }

    /// Adds a breathing pulse ring behind this view.
    /// - Parameters:
    ///   - isActive: Whether the pulse is animating.
    ///   - color: Pulse ring color (defaults to accent).
    func kairoPulse(isActive: Bool, color: Color = KairoColors.accentAdaptive) -> some View {
        modifier(PulseModifier(isActive: isActive, color: color))
    }

    /// Adds a shimmer loading overlay to this view.
    /// - Parameter isActive: Whether the shimmer is visible.
    func kairoShimmer(isActive: Bool) -> some View {
        modifier(ShimmerModifier(isActive: isActive))
    }

    /// Applies the standard Kairo entrance animation with optional stagger.
    /// - Parameter index: Stagger index (0-based).
    func kairoEntrance(index: Int = 0) -> some View {
        self.transition(.opacity.combined(with: .move(edge: .bottom)))
            .animation(KairoAnimation.staggeredEntrance(index: index), value: true)
    }
}

// MARK: - Reduce Motion Wrapper

/// Convenience property wrapper that falls back to non-animated behavior
/// when the user has enabled Reduce Motion in Accessibility settings.
///
/// Usage:
/// ```swift
/// @ReduceMotionAware var animation: Animation? = KairoAnimation.springBounce
/// // Returns nil when Reduce Motion is enabled
/// ```
@propertyWrapper
struct ReduceMotionAware {
    private let animation: Animation?

    init(wrappedValue: Animation?) {
        self.animation = wrappedValue
    }

    var wrappedValue: Animation? {
        UIAccessibility.isReduceMotionEnabled ? nil : animation
    }
}
