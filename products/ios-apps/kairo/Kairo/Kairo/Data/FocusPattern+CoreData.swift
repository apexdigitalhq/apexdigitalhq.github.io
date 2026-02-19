import Foundation
import CoreData

@objc(FocusPattern)
public class FocusPattern: NSManagedObject, Identifiable {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<FocusPattern> {
        NSFetchRequest<FocusPattern>(entityName: "FocusPattern")
    }

    // MARK: - Attributes

    @NSManaged public var id: UUID
    @NSManaged public var updatedAt: Date
    @NSManaged public var optimalDuration: Float     // minutes
    @NSManaged public var bestHourStart: Int16       // 0–23
    @NSManaged public var bestHourEnd: Int16         // 0–23
    @NSManaged public var bestDayOfWeek: Int16       // 1 = Monday, 7 = Sunday
    @NSManaged public var avgCompletionRate: Float   // 0.0–1.0
    @NSManaged public var avgSessionsPerDay: Float
    @NSManaged public var preferredBreakLength: Int16 // seconds
    @NSManaged public var modelVersion: Int16        // 0 = rule engine, 1+ = ML model versions
    @NSManaged public var modelConfidence: Float     // 0.0–1.0
    @NSManaged public var ruleEngineActive: Bool     // true until ML model takes over
    @NSManaged public var dataPointCount: Int32      // how many sessions inform this pattern
}

// MARK: - Convenience

extension FocusPattern {

    var isMLActive: Bool { !ruleEngineActive && modelVersion > 0 }

    var bestDayName: String {
        let days = ["", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        let index = Int(bestDayOfWeek)
        guard index >= 1, index <= 7 else { return "Unknown" }
        return days[index]
    }

    var bestTimeRange: String {
        let start = String(format: "%d:00", bestHourStart)
        let end = String(format: "%d:00", bestHourEnd)
        return "\(start) – \(end)"
    }

    var optimalDurationFormatted: String {
        let minutes = Int(optimalDuration)
        return "\(minutes) min"
    }

    /// Creates the initial FocusPattern with default values (rule engine active).
    static func createDefault(in context: NSManagedObjectContext) -> FocusPattern {
        let pattern = FocusPattern(context: context)
        pattern.id = UUID()
        pattern.updatedAt = Date()
        pattern.optimalDuration = 25.0      // Pomodoro default
        pattern.bestHourStart = 9           // 9 AM
        pattern.bestHourEnd = 11            // 11 AM
        pattern.bestDayOfWeek = 2           // Tuesday (placeholder)
        pattern.avgCompletionRate = 0
        pattern.avgSessionsPerDay = 0
        pattern.preferredBreakLength = 300  // 5 minutes
        pattern.modelVersion = 0
        pattern.modelConfidence = 0
        pattern.ruleEngineActive = true
        pattern.dataPointCount = 0
        return pattern
    }
}
