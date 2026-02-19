import CoreData

/// Manages the Core Data stack for Kairo.
/// Local-only storage — no CloudKit, no network, no shared containers.
final class PersistenceController {

    // MARK: - Shared Instances

    static let shared = PersistenceController()

    /// In-memory store for SwiftUI previews and unit tests.
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext

        // Seed preview data
        let session = FocusSession.create(in: context, type: "work", targetDuration: 1500)
        session.status = "completed"
        session.actualDuration = 1500
        session.endedAt = Date()
        session.qualityRating = "high"
        session.focusScore = 85.0

        let session2 = FocusSession.create(in: context, type: "study", targetDuration: 2100)
        session2.status = "completed"
        session2.actualDuration = 1980
        session2.endedAt = Date().addingTimeInterval(-3600)
        session2.qualityRating = "medium"
        session2.focusScore = 72.0

        let score = DailyScore.create(in: context)
        score.focusScore = 78.0
        score.sessionsCompleted = 2
        score.sessionsStarted = 2
        score.totalFocusMinutes = 58
        score.completionRate = 1.0
        score.qualityFactor = 0.78
        score.consistencyFactor = 0.85

        let streak = FocusStreak.createNew(in: context)
        streak.currentLength = 5
        streak.longestLength = 12

        let pattern = FocusPattern.createDefault(in: context)
        pattern.dataPointCount = 2

        try? context.save()
        return controller
    }()

    // MARK: - Container

    let container: NSPersistentContainer

    // MARK: - Init

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Kairo", managedObjectModel: Self.createModel())

        if inMemory {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [description]
        } else {
            let description = NSPersistentStoreDescription()
            description.type = NSSQLiteStoreType
            description.url = Self.storeURL

            // Enable lightweight migration
            description.setOption(
                true as NSNumber,
                forKey: NSMigratePersistentStoresAutomaticallyOption
            )
            description.setOption(
                true as NSNumber,
                forKey: NSInferMappingModelAutomaticallyOption
            )

            container.persistentStoreDescriptions = [description]
        }

        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: - Store URL

    private static var storeURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("Kairo.sqlite")
    }

    // MARK: - Save

    func save() {
        let context = container.viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            let nsError = error as NSError
            fatalError("Core Data save error: \(nsError), \(nsError.userInfo)")
        }
    }

    // MARK: - Background Context

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    // MARK: - Delete All Data

    /// Wipes every entity from the store. Used by Privacy Dashboard "Delete All Data".
    func deleteAllData() throws {
        let context = container.viewContext
        let entityNames = ["FocusSession", "DistractionEvent", "DailyScore", "FocusPattern", "FocusStreak"]

        for name in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: name)
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
    }

    // MARK: - Programmatic Core Data Model

    /// Builds the entire Core Data model in code — no .xcdatamodeld file needed.
    private static func createModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // -- FocusSession Entity --
        let sessionEntity = NSEntityDescription()
        sessionEntity.name = "FocusSession"
        sessionEntity.managedObjectClassName = "FocusSession"

        let sessionID            = NSAttributeDescription.uuid("id")
        let sessionStartedAt     = NSAttributeDescription.date("startedAt")
        let sessionEndedAt       = NSAttributeDescription.optionalDate("endedAt")
        let sessionTargetDur     = NSAttributeDescription.int32("targetDuration")
        let sessionActualDur     = NSAttributeDescription.int32("actualDuration")
        let sessionType          = NSAttributeDescription.string("sessionType", defaultValue: "work")
        let sessionStatus        = NSAttributeDescription.string("status", defaultValue: "active")
        let sessionSoundscape    = NSAttributeDescription.optionalString("soundscape")
        let sessionPauseCount    = NSAttributeDescription.int16("pauseCount")
        let sessionDistCount     = NSAttributeDescription.int16("distractionCount")
        let sessionQuality       = NSAttributeDescription.string("qualityRating", defaultValue: "medium")
        let sessionFocusScore    = NSAttributeDescription.float("focusScore")
        let sessionNotes         = NSAttributeDescription.optionalString("notes")
        let sessionCreatedAt     = NSAttributeDescription.date("createdAt")

        sessionEntity.properties = [
            sessionID, sessionStartedAt, sessionEndedAt, sessionTargetDur,
            sessionActualDur, sessionType, sessionStatus, sessionSoundscape,
            sessionPauseCount, sessionDistCount, sessionQuality, sessionFocusScore,
            sessionNotes, sessionCreatedAt
        ]

        // -- DistractionEvent Entity --
        let distractionEntity = NSEntityDescription()
        distractionEntity.name = "DistractionEvent"
        distractionEntity.managedObjectClassName = "DistractionEvent"

        let distID       = NSAttributeDescription.uuid("id")
        let distSessID   = NSAttributeDescription.uuid("sessionID")
        let distTime     = NSAttributeDescription.date("timestamp")
        let distType     = NSAttributeDescription.string("type", defaultValue: "phone_pickup")
        let distDuration = NSAttributeDescription.int16("durationSeconds")

        distractionEntity.properties = [distID, distSessID, distTime, distType, distDuration]

        // -- Relationships: FocusSession ↔ DistractionEvent --
        let sessionToDistractions = NSRelationshipDescription()
        sessionToDistractions.name = "distractionEvents"
        sessionToDistractions.destinationEntity = distractionEntity
        sessionToDistractions.minCount = 0
        sessionToDistractions.maxCount = 0 // to-many
        sessionToDistractions.deleteRule = .cascadeDeleteRule
        sessionToDistractions.isOptional = true

        let distractionToSession = NSRelationshipDescription()
        distractionToSession.name = "session"
        distractionToSession.destinationEntity = sessionEntity
        distractionToSession.minCount = 0
        distractionToSession.maxCount = 1 // to-one
        distractionToSession.deleteRule = .nullifyDeleteRule
        distractionToSession.isOptional = true

        sessionToDistractions.inverseRelationship = distractionToSession
        distractionToSession.inverseRelationship = sessionToDistractions

        sessionEntity.properties.append(sessionToDistractions)
        distractionEntity.properties.append(distractionToSession)

        // -- DailyScore Entity --
        let scoreEntity = NSEntityDescription()
        scoreEntity.name = "DailyScore"
        scoreEntity.managedObjectClassName = "DailyScore"

        let scoreID          = NSAttributeDescription.uuid("id")
        let scoreDate        = NSAttributeDescription.date("date")
        let scoreCompletion  = NSAttributeDescription.float("completionRate")
        let scoreQuality     = NSAttributeDescription.float("qualityFactor")
        let scoreConsistency = NSAttributeDescription.float("consistencyFactor")
        let scoreFocus       = NSAttributeDescription.float("focusScore")
        let scoreStarted     = NSAttributeDescription.int16("sessionsStarted")
        let scoreCompleted   = NSAttributeDescription.int16("sessionsCompleted")
        let scoreFocusMin    = NSAttributeDescription.int32("totalFocusMinutes")
        let scoreBestHour    = NSAttributeDescription.int16("bestHour")
        let scoreDomType     = NSAttributeDescription.string("dominantType", defaultValue: "work")

        scoreEntity.properties = [
            scoreID, scoreDate, scoreCompletion, scoreQuality, scoreConsistency,
            scoreFocus, scoreStarted, scoreCompleted, scoreFocusMin,
            scoreBestHour, scoreDomType
        ]

        // -- FocusPattern Entity --
        let patternEntity = NSEntityDescription()
        patternEntity.name = "FocusPattern"
        patternEntity.managedObjectClassName = "FocusPattern"

        let patternID           = NSAttributeDescription.uuid("id")
        let patternUpdated      = NSAttributeDescription.date("updatedAt")
        let patternOptDur       = NSAttributeDescription.float("optimalDuration")
        let patternBestStart    = NSAttributeDescription.int16("bestHourStart")
        let patternBestEnd      = NSAttributeDescription.int16("bestHourEnd")
        let patternBestDay      = NSAttributeDescription.int16("bestDayOfWeek")
        let patternAvgComp      = NSAttributeDescription.float("avgCompletionRate")
        let patternAvgSPD       = NSAttributeDescription.float("avgSessionsPerDay")
        let patternBreakLen     = NSAttributeDescription.int16("preferredBreakLength")
        let patternModelVer     = NSAttributeDescription.int16("modelVersion")
        let patternModelConf    = NSAttributeDescription.float("modelConfidence")
        let patternRuleActive   = NSAttributeDescription.bool("ruleEngineActive", defaultValue: true)
        let patternDataPoints   = NSAttributeDescription.int32("dataPointCount")

        patternEntity.properties = [
            patternID, patternUpdated, patternOptDur, patternBestStart, patternBestEnd,
            patternBestDay, patternAvgComp, patternAvgSPD, patternBreakLen,
            patternModelVer, patternModelConf, patternRuleActive, patternDataPoints
        ]

        // -- FocusStreak Entity --
        let streakEntity = NSEntityDescription()
        streakEntity.name = "FocusStreak"
        streakEntity.managedObjectClassName = "FocusStreak"

        let streakID         = NSAttributeDescription.uuid("id")
        let streakStart      = NSAttributeDescription.date("startDate")
        let streakCurrent    = NSAttributeDescription.int32("currentLength")
        let streakLongest    = NSAttributeDescription.int32("longestLength")
        let streakActive     = NSAttributeDescription.bool("isActive", defaultValue: true)
        let streakLastActive = NSAttributeDescription.date("lastActiveDate")

        streakEntity.properties = [
            streakID, streakStart, streakCurrent, streakLongest, streakActive, streakLastActive
        ]

        // -- Assemble Model --
        model.entities = [sessionEntity, distractionEntity, scoreEntity, patternEntity, streakEntity]
        return model
    }
}

// MARK: - NSAttributeDescription Helpers

private extension NSAttributeDescription {

    static func uuid(_ name: String) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = .UUIDAttributeType
        attr.isOptional = false
        return attr
    }

    static func date(_ name: String) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = .dateAttributeType
        attr.isOptional = false
        return attr
    }

    static func optionalDate(_ name: String) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = .dateAttributeType
        attr.isOptional = true
        return attr
    }

    static func string(_ name: String, defaultValue: String? = nil) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = .stringAttributeType
        attr.isOptional = false
        if let dv = defaultValue { attr.defaultValue = dv }
        return attr
    }

    static func optionalString(_ name: String) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = .stringAttributeType
        attr.isOptional = true
        return attr
    }

    static func int16(_ name: String) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = .integer16AttributeType
        attr.isOptional = false
        attr.defaultValue = Int16(0)
        return attr
    }

    static func int32(_ name: String) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = .integer32AttributeType
        attr.isOptional = false
        attr.defaultValue = Int32(0)
        return attr
    }

    static func float(_ name: String) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = .floatAttributeType
        attr.isOptional = false
        attr.defaultValue = Float(0)
        return attr
    }

    static func bool(_ name: String, defaultValue: Bool = false) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = .booleanAttributeType
        attr.isOptional = false
        attr.defaultValue = defaultValue
        return attr
    }
}
