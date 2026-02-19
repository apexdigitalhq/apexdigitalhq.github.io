import Foundation
import CoreData

@objc(DailyScore)
public class DailyScore: NSManagedObject, Identifiable {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DailyScore> {
        NSFetchRequest<DailyScore>(entityName: "DailyScore")
    }

    // MARK: - Attributes

    @NSManaged public var id: UUID
    @NSManaged public var date: Date                   // midnight-normalized, unique
    @NSManaged public var completionRate: Float         // 0.0–1.0
    @NSManaged public var qualityFactor: Float          // 0.0–1.0
    @NSManaged public var consistencyFactor: Float      // 0.0–1.0
    @NSManaged public var focusScore: Float             // 0.0–100.0
    @NSManaged public var sessionsStarted: Int16
    @NSManaged public var sessionsCompleted: Int16
    @NSManaged public var totalFocusMinutes: Int32
    @NSManaged public var bestHour: Int16               // hour with highest quality sessions
    @NSManaged public var dominantType: String           // most-used session type
}

// MARK: - Score Level

extension DailyScore {

    enum ScoreLevel: String {
        case deepFlow    = "Deep Flow"
        case lockedIn    = "Locked In"
        case steady      = "Steady"
        case scattered   = "Scattered"
        case rebuilding  = "Rebuilding"

        var emoji: String {
            switch self {
            case .deepFlow:   return "🔥"
            case .lockedIn:   return "💪"
            case .steady:     return "👍"
            case .scattered:  return "🌀"
            case .rebuilding: return "🌱"
            }
        }
    }

    var scoreLevel: ScoreLevel {
        switch focusScore {
        case 90...100: return .deepFlow
        case 70..<90:  return .lockedIn
        case 50..<70:  return .steady
        case 30..<50:  return .scattered
        default:       return .rebuilding
        }
    }

    /// Creates a new DailyScore for a given date.
    static func create(
        in context: NSManagedObjectContext,
        date: Date = Date()
    ) -> DailyScore {
        let score = DailyScore(context: context)
        score.id = UUID()
        score.date = date.startOfDay
        score.completionRate = 0
        score.qualityFactor = 0
        score.consistencyFactor = 0
        score.focusScore = 0
        score.sessionsStarted = 0
        score.sessionsCompleted = 0
        score.totalFocusMinutes = 0
        score.bestHour = 0
        score.dominantType = "work"
        return score
    }
}
