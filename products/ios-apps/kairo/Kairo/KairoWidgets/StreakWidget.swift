import SwiftUI
import WidgetKit

// MARK: - StreakEntry

/// Timeline entry carrying current streak data for the streak widget.
struct StreakEntry: TimelineEntry {

    /// The date this entry represents.
    let date: Date

    /// Number of consecutive days the user has focused.
    let currentStreak: Int

    /// All-time longest streak achieved.
    let longestStreak: Int

    /// Completion flags for the last 7 days (index 0 = oldest, 6 = today).
    let last7Days: [Bool]

    /// Contextual motivational message.
    let motivationalMessage: String

    // MARK: - Placeholder

    /// Default placeholder entry shown while data loads.
    static let placeholder = StreakEntry(
        date: .now,
        currentStreak: 7,
        longestStreak: 14,
        last7Days: [true, true, false, true, true, true, true],
        motivationalMessage: "You're on fire! Keep going 🔥"
    )
}

// MARK: - StreakProvider

/// Timeline provider that reads streak data from the shared app group
/// and schedules daily updates at midnight plus post-session refreshes.
struct StreakProvider: TimelineProvider {

    private let dataProvider = WidgetDataProvider()

    func placeholder(in context: Context) -> StreakEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
        } else {
            completion(currentEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let entry = currentEntry()

        // Schedule next update at midnight to reflect the new day.
        let nextMidnight = Calendar.current.nextDate(
            after: entry.date,
            matching: DateComponents(hour: 0, minute: 1),
            matchingPolicy: .nextTime
        ) ?? Calendar.current.date(byAdding: .hour, value: 1, to: entry.date)!

        let timeline = Timeline(entries: [entry], policy: .after(nextMidnight))
        completion(timeline)
    }

    // MARK: - Private

    /// Reads the latest streak data from the shared container.
    private func currentEntry() -> StreakEntry {
        let data = dataProvider.readStreakData()
        return StreakEntry(
            date: .now,
            currentStreak: data.current,
            longestStreak: data.longest,
            last7Days: data.last7Days,
            motivationalMessage: motivationalMessage(for: data.current)
        )
    }

    /// Generates a contextual motivational message based on streak length.
    private func motivationalMessage(for streak: Int) -> String {
        switch streak {
        case 0:
            return "Start today — every streak begins with one session."
        case 1:
            return "Day 1 done! Come back tomorrow to build momentum."
        case 2:
            return "Two days in — the habit is forming. Keep it up!"
        case 3...6:
            return "Nice streak! You're building real consistency. 💪"
        case 7...13:
            return "A full week+! Your focus habit is taking hold. 🔥"
        case 14...29:
            return "Two weeks strong — you're in the top tier. 🏆"
        case 30...99:
            return "Over a month! Incredible discipline. 🚀"
        default:
            return "Triple digits! You're a focus legend. 👑"
        }
    }
}

// MARK: - StreakWidget

/// Home screen widget displaying the current focus streak.
///
/// Supports `.systemSmall` (big streak number with fire) and `.systemMedium`
/// (streak + 7-day history dots + motivational message).
struct StreakWidget: Widget {

    let kind: String = "StreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider()) { entry in
            StreakWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    streakBackground(for: entry.currentStreak)
                }
        }
        .configurationDisplayName("Focus Streak")
        .description("Stay motivated with your daily focus streak.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }

    /// Background gradient that intensifies with streak length.
    private func streakBackground(for streak: Int) -> some View {
        LinearGradient(
            colors: StreakColors.backgroundGradient(for: streak),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - StreakWidgetView

/// Root view that switches layout based on widget family.
struct StreakWidgetView: View {

    @Environment(\.widgetFamily) var family
    let entry: StreakEntry

    var body: some View {
        switch family {
        case .systemMedium:
            MediumStreakView(entry: entry)
        default:
            SmallStreakView(entry: entry)
        }
    }
}

// MARK: - SmallStreakView

/// Compact display: bold streak number + 🔥 emoji + "day streak" label.
struct SmallStreakView: View {

    let entry: StreakEntry

    var body: some View {
        VStack(spacing: 4) {
            Text("🔥")
                .font(.system(size: 36))

            Text("\(entry.currentStreak)")
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            Text(entry.currentStreak == 1 ? "day streak" : "day streak")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
        }
    }
}

// MARK: - MediumStreakView

/// Wider layout: streak number + 7-day dots + motivational message.
struct MediumStreakView: View {

    let entry: StreakEntry

    var body: some View {
        HStack(spacing: 16) {
            // Left: streak number stack
            VStack(spacing: 4) {
                Text("🔥")
                    .font(.system(size: 28))

                Text("\(entry.currentStreak)")
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text(entry.currentStreak == 1 ? "day" : "days")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(width: 90)

            // Right: history + message
            VStack(alignment: .leading, spacing: 12) {
                weekDots
                messageLabel
                longestStreakLabel
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - 7-Day Dots

    /// Row of 7 circles representing the last 7 days.
    private var weekDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { index in
                let completed = index < entry.last7Days.count && entry.last7Days[index]
                Circle()
                    .fill(completed ? .white : .white.opacity(0.25))
                    .frame(width: 12, height: 12)
                    .overlay {
                        if completed {
                            Circle()
                                .stroke(.white.opacity(0.4), lineWidth: 1)
                        }
                    }
            }
        }
    }

    // MARK: - Message Label

    /// Motivational text below the dots.
    private var messageLabel: some View {
        Text(entry.motivationalMessage)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.9))
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Longest Streak

    /// Shows the all-time best streak if it exceeds the current one.
    @ViewBuilder
    private var longestStreakLabel: some View {
        if entry.longestStreak > entry.currentStreak {
            HStack(spacing: 4) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.6))

                Text("Best: \(entry.longestStreak) days")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }
}

// MARK: - StreakColors

/// Color tiers that intensify with streak length.
///
/// Streak < 3  → warm yellow
/// Streak 3–6  → orange
/// Streak 7–13 → deep orange
/// Streak 14+  → red / fire
enum StreakColors {

    /// Returns a pair of gradient colors for the streak background.
    static func backgroundGradient(for streak: Int) -> [Color] {
        switch streak {
        case 0...2:
            // Warm yellow
            return [Color(hex: 0xF9A825), Color(hex: 0xF57F17)]
        case 3...6:
            // Orange
            return [Color(hex: 0xFB8C00), Color(hex: 0xEF6C00)]
        case 7...13:
            // Deep orange
            return [Color(hex: 0xF4511E), Color(hex: 0xD84315)]
        default:
            // Red / fire
            return [Color(hex: 0xE53935), Color(hex: 0xB71C1C)]
        }
    }

    /// Foreground accent that pairs with each background tier.
    static func foregroundAccent(for streak: Int) -> Color {
        switch streak {
        case 0...2:
            return Color(hex: 0xFFF8E1)
        case 3...6:
            return Color(hex: 0xFFF3E0)
        case 7...13:
            return Color(hex: 0xFBE9E7)
        default:
            return Color(hex: 0xFFEBEE)
        }
    }
}

// MARK: - Previews

#Preview("Small Streak", as: .systemSmall) {
    StreakWidget()
} timeline: {
    StreakEntry.placeholder
    StreakEntry(
        date: .now,
        currentStreak: 21,
        longestStreak: 30,
        last7Days: [true, true, true, true, true, true, true],
        motivationalMessage: "Three weeks! Unstoppable. 🔥"
    )
}

#Preview("Medium Streak", as: .systemMedium) {
    StreakWidget()
} timeline: {
    StreakEntry.placeholder
    StreakEntry(
        date: .now,
        currentStreak: 1,
        longestStreak: 14,
        last7Days: [false, false, false, false, false, false, true],
        motivationalMessage: "Day 1 done! Come back tomorrow to build momentum."
    )
}
