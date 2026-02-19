import Foundation
import CoreData

@objc(FocusStreak)
public class FocusStreak: NSManagedObject, Identifiable {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<FocusStreak> {
        NSFetchRequest<FocusStreak>(entityName: "FocusStreak")
    }

    // MARK: - Attributes

    @NSManaged public var id: UUID
    @NSManaged public var startDate: Date
    @NSManaged public var currentLength: Int32       // days
    @NSManaged public var longestLength: Int32        // all-time longest
    @NSManaged public var isActive: Bool
    @NSManaged public var lastActiveDate: Date
}

// MARK: - Convenience

extension FocusStreak {

    /// Whether the streak is still valid (user focused yesterday or today).
    var isCurrentlyValid: Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastActive = calendar.startOfDay(for: lastActiveDate)
        let daysSince = calendar.dateComponents([.day], from: lastActive, to: today).day ?? 0
        return daysSince <= 1
    }

    /// Marks today as active and increments the streak.
    func recordActivity() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastActive = calendar.startOfDay(for: lastActiveDate)

        guard today != lastActive else { return } // Already recorded today

        let daysSince = calendar.dateComponents([.day], from: lastActive, to: today).day ?? 0

        if daysSince == 1 {
            // Consecutive day — extend streak
            currentLength += 1
        } else if daysSince > 1 {
            // Streak broken — restart
            startDate = today
            currentLength = 1
        }

        lastActiveDate = today
        isActive = true

        if currentLength > longestLength {
            longestLength = currentLength
        }
    }

    /// Creates a new FocusStreak starting today.
    static func createNew(in context: NSManagedObjectContext) -> FocusStreak {
        let streak = FocusStreak(context: context)
        streak.id = UUID()
        streak.startDate = Date().startOfDay
        streak.currentLength = 1
        streak.longestLength = 1
        streak.isActive = true
        streak.lastActiveDate = Date().startOfDay
        return streak
    }
}
