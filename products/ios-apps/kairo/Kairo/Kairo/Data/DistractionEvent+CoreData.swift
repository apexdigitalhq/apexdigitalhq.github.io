import Foundation
import CoreData

@objc(DistractionEvent)
public class DistractionEvent: NSManagedObject, Identifiable {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DistractionEvent> {
        NSFetchRequest<DistractionEvent>(entityName: "DistractionEvent")
    }

    // MARK: - Attributes

    @NSManaged public var id: UUID
    @NSManaged public var sessionID: UUID
    @NSManaged public var timestamp: Date
    @NSManaged public var type: String            // "phone_pickup", "app_background", "manual_pause"
    @NSManaged public var durationSeconds: Int16   // how long the distraction lasted

    // MARK: - Relationships

    @NSManaged public var session: FocusSession?
}

// MARK: - Distraction Types

extension DistractionEvent {

    enum DistractionType: String, CaseIterable {
        case phonePickup   = "phone_pickup"
        case appBackground = "app_background"
        case manualPause   = "manual_pause"

        var displayName: String {
            switch self {
            case .phonePickup:   return "Phone Pickup"
            case .appBackground: return "App Switch"
            case .manualPause:   return "Manual Pause"
            }
        }

        var iconName: String {
            switch self {
            case .phonePickup:   return "iphone.radiowaves.left.and.right"
            case .appBackground: return "arrow.uturn.left"
            case .manualPause:   return "pause.circle"
            }
        }
    }

    var distractionType: DistractionType? {
        DistractionType(rawValue: type)
    }

    /// Creates a new DistractionEvent linked to a session.
    static func create(
        in context: NSManagedObjectContext,
        session: FocusSession,
        type: DistractionType,
        duration: Int16 = 0
    ) -> DistractionEvent {
        let event = DistractionEvent(context: context)
        event.id = UUID()
        event.sessionID = session.id
        event.timestamp = Date()
        event.type = type.rawValue
        event.durationSeconds = duration
        event.session = session
        return event
    }
}
