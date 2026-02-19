import SwiftUI
import EventKit

// MARK: - KairoCalendarView

/// In-app calendar showing scheduled focus sessions, goals, and deadlines.
/// Optionally syncs with Apple Calendar via EventKit.
struct KairoCalendarView: View {

    @StateObject private var calendarManager = CalendarManager.shared
    @StateObject private var goalStore = CustomGoalStore()
    @State private var selectedDate: Date = Date()
    @State private var currentMonth: Date = Date()
    @State private var showAddEvent = false

    private let calendar = Calendar.current

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Month navigation
                    monthHeader

                    // Calendar grid
                    calendarGrid

                    // Today's schedule
                    todaySchedule

                    // Active goals with deadlines
                    activeGoalsSection

                    // Quick actions
                    quickActions

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 16)
            }
            .background(KairoColors.backgroundAdaptive.ignoresSafeArea())
            .navigationTitle("Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        selectedDate = Date()
                        currentMonth = Date()
                    } label: {
                        Text("Today")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(KairoTheme.Colors.accent)
                    }
                }
            }
            .onAppear {
                calendarManager.fetchUpcoming(days: 31)
                goalStore.resetExpiredGoals()
            }
        }
    }

    // MARK: - Month Header

    private var monthHeader: some View {
        HStack {
            Button {
                withAnimation { moveMonth(-1) }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(KairoColors.primaryAdaptive)
            }

            Spacer()

            Text(monthYearString)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(KairoColors.primaryAdaptive)

            Spacer()

            Button {
                withAnimation { moveMonth(1) }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(KairoColors.primaryAdaptive)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        VStack(spacing: 4) {
            // Day headers
            HStack(spacing: 0) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(KairoColors.mutedAdaptive)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 4)

            // Date cells
            let days = generateDays()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
                ForEach(days, id: \.self) { date in
                    if let date = date {
                        dateCellView(date)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedDate = date
                                }
                            }
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(KairoColors.surfaceAdaptive)
        )
    }

    private func dateCellView(_ date: Date) -> some View {
        let isToday = calendar.isDateInToday(date)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let hasEvents = eventsForDate(date).count > 0
        let hasGoalDue = goalsForDate(date).count > 0
        let dayNumber = calendar.component(.day, from: date)
        let isCurrentMonth = calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)

        return VStack(spacing: 2) {
            Text("\(dayNumber)")
                .font(.system(size: 15, weight: isToday ? .bold : .medium, design: .rounded))
                .foregroundColor(
                    isSelected ? .white :
                    isToday ? KairoTheme.Colors.accent :
                    isCurrentMonth ? KairoColors.primaryAdaptive :
                    KairoColors.mutedAdaptive.opacity(0.4)
                )

            // Event dots
            HStack(spacing: 3) {
                if hasEvents {
                    Circle()
                        .fill(Color(hex: 0x9B59B6))
                        .frame(width: 5, height: 5)
                }
                if hasGoalDue {
                    Circle()
                        .fill(Color(hex: 0xE74C3C))
                        .frame(width: 5, height: 5)
                }
            }
            .frame(height: 5)
        }
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    isSelected ? KairoTheme.Colors.accent :
                    isToday ? KairoTheme.Colors.accent.opacity(0.1) :
                    Color.clear
                )
        )
    }

    // MARK: - Today's Schedule

    private var todaySchedule: some View {
        let dayEvents = eventsForDate(selectedDate)
        let dayGoals = goalsForDate(selectedDate)
        let isToday = calendar.isDateInToday(selectedDate)
        let dateLabel = isToday ? "Today" : formattedDate(selectedDate)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(dateLabel)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(KairoColors.primaryAdaptive)

                Spacer()

                if !dayEvents.isEmpty || !dayGoals.isEmpty {
                    Text("\(dayEvents.count + dayGoals.count) items")
                        .font(.system(size: 12))
                        .foregroundColor(KairoColors.mutedAdaptive)
                }
            }

            if dayEvents.isEmpty && dayGoals.isEmpty {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 28))
                        .foregroundColor(KairoColors.mutedAdaptive.opacity(0.5))
                    Text("No sessions scheduled")
                        .font(.system(size: 14))
                        .foregroundColor(KairoColors.mutedAdaptive)
                    Text("Create a goal to add focus sessions to your calendar")
                        .font(.system(size: 12))
                        .foregroundColor(KairoColors.mutedAdaptive.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                // Events list
                ForEach(dayEvents) { event in
                    eventRow(event)
                }

                // Goal deadlines
                ForEach(dayGoals) { goal in
                    goalDeadlineRow(goal)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(KairoColors.surfaceAdaptive)
        )
    }

    private func eventRow(_ event: KairoCalendarEvent) -> some View {
        HStack(spacing: 12) {
            // Time bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: 0x9B59B6))
                .frame(width: 3, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(KairoColors.primaryAdaptive)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(event.formattedTime)
                        .font(.system(size: 12, weight: .medium))
                    Text("·")
                    Text("\(event.durationMinutes) min")
                        .font(.system(size: 12))
                }
                .foregroundColor(KairoColors.mutedAdaptive)
            }

            Spacer()

            if event.isUpcoming {
                Image(systemName: "clock")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: 0x9B59B6))
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: 0x2ECC71))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: 0x9B59B6).opacity(0.06))
        )
    }

    private func goalDeadlineRow(_ goal: CustomGoal) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: 0xE74C3C))
                .frame(width: 3, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text("⏰ Due: \(goal.title)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(KairoColors.primaryAdaptive)

                HStack(spacing: 4) {
                    Text("\(goal.currentProgress)/\(goal.targetValue) \(goal.goalType.displayName.lowercased())")
                        .font(.system(size: 12, weight: .medium))

                    if goal.isAchieved {
                        Text("✅ Done!")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(hex: 0x2ECC71))
                    }
                }
                .foregroundColor(KairoColors.mutedAdaptive)
            }

            Spacer()

            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color(hex: 0xE74C3C).opacity(0.15), lineWidth: 3)
                    .frame(width: 30, height: 30)

                Circle()
                    .trim(from: 0, to: goal.progress)
                    .stroke(Color(hex: 0xE74C3C), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 30, height: 30)
                    .rotationEffect(.degrees(-90))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: 0xE74C3C).opacity(0.06))
        )
    }

    // MARK: - Active Goals

    private var activeGoalsSection: some View {
        Group {
            if !goalStore.goals.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Active Goals")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(KairoColors.primaryAdaptive)

                    ForEach(goalStore.goals) { goal in
                        HStack(spacing: 12) {
                            Image(systemName: goal.activity.icon)
                                .font(.system(size: 16))
                                .foregroundColor(goal.activity.color)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(goal.activity.color.opacity(0.12))
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(goal.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(KairoColors.primaryAdaptive)

                                Text("\(goal.currentProgress)/\(goal.targetValue) \(goal.goalType.displayName.lowercased()) \(goal.timeFrame.label)")
                                    .font(.system(size: 12))
                                    .foregroundColor(KairoColors.mutedAdaptive)
                            }

                            Spacer()

                            // Progress
                            Text("\(Int(goal.progress * 100))%")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(goal.isAchieved ? Color(hex: 0x2ECC71) : goal.goalType.color)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(KairoColors.surfaceAdaptive)
                        )
                    }
                }
            }
        }
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Calendar Sync")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(KairoColors.primaryAdaptive)

            if calendarManager.hasAccess {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: 0x2ECC71))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Connected to Apple Calendar")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(KairoColors.primaryAdaptive)
                        Text("Focus sessions sync to your \"Kairo Focus\" calendar")
                            .font(.system(size: 12))
                            .foregroundColor(KairoColors.mutedAdaptive)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: 0x2ECC71).opacity(0.06))
                )
            } else {
                Button {
                    Task {
                        _ = await calendarManager.requestAccess()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 18))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Connect Apple Calendar")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Sync your focus sessions automatically")
                                .font(.system(size: 12))
                                .foregroundColor(KairoColors.mutedAdaptive)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(KairoTheme.Colors.accent)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(KairoTheme.Colors.accent.opacity(0.08))
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    private func moveMonth(_ delta: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: delta, to: currentMonth) {
            currentMonth = newMonth
        }
    }

    /// Returns optional dates for the calendar grid (nil = empty cell).
    private func generateDays() -> [Date?] {
        var days: [Date?] = []

        let comps = calendar.dateComponents([.year, .month], from: currentMonth)
        guard let firstOfMonth = calendar.date(from: comps) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let daysInMonth = calendar.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 30

        // Leading empty cells
        for _ in 0..<(firstWeekday - 1) {
            days.append(nil)
        }

        // Actual days
        for day in 1...daysInMonth {
            var dc = comps
            dc.day = day
            days.append(calendar.date(from: dc))
        }

        return days
    }

    /// Events for a specific date.
    private func eventsForDate(_ date: Date) -> [KairoCalendarEvent] {
        calendarManager.upcomingEvents.filter {
            calendar.isDate($0.startDate, inSameDayAs: date)
        }
    }

    /// Goals that have deadlines on this date (stored in notes as dates).
    /// For now, we show daily goals on every day and weekly goals on their period.
    private func goalsForDate(_ date: Date) -> [CustomGoal] {
        goalStore.goals.filter { goal in
            switch goal.timeFrame {
            case .daily:
                return calendar.isDateInToday(date)
            case .weekly:
                let start = goal.timeFrame.periodStart
                let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
                return date >= start && date <= end
            case .monthly:
                return calendar.isDate(date, equalTo: Date(), toGranularity: .month)
            }
        }
    }
}

#Preview {
    KairoCalendarView()
        .environmentObject(SessionCoordinator(
            focusEngine: FocusEngine(context: PersistenceController.shared.container.viewContext),
            soundManager: SoundManager.shared,
            distractionDetector: DistractionDetector(),
            hapticEngine: HapticEngine(),
            notificationManager: NotificationManager.shared
        ))
}
