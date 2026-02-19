import UserNotifications
import UIKit
import Combine

/// Manages all local notifications for Kairo — session completion,
/// daily focus reminders, and badge count.
///
/// Usage:
/// ```swift
/// let manager = NotificationManager.shared
/// await manager.requestPermission()
/// manager.scheduleSessionComplete(in: 25 * 60, sessionType: "Work")
/// manager.scheduleDailyReminder(hour: 9, minute: 0)
/// ```
final class NotificationManager: ObservableObject {

    static let shared = NotificationManager()

    // MARK: - Published State

    /// Current authorization status.
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    /// Whether notifications are fully authorized.
    @Published private(set) var isAuthorized: Bool = false

    /// Whether we've already requested permission this install.
    @Published private(set) var hasRequestedPermission: Bool = false

    // MARK: - Constants

    private enum NotificationID {
        static let sessionComplete = "kairo.session.complete"
        static let dailyReminder = "kairo.daily.reminder"
        static let streakReminder = "kairo.streak.reminder"
    }

    private enum DefaultsKey {
        static let hasRequestedPermission = "kairo_notif_requested"
        static let dailyReminderEnabled = "kairo_daily_reminder_enabled"
        static let dailyReminderHour = "kairo_daily_reminder_hour"
        static let dailyReminderMinute = "kairo_daily_reminder_minute"
    }

    private let center = UNUserNotificationCenter.current()

    // MARK: - Init

    private init() {
        hasRequestedPermission = UserDefaults.standard.bool(forKey: DefaultsKey.hasRequestedPermission)
        Task { await refreshAuthorizationStatus() }
    }

    // MARK: - Permission

    /// Request notification permission. Safe to call multiple times —
    /// only shows the system prompt once.
    @MainActor
    @discardableResult
    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(
                options: [.alert, .sound, .badge]
            )

            hasRequestedPermission = true
            UserDefaults.standard.set(true, forKey: DefaultsKey.hasRequestedPermission)

            await refreshAuthorizationStatus()
            return granted
        } catch {
            #if DEBUG
            print("[NotificationManager] Permission request failed: \(error.localizedDescription)")
            #endif
            return false
        }
    }

    /// Request permission only if we haven't asked before.
    /// Ideal for calling on first session start.
    @MainActor
    func requestPermissionIfNeeded() async {
        guard !hasRequestedPermission else { return }
        await requestPermission()
    }

    /// Refresh the current authorization status from the system.
    @MainActor
    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        isAuthorized = settings.authorizationStatus == .authorized
    }

    // MARK: - Session Complete Notification

    /// Schedule a notification for when the focus session completes.
    ///
    /// - Parameters:
    ///   - interval: Time interval in seconds until session ends.
    ///   - sessionType: Display name of the session type (e.g., "Work").
    ///   - duration: Session duration in minutes (for display).
    func scheduleSessionComplete(
        in interval: TimeInterval,
        sessionType: String = "Focus",
        duration: Int = 25
    ) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Session Complete! 🎯"
        content.body = "Great work! Your \(duration)-minute \(sessionType.lowercased()) session is done."
        content.sound = .default
        content.categoryIdentifier = "SESSION_COMPLETE"

        // Custom data for deep linking
        content.userInfo = [
            "type": "session_complete",
            "sessionType": sessionType,
            "duration": duration
        ]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(interval, 1),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: NotificationID.sessionComplete,
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            #if DEBUG
            if let error {
                print("[NotificationManager] Failed to schedule session notification: \(error.localizedDescription)")
            }
            #endif
        }
    }

    /// Cancel a pending session complete notification (e.g., user stopped early).
    func cancelSessionComplete() {
        center.removePendingNotificationRequests(
            withIdentifiers: [NotificationID.sessionComplete]
        )
    }

    // MARK: - Daily Focus Reminder

    /// Schedule a recurring daily reminder to focus.
    ///
    /// - Parameters:
    ///   - hour: Hour of day (0-23).
    ///   - minute: Minute of hour (0-59).
    func scheduleDailyReminder(hour: Int, minute: Int) {
        guard isAuthorized else { return }

        // Persist settings
        UserDefaults.standard.set(true, forKey: DefaultsKey.dailyReminderEnabled)
        UserDefaults.standard.set(hour, forKey: DefaultsKey.dailyReminderHour)
        UserDefaults.standard.set(minute, forKey: DefaultsKey.dailyReminderMinute)

        // Cancel existing before rescheduling
        cancelDailyReminder()

        let content = UNMutableNotificationContent()
        content.title = "Time to Focus ⏱️"
        content.body = motivationalMessage
        content.sound = .default
        content.categoryIdentifier = "DAILY_REMINDER"
        content.userInfo = ["type": "daily_reminder"]

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: NotificationID.dailyReminder,
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            #if DEBUG
            if let error {
                print("[NotificationManager] Failed to schedule daily reminder: \(error.localizedDescription)")
            }
            #endif
        }
    }

    /// Cancel the daily focus reminder.
    func cancelDailyReminder() {
        UserDefaults.standard.set(false, forKey: DefaultsKey.dailyReminderEnabled)
        center.removePendingNotificationRequests(
            withIdentifiers: [NotificationID.dailyReminder]
        )
    }

    /// Check if daily reminder is currently enabled.
    var isDailyReminderEnabled: Bool {
        UserDefaults.standard.bool(forKey: DefaultsKey.dailyReminderEnabled)
    }

    /// The configured daily reminder time, or nil if not set.
    var dailyReminderTime: DateComponents? {
        guard isDailyReminderEnabled else { return nil }
        var components = DateComponents()
        components.hour = UserDefaults.standard.integer(forKey: DefaultsKey.dailyReminderHour)
        components.minute = UserDefaults.standard.integer(forKey: DefaultsKey.dailyReminderMinute)
        return components
    }

    // MARK: - Streak Reminder

    /// Schedule a reminder to maintain streak (fires if no session today by evening).
    ///
    /// - Parameter streakDays: Current streak count for motivational messaging.
    func scheduleStreakReminder(streakDays: Int) {
        guard isAuthorized, streakDays > 0 else { return }

        // Cancel any existing streak reminder
        cancelStreakReminder()

        let content = UNMutableNotificationContent()
        content.title = "Don't Break Your Streak! 🔥"
        content.body = "You're on a \(streakDays)-day focus streak. Complete a session today to keep it going!"
        content.sound = .default
        content.categoryIdentifier = "STREAK_REMINDER"
        content.userInfo = [
            "type": "streak_reminder",
            "streakDays": streakDays
        ]

        // Fire at 7 PM if no session completed
        var dateComponents = DateComponents()
        dateComponents.hour = 19
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: NotificationID.streakReminder,
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            #if DEBUG
            if let error {
                print("[NotificationManager] Failed to schedule streak reminder: \(error.localizedDescription)")
            }
            #endif
        }
    }

    /// Cancel the streak reminder (e.g., user completed a session today).
    func cancelStreakReminder() {
        center.removePendingNotificationRequests(
            withIdentifiers: [NotificationID.streakReminder]
        )
    }

    // MARK: - Badge Management

    /// Update the app badge count (e.g., to show current streak).
    @MainActor
    func updateBadgeCount(_ count: Int) {
        guard isAuthorized else { return }
        UNUserNotificationCenter.current().setBadgeCount(max(count, 0)) { error in
            #if DEBUG
            if let error {
                print("[NotificationManager] Badge update failed: \(error.localizedDescription)")
            }
            #endif
        }
    }

    /// Clear the badge count.
    @MainActor
    func clearBadge() {
        updateBadgeCount(0)
    }

    // MARK: - Cleanup

    /// Cancel all pending Kairo notifications.
    func cancelAllPending() {
        center.removePendingNotificationRequests(withIdentifiers: [
            NotificationID.sessionComplete,
            NotificationID.dailyReminder,
            NotificationID.streakReminder
        ])
    }

    /// Remove all delivered notifications from Notification Center.
    func clearDelivered() {
        center.removeAllDeliveredNotifications()
    }

    // MARK: - Pending Summary (Debug)

    /// Returns count of pending notifications (useful for debugging).
    func pendingCount() async -> Int {
        let pending = await center.pendingNotificationRequests()
        return pending.count
    }

    // MARK: - Private Helpers

    /// Rotating motivational messages for the daily reminder.
    private var motivationalMessage: String {
        let messages = [
            "Your best focus session is waiting. Let's go!",
            "Small consistent sessions build big results.",
            "25 minutes of deep work can change your day.",
            "Ready to enter the flow state?",
            "Your future self will thank you for focusing now.",
            "Block distractions. Build momentum. Start now.",
            "Every session is a step toward mastery."
        ]
        return messages.randomElement() ?? messages[0]
    }
}

// MARK: - Notification Categories Setup

extension NotificationManager {

    /// Register notification action categories. Call once at app launch.
    func registerCategories() {
        let startAction = UNNotificationAction(
            identifier: "START_SESSION",
            title: "Start Session",
            options: [.foreground]
        )

        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: [.destructive]
        )

        let sessionCategory = UNNotificationCategory(
            identifier: "SESSION_COMPLETE",
            actions: [startAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        let reminderCategory = UNNotificationCategory(
            identifier: "DAILY_REMINDER",
            actions: [startAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        let streakCategory = UNNotificationCategory(
            identifier: "STREAK_REMINDER",
            actions: [startAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([
            sessionCategory,
            reminderCategory,
            streakCategory
        ])
    }
}
