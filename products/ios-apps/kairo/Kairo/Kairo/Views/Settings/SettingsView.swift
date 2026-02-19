import SwiftUI
import CoreData
import StoreKit

/// Main settings screen — grouped list with Account, Focus Preferences, Privacy, and About sections.
///
/// Uses KairoTheme throughout. Integrates with SubscriptionManager for subscription
/// status and PersistenceController for data management.
struct SettingsView: View {

    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.managedObjectContext) private var viewContext

    // MARK: - Focus Preferences State

    @AppStorage("kairo_default_session_duration") private var defaultSessionDuration: Int = KairoTheme.SessionPreset.defaultDuration
    @AppStorage("kairo_break_duration") private var breakDuration: Int = KairoTheme.SessionPreset.shortBreak
    @AppStorage("kairo_sound_enabled") private var soundEnabled: Bool = true

    // MARK: - Sheet State

    @State private var showPaywall = false
    @State private var showDeleteConfirmation = false
    @State private var showExportShare = false
    @State private var exportURL: URL?
    @State private var showExportError = false

    // Available duration options
    private let sessionDurations = [15, 20, 25, 30, 35, 40, 45, 50, 60, 90]
    private let breakDurations   = [3, 5, 10, 15, 20]

    var body: some View {
        NavigationStack {
            List {
                accountSection
                focusPreferencesSection
                privacySection
                aboutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .background(KairoColors.backgroundAdaptive.ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .fullScreenCover(isPresented: $showPaywall) {
                PaywallView()
                    .environmentObject(subscriptionManager)
            }
            .alert("Delete All Data?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete Everything", role: .destructive) {
                    deleteAllData()
                }
            } message: {
                Text("This will permanently delete all your focus sessions, scores, streaks, and learned patterns. This action cannot be undone.")
            }
            .alert("Export Error", isPresented: $showExportError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Unable to export your data. Please try again.")
            }
            .sheet(isPresented: $showExportShare) {
                if let url = exportURL {
                    ShareSheet(url: url)
                }
            }
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        Section {
            // Subscription status row
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: KairoTheme.Radius.small)
                        .fill(subscriptionManager.isPro
                              ? KairoColors.accentAdaptive.opacity(0.15)
                              : KairoColors.mutedAdaptive.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: subscriptionManager.isPro ? "crown.fill" : "person.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(subscriptionManager.isPro
                                         ? KairoColors.accentAdaptive
                                         : KairoColors.mutedAdaptive)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Subscription")
                        .font(KairoTypography.bodyLarge)
                        .foregroundColor(KairoColors.primaryAdaptive)

                    Text(subscriptionManager.subscriptionStatusText)
                        .font(KairoTypography.bodySmall)
                        .foregroundColor(subscriptionManager.isPro
                                         ? KairoColors.accentAdaptive
                                         : KairoColors.mutedAdaptive)
                }

                Spacer()

                if subscriptionManager.isPro {
                    Text("PRO")
                        .font(KairoTypography.labelSmall)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, KairoTheme.Spacing.xs)
                        .padding(.vertical, KairoTheme.Spacing.xxs)
                        .background(
                            Capsule().fill(KairoColors.accentAdaptive)
                        )
                }
            }
            .listRowBackground(KairoColors.surfaceAdaptive)

            // Upgrade / Manage button
            if !subscriptionManager.isPro || subscriptionManager.isWithinReverseTrial() {
                Button {
                    showPaywall = true
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(KairoColors.accentAdaptive)
                        Text(subscriptionManager.isWithinReverseTrial()
                             ? "Upgrade to Keep Pro"
                             : "Upgrade to Pro")
                            .font(KairoTypography.bodyLarge)
                            .foregroundColor(KairoColors.accentAdaptive)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(KairoColors.mutedAdaptive)
                    }
                }
                .listRowBackground(KairoColors.surfaceAdaptive)
            }
        } header: {
            Text("Account")
                .font(KairoTypography.label)
                .foregroundColor(KairoColors.mutedAdaptive)
                .textCase(nil)
        }
    }

    // MARK: - Focus Preferences Section

    private var focusPreferencesSection: some View {
        Section {
            // Default session duration
            HStack {
                settingsIcon("timer", color: KairoColors.accentAdaptive)

                Picker("Session Duration", selection: $defaultSessionDuration) {
                    ForEach(sessionDurations, id: \.self) { minutes in
                        Text("\(minutes) min").tag(minutes)
                    }
                }
                .font(KairoTypography.bodyLarge)
                .foregroundColor(KairoColors.primaryAdaptive)
            }
            .listRowBackground(KairoColors.surfaceAdaptive)

            // Break duration
            HStack {
                settingsIcon("cup.and.saucer.fill", color: KairoColors.successAdaptive)

                Picker("Break Duration", selection: $breakDuration) {
                    ForEach(breakDurations, id: \.self) { minutes in
                        Text("\(minutes) min").tag(minutes)
                    }
                }
                .font(KairoTypography.bodyLarge)
                .foregroundColor(KairoColors.primaryAdaptive)
            }
            .listRowBackground(KairoColors.surfaceAdaptive)

            // Sound toggle
            HStack {
                settingsIcon("speaker.wave.2.fill", color: Color(hex: 0x9B59B6))

                Toggle("Session Sounds", isOn: $soundEnabled)
                    .font(KairoTypography.bodyLarge)
                    .foregroundColor(KairoColors.primaryAdaptive)
                    .tint(KairoColors.accentAdaptive)
            }
            .listRowBackground(KairoColors.surfaceAdaptive)
        } header: {
            Text("Focus Preferences")
                .font(KairoTypography.label)
                .foregroundColor(KairoColors.mutedAdaptive)
                .textCase(nil)
        }
    }

    // MARK: - Privacy Section

    private var privacySection: some View {
        Section {
            // Data residency info
            HStack(alignment: .top, spacing: KairoTheme.Spacing.sm) {
                settingsIcon("lock.shield.fill", color: KairoColors.successAdaptive)

                VStack(alignment: .leading, spacing: KairoTheme.Spacing.xxs) {
                    Text("Your Data Stays on This Device")
                        .font(KairoTypography.bodyLarge)
                        .foregroundColor(KairoColors.primaryAdaptive)

                    Text("Kairo never sends your data to any server. All focus sessions, scores, and learned patterns are stored locally on your iPhone.")
                        .font(KairoTypography.bodySmall)
                        .foregroundColor(KairoColors.mutedAdaptive)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .listRowBackground(KairoColors.surfaceAdaptive)

            // Export data
            Button {
                exportData()
            } label: {
                HStack {
                    settingsIcon("square.and.arrow.up.fill", color: Color(hex: 0x3498DB))
                    Text("Export Your Data")
                        .font(KairoTypography.bodyLarge)
                        .foregroundColor(KairoColors.primaryAdaptive)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(KairoColors.mutedAdaptive)
                }
            }
            .listRowBackground(KairoColors.surfaceAdaptive)

            // Delete all data
            Button {
                showDeleteConfirmation = true
            } label: {
                HStack {
                    settingsIcon("trash.fill", color: .red)
                    Text("Delete All Data")
                        .font(KairoTypography.bodyLarge)
                        .foregroundColor(.red)
                    Spacer()
                }
            }
            .listRowBackground(KairoColors.surfaceAdaptive)
        } header: {
            Text("Your Data")
                .font(KairoTypography.label)
                .foregroundColor(KairoColors.mutedAdaptive)
                .textCase(nil)
        } footer: {
            Text("No analytics. No tracking. No ads. Your focus data is yours alone.")
                .font(KairoTypography.caption)
                .foregroundColor(KairoColors.mutedAdaptive)
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            // App version
            HStack {
                settingsIcon("info.circle.fill", color: KairoColors.mutedAdaptive)
                Text("Version")
                    .font(KairoTypography.bodyLarge)
                    .foregroundColor(KairoColors.primaryAdaptive)
                Spacer()
                Text(appVersion)
                    .font(KairoTypography.body)
                    .foregroundColor(KairoColors.mutedAdaptive)
            }
            .listRowBackground(KairoColors.surfaceAdaptive)

            // Privacy policy
            Link(destination: URL(string: "https://apexdigitalhq.github.io/kairo-privacy.html")!) {
                HStack {
                    settingsIcon("hand.raised.fill", color: Color(hex: 0x3498DB))
                    Text("Privacy Policy")
                        .font(KairoTypography.bodyLarge)
                        .foregroundColor(KairoColors.primaryAdaptive)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(KairoColors.mutedAdaptive)
                }
            }
            .listRowBackground(KairoColors.surfaceAdaptive)

            // Rate app
            Button {
                requestAppReview()
            } label: {
                HStack {
                    settingsIcon("star.fill", color: KairoColors.warningAdaptive)
                    Text("Rate Kairo")
                        .font(KairoTypography.bodyLarge)
                        .foregroundColor(KairoColors.primaryAdaptive)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(KairoColors.mutedAdaptive)
                }
            }
            .listRowBackground(KairoColors.surfaceAdaptive)
        } header: {
            Text("About")
                .font(KairoTypography.label)
                .foregroundColor(KairoColors.mutedAdaptive)
                .textCase(nil)
        }
    }

    // MARK: - Settings Icon Helper

    private func settingsIcon(_ systemName: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: KairoTheme.Radius.small)
                .fill(color.opacity(0.15))
                .frame(width: 32, height: 32)

            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func exportData() {
        let exporter = DataExporter(context: viewContext)
        do {
            let url = try exporter.exportToFile()
            exportURL = url
            showExportShare = true
        } catch {
            showExportError = true
        }
    }

    private func deleteAllData() {
        do {
            try PersistenceController.shared.deleteAllData()
            // Reset user defaults for focus preferences
            defaultSessionDuration = KairoTheme.SessionPreset.defaultDuration
            breakDuration = KairoTheme.SessionPreset.shortBreak
        } catch {
            // Silently fail — Core Data batch delete is best-effort
        }
    }

    private func requestAppReview() {
        guard let scene = UIApplication.shared.connectedScenes.first(where: {
            $0.activationState == .foregroundActive
        }) as? UIWindowScene else { return }
        SKStoreReviewController.requestReview(in: scene)
    }
}

// MARK: - Share Sheet (UIKit bridge)

private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(SubscriptionManager())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
