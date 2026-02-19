import EventKit
import SwiftUI

/// Manages iOS Calendar integration for scheduling focus sessions and goal reminders.
/// Uses EventKit to create, read, and manage calendar events tied to Kairo goals.
final class CalendarManager: ObservableObject {

    static let shared = CalendarManager()

    private let eventStore = EKEventStore()

    @Published var hasAccess: Bool = false
    @Published var upcomingEvents: [KairoCalendarEvent] = []

    private let kairoCalendarTitle = "Kairo Focus"

    init() {
        checkAccess()
    }

    // MARK: - Permissions

    func checkAccess() {
        let status = EKEventStore.authorizationStatus(for: .event)
        hasAccess = (status == .fullAccess || status == .authorized)
    }

    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            await MainActor.run { hasAccess = granted }
            return granted
        } catch {
            return false
        }
    }

    // MARK: - Kairo Calendar

    /// Gets or creates the "Kairo Focus" calendar.
    private func getOrCreateCalendar() -> EKCalendar? {
        // Check if we already have a Kairo calendar
        let calendars = eventStore.calendars(for: .event)
        if let existing = calendars.first(where: { $0.title == kairoCalendarTitle }) {
            return existing
        }

        // Create a new one
        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = kairoCalendarTitle
        calendar.cgColor = UIColor(red: 0.61, green: 0.35, blue: 0.71, alpha: 1.0).cgColor // Purple

        // Use the default calendar source
        if let source = eventStore.defaultCalendarForNewEvents?.source {
            calendar.source = source
        } else if let source = eventStore.sources.first(where: { $0.sourceType == .local }) {
            calendar.source = source
        } else {
            return nil
        }

        do {
            try eventStore.saveCalendar(calendar, commit: true)
            return calendar
        } catch {
            return nil
        }
    }

    // MARK: - Schedule Goal Sessions

    /// Schedules recurring calendar events for a goal.
    /// - Parameters:
    ///   - goal: The custom goal to schedule
    ///   - days: Which days of the week to schedule (1=Sunday, 2=Monday, etc.)
    ///   - startHour: Hour to start the session (24h format)
    ///   - durationMinutes: How long each session should be
    ///   - weeksAhead: How many weeks ahead to create events
    /// - Returns: Number of events created
    @discardableResult
    func scheduleGoalSessions(
        goal: CustomGoal,
        days: [Int],
        startHour: Int,
        startMinute: Int = 0,
        durationMinutes: Int,
        weeksAhead: Int = 4
    ) -> Int {
        guard hasAccess, let calendar = getOrCreateCalendar() else { return 0 }

        var eventsCreated = 0
        let cal = Calendar.current
        let now = Date()

        for weekOffset in 0..<weeksAhead {
            for dayOfWeek in days {
                // Find the next occurrence of this day
                var components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
                components.weekday = dayOfWeek

                guard let baseDate = cal.date(from: components) else { continue }
                guard let targetDate = cal.date(byAdding: .weekOfYear, value: weekOffset, to: baseDate) else { continue }

                // Skip dates in the past
                if targetDate < cal.startOfDay(for: now) { continue }

                // Set the time
                var eventComponents = cal.dateComponents([.year, .month, .day], from: targetDate)
                eventComponents.hour = startHour
                eventComponents.minute = startMinute

                guard let startDate = cal.date(from: eventComponents) else { continue }
                guard let endDate = cal.date(byAdding: .minute, value: durationMinutes, to: startDate) else { continue }

                // Create the event
                let event = EKEvent(eventStore: eventStore)
                event.title = "\(goal.activity.displayName) — \(goal.title)"
                event.startDate = startDate
                event.endDate = endDate
                event.calendar = calendar
                event.notes = "Kairo Focus Session\nGoal: \(goal.title)\nTarget: \(goal.targetValue) \(goal.goalType.displayName.lowercased()) \(goal.timeFrame.label)"

                // Add alerts
                event.addAlarm(EKAlarm(relativeOffset: -15 * 60))  // 15 min before
                event.addAlarm(EKAlarm(relativeOffset: 0))          // At start time

                do {
                    try eventStore.save(event, span: .thisEvent)
                    eventsCreated += 1
                } catch {
                    continue
                }
            }
        }

        return eventsCreated
    }

    /// Creates a single calendar event for a deadline/due date.
    func createDeadlineEvent(
        title: String,
        dueDate: Date,
        activity: CustomGoal.FocusActivity,
        notes: String? = nil
    ) -> Bool {
        guard hasAccess, let calendar = getOrCreateCalendar() else { return false }

        let event = EKEvent(eventStore: eventStore)
        event.title = "⏰ Due: \(title)"
        event.startDate = dueDate
        event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: dueDate) ?? dueDate
        event.calendar = calendar
        event.isAllDay = false
        event.notes = notes ?? "Kairo deadline for \(activity.displayName)"

        // Add alerts: 1 day before, 2 hours before, at time
        event.addAlarm(EKAlarm(relativeOffset: -24 * 60 * 60))
        event.addAlarm(EKAlarm(relativeOffset: -2 * 60 * 60))
        event.addAlarm(EKAlarm(relativeOffset: 0))

        do {
            try eventStore.save(event, span: .thisEvent)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Fetch Upcoming Events

    /// Fetches upcoming Kairo calendar events for the next N days.
    func fetchUpcoming(days: Int = 7) {
        guard hasAccess else { return }

        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        guard let end = cal.date(byAdding: .day, value: days, to: start) else { return }

        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = eventStore.events(matching: predicate)

        // Filter for Kairo events (by calendar name or title prefix)
        let kairoEvents = events.filter {
            $0.calendar?.title == kairoCalendarTitle
            || $0.title?.contains("Kairo") == true
            || $0.notes?.contains("Kairo") == true
        }

        upcomingEvents = kairoEvents.map { event in
            KairoCalendarEvent(
                id: event.eventIdentifier ?? UUID().uuidString,
                title: event.title ?? "Focus Session",
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                notes: event.notes
            )
        }.sorted { $0.startDate < $1.startDate }
    }
}

// MARK: - Kairo Calendar Event (lightweight model)

struct KairoCalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let notes: String?

    var durationMinutes: Int {
        Int(endDate.timeIntervalSince(startDate) / 60)
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: startDate)
    }

    var formattedDay: String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(startDate) {
            return "Today"
        } else if Calendar.current.isDateInTomorrow(startDate) {
            return "Tomorrow"
        }
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: startDate)
    }

    var isUpcoming: Bool {
        startDate > Date()
    }
}
