import Foundation
import CoreMotion
import UIKit
import Combine

// MARK: - DistractionType

/// Categories of distraction events that can occur during a focus session.
///
/// Each type maps to a distinct detection mechanism — from Core Motion physics
/// to UIApplication lifecycle hooks — allowing fine-grained penalty calculations
/// and post-session analytics. All detection is on-device; no network calls.
enum DistractionType: String, CaseIterable, Codable {
    /// Device picked up from a resting surface (detected via accelerometer orientation shift).
    case phonePickup = "phone_pickup"
    /// App moved to background (user switched away during focus).
    case appBackgrounded = "app_background"
    /// User manually paused the session.
    case manualPause = "manual_pause"
    /// Session remained paused for longer than the extended threshold (2 minutes).
    case extendedPause = "extended_pause"

    /// Human-readable label for UI display.
    var displayName: String {
        switch self {
        case .phonePickup:    return "Phone Pickup"
        case .appBackgrounded: return "App Switch"
        case .manualPause:    return "Manual Pause"
        case .extendedPause:  return "Extended Pause"
        }
    }

    /// SF Symbol representing this distraction type.
    var iconName: String {
        switch self {
        case .phonePickup:    return "iphone.radiowaves.left.and.right"
        case .appBackgrounded: return "arrow.uturn.left"
        case .manualPause:    return "pause.circle"
        case .extendedPause:  return "clock.badge.exclamationmark"
        }
    }

    /// Base penalty weight for focus score calculation.
    var penaltyWeight: Double {
        switch self {
        case .phonePickup:    return 0.03
        case .appBackgrounded: return 0.05
        case .manualPause:    return 0.05
        case .extendedPause:  return 0.08
        }
    }
}

// MARK: - DistractionRecord

/// An immutable record of a single distraction event within a focus session.
///
/// Lightweight value type used for in-memory tracking during a session.
/// Records are persisted to Core Data via `DistractionEvent` when the
/// session finalizes.
struct DistractionRecord: Identifiable, Codable, Equatable {

    /// Unique identifier for this record.
    let id: UUID

    /// The kind of distraction detected.
    let type: DistractionType

    /// When the distraction occurred.
    let timestamp: Date

    /// Duration of the distraction in seconds (nil if instantaneous, e.g. a pickup).
    let durationSeconds: TimeInterval?

    init(
        id: UUID = UUID(),
        type: DistractionType,
        timestamp: Date = Date(),
        durationSeconds: TimeInterval? = nil
    ) {
        self.id = id
        self.type = type
        self.timestamp = timestamp
        self.durationSeconds = durationSeconds
    }
}

// MARK: - DistractionDetector

/// On-device distraction awareness engine using Core Motion and app lifecycle signals.
///
/// Monitors three independent channels during a focus session:
/// 1. **Physics**: Core Motion device-motion updates detect flat→upright orientation
///    changes (phone pickups) without accessing location, camera, or microphone.
/// 2. **Lifecycle**: `UIApplication` notifications capture app backgrounding events.
/// 3. **Pause timer**: Tracks how long a session stays paused — exceeding 2 minutes
///    records an extended pause distraction.
///
/// All processing is on-device. No data leaves the phone. If Core Motion
/// authorization is denied, the detector gracefully degrades to lifecycle-only mode.
@MainActor
final class DistractionDetector: ObservableObject {

    // MARK: - Published State

    /// Whether the detector is actively monitoring for distractions.
    @Published private(set) var isMonitoring: Bool = false

    /// All distractions recorded during the current session.
    @Published private(set) var distractionsThisSession: [DistractionRecord] = []

    /// Total number of distractions this session (convenience count).
    @Published private(set) var distractionCount: Int = 0

    /// Number of phone pickups detected this session.
    @Published private(set) var pickupCount: Int = 0

    /// Whether Core Motion authorization has been granted.
    @Published private(set) var motionAuthorized: Bool = false

    // MARK: - Core Motion

    /// Activity manager for motion activity queries (requires authorization).
    private let motionActivityManager = CMMotionActivityManager()

    /// Device motion manager for accelerometer-based pickup detection.
    private let deviceMotionManager = CMMotionManager()

    /// Pedometer used to verify motion context alongside device orientation.
    private let pedometer = CMPedometer()

    // MARK: - Configuration

    /// Minimum angle from horizontal (in degrees) to consider the device "upright".
    /// A phone flat on a desk is ~0°; held in hand is typically 50°–80°.
    private let pickupAngleThreshold: Double = 45.0

    /// Minimum seconds between consecutive pickup detections to avoid duplicates.
    private let pickupCooldownInterval: TimeInterval = 15.0

    /// Seconds a session must remain paused before recording an extended pause.
    private let extendedPauseThreshold: TimeInterval = 120.0

    /// Minimum background duration (in seconds) to record as a distraction.
    /// Brief system interrupts (< 2s) are ignored.
    private let backgroundMinDuration: TimeInterval = 2.0

    // MARK: - Internal State

    /// Whether the device was in a flat/resting position on last sample.
    private var wasDeviceFlat: Bool = true

    /// Timestamp of the last recorded phone pickup (for cooldown gating).
    private var lastPickupTime: Date?

    /// When the app entered the background (nil if foregrounded).
    private var backgroundEntryDate: Date?

    /// When the current pause started (nil if not paused).
    private var pauseStartDate: Date?

    /// Timer that fires to check for extended pauses.
    private var extendedPauseTimer: Timer?

    /// Lifecycle notification observers.
    private var backgroundObserver: Any?
    private var foregroundObserver: Any?

    /// Operation queue for Core Motion callbacks (off main thread).
    private let motionQueue = OperationQueue()

    // MARK: - Init

    init() {
        motionQueue.name = "com.kairo.distraction.motion"
        motionQueue.maxConcurrentOperationCount = 1
        checkMotionAuthorization()
    }

    deinit {
        if let obs = backgroundObserver {
            NotificationCenter.default.removeObserver(obs)
        }
        if let obs = foregroundObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    // MARK: - Authorization

    /// Checks the current Core Motion authorization status and updates `motionAuthorized`.
    private func checkMotionAuthorization() {
        let status = CMMotionActivityManager.authorizationStatus()
        motionAuthorized = (status == .authorized)
    }

    /// Requests Core Motion authorization by starting a brief activity query.
    ///
    /// Core Motion doesn't have an explicit "request permission" API — authorization
    /// is triggered on first use. This fires a short query, checks the resulting
    /// status, and stops immediately.
    func requestMotionAuthorization() {
        guard CMMotionActivityManager.isActivityAvailable() else {
            motionAuthorized = false
            return
        }

        motionActivityManager.queryActivityStarting(
            from: Date().addingTimeInterval(-3600),
            to: Date(),
            to: motionQueue
        ) { [weak self] _, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let nsError = error as NSError?,
                   nsError.domain == CMErrorDomain,
                   nsError.code == CMErrorMotionActivityNotAuthorized.rawValue {
                    self.motionAuthorized = false
                } else {
                    self.motionAuthorized = true
                }
            }
        }
    }

    // MARK: - Start / Stop Monitoring

    /// Begins monitoring for distractions across all available channels.
    ///
    /// Registers for app lifecycle notifications (always available), and starts
    /// Core Motion device-motion updates if authorized. Safe to call multiple
    /// times — subsequent calls are no-ops while already monitoring.
    func startMonitoring() {
        guard !isMonitoring else { return }

        // Reset session state
        distractionsThisSession = []
        distractionCount = 0
        pickupCount = 0
        wasDeviceFlat = true
        lastPickupTime = nil
        backgroundEntryDate = nil
        pauseStartDate = nil

        // Always register for lifecycle events
        registerLifecycleObservers()

        // Start device motion if authorized and available
        startDeviceMotionIfAvailable()

        isMonitoring = true
    }

    /// Stops all monitoring and returns the complete distraction log for this session.
    ///
    /// Call this when the focus session ends (completed or abandoned). After this
    /// call, the detector is idle and ready for a new session via `startMonitoring()`.
    ///
    /// - Returns: Array of all `DistractionRecord`s captured during the session.
    @discardableResult
    func stopMonitoring() -> [DistractionRecord] {
        guard isMonitoring else { return distractionsThisSession }

        // Tear down motion updates
        deviceMotionManager.stopDeviceMotionUpdates()

        // Tear down lifecycle observers
        removeLifecycleObservers()

        // Cancel extended pause timer
        extendedPauseTimer?.invalidate()
        extendedPauseTimer = nil

        // Close out any open background window
        if let bgEntry = backgroundEntryDate {
            let duration = Date().timeIntervalSince(bgEntry)
            if duration >= backgroundMinDuration {
                appendRecord(DistractionRecord(
                    type: .appBackgrounded,
                    durationSeconds: duration
                ))
            }
            backgroundEntryDate = nil
        }

        // Close out any open pause window
        closePauseWindow()

        isMonitoring = false

        return distractionsThisSession
    }

    // MARK: - Manual Recording

    /// Manually record a distraction event.
    ///
    /// Used by external systems (e.g. `FocusEngine.pause()`) to log events
    /// that the detector cannot observe directly.
    ///
    /// - Parameter type: The distraction type to record.
    func recordDistraction(type: DistractionType) {
        guard isMonitoring else { return }

        let record = DistractionRecord(type: type)
        appendRecord(record)
    }

    // MARK: - Pause Tracking

    /// Notifies the detector that the session has been paused.
    ///
    /// Starts an internal timer; if the pause exceeds `extendedPauseThreshold`
    /// (2 minutes), an `.extendedPause` distraction is automatically recorded.
    func sessionDidPause() {
        guard isMonitoring else { return }
        pauseStartDate = Date()
        startExtendedPauseTimer()
    }

    /// Notifies the detector that the session has resumed from a pause.
    ///
    /// Cancels the extended pause timer and closes the pause tracking window.
    func sessionDidResume() {
        extendedPauseTimer?.invalidate()
        extendedPauseTimer = nil
        closePauseWindow()
    }

    // MARK: - Focus Score Penalty

    /// Calculates a distraction-based penalty factor for the session focus score.
    ///
    /// Formula: `1.0 - (pauseCount × 0.05) - (pickupCount × 0.03)`, clamped to
    /// a floor of 0.5. A perfect session with zero distractions returns 1.0.
    ///
    /// - Returns: Penalty factor between 0.5 and 1.0.
    func calculateDistractionPenalty() -> Double {
        let pauseDistractions = distractionsThisSession.filter {
            $0.type == .manualPause || $0.type == .extendedPause || $0.type == .appBackgrounded
        }.count

        let pickups = pickupCount

        let penalty = 1.0
            - (Double(pauseDistractions) * 0.05)
            - (Double(pickups) * 0.03)

        return max(0.5, min(1.0, penalty))
    }

    /// Returns the total time spent in distractions this session (seconds).
    var totalDistractionDuration: TimeInterval {
        distractionsThisSession.compactMap(\.durationSeconds).reduce(0, +)
    }

    // MARK: - Device Motion (Pickup Detection)

    /// Starts Core Motion device-motion updates for phone pickup detection.
    ///
    /// Monitors the device's pitch angle (rotation around the lateral axis).
    /// A transition from flat (< threshold) to upright (≥ threshold) within
    /// the cooldown window is classified as a phone pickup.
    private func startDeviceMotionIfAvailable() {
        guard deviceMotionManager.isDeviceMotionAvailable else { return }
        guard motionAuthorized || CMMotionActivityManager.authorizationStatus() != .denied else {
            return
        }

        deviceMotionManager.deviceMotionUpdateInterval = 0.5 // 2 Hz — battery-friendly

        deviceMotionManager.startDeviceMotionUpdates(
            using: .xArbitraryZVertical,
            to: motionQueue
        ) { [weak self] motion, error in
            guard let motion = motion, error == nil else { return }
            Task { @MainActor [weak self] in
                self?.processDeviceMotion(motion)
            }
        }
    }

    /// Evaluates a device-motion sample to detect flat→upright transitions.
    ///
    /// The pitch angle (in degrees) measures tilt from horizontal. A phone
    /// lying flat reads ~0°; held upright reads ~70°–90°. The detector looks
    /// for transitions crossing `pickupAngleThreshold` with cooldown gating
    /// to prevent rapid-fire false positives.
    private func processDeviceMotion(_ motion: CMDeviceMotion) {
        // Pitch in degrees (0 = flat, 90 = upright, negative = face down)
        let pitchDegrees = abs(motion.attitude.pitch * 180.0 / .pi)

        let isFlat = pitchDegrees < pickupAngleThreshold
        let isUpright = pitchDegrees >= pickupAngleThreshold

        // Detect flat → upright transition
        if wasDeviceFlat && isUpright {
            // Cooldown check: ignore if we just logged a pickup
            let now = Date()
            if let lastPickup = lastPickupTime,
               now.timeIntervalSince(lastPickup) < pickupCooldownInterval {
                wasDeviceFlat = false
                return
            }

            lastPickupTime = now
            let record = DistractionRecord(type: .phonePickup)
            appendRecord(record)
            pickupCount += 1
        }

        wasDeviceFlat = isFlat
    }

    // MARK: - App Lifecycle Observers

    /// Registers for UIApplication background/foreground notifications.
    private func registerLifecycleObservers() {
        removeLifecycleObservers()

        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleDidEnterBackground()
            }
        }

        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleWillEnterForeground()
            }
        }
    }

    /// Removes lifecycle notification observers.
    private func removeLifecycleObservers() {
        if let obs = backgroundObserver {
            NotificationCenter.default.removeObserver(obs)
            backgroundObserver = nil
        }
        if let obs = foregroundObserver {
            NotificationCenter.default.removeObserver(obs)
            foregroundObserver = nil
        }
    }

    /// Handles the app entering background — marks the timestamp for duration tracking.
    private func handleDidEnterBackground() {
        guard isMonitoring else { return }
        backgroundEntryDate = Date()
    }

    /// Handles the app returning to foreground — calculates time away and records
    /// the distraction if it exceeds the minimum threshold.
    private func handleWillEnterForeground() {
        guard isMonitoring, let bgEntry = backgroundEntryDate else { return }

        let duration = Date().timeIntervalSince(bgEntry)
        backgroundEntryDate = nil

        // Ignore very brief system interrupts (< 2 seconds)
        guard duration >= backgroundMinDuration else { return }

        let record = DistractionRecord(
            type: .appBackgrounded,
            durationSeconds: duration
        )
        appendRecord(record)
    }

    // MARK: - Extended Pause Detection

    /// Starts a timer that fires after `extendedPauseThreshold` seconds to
    /// record an extended pause distraction.
    private func startExtendedPauseTimer() {
        extendedPauseTimer?.invalidate()

        extendedPauseTimer = Timer.scheduledTimer(
            withTimeInterval: extendedPauseThreshold,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isMonitoring, self.pauseStartDate != nil else { return }
                let record = DistractionRecord(
                    type: .extendedPause,
                    durationSeconds: self.extendedPauseThreshold
                )
                self.appendRecord(record)
            }
        }
    }

    /// Closes the pause tracking window, calculating final duration if applicable.
    private func closePauseWindow() {
        pauseStartDate = nil
        extendedPauseTimer?.invalidate()
        extendedPauseTimer = nil
    }

    // MARK: - Record Management

    /// Appends a distraction record and updates published counters.
    private func appendRecord(_ record: DistractionRecord) {
        distractionsThisSession.append(record)
        distractionCount = distractionsThisSession.count
    }

    // MARK: - Session Summary

    /// Returns a breakdown of distractions by type for post-session analytics.
    var distractionsByType: [DistractionType: Int] {
        Dictionary(grouping: distractionsThisSession, by: \.type)
            .mapValues(\.count)
    }

    /// The most recent distraction record, if any.
    var lastDistraction: DistractionRecord? {
        distractionsThisSession.last
    }

    /// The most recent background entry date, exposed for the overlay view
    /// to calculate time-away duration when the app returns to foreground.
    var lastBackgroundEntryDate: Date? {
        backgroundEntryDate
    }
}
