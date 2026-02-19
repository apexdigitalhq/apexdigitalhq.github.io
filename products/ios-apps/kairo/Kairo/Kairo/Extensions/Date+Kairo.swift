import Foundation

extension Date {

    /// Returns midnight (start of day) for this date.
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// Returns the end of day (23:59:59) for this date.
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay)!
    }

    /// The hour component (0–23) for the current calendar.
    var hour: Int {
        Calendar.current.component(.hour, from: self)
    }

    /// The day of week (1 = Sunday, 7 = Saturday in Gregorian).
    var dayOfWeek: Int {
        Calendar.current.component(.weekday, from: self)
    }

    /// ISO weekday where Monday = 1, Sunday = 7.
    var isoDayOfWeek: Int {
        let weekday = dayOfWeek
        return weekday == 1 ? 7 : weekday - 1
    }

    /// Short day name (e.g., "Mon", "Tue").
    var shortDayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: self)
    }

    /// Readable date string (e.g., "Jan 15, 2025").
    var mediumDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }

    /// Readable time string (e.g., "2:30 PM").
    var shortTimeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }

    /// Whether this date falls on the same calendar day as another.
    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }

    /// Number of calendar days between this date and another.
    func daysBetween(_ other: Date) -> Int {
        let components = Calendar.current.dateComponents([.day], from: startOfDay, to: other.startOfDay)
        return abs(components.day ?? 0)
    }

    /// Returns an array of dates for the last N days including today.
    static func lastDays(_ count: Int) -> [Date] {
        let today = Date().startOfDay
        return (0..<count).reversed().compactMap { offset in
            Calendar.current.date(byAdding: .day, value: -offset, to: today)
        }
    }
}
