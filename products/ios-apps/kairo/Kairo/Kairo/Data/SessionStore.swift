import CoreData

/// CRUD and query interface for FocusSession entities.
final class SessionStore {

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }

    // MARK: - Fetch

    func fetchAll(limit: Int? = nil) -> [FocusSession] {
        let request = FocusSession.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FocusSession.startedAt, ascending: false)]
        if let limit { request.fetchLimit = limit }
        return (try? context.fetch(request)) ?? []
    }

    func fetchToday() -> [FocusSession] {
        let start = Date().startOfDay
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        return fetchSessions(from: start, to: end)
    }

    func fetchSessions(from startDate: Date, to endDate: Date) -> [FocusSession] {
        let request = FocusSession.fetchRequest()
        request.predicate = NSPredicate(
            format: "startedAt >= %@ AND startedAt < %@",
            startDate as NSDate,
            endDate as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FocusSession.startedAt, ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    func fetchCompleted(last days: Int = 7) -> [FocusSession] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date().startOfDay)!
        let request = FocusSession.fetchRequest()
        request.predicate = NSPredicate(
            format: "startedAt >= %@ AND status == %@",
            startDate as NSDate,
            "completed"
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FocusSession.startedAt, ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    func fetchSession(by id: UUID) -> FocusSession? {
        let request = FocusSession.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return (try? context.fetch(request))?.first
    }

    func count() -> Int {
        let request = FocusSession.fetchRequest()
        return (try? context.count(for: request)) ?? 0
    }

    // MARK: - Save

    func save() {
        guard context.hasChanges else { return }
        try? context.save()
    }

    // MARK: - Delete

    func delete(_ session: FocusSession) {
        context.delete(session)
        save()
    }
}
