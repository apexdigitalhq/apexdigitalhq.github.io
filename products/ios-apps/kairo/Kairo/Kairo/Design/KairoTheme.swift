import SwiftUI

/// Central theme tokens for Kairo — spacing, radius, animation, and haptics.
enum KairoTheme {

    // MARK: - Spacing

    enum Spacing {
        /// 4pt
        static let xxs: CGFloat = 4
        /// 8pt
        static let xs: CGFloat = 8
        /// 12pt
        static let sm: CGFloat = 12
        /// 16pt — default padding
        static let md: CGFloat = 16
        /// 24pt
        static let lg: CGFloat = 24
        /// 32pt
        static let xl: CGFloat = 32
        /// 48pt
        static let xxl: CGFloat = 48
    }

    // MARK: - Corner Radius

    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let card: CGFloat = 20
        static let full: CGFloat = 999  // pill shape
    }

    // MARK: - Animation

    enum Animation {
        /// Session start: scale-up with spring (0.5s).
        static let sessionStart = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.7)

        /// Timer tick: subtle pulse on minute boundaries.
        static let timerPulse = SwiftUI.Animation.easeInOut(duration: 0.3)

        /// Score reveal: count-up animation (0.8s ease-out).
        static let scoreReveal = SwiftUI.Animation.easeOut(duration: 0.8)

        /// Standard transition for views.
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.25)

        /// Quick snap for interactive elements.
        static let quick = SwiftUI.Animation.easeOut(duration: 0.15)
    }

    // MARK: - Shadows

    enum Shadow {
        static let card = (color: Color.black.opacity(0.08), radius: CGFloat(12), y: CGFloat(4))
        static let button = (color: Color.black.opacity(0.12), radius: CGFloat(8), y: CGFloat(2))
    }

    // MARK: - Timer Ring

    enum TimerRing {
        static let lineWidth: CGFloat = 12
        static let trackOpacity: Double = 0.15
        static let size: CGFloat = 280
    }

    // MARK: - Session Presets

    enum SessionPreset {
        static let durations: [Int] = [15, 25, 35, 50]  // minutes
        static let defaultDuration: Int = 25              // Pomodoro baseline
        static let shortBreak: Int = 5                    // minutes
        static let longBreak: Int = 15                    // minutes
        static let longBreakInterval: Int = 4             // every N sessions
    }

    // MARK: - Session Types

    enum SessionType: String, CaseIterable, Identifiable {
        case work     = "work"
        case study    = "study"
        case creative = "creative"
        case personal = "personal"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .work:     return "Work"
            case .study:    return "Study"
            case .creative: return "Creative"
            case .personal: return "Personal"
            }
        }

        var iconName: String {
            switch self {
            case .work:     return "briefcase.fill"
            case .study:    return "book.fill"
            case .creative: return "paintbrush.fill"
            case .personal: return "person.fill"
            }
        }

        var color: Color {
            switch self {
            case .work:     return KairoColors.accentAdaptive
            case .study:    return Color(hex: 0x3498DB)
            case .creative: return Color(hex: 0x9B59B6)
            case .personal: return KairoColors.successAdaptive
            }
        }

        /// Whether this type requires Pro subscription.
        var requiresPro: Bool {
            switch self {
            case .work, .study, .personal: return false
            case .creative: return true
            }
        }
    }
}

// MARK: - Card Style Modifier

struct KairoCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
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

extension View {
    func kairoCard() -> some View {
        modifier(KairoCardStyle())
    }
}
