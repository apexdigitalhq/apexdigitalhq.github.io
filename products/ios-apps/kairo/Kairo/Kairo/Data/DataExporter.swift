import CoreData
import Foundation

/// Exports, deletes, and resets all user data for Kairo's Privacy Dashboard.
///
/// Handles three critical data operations:
/// 1. **Export** — Serializes all entities (sessions, scores, streaks, patterns)
///    to JSON format, either as in-memory `Data` or a temporary file URL.
/// 2. **Delete** — Batch-deletes all Core Data entities and clears related
///    UserDefaults keys. Uses `NSBatchDeleteRequest` for performance.
/// 3. **Reset ML** — Clears the `FocusPattern` entity and ML-related flags,
///    reverting Kairo to the heuristic RuleEngine.
///
/// Usage:
/// ```swift
/// let exporter = DataExporter()
/// let jsonData = try exporter.exportAsJSON()
/// let fileURL = try exporter.exportToFile()
/// try exporter.deleteAllData()
/// exporter.resetMLModel()
/// ```
final class DataExporter {

    private let context: NSManagedObjectContext

    /// Creates a `DataExporter` operating on the given context.
    ///
    /// - Parameter context: The managed object context to query and modify.
    ///   Defaults to `PersistenceController.shared.container.viewContext`.
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }

    // MARK: - Export

    /// Exports all Kairo data as a JSON-serializable dictionary.
    ///
    /// Includes metadata (export date, app version) and all entity data:
    /// sessions with nested distraction events, daily scores, focus pattern,
    /// and focus streak.
    ///
    /// - Returns: A dictionary suitable for `JSONSerialization`.
    func exportAllData() -> [String: Any] {
        var export: [String: Any] = [
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            "exportFormat": "kairo_v1",
        ]

        export["sessions"] = exportSessions()
        export["dailyScores"] = exportDailyScores()
        export["focusPattern"] = exportFocusPattern()
        export["focusStreak"] = exportFocusStreak()
        export["statistics"] = exportStatistics()

        return export
    }

    /// Exports all data as pretty-printed JSON `Data`.
    ///
    /// - Throws: `JSONSerialization` errors if data cannot be encoded.
    /// - Returns: UTF-8 encoded JSON data.
    func exportAsJSON() throws -> Data {
        let data = exportAllData()
        return try JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .sortedKeys])
    }

    /// Writes the full export to a temporary file and returns its URL.
    ///
    /// The file is placed in the system's temporary directory with a
    /// timestamped filename (e.g., `kairo_export_2025-01-15_143022.json`).
    /// Suitable for use with `UIActivityViewController` / share sheet.
    ///
    /// - Throws: File I/O or JSON serialization errors.
    /// - Returns: URL to the temporary export file.
    func exportToFile() throws -> URL {
        let jsonData = try exportAsJSON()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let filename = "kairo_export_\(formatter.string(from: Date())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try jsonData.write(to: url)
        return url
    }

    // MARK: - Delete All Data

    /// Deletes all user data from Core Data and clears related UserDefaults.
    ///
    /// Uses `NSBatchDeleteRequest` for each entity type for optimal performance.
    /// After batch deletion, merges the changes into the view context so all
    /// in-memory objects are invalidated.
    ///
    /// - Throws: Core Data errors if batch deletion fails.
    func deleteAllData() throws {
        let entityNames = [
            "DistractionEvent",
            "FocusSession",
            "DailyScore",
            "FocusPattern",
            "FocusStreak",
        ]

        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            deleteRequest.resultType = .resultTypeObjectIDs

            let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
            if let objectIDs = result?.result as? [NSManagedObjectID] {
                NSManagedObjectContext.mergeChanges(
                    fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs],
                    into: [context]
                )
            }
        }

        // Clear session-related UserDefaults
        clearUserDefaults()
    }

    // MARK: - Reset ML Model

    /// Resets the ML model by deleting all `FocusPattern` data and clearing
    /// ML-related UserDefaults flags.
    ///
    /// After reset, Kairo reverts to the heuristic `RuleEngine` for all
    /// suggestions until enough new sessions are collected to retrain.
    func resetMLModel() {
        // Delete all FocusPattern entities
        do {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "FocusPattern")
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            deleteRequest.resultType = .resultTypeObjectIDs

            let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
            if let objectIDs = result?.result as? [NSManagedObjectID] {
                NSManagedObjectContext.mergeChanges(
                    fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs],
                    into: [context]
                )
            }
        } catch {
            #if DEBUG
            print("[DataExporter] Failed to delete FocusPattern entities: \(error.localizedDescription)")
            #endif
        }

        // Clear ML-related UserDefaults
        let mlKeys = [
            "kairo_ml_model_trained",
            "kairo_ml_last_training_date",
            "kairo_ml_model_version",
            "kairo_ml_training_session_count",
            "kairo_pattern_analyzer_readiness",
        ]

        for key in mlKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }

        #if DEBUG
        print("[DataExporter] ML model reset complete — reverted to RuleEngine heuristics")
        #endif
    }

    // MARK: - Entity Exports

    /// Serializes all `FocusSession` entities with nested distraction events.
    private func exportSessions() -> [[String: Any]] {
        let request = FocusSession.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FocusSession.startedAt, ascending: true)]

        guard let sessions = try? context.fetch(request) else { return [] }

        let iso = ISO8601DateFormatter()
        return sessions.map { session in
            var dict: [String: Any] = [
                "id": session.id.uuidString,
                "startedAt": iso.string(from: session.startedAt),
                "targetDuration": session.targetDuration,
                "actualDuration": session.actualDuration,
                "sessionType": session.sessionType,
                "status": session.status,
                "pauseCount": session.pauseCount,
                "distractionCount": session.distractionCount,
                "qualityRating": session.qualityRating,
                "focusScore": session.focusScore,
                "createdAt": iso.string(from: session.createdAt),
            ]

            if let endedAt = session.endedAt {
                dict["endedAt"] = iso.string(from: endedAt)
            }
            if let soundscape = session.soundscape {
                dict["soundscape"] = soundscape
            }
            if let notes = session.notes {
                dict["notes"] = notes
            }

            // Nested distraction events
            dict["distractionEvents"] = session.distractionEventsArray.map { event in
                [
                    "id": event.id.uuidString,
                    "timestamp": iso.string(from: event.timestamp),
                    "type": event.type,
                    "durationSeconds": event.durationSeconds,
                ] as [String: Any]
            }

            return dict
        }
    }

    /// Serializes all `DailyScore` entities.
    private func exportDailyScores() -> [[String: Any]] {
        let request = DailyScore.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \DailyScore.date, ascending: true)]

        guard let scores = try? context.fetch(request) else { return [] }

        let iso = ISO8601DateFormatter()
        return scores.map { score in
            [
                "id": score.id.uuidString,
                "date": iso.string(from: score.date),
                "focusScore": score.focusScore,
                "completionRate": score.completionRate,
                "qualityFactor": score.qualityFactor,
                "consistencyFactor": score.consistencyFactor,
                "sessionsStarted": score.sessionsStarted,
                "sessionsCompleted": score.sessionsCompleted,
                "totalFocusMinutes": score.totalFocusMinutes,
                "bestHour": score.bestHour,
                "dominantType": score.dominantType,
            ] as [String: Any]
        }
    }

    /// Serializes the singleton `FocusPattern` entity, if it exists.
    private func exportFocusPattern() -> [String: Any]? {
        let request = FocusPattern.fetchRequest()
        request.fetchLimit = 1

        guard let pattern = (try? context.fetch(request))?.first else { return nil }

        return [
            "id": pattern.id.uuidString,
            "updatedAt": ISO8601DateFormatter().string(from: pattern.updatedAt),
            "optimalDuration": pattern.optimalDuration,
            "bestHourStart": pattern.bestHourStart,
            "bestHourEnd": pattern.bestHourEnd,
            "bestDayOfWeek": pattern.bestDayOfWeek,
            "avgCompletionRate": pattern.avgCompletionRate,
            "avgSessionsPerDay": pattern.avgSessionsPerDay,
            "preferredBreakLength": pattern.preferredBreakLength,
            "modelVersion": pattern.modelVersion,
            "modelConfidence": pattern.modelConfidence,
            "ruleEngineActive": pattern.ruleEngineActive,
            "dataPointCount": pattern.dataPointCount,
        ]
    }

    /// Serializes the `FocusStreak` entity, if it exists.
    private func exportFocusStreak() -> [String: Any]? {
        let request = FocusStreak.fetchRequest()
        request.fetchLimit = 1

        guard let streak = (try? context.fetch(request))?.first else { return nil }

        let iso = ISO8601DateFormatter()
        return [
            "id": streak.id.uuidString,
            "startDate": iso.string(from: streak.startDate),
            "currentLength": streak.currentLength,
            "longestLength": streak.longestLength,
            "isActive": streak.isActive,
            "lastActiveDate": iso.string(from: streak.lastActiveDate),
        ]
    }

    /// Computes aggregate statistics for the export metadata.
    private func exportStatistics() -> [String: Any] {
        let sessionRequest = FocusSession.fetchRequest()
        let totalSessions = (try? context.count(for: sessionRequest)) ?? 0

        let completedRequest = FocusSession.fetchRequest()
        completedRequest.predicate = NSPredicate(format: "status == %@", "completed")
        let completedSessions = (try? context.count(for: completedRequest)) ?? 0

        let scoreRequest = DailyScore.fetchRequest()
        let totalScoreDays = (try? context.count(for: scoreRequest)) ?? 0

        return [
            "totalSessions": totalSessions,
            "completedSessions": completedSessions,
            "totalScoreDays": totalScoreDays,
        ]
    }

    // MARK: - Private Helpers

    /// Clears all Kairo-specific UserDefaults keys after a full data wipe.
    private func clearUserDefaults() {
        let keysToRemove = [
            "kairo_install_date",
            "kairo_ml_model_trained",
            "kairo_ml_last_training_date",
            "kairo_ml_model_version",
            "kairo_ml_training_session_count",
            "kairo_pattern_analyzer_readiness",
            "kairo_daily_reminder_enabled",
            "kairo_daily_reminder_hour",
            "kairo_daily_reminder_minute",
            "kairo_notif_requested",
        ]

        for key in keysToRemove {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
