import CoreData

/// CRUD interface for the FocusPattern singleton entity.
final class PatternStore {

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }

    // MARK: - Fetch

    /// Returns the user's FocusPattern, creating a default if none exists.
    func fetchOrCreate() -> FocusPattern {
        let request = FocusPattern.fetchRequest()
        request.fetchLimit = 1
        if let existing = (try? context.fetch(request))?.first {
            return existing
        }
        let pattern = FocusPattern.createDefault(in: context)
        save()
        return pattern
    }

    // MARK: - Reset

    /// Deletes the current pattern (ML model reset). A fresh default will be created on next access.
    func resetPattern() {
        let request = FocusPattern.fetchRequest()
        if let patterns = try? context.fetch(request) {
            for pattern in patterns {
                context.delete(pattern)
            }
        }
        save()
    }

    // MARK: - Save

    func save() {
        guard context.hasChanges else { return }
        try? context.save()
    }
}
