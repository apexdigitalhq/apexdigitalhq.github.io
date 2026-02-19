import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - App Group

/// Shared app group identifier for data exchange between the main app
/// and widget extensions.
private let kAppGroupSuite = "group.com.kairo.shared"

// MARK: - UserDefaults Keys

private enum WidgetKeys {
    static let focusData  = "widget.focusData"
    static let streakData = "widget.streakData"
}

// MARK: - FocusWidgetData

/// Lightweight transfer struct carrying today's focus metrics to the widget.
struct FocusWidgetData: Codable, Equatable {

    /// Total focused minutes accumulated today.
    let totalMinutes: Int

    /// Composite focus score (0–100).
    let score: Int

    /// Number of completed sessions today.
    let sessions: Int

    /// Current consecutive day streak.
    let streak: Int

    /// Hour of the day (0–23) with the highest focus output.
    let bestHour: Int?

    /// User's daily focus goal in minutes.
    let dailyGoalMinutes: Int

    // MARK: - Default

    /// Empty state used when no data has been written yet.
    static let empty = FocusWidgetData(
        totalMinutes: 0,
        score: 0,
        sessions: 0,
        streak: 0,
        bestHour: nil,
        dailyGoalMinutes: 120
    )
}

// MARK: - StreakWidgetData

/// Lightweight transfer struct carrying streak metrics to the widget.
struct StreakWidgetData: Codable, Equatable {

    /// Number of consecutive days the user has focused.
    let current: Int

    /// All-time longest streak achieved.
    let longest: Int

    /// Completion flags for the last 7 days (index 0 = oldest, 6 = today).
    let last7Days: [Bool]

    // MARK: - Default

    /// Empty state used when no data has been written yet.
    static let empty = StreakWidgetData(
        current: 0,
        longest: 0,
        last7Days: Array(repeating: false, count: 7)
    )
}

// MARK: - WidgetDataProvider

/// Bridge between the main Kairo app and its widget extension.
///
/// Both targets instantiate this class to read and write shared data
/// via `UserDefaults(suiteName:)` under the Kairo app group. The main
/// app calls `update*` methods after each session or daily recalculation;
/// widget providers call `read*` methods from their timeline builders.
///
/// Data is serialized as JSON via `Codable` for safety and forward
/// compatibility. After every write the provider triggers a widget
/// timeline reload so changes appear on the home screen promptly.
final class WidgetDataProvider {

    // MARK: - Shared Defaults

    /// Shared `UserDefaults` for the app group container.
    /// Falls back to `.standard` if the suite is unavailable (simulator edge case).
    private let defaults: UserDefaults

    /// JSON encoder reused across writes.
    private let encoder = JSONEncoder()

    /// JSON decoder reused across reads.
    private let decoder = JSONDecoder()

    // MARK: - Init

    /// Creates a provider backed by the shared app group defaults.
    init() {
        self.defaults = UserDefaults(suiteName: kAppGroupSuite) ?? .standard
    }

    // MARK: - Focus Data

    /// Writes updated focus metrics to the shared container and reloads
    /// widget timelines.
    ///
    /// Call this from the main app after each session completes or when
    /// daily totals are recalculated.
    ///
    /// - Parameters:
    ///   - totalMinutes: Total focused minutes today.
    ///   - score: Composite focus score (0–100).
    ///   - sessions: Number of completed sessions today.
    ///   - streak: Current consecutive day streak.
    ///   - bestHour: Hour (0–23) with the highest focus output.
    ///   - dailyGoal: Daily goal in minutes (default 120).
    func updateFocusData(
        totalMinutes: Int,
        score: Int,
        sessions: Int,
        streak: Int,
        bestHour: Int?,
        dailyGoal: Int = 120
    ) {
        let data = FocusWidgetData(
            totalMinutes: totalMinutes,
            score: score,
            sessions: sessions,
            streak: streak,
            bestHour: bestHour,
            dailyGoalMinutes: dailyGoal
        )
        write(data, forKey: WidgetKeys.focusData)
        reloadTimelines()
    }

    /// Reads the latest focus metrics from the shared container.
    ///
    /// - Returns: The stored `FocusWidgetData`, or `.empty` if nothing has
    ///   been written yet.
    func readFocusData() -> FocusWidgetData {
        read(FocusWidgetData.self, forKey: WidgetKeys.focusData) ?? .empty
    }

    // MARK: - Streak Data

    /// Writes updated streak metrics to the shared container and reloads
    /// widget timelines.
    ///
    /// Call this from the main app after each session completes or when
    /// the streak is recalculated at day boundaries.
    ///
    /// - Parameters:
    ///   - current: Current consecutive day streak.
    ///   - longest: All-time longest streak.
    ///   - last7Days: Completion flags for the last 7 days.
    func updateStreakData(
        current: Int,
        longest: Int,
        last7Days: [Bool]
    ) {
        let paddedDays = padOrTrim(last7Days, to: 7)
        let data = StreakWidgetData(
            current: current,
            longest: longest,
            last7Days: paddedDays
        )
        write(data, forKey: WidgetKeys.streakData)
        reloadTimelines()
    }

    /// Reads the latest streak metrics from the shared container.
    ///
    /// - Returns: The stored `StreakWidgetData`, or `.empty` if nothing has
    ///   been written yet.
    func readStreakData() -> StreakWidgetData {
        read(StreakWidgetData.self, forKey: WidgetKeys.streakData) ?? .empty
    }

    // MARK: - Private Helpers

    /// Encodes a `Codable` value to JSON and writes it to shared defaults.
    private func write<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    /// Reads a JSON blob from shared defaults and decodes it.
    private func read<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    /// Ensures the boolean array is exactly `count` elements long.
    private func padOrTrim(_ array: [Bool], to count: Int) -> [Bool] {
        if array.count == count { return array }
        if array.count > count { return Array(array.suffix(count)) }
        return Array(repeating: false, count: count - array.count) + array
    }

    /// Tells WidgetKit to reload all Kairo widget timelines.
    private func reloadTimelines() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
