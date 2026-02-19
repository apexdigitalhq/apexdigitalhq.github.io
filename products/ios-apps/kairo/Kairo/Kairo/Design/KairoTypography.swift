import SwiftUI

/// Kairo typography system — SF Pro family, consistent sizing.
enum KairoTypography {

    // MARK: - Display (Timer Countdown)

    /// Large timer countdown — SF Pro Rounded, Bold.
    static let timerDisplay = Font.system(size: 72, weight: .bold, design: .rounded)

    /// Smaller timer display for break screens.
    static let timerDisplaySmall = Font.system(size: 48, weight: .bold, design: .rounded)

    /// Preparing countdown (3-2-1).
    static let countdownDisplay = Font.system(size: 96, weight: .bold, design: .rounded)

    // MARK: - Headings (SF Pro, Semibold)

    static let heading1 = Font.system(size: 28, weight: .semibold)
    static let heading2 = Font.system(size: 22, weight: .semibold)
    static let heading3 = Font.system(size: 18, weight: .semibold)

    // MARK: - Body (SF Pro, Regular)

    static let bodyLarge  = Font.system(size: 17, weight: .regular)
    static let body       = Font.system(size: 15, weight: .regular)
    static let bodySmall  = Font.system(size: 13, weight: .regular)

    // MARK: - Labels

    static let label      = Font.system(size: 13, weight: .medium)
    static let labelSmall = Font.system(size: 11, weight: .medium)

    // MARK: - Mono (Scores, Stats — SF Mono)

    static let scoreLarge = Font.system(size: 36, weight: .bold, design: .monospaced)
    static let scoreMedium = Font.system(size: 24, weight: .semibold, design: .monospaced)
    static let scoreSmall = Font.system(size: 16, weight: .medium, design: .monospaced)
    static let statValue = Font.system(size: 20, weight: .semibold, design: .monospaced)

    // MARK: - Caption

    static let caption = Font.system(size: 11, weight: .regular)
}

// MARK: - View Modifier Convenience

extension View {

    func kairoFont(_ font: Font) -> some View {
        self.font(font)
    }
}
