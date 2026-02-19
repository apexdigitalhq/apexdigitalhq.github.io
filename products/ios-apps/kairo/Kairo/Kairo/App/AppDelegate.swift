import UIKit
import BackgroundTasks
import UserNotifications
import CoreData

/// Kairo's app delegate — handles notification actions, background task
/// registration, and app-level lifecycle events.
///
/// Responsibilities:
/// 1. **Notification delegate** — processes user actions on delivered
///    notifications (Start Session, Dismiss) via `UNUserNotificationCenterDelegate`.
/// 2. **Background tasks** — registers and schedules `BGProcessingTask`
///    requests for weekly ML model retraining and daily score aggregation.
/// 3. **Category registration** — ensures notification categories are
///    registered as early as possible in the app lifecycle.
final class AppDelegate: NSObject, UIApplicationDelegate {

    // MARK: - Background Task Identifiers

    /// Weekly ML model retrain task.
    static let modelRetrainTaskID = "com.kairo.ml.retrain"

    /// Nightly daily score aggregation task.
    static let dailyScoreTaskID = "com.kairo.scoring.daily"

    // MARK: - UIApplicationDelegate

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Set self as notification delegate to handle actions
        UNUserNotificationCenter.current().delegate = self

        // Register notification categories (Start Session, Dismiss actions)
        NotificationManager.shared.registerCategories()

        // Register background processing tasks
        registerBackgroundTasks()

        // Schedule initial background tasks
        scheduleDailyScore()
        scheduleModelRetrain()

        return true
    }

    // MARK: - Background Task Registration

    /// Registers all background task handlers with the system.
    ///
    /// Must be called during `didFinishLaunchingWithOptions` before the
    /// app finishes launching. Each task identifier must also appear in
    /// the app's `Info.plist` under `BGTaskSchedulerPermittedIdentifiers`.
    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.modelRetrainTaskID,
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleModelRetrain(task: processingTask)
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.dailyScoreTaskID,
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleDailyScore(task: processingTask)
        }
    }

    // MARK: - Background Task Handlers

    /// Handles the weekly ML model retrain task.
    ///
    /// Runs `FocusPatternAnalyzer` on the background context to update
    /// the `FocusPattern` entity with the latest session data. Requires
    /// external power to run (heavy computation).
    private func handleModelRetrain(task: BGProcessingTask) {
        let context = PersistenceController.shared.newBackgroundContext()

        task.expirationHandler = {
            // Clean up if the system terminates the task early
            context.reset()
        }

        context.perform {
            do {
                let sessionRequest = FocusSession.fetchRequest()
                sessionRequest.predicate = NSPredicate(format: "status == %@", "completed")
                sessionRequest.sortDescriptors = [
                    NSSortDescriptor(keyPath: \FocusSession.startedAt, ascending: true)
                ]

                let sessions = try context.fetch(sessionRequest)

                guard sessions.count >= 10 else {
                    task.setTaskCompleted(success: true)
                    self.scheduleModelRetrain()
                    return
                }

                let patternRequest = FocusPattern.fetchRequest()
                patternRequest.fetchLimit = 1
                let pattern = try context.fetch(patternRequest).first
                    ?? FocusPattern.createDefault(in: context)

                let analyzer = FocusPatternAnalyzer()
                analyzer.analyzePatterns(sessions: sessions, into: pattern)

                try context.save()
                task.setTaskCompleted(success: true)
            } catch {
                #if DEBUG
                print("[AppDelegate] Model retrain failed: \(error.localizedDescription)")
                #endif
                task.setTaskCompleted(success: false)
            }

            self.scheduleModelRetrain()
        }
    }

    /// Handles the nightly daily score aggregation task.
    ///
    /// Recalculates the previous day's focus score in case any session
    /// data arrived late or the app was closed before scoring.
    private func handleDailyScore(task: BGProcessingTask) {
        let context = PersistenceController.shared.newBackgroundContext()

        task.expirationHandler = {
            context.reset()
        }

        context.perform {
            let calculator = DailyScoreCalculator(context: context)
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            calculator.calculateAndSave(for: yesterday)

            task.setTaskCompleted(success: true)
            self.scheduleDailyScore()
        }
    }

    // MARK: - Task Scheduling

    /// Schedules the weekly ML model retrain task.
    ///
    /// Requires external power (heavy computation). Earliest begin date
    /// is 7 days from now, allowing the system flexibility to run it
    /// when conditions are optimal.
    func scheduleModelRetrain() {
        let request = BGProcessingTaskRequest(identifier: Self.modelRetrainTaskID)
        request.requiresExternalPower = true
        request.earliestBeginDate = Date(timeIntervalSinceNow: 7 * 24 * 60 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            #if DEBUG
            print("[AppDelegate] Failed to schedule model retrain: \(error.localizedDescription)")
            #endif
        }
    }

    /// Schedules the nightly daily score aggregation task.
    ///
    /// Targets 12:05 AM (shortly after midnight) to catch any end-of-day
    /// sessions that completed late. Does not require external power.
    func scheduleDailyScore() {
        let request = BGProcessingTaskRequest(identifier: Self.dailyScoreTaskID)
        request.requiresExternalPower = false

        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.day = (components.day ?? 0) + 1
        components.hour = 0
        components.minute = 5

        if let midnight = Calendar.current.date(from: components) {
            request.earliestBeginDate = midnight
        }

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            #if DEBUG
            print("[AppDelegate] Failed to schedule daily score: \(error.localizedDescription)")
            #endif
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {

    /// Handles notification delivery while the app is in the foreground.
    ///
    /// Shows the notification banner even when the app is active, so the
    /// user sees session-complete and break-end alerts in-app.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    /// Handles the user tapping on a notification or selecting an action.
    ///
    /// Supported actions:
    /// - **START_SESSION** — Opens the app ready to start a new session.
    /// - **DISMISS** — Clears the notification with no further action.
    /// - **Default tap** — Opens the app normally.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let actionIdentifier = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo

        switch actionIdentifier {
        case "START_SESSION":
            // Post a notification that the session coordinator can observe
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .kairoStartSessionFromNotification,
                    object: nil,
                    userInfo: userInfo
                )
            }

        case "DISMISS", UNNotificationDismissActionIdentifier:
            // User dismissed — no action needed
            break

        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification body — just open the app
            break

        default:
            break
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {

    /// Posted when the user taps "Start Session" from a notification action.
    ///
    /// The `SessionCoordinator` can observe this to auto-navigate to the
    /// session start screen.
    static let kairoStartSessionFromNotification = Notification.Name("kairoStartSessionFromNotification")
}
