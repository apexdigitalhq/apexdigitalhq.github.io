import SwiftUI
import WidgetKit

// MARK: - FocusTimeEntry

/// Timeline entry carrying today's focus metrics for display in the widget.
struct FocusTimeEntry: TimelineEntry {

    /// The date this entry represents.
    let date: Date

    /// Total focused minutes accumulated today.
    let totalMinutesToday: Int

    /// User's daily focus goal in minutes (default 120).
    let dailyGoalMinutes: Int

    /// Composite focus score (0–100) for today.
    let focusScore: Int

    /// Number of completed sessions today.
    let sessionsCompleted: Int

    /// Current consecutive day streak.
    let streakDays: Int

    /// Hour of the day (0–23) with the highest focus output, if any.
    let bestHour: Int?

    // MARK: - Placeholder

    /// Default placeholder entry shown while data loads.
    static let placeholder = FocusTimeEntry(
        date: .now,
        totalMinutesToday: 47,
        dailyGoalMinutes: 120,
        focusScore: 72,
        sessionsCompleted: 3,
        streakDays: 5,
        bestHour: 9
    )
}

// MARK: - FocusTimeProvider

/// Timeline provider that reads shared `UserDefaults` and schedules
/// updates every 30 minutes to keep the widget reasonably fresh.
struct FocusTimeProvider: TimelineProvider {

    private let dataProvider = WidgetDataProvider()

    func placeholder(in context: Context) -> FocusTimeEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (FocusTimeEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
        } else {
            completion(currentEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FocusTimeEntry>) -> Void) {
        let entry = currentEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: entry.date) ?? entry.date
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    // MARK: - Private

    /// Reads the latest focus data from the shared app group container.
    private func currentEntry() -> FocusTimeEntry {
        let data = dataProvider.readFocusData()
        return FocusTimeEntry(
            date: .now,
            totalMinutesToday: data.totalMinutes,
            dailyGoalMinutes: data.dailyGoalMinutes,
            focusScore: data.score,
            sessionsCompleted: data.sessions,
            streakDays: data.streak,
            bestHour: data.bestHour
        )
    }
}

// MARK: - FocusTimeWidget

/// Home screen widget displaying today's focus progress.
///
/// Supports `.systemSmall` (progress ring + score) and `.systemMedium`
/// (ring + sessions, streak, and best-hour details).
struct FocusTimeWidget: Widget {

    let kind: String = "FocusTimeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FocusTimeProvider()) { entry in
            FocusTimeWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetColors.background
                }
        }
        .configurationDisplayName("Focus Time")
        .description("Track today's focus progress at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - FocusTimeWidgetView

/// Root view that switches layout based on widget family.
struct FocusTimeWidgetView: View {

    @Environment(\.widgetFamily) var family
    let entry: FocusTimeEntry

    var body: some View {
        switch family {
        case .systemMedium:
            MediumFocusView(entry: entry)
        case .accessoryCircular:
            LockScreenCircularView(entry: entry)
        case .accessoryRectangular:
            LockScreenRectangularView(entry: entry)
        case .accessoryInline:
            LockScreenInlineView(entry: entry)
        default:
            SmallFocusView(entry: entry)
        }
    }
}

// MARK: - Lock Screen Circular

struct LockScreenCircularView: View {
    let entry: FocusTimeEntry

    private var progress: Double {
        guard entry.dailyGoalMinutes > 0 else { return 0 }
        return min(1.0, Double(entry.totalMinutesToday) / Double(entry.dailyGoalMinutes))
    }

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()

            Gauge(value: progress) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 10))
            } currentValueLabel: {
                Text("\(entry.focusScore)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }
            .gaugeStyle(.accessoryCircularCapacity)
        }
        .widgetURL(URL(string: "kairo://start"))
    }
}

// MARK: - Lock Screen Rectangular

struct LockScreenRectangularView: View {
    let entry: FocusTimeEntry

    private var progress: Double {
        guard entry.dailyGoalMinutes > 0 else { return 0 }
        return min(1.0, Double(entry.totalMinutesToday) / Double(entry.dailyGoalMinutes))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 11, weight: .semibold))
                Text("Kairo")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                Spacer()
                if entry.streakDays > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 9))
                        Text("\(entry.streakDays)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                }
            }

            HStack(spacing: 8) {
                Text("\(entry.totalMinutesToday)m")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text("·")
                Text("\(entry.sessionsCompleted) sessions")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
            }

            ProgressView(value: progress)
                .tint(.white)
        }
        .widgetURL(URL(string: "kairo://start"))
    }
}

// MARK: - Lock Screen Inline

struct LockScreenInlineView: View {
    let entry: FocusTimeEntry

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "brain.head.profile")
            Text("\(entry.totalMinutesToday)m focused")
            if entry.streakDays > 0 {
                Text("· 🔥\(entry.streakDays)")
            }
        }
        .widgetURL(URL(string: "kairo://start"))
    }
}

// MARK: - SmallFocusView

/// Compact circular progress ring with the focus score centered.
struct SmallFocusView: View {

    let entry: FocusTimeEntry

    /// Progress clamped to [0, 1].
    private var progress: Double {
        guard entry.dailyGoalMinutes > 0 else { return 0 }
        return min(1.0, Double(entry.totalMinutesToday) / Double(entry.dailyGoalMinutes))
    }

    var body: some View {
        ZStack {
            // Track ring
            Circle()
                .stroke(
                    WidgetColors.accent.opacity(0.15),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .padding(12)

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    progressGradient,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .padding(12)

            // Center content
            VStack(spacing: 2) {
                Text("\(entry.focusScore)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(WidgetColors.primary)

                Text("\(entry.totalMinutesToday)m")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(WidgetColors.muted)
            }
        }
    }

    /// Gradient that shifts from accent to success as progress increases.
    private var progressGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [WidgetColors.accent, WidgetColors.accentBright]),
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360 * progress)
        )
    }
}

// MARK: - MediumFocusView

/// Wider layout: progress ring on the left, stat rows on the right.
struct MediumFocusView: View {

    let entry: FocusTimeEntry

    /// Progress clamped to [0, 1].
    private var progress: Double {
        guard entry.dailyGoalMinutes > 0 else { return 0 }
        return min(1.0, Double(entry.totalMinutesToday) / Double(entry.dailyGoalMinutes))
    }

    var body: some View {
        HStack(spacing: 16) {
            // Left: progress ring
            ZStack {
                Circle()
                    .stroke(
                        WidgetColors.accent.opacity(0.15),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        progressGradient,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 1) {
                    Text("\(entry.focusScore)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetColors.primary)

                    Text("\(entry.totalMinutesToday)/\(entry.dailyGoalMinutes)m")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(WidgetColors.muted)
                }
            }
            .frame(width: 100, height: 100)

            // Right: stat rows
            VStack(alignment: .leading, spacing: 10) {
                StatRow(
                    icon: "checkmark.circle.fill",
                    label: "Sessions",
                    value: "\(entry.sessionsCompleted)",
                    color: WidgetColors.success
                )

                StatRow(
                    icon: "flame.fill",
                    label: "Streak",
                    value: "\(entry.streakDays) days",
                    color: Color(hex: 0xE67E22)
                )

                if let bestHour = entry.bestHour {
                    StatRow(
                        icon: "star.fill",
                        label: "Best Hour",
                        value: formattedHour(bestHour),
                        color: WidgetColors.accent
                    )
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }

    /// Gradient that shifts from accent to its brighter variant.
    private var progressGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [WidgetColors.accent, WidgetColors.accentBright]),
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360 * progress)
        )
    }

    /// Formats a 24-hour value into a human-readable label like "9 AM".
    private func formattedHour(_ hour: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return "\(displayHour) \(period)"
    }
}

// MARK: - StatRow

/// A single icon + label + value row used in the medium widget.
struct StatRow: View {

    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 16)

            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(WidgetColors.muted)

            Spacer(minLength: 4)

            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(WidgetColors.primary)
        }
    }
}

// MARK: - WidgetColors

/// Self-contained color definitions for the widget extension.
///
/// Widget targets cannot import the main app module, so we replicate
/// Kairo's design palette here using the same hex values defined in
/// `KairoColors`. Adapts automatically for light/dark appearances.
enum WidgetColors {

    /// Main text color — adapts between near-black and soft white.
    static let primary = Color(
        light: Color(hex: 0x1A1A2E),
        dark: Color(hex: 0xE8E8F0)
    )

    /// Accent — timer rings, scores, CTAs.
    static let accent = Color(
        light: Color(hex: 0xE94560),
        dark: Color(hex: 0xFF6B81)
    )

    /// Brighter accent variant for gradient endpoints.
    static let accentBright = Color(
        light: Color(hex: 0xFF6B81),
        dark: Color(hex: 0xFF8FA3)
    )

    /// Success — completed sessions, high scores.
    static let success = Color(
        light: Color(hex: 0x2ECC71),
        dark: Color(hex: 0x27AE60)
    )

    /// Secondary text and labels.
    static let muted = Color(
        light: Color(hex: 0x95A5A6),
        dark: Color(hex: 0x5D6D7E)
    )

    /// Widget background.
    static let background = Color(
        light: Color(hex: 0xF5F5FA),
        dark: Color(hex: 0x0F3460)
    )

    /// Card / surface.
    static let surface = Color(
        light: Color(hex: 0xFFFFFF),
        dark: Color(hex: 0x16213E)
    )
}

// Color hex initializer and light/dark init are provided by shared KairoColors.swift

// MARK: - Previews

#Preview("Small Focus", as: .systemSmall) {
    FocusTimeWidget()
} timeline: {
    FocusTimeEntry.placeholder
    FocusTimeEntry(
        date: .now,
        totalMinutesToday: 95,
        dailyGoalMinutes: 120,
        focusScore: 88,
        sessionsCompleted: 5,
        streakDays: 12,
        bestHour: 10
    )
}

#Preview("Medium Focus", as: .systemMedium) {
    FocusTimeWidget()
} timeline: {
    FocusTimeEntry.placeholder
}
