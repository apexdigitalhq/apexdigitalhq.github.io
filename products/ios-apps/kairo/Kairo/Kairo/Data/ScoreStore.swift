import CoreData

/// CRUD and query interface for DailyScore entities.
final class ScoreStore {

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }

    // MARK: - Fetch

    func fetchScore(for date: Date) -> DailyScore? {
        let dayStart = date.startOfDay
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!

        let request = DailyScore.fetchRequest()
        request.predicate = NSPredicate(
            format: "date >= %@ AND date < %@",
            dayStart as NSDate,
            dayEnd as NSDate
        )
        request.fetchLimit = 1
        return (try? context.fetch(request))?.first
    }

    func fetchScores(last days: Int = 7) -> [DailyScore] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date().startOfDay)!
        let request = DailyScore.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@", startDate as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \DailyScore.date, ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    func fetchOrCreate(for date: Date) -> DailyScore {
        if let existing = fetchScore(for: date) {
            return existing
        }
        return DailyScore.create(in: context, date: date)
    }

    func count() -> Int {
        let request = DailyScore.fetchRequest()
        return (try? context.count(for: request)) ?? 0
    }

    // MARK: - Save

    func save() {
        guard context.hasChanges else { return }
        try? context.save()
    }
}
