import SwiftUI

// MARK: - Custom Goal Model

/// A user-created focus goal stored locally via UserDefaults.
struct CustomGoal: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var targetValue: Int
    var currentProgress: Int = 0   // Actual tracked progress — updated per session
    var goalType: GoalType
    var timeFrame: TimeFrame
    var activity: FocusActivity
    var createdAt: Date = Date()
    var lastResetDate: Date = Date()  // When the period last reset
    var reminderEnabled: Bool = true
    var reminderHour: Int = 9     // Default 9 AM reminder
    var reminderMinute: Int = 0

    /// Whether this goal's time period has expired and needs a reset.
    var needsReset: Bool {
        let now = Date()
        switch timeFrame {
        case .daily:
            return !Calendar.current.isDate(lastResetDate, inSameDayAs: now)
        case .weekly:
            let lastWeek = Calendar.current.component(.weekOfYear, from: lastResetDate)
            let thisWeek = Calendar.current.component(.weekOfYear, from: now)
            let lastYear = Calendar.current.component(.year, from: lastResetDate)
            let thisYear = Calendar.current.component(.year, from: now)
            return lastWeek != thisWeek || lastYear != thisYear
        case .monthly:
            let lastMonth = Calendar.current.component(.month, from: lastResetDate)
            let thisMonth = Calendar.current.component(.month, from: now)
            let lastYear = Calendar.current.component(.year, from: lastResetDate)
            let thisYear = Calendar.current.component(.year, from: now)
            return lastMonth != thisMonth || lastYear != thisYear
        }
    }

    /// Progress percentage (0.0–1.0).
    var progress: Double {
        guard targetValue > 0 else { return 0 }
        return min(1.0, Double(currentProgress) / Double(targetValue))
    }

    /// Whether the goal is achieved for this period.
    var isAchieved: Bool {
        currentProgress >= targetValue
    }

    enum GoalType: String, Codable, CaseIterable {
        case sessions = "sessions"
        case minutes = "minutes"
        case days = "days"

        var displayName: String {
            switch self {
            case .sessions: return "Sessions"
            case .minutes: return "Minutes"
            case .days: return "Days"
            }
        }

        var icon: String {
            switch self {
            case .sessions: return "flame.fill"
            case .minutes: return "clock.fill"
            case .days: return "calendar.badge.checkmark"
            }
        }

        var color: Color {
            switch self {
            case .sessions: return Color.orange
            case .minutes: return Color(hex: 0x3498DB)
            case .days: return Color(hex: 0x2ECC71)
            }
        }

        var subtitle: String {
            switch self {
            case .sessions: return "Completed sessions"
            case .minutes: return "Focus minutes"
            case .days: return "Days with a session"
            }
        }
    }

    enum TimeFrame: String, Codable, CaseIterable {
        case daily = "daily"
        case weekly = "weekly"
        case monthly = "monthly"

        var displayName: String {
            switch self {
            case .daily: return "Daily"
            case .weekly: return "Weekly"
            case .monthly: return "Monthly"
            }
        }

        var icon: String {
            switch self {
            case .daily: return "sun.max.fill"
            case .weekly: return "calendar"
            case .monthly: return "calendar.badge.clock"
            }
        }

        var color: Color {
            switch self {
            case .daily: return Color(hex: 0xF39C12)
            case .weekly: return Color(hex: 0x9B59B6)
            case .monthly: return Color(hex: 0x3498DB)
            }
        }

        var label: String {
            switch self {
            case .daily: return "today"
            case .weekly: return "this week"
            case .monthly: return "this month"
            }
        }

        /// Start date for the current period.
        var periodStart: Date {
            let cal = Calendar.current
            let now = Date()
            switch self {
            case .daily:
                return cal.startOfDay(for: now)
            case .weekly:
                var components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
                components.weekday = cal.firstWeekday
                return cal.date(from: components) ?? cal.startOfDay(for: now)
            case .monthly:
                var components = cal.dateComponents([.year, .month], from: now)
                components.day = 1
                return cal.date(from: components) ?? cal.startOfDay(for: now)
            }
        }

        /// How much time is left in the period.
        var timeRemaining: String {
            let cal = Calendar.current
            let now = Date()
            switch self {
            case .daily:
                let endOfDay = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now))!
                let hours = cal.dateComponents([.hour], from: now, to: endOfDay).hour ?? 0
                return "\(hours)h left"
            case .weekly:
                let endOfWeek = cal.date(byAdding: .day, value: 7, to: periodStart)!
                let days = cal.dateComponents([.day], from: now, to: endOfWeek).day ?? 0
                return "\(days)d left"
            case .monthly:
                let endOfMonth = cal.date(byAdding: .month, value: 1, to: periodStart)!
                let days = cal.dateComponents([.day], from: now, to: endOfMonth).day ?? 0
                return "\(days)d left"
            }
        }
    }

    // MARK: - Focus Activity

    enum FocusActivity: Codable, Equatable, Hashable {
        case studying
        case reading
        case deepWork
        case creative
        case meditation
        case yoga
        case mindfulness
        case exercise
        case personal
        case custom(String)

        var displayName: String {
            switch self {
            case .studying:    return "Studying"
            case .reading:     return "Reading"
            case .deepWork:    return "Deep Work"
            case .creative:    return "Creative"
            case .meditation:  return "Meditation"
            case .yoga:        return "Yoga"
            case .mindfulness: return "Mindfulness"
            case .exercise:    return "Exercise"
            case .personal:    return "Personal"
            case .custom(let name): return name
            }
        }

        var icon: String {
            switch self {
            case .studying:    return "book.fill"
            case .reading:     return "text.book.closed.fill"
            case .deepWork:    return "laptopcomputer"
            case .creative:    return "paintbrush.fill"
            case .meditation:  return "brain.head.profile"
            case .yoga:        return "figure.yoga"
            case .mindfulness: return "leaf.fill"
            case .exercise:    return "figure.run"
            case .personal:    return "person.fill"
            case .custom:      return "star.fill"
            }
        }

        var color: Color {
            switch self {
            case .studying:    return Color(hex: 0x3498DB)
            case .reading:     return Color(hex: 0x9B59B6)
            case .deepWork:    return Color(hex: 0x2C3E50)
            case .creative:    return Color(hex: 0xE74C3C)
            case .meditation:  return Color(hex: 0x1ABC9C)
            case .yoga:        return Color(hex: 0x16A085)
            case .mindfulness: return Color(hex: 0x27AE60)
            case .exercise:    return Color(hex: 0xF39C12)
            case .personal:    return Color(hex: 0x8E44AD)
            case .custom:      return Color(hex: 0x2980B9)
            }
        }

        static var allBuiltIn: [FocusActivity] {
            [.studying, .reading, .deepWork, .creative, .meditation, .yoga, .mindfulness, .exercise, .personal]
        }
    }

    /// Placeholder text for target value based on type + timeframe.
    var placeholder: String {
        switch (goalType, timeFrame) {
        case (.sessions, .daily): return "e.g. 3"
        case (.sessions, .weekly): return "e.g. 15"
        case (.sessions, .monthly): return "e.g. 50"
        case (.minutes, .daily): return "e.g. 60"
        case (.minutes, .weekly): return "e.g. 300"
        case (.minutes, .monthly): return "e.g. 1000"
        case (.days, .weekly): return "e.g. 5"
        case (.days, .monthly): return "e.g. 20"
        case (.days, .daily): return "e.g. 1"
        }
    }
}

// MARK: - Custom Goal Store

/// Manages persistence of custom goals and progress tracking.
/// Progress is tracked per-goal and resets at the start of each time period.
class CustomGoalStore: ObservableObject {

    @Published var goals: [CustomGoal] = []

    private let storageKey = "kairo_custom_goals"

    init() {
        load()
        resetExpiredGoals()
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([CustomGoal].self, from: data) else {
            goals = []
            return
        }
        goals = decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(goals) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    func add(_ goal: CustomGoal) {
        var newGoal = goal
        newGoal.currentProgress = 0
        newGoal.lastResetDate = Date()
        goals.append(newGoal)
        save()
        scheduleReminder(for: newGoal)
    }

    func remove(id: UUID) {
        cancelReminder(for: id)
        goals.removeAll { $0.id == id }
        save()
    }

    /// Reset progress for goals whose time period has expired.
    func resetExpiredGoals() {
        var changed = false
        for i in goals.indices {
            if goals[i].needsReset {
                goals[i].currentProgress = 0
                goals[i].lastResetDate = Date()
                changed = true
            }
        }
        if changed { save() }
    }

    /// Called after a session completes to update goal progress.
    /// - Parameters:
    ///   - sessionMinutes: Duration of the completed session in minutes.
    ///   - sessionDate: When the session happened.
    func recordSession(sessionMinutes: Int, sessionDate: Date = Date()) {
        resetExpiredGoals()

        for i in goals.indices {
            switch goals[i].goalType {
            case .sessions:
                goals[i].currentProgress += 1
            case .minutes:
                goals[i].currentProgress += sessionMinutes
            case .days:
                // Only increment if we haven't already counted today
                let lastIncrement = goals[i].lastResetDate
                if !Calendar.current.isDate(lastIncrement, inSameDayAs: sessionDate)
                    || goals[i].currentProgress == 0 {
                    goals[i].currentProgress += 1
                }
            }
        }
        save()
    }

    /// Static convenience for updating goals from anywhere (e.g. SessionCoordinator).
    /// Creates a fresh store, loads goals, records progress, and saves.
    func recordSessionAndSync(sessionMinutes: Int) {
        load()
        recordSession(sessionMinutes: sessionMinutes)
    }

    // MARK: - Notifications

    /// Schedule a daily reminder notification for a goal.
    func scheduleReminder(for goal: CustomGoal) {
        guard goal.reminderEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Goal Reminder: \(goal.title)"
        content.body = goalReminderMessage(for: goal)
        content.sound = .default
        content.categoryIdentifier = "GOAL_REMINDER"

        var dateComponents = DateComponents()
        dateComponents.hour = goal.reminderHour
        dateComponents.minute = goal.reminderMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "goal-\(goal.id.uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Cancel reminder for a goal.
    func cancelReminder(for goalId: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["goal-\(goalId.uuidString)"]
        )
    }

    /// Reschedule all active goal reminders.
    func rescheduleAllReminders() {
        for goal in goals where goal.reminderEnabled {
            cancelReminder(for: goal.id)
            scheduleReminder(for: goal)
        }
    }

    /// Toggle reminder for a specific goal.
    func toggleReminder(for goalId: UUID) {
        guard let idx = goals.firstIndex(where: { $0.id == goalId }) else { return }
        goals[idx].reminderEnabled.toggle()
        if goals[idx].reminderEnabled {
            scheduleReminder(for: goals[idx])
        } else {
            cancelReminder(for: goalId)
        }
        save()
    }

    private func goalReminderMessage(for goal: CustomGoal) -> String {
        let remaining = max(0, goal.targetValue - goal.currentProgress)
        let unit = goal.goalType.displayName.lowercased()

        if goal.isAchieved {
            return "You've hit your goal! 🎉 \(goal.targetValue) \(unit) \(goal.timeFrame.label). Keep going!"
        }

        switch goal.timeFrame {
        case .daily:
            return "You need \(remaining) more \(unit) today. You've got this! 💪"
        case .weekly:
            return "\(remaining) \(unit) left this week for \"\(goal.title)\". Stay on track! 🎯"
        case .monthly:
            return "\(remaining) \(unit) to go this month. Keep pushing! 🔥"
        }
    }
}

import UserNotifications
