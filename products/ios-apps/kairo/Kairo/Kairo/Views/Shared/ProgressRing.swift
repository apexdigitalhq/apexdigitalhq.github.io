import SwiftUI

/// A circular progress ring used as the primary timer visualization.
///
/// The ring fills clockwise from 12-o'clock. Supports configurable track/fill
/// colors, line width, and smooth animation driven by the bound progress value.
struct ProgressRing: View {
    /// 0.0 (empty) → 1.0 (full).
    let progress: Double
    /// Width of both the track and the fill stroke.
    var lineWidth: CGFloat = KairoTheme.TimerRing.lineWidth
    /// Background track color.
    var trackColor: Color = KairoColors.mutedAdaptive.opacity(KairoTheme.TimerRing.trackOpacity)
    /// Foreground fill color.
    var fillColor: Color = KairoColors.accentAdaptive
    /// When true, applies a subtle glow behind the fill arc.
    var glowEnabled: Bool = true

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(trackColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            // Fill
            Circle()
                .trim(from: 0, to: CGFloat(min(1.0, max(0, progress))))
                .stroke(
                    fillColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Glow layer (behind the fill, slightly wider)
            if glowEnabled && progress > 0 {
                Circle()
                    .trim(from: 0, to: CGFloat(min(1.0, max(0, progress))))
                    .stroke(
                        fillColor.opacity(0.3),
                        style: StrokeStyle(lineWidth: lineWidth + 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .blur(radius: 6)
            }
        }
        .animation(.linear(duration: 0.15), value: progress)
    }
}

// MARK: - Preview

#Preview("Progress Ring — 60%") {
    ProgressRing(progress: 0.6)
        .frame(width: 260, height: 260)
        .padding()
        .background(KairoColors.backgroundAdaptive)
}

#Preview("Progress Ring — Full") {
    ProgressRing(progress: 1.0, fillColor: KairoColors.successAdaptive)
        .frame(width: 260, height: 260)
        .padding()
        .background(KairoColors.backgroundAdaptive)
}
