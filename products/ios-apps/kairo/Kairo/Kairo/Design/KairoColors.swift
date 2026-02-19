import SwiftUI

/// Kairo color palette — light and dark mode adaptive.
enum KairoColors {

    // MARK: - Primary

    /// Main text and primary action color.
    static let primary = Color("primary", bundle: nil)
    static let primaryLight = Color(hex: 0x1A1A2E)
    static let primaryDark  = Color(hex: 0xE8E8F0)

    static var primaryAdaptive: Color {
        Color(light: primaryLight, dark: primaryDark)
    }

    // MARK: - Accent

    /// Timer ring, scores, CTAs.
    static let accent = Color("accent", bundle: nil)
    static let accentLight = Color(hex: 0xE94560)
    static let accentDark  = Color(hex: 0xFF6B81)

    static var accentAdaptive: Color {
        Color(light: accentLight, dark: accentDark)
    }

    // MARK: - Surface

    /// Card backgrounds.
    static let surface = Color("surface", bundle: nil)
    static let surfaceLight = Color(hex: 0xFFFFFF)
    static let surfaceDark  = Color(hex: 0x16213E)

    static var surfaceAdaptive: Color {
        Color(light: surfaceLight, dark: surfaceDark)
    }

    // MARK: - Background

    /// Screen backgrounds.
    static let background = Color("background", bundle: nil)
    static let backgroundLight = Color(hex: 0xF5F5FA)
    static let backgroundDark  = Color(hex: 0x0F3460)

    static var backgroundAdaptive: Color {
        Color(light: backgroundLight, dark: backgroundDark)
    }

    // MARK: - Semantic

    /// Completed sessions, high scores.
    static let success = Color("success", bundle: nil)
    static let successLight = Color(hex: 0x2ECC71)
    static let successDark  = Color(hex: 0x27AE60)

    static var successAdaptive: Color {
        Color(light: successLight, dark: successDark)
    }

    /// Medium scores, streak at risk.
    static let warning = Color("warning", bundle: nil)
    static let warningLight = Color(hex: 0xF39C12)
    static let warningDark  = Color(hex: 0xE67E22)

    static var warningAdaptive: Color {
        Color(light: warningLight, dark: warningDark)
    }

    /// Secondary text, borders.
    static let muted = Color("muted", bundle: nil)
    static let mutedLight = Color(hex: 0x95A5A6)
    static let mutedDark  = Color(hex: 0x5D6D7E)

    static var mutedAdaptive: Color {
        Color(light: mutedLight, dark: mutedDark)
    }

    // MARK: - Focus Score Level Colors

    static func scoreColor(for score: Float) -> Color {
        switch score {
        case 90...100: return successAdaptive
        case 70..<90:  return accentAdaptive
        case 50..<70:  return warningAdaptive
        case 30..<50:  return Color.orange
        default:       return mutedAdaptive
        }
    }
}

// MARK: - Color Hex Initializer

extension Color {

    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }

    /// Creates a color that adapts between light and dark appearances.
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
}
