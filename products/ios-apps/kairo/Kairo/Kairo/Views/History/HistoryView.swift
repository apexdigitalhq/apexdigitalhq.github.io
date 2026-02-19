import SwiftUI

// MARK: - HistoryView

/// Displays past focus sessions grouped by day with pull-to-refresh.
struct HistoryView: View {

    @StateObject private var viewModel = HistoryViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.groupedSessions.isEmpty {
                    emptyState
                } else {
                    sessionList
                }
            }
            .navigationTitle("History")
            .background(KairoColors.backgroundAdaptive.ignoresSafeArea())
            .onAppear { viewModel.load() }
        }
    }

    // MARK: - Session List

    private var sessionList: some View {
        List {
            ForEach(viewModel.groupedSessions, id: \.date) { group in
                Section {
                    ForEach(group.sessions) { session in
                        NavigationLink(destination: SessionDetailPlaceholder(session: session)) {
                            SessionRow(session: session)
                        }
                        .listRowBackground(KairoColors.surfaceAdaptive)
                    }
                } header: {
                    sectionHeader(for: group)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .refreshable { viewModel.load() }
    }

    // MARK: - Section Header

    private func sectionHeader(for group: HistoryViewModel.DayGroup) -> some View {
        HStack {
            Text(group.displayDate)
                .font(KairoTypography.label)
                .foregroundColor(KairoColors.mutedAdaptive)

            Spacer()

            Text("\(group.sessions.count) session\(group.sessions.count == 1 ? "" : "s")")
                .font(KairoTypography.caption)
                .foregroundColor(KairoColors.mutedAdaptive)
        }
        .textCase(nil)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: KairoTheme.Spacing.lg) {
            Spacer()

            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 64))
                .foregroundColor(KairoColors.mutedAdaptive.opacity(0.5))

            Text("No Sessions Yet")
                .font(KairoTypography.heading2)
                .foregroundColor(KairoColors.primaryAdaptive)

            Text("Complete your first focus session\nand it will appear here.")
                .font(KairoTypography.body)
                .foregroundColor(KairoColors.mutedAdaptive)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(KairoTheme.Spacing.xl)
    }
}

// MARK: - SessionRow

/// A single session row: time, duration, focus score, and session type icon.
struct SessionRow: View {

    let session: FocusSession

    private var sessionTypeInfo: KairoTheme.SessionType {
        KairoTheme.SessionType(rawValue: session.sessionType) ?? .work
    }

    var body: some View {
        HStack(spacing: KairoTheme.Spacing.sm) {
            // Session type icon
            ZStack {
                Circle()
                    .fill(sessionTypeInfo.color.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: sessionTypeInfo.iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(sessionTypeInfo.color)
            }

            // Time and type
            VStack(alignment: .leading, spacing: 2) {
                Text(session.startedAt.shortTimeString)
                    .font(KairoTypography.bodyLarge)
                    .foregroundColor(KairoColors.primaryAdaptive)

                Text(sessionTypeInfo.displayName)
                    .font(KairoTypography.caption)
                    .foregroundColor(KairoColors.mutedAdaptive)
            }

            Spacer()

            // Duration
            VStack(alignment: .trailing, spacing: 2) {
                Text(session.actualDuration.humanReadable)
                    .font(KairoTypography.scoreSmall)
                    .foregroundColor(KairoColors.primaryAdaptive)

                statusBadge
            }

            // Focus score pill
            scorePill
        }
        .padding(.vertical, KairoTheme.Spacing.xxs)
    }

    private var statusBadge: some View {
        Text(session.isCompleted ? "Completed" : session.isAbandoned ? "Abandoned" : "Paused")
            .font(KairoTypography.caption)
            .foregroundColor(session.isCompleted ? KairoColors.successAdaptive : KairoColors.mutedAdaptive)
    }

    private var scorePill: some View {
        Text("\(Int(session.focusScore))")
            .font(KairoTypography.scoreSmall)
            .foregroundColor(.white)
            .frame(width: 40, height: 28)
            .background(KairoColors.scoreColor(for: session.focusScore))
            .clipShape(Capsule())
    }
}

// MARK: - Session Detail Placeholder

struct SessionDetailPlaceholder: View {

    let session: FocusSession

    private var sessionTypeInfo: KairoTheme.SessionType {
        KairoTheme.SessionType(rawValue: session.sessionType) ?? .work
    }

    var body: some View {
        VStack(spacing: KairoTheme.Spacing.lg) {
            Spacer()

            Image(systemName: sessionTypeInfo.iconName)
                .font(.system(size: 48))
                .foregroundColor(sessionTypeInfo.color)

            Text("\(sessionTypeInfo.displayName) Session")
                .font(KairoTypography.heading2)
                .foregroundColor(KairoColors.primaryAdaptive)

            VStack(spacing: KairoTheme.Spacing.xs) {
                detailRow("Started", value: session.startedAt.shortTimeString)
                detailRow("Duration", value: session.actualDuration.humanReadable)
                detailRow("Target", value: session.targetDuration.humanReadable)
                detailRow("Focus Score", value: "\(Int(session.focusScore))/100")
                detailRow("Quality", value: session.qualityRating.capitalized)
                detailRow("Distractions", value: "\(session.distractionCount)")
            }
            .padding(KairoTheme.Spacing.md)
            .kairoCard()

            Spacer()
        }
        .padding(KairoTheme.Spacing.md)
        .background(KairoColors.backgroundAdaptive.ignoresSafeArea())
        .navigationTitle("Session Detail")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(KairoTypography.body)
                .foregroundColor(KairoColors.mutedAdaptive)
            Spacer()
            Text(value)
                .font(KairoTypography.label)
                .foregroundColor(KairoColors.primaryAdaptive)
        }
    }
}

// MARK: - HistoryViewModel

final class HistoryViewModel: ObservableObject {

    struct DayGroup {
        let date: Date
        let sessions: [FocusSession]

        var displayDate: String {
            let calendar = Calendar.current
            if calendar.isDateInToday(date) { return "Today" }
            if calendar.isDateInYesterday(date) { return "Yesterday" }
            return date.mediumDateString
        }
    }

    @Published var groupedSessions: [DayGroup] = []

    private let sessionStore = SessionStore()

    func load() {
        let all = sessionStore.fetchAll()
        let calendar = Calendar.current

        // Group by startOfDay
        let grouped = Dictionary(grouping: all) { session in
            calendar.startOfDay(for: session.startedAt)
        }

        // Sort days descending, sessions within each day descending by time
        groupedSessions = grouped
            .map { DayGroup(date: $0.key, sessions: $0.value.sorted { $0.startedAt > $1.startedAt }) }
            .sorted { $0.date > $1.date }
    }
}

// MARK: - Previews

#Preview("History — With Sessions") {
    HistoryView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

#Preview("History — Empty") {
    HistoryView()
}
