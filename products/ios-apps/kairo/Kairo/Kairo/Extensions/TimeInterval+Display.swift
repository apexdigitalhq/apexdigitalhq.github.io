import Foundation

extension TimeInterval {

    /// Formats as "MM:SS" (e.g., "25:00", "1:30").
    var timerDisplay: String {
        let totalSeconds = Int(self)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Formats as "HH:MM:SS" for durations over an hour.
    var longTimerDisplay: String {
        let totalSeconds = Int(self)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Human-readable duration (e.g., "25 min", "1h 30m").
    var humanReadable: String {
        let totalMinutes = Int(self) / 60

        if totalMinutes < 1 {
            return "\(Int(self))s"
        }
        if totalMinutes < 60 {
            return "\(totalMinutes) min"
        }

        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if minutes == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(minutes)m"
    }
}

extension Int32 {

    /// Converts seconds (stored as Int32) to a timer display string.
    var timerDisplay: String {
        TimeInterval(self).timerDisplay
    }

    /// Converts seconds (stored as Int32) to a human-readable duration string.
    var humanReadable: String {
        TimeInterval(self).humanReadable
    }
}

extension Int {

    /// Converts minutes to a human-readable string (e.g., "25 min").
    var minutesDisplay: String {
        if self < 60 {
            return "\(self) min"
        }
        let hours = self / 60
        let mins = self % 60
        if mins == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(mins)m"
    }
}
