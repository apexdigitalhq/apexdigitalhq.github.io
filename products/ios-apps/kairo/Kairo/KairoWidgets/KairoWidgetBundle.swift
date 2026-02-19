import SwiftUI
import WidgetKit

// MARK: - KairoWidgetBundle

/// Entry point for Kairo's widget extension.
///
/// Bundles both home screen widgets — FocusTimeWidget and StreakWidget —
/// into a single extension target. Each widget provides small and medium
/// families, sharing the same `AppGroup` data layer via `WidgetDataProvider`.
@main
struct KairoWidgetBundle: WidgetBundle {

    var body: some Widget {
        FocusTimeWidget()
        StreakWidget()
    }
}
