import Foundation

// MARK: - InfoPlistKeys

/// Info.plist key constants and privacy usage descriptions.
///
/// Centralizes all plist-related strings so they can be referenced in code
/// (e.g., checking capabilities at runtime) and kept in sync with the
/// actual Info.plist file.
///
/// Note: These values must match what's declared in the Xcode project's
/// Info.plist or target build settings. This file is the source of truth
/// for what should be there.
enum InfoPlistKeys {

    // MARK: - Privacy Usage Descriptions

    /// Motion & Fitness usage description (required for CMMotionManager).
    ///
    /// Kairo uses accelerometer data to detect phone pickups during focus
    /// sessions. This is the string shown in the system permission dialog.
    static let motionUsageDescription = """
    Kairo uses motion data to detect when you pick up your phone during \
    focus sessions. This helps measure focus quality. All data stays on \
    your device.
    """

    // NOTE: NSUserTrackingUsageDescription is intentionally NOT included.
    // Kairo does not use ATT (App Tracking Transparency) because we do
    // not track users, period. No analytics SDKs, no ad networks, no
    // cross-app identifiers.

    // MARK: - Background Modes

    /// Background modes required by Kairo.
    ///
    /// - `audio`: Ambient soundscape playback continues in background
    /// - `fetch`: Periodic background refresh for widget data updates
    /// - `processing`: Background task for streak/score recalculation
    static let backgroundModes: [String] = [
        "audio",
        "fetch",
        "processing"
    ]

    /// Background task identifiers registered in Info.plist.
    static let backgroundTaskIdentifiers: [String] = [
        "com.kairo.app.streak-check",
        "com.kairo.app.daily-score",
        "com.kairo.app.widget-refresh"
    ]

    // MARK: - App Transport Security

    /// ATS configuration: no exceptions needed.
    ///
    /// Kairo makes zero network calls. All data is on-device.
    /// We leave ATS at its strictest default — no exceptions, no
    /// arbitrary loads, no cleartext traffic.
    static let atsAllowsArbitraryLoads = false

    // MARK: - Required Device Capabilities

    /// Device capabilities required to install Kairo.
    ///
    /// - `armv7`: ARM processor (all modern iPhones)
    /// - `accelerometer`: Required for distraction detection via motion
    static let requiredDeviceCapabilities: [String] = [
        "armv7",
        "accelerometer"
    ]

    // MARK: - Interface Orientations

    /// Supported interface orientations — portrait only.
    ///
    /// Focus apps benefit from a locked orientation. No landscape
    /// to prevent accidental rotations during focus sessions.
    static let supportedOrientations: [String] = [
        "UIInterfaceOrientationPortrait"
    ]

    /// iPad orientations (if we ever ship on iPad).
    static let supportedOrientationsiPad: [String] = [
        "UIInterfaceOrientationPortrait",
        "UIInterfaceOrientationPortraitUpsideDown"
    ]

    // MARK: - Bundle Identifiers

    /// Main app bundle identifier.
    static let mainBundleIdentifier = "com.kairo.app"

    /// Widget extension bundle identifier.
    static let widgetBundleIdentifier = "com.kairo.app.widget"

    // MARK: - Deployment

    /// Minimum iOS deployment target.
    static let minimumOSVersion = "17.0"

    /// Launch storyboard name (or "LaunchScreen" if using storyboard).
    static let launchStoryboardName = "LaunchScreen"

    // MARK: - Status Bar

    /// Status bar style — light content for dark navigation bars.
    static let statusBarStyle = "UIStatusBarStyleLightContent"

    /// Whether the status bar is initially hidden.
    static let statusBarHidden = false

    // MARK: - Scene Configuration

    /// Application scene manifest — required for SwiftUI lifecycle.
    static let supportsMultipleScenes = false
}
