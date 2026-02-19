import Foundation

/// All possible states of a Kairo focus session.
enum TimerState: String, Equatable {
    /// No session active. Ready to start.
    case idle

    /// 3-2-1 countdown before focus begins.
    case preparing

    /// Active focus session in progress.
    case focusing

    /// Session paused by user.
    case paused

    /// Break between focus sessions.
    case onBreak

    /// Session completed successfully (reached target duration).
    case completed

    /// Session abandoned (quit before 50% completion).
    case abandoned

    var isActive: Bool {
        switch self {
        case .preparing, .focusing, .paused, .onBreak:
            return true
        case .idle, .completed, .abandoned:
            return false
        }
    }

    var displayName: String {
        switch self {
        case .idle:      return "Ready"
        case .preparing: return "Get Ready"
        case .focusing:  return "Focusing"
        case .paused:    return "Paused"
        case .onBreak:   return "Break"
        case .completed: return "Complete"
        case .abandoned: return "Ended"
        }
    }

    var iconName: String {
        switch self {
        case .idle:      return "play.circle.fill"
        case .preparing: return "hourglass"
        case .focusing:  return "brain.head.profile"
        case .paused:    return "pause.circle.fill"
        case .onBreak:   return "cup.and.saucer.fill"
        case .completed: return "checkmark.circle.fill"
        case .abandoned: return "xmark.circle.fill"
        }
    }
}
