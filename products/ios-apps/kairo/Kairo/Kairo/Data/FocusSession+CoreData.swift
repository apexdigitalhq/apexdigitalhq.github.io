import Foundation
import CoreData

@objc(FocusSession)
public class FocusSession: NSManagedObject, Identifiable {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<FocusSession> {
        NSFetchRequest<FocusSession>(entityName: "FocusSession")
    }

    // MARK: - Attributes

    @NSManaged public var id: UUID
    @NSManaged public var startedAt: Date
    @NSManaged public var endedAt: Date?
    @NSManaged public var targetDuration: Int32      // seconds
    @NSManaged public var actualDuration: Int32      // seconds
    @NSManaged public var sessionType: String         // "work", "study", "creative", "personal"
    @NSManaged public var status: String              // "completed", "abandoned", "paused", "active"
    @NSManaged public var soundscape: String?         // "deep_focus", "rain", etc. or nil
    @NSManaged public var pauseCount: Int16
    @NSManaged public var distractionCount: Int16
    @NSManaged public var qualityRating: String       // "high", "medium", "low"
    @NSManaged public var focusScore: Float           // 0.0–100.0
    @NSManaged public var notes: String?
    @NSManaged public var createdAt: Date

    // MARK: - Relationships

    @NSManaged public var distractionEvents: NSSet?
}

// MARK: - Generated Accessors for DistractionEvents

extension FocusSession {

    @objc(addDistractionEventsObject:)
    @NSManaged public func addToDistractionEvents(_ value: DistractionEvent)

    @objc(removeDistractionEventsObject:)
    @NSManaged public func removeFromDistractionEvents(_ value: DistractionEvent)

    @objc(addDistractionEvents:)
    @NSManaged public func addToDistractionEvents(_ values: NSSet)

    @objc(removeDistractionEvents:)
    @NSManaged public func removeFromDistractionEvents(_ values: NSSet)
}

// MARK: - Convenience

extension FocusSession {

    var distractionEventsArray: [DistractionEvent] {
        let set = distractionEvents as? Set<DistractionEvent> ?? []
        return set.sorted { $0.timestamp < $1.timestamp }
    }

    var isCompleted: Bool { status == "completed" }
    var isAbandoned: Bool { status == "abandoned" }
    var isActive: Bool    { status == "active" }

    var completionRatio: Double {
        guard targetDuration > 0 else { return 0 }
        return Double(actualDuration) / Double(targetDuration)
    }

    var targetMinutes: Int { Int(targetDuration) / 60 }
    var actualMinutes: Int { Int(actualDuration) / 60 }

    /// Creates a new FocusSession with sensible defaults.
    static func create(
        in context: NSManagedObjectContext,
        type: String = "work",
        targetDuration: Int32 = 1500 // 25 min
    ) -> FocusSession {
        let session = FocusSession(context: context)
        session.id = UUID()
        session.startedAt = Date()
        session.targetDuration = targetDuration
        session.actualDuration = 0
        session.sessionType = type
        session.status = "active"
        session.pauseCount = 0
        session.distractionCount = 0
        session.qualityRating = "medium"
        session.focusScore = 0
        session.createdAt = Date()
        return session
    }
}
