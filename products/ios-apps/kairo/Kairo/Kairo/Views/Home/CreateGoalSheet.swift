import SwiftUI

/// Sheet for creating a new custom focus goal.
struct CreateGoalSheet: View {

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: CustomGoalStore

    @State private var title: String = ""
    @State private var targetValue: String = ""
    @State private var selectedType: CustomGoal.GoalType = .minutes
    @State private var selectedTimeFrame: CustomGoal.TimeFrame = .weekly
    @State private var selectedActivity: CustomGoal.FocusActivity = .deepWork
    @State private var customActivityName: String = ""
    @State private var showCustomActivity = false
    @State private var reminderEnabled: Bool = true
    @State private var reminderHour: Int = 9
    @State private var addToCalendar: Bool = false
    @State private var selectedDays: Set<Int> = [2, 3, 4, 5, 6] // Mon-Fri
    @State private var sessionStartHour: Int = 9
    @State private var sessionDuration: Int = 30
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @StateObject private var calendarManager = CalendarManager.shared

    // Quick presets organized by activity
    private var presets: [(String, Int, CustomGoal.GoalType, CustomGoal.TimeFrame, CustomGoal.FocusActivity)] {
        [
            ("Study 2 hours this week", 120, .minutes, .weekly, .studying),
            ("Read 30 min daily", 30, .minutes, .daily, .reading),
            ("Meditate 10 min daily", 10, .minutes, .daily, .meditation),
            ("5 yoga sessions this week", 5, .sessions, .weekly, .yoga),
            ("Deep work 4 hours weekly", 240, .minutes, .weekly, .deepWork),
            ("Mindfulness 15 min daily", 15, .minutes, .daily, .mindfulness),
            ("Exercise 3 times a week", 3, .sessions, .weekly, .exercise),
            ("Creative time 2 hrs weekly", 120, .minutes, .weekly, .creative),
            ("Study 20 hours this month", 1200, .minutes, .monthly, .studying),
        ]
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Activity selector (WHAT are you focusing on?)
                    activityPicker

                    // Time frame selector
                    timeFramePicker

                    // Goal name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Goal Name")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(KairoColors.primaryAdaptive)

                        TextField("e.g. Study for exams", text: $title)
                            .font(.system(size: 16))
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(KairoColors.surfaceAdaptive)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(KairoColors.mutedAdaptive.opacity(0.15), lineWidth: 1)
                            )
                    }

                    // Track by + Target
                    HStack(spacing: 12) {
                        // Track by selector
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Track By")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(KairoColors.primaryAdaptive)

                            Menu {
                                ForEach(CustomGoal.GoalType.allCases, id: \.rawValue) { type in
                                    Button {
                                        selectedType = type
                                    } label: {
                                        Label(type.displayName, systemImage: type.icon)
                                    }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: selectedType.icon)
                                        .foregroundColor(selectedType.color)
                                    Text(selectedType.displayName)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(KairoColors.primaryAdaptive)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 11))
                                        .foregroundColor(KairoColors.mutedAdaptive)
                                }
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(KairoColors.surfaceAdaptive)
                                )
                            }
                        }

                        // Target value
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Target")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(KairoColors.primaryAdaptive)

                            HStack(spacing: 6) {
                                TextField(currentPlaceholder, text: $targetValue)
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.center)
                                    .padding(14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(KairoColors.surfaceAdaptive)
                                    )
                            }
                        }
                    }

                    // Summary preview
                    if canCreate {
                        goalPreview
                    }

                    // Reminder setting
                    reminderSection

                    // Calendar scheduling
                    calendarSection

                    // Quick presets
                    presetsSection

                    // Create button
                    Button {
                        createGoal()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                            Text("Create Goal")
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(canCreate ? selectedActivity.color : KairoColors.mutedAdaptive.opacity(0.3))
                        )
                    }
                    .disabled(!canCreate)

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .background(KairoColors.backgroundAdaptive.ignoresSafeArea())
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(KairoColors.mutedAdaptive)
                }
            }
        }
    }

    // MARK: - Activity Picker

    private var activityPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What are you focusing on?")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(KairoColors.primaryAdaptive)

            // Activity grid
            let columns = [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
            ]

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(CustomGoal.FocusActivity.allBuiltIn, id: \.displayName) { activity in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedActivity = activity
                            showCustomActivity = false
                            if title.isEmpty {
                                title = activity.displayName
                            }
                        }
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: activity.icon)
                                .font(.system(size: 18))
                            Text(activity.displayName)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                        }
                        .foregroundColor(selectedActivity == activity && !showCustomActivity ? .white : KairoColors.primaryAdaptive)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedActivity == activity && !showCustomActivity ? activity.color : KairoColors.surfaceAdaptive)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedActivity == activity && !showCustomActivity ? Color.clear : KairoColors.mutedAdaptive.opacity(0.08), lineWidth: 1)
                        )
                    }
                }

                // Custom activity button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showCustomActivity = true
                    }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 18))
                        Text("Custom")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(showCustomActivity ? .white : KairoColors.mutedAdaptive)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(showCustomActivity ? Color(hex: 0x2980B9) : KairoColors.surfaceAdaptive)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(showCustomActivity ? Color.clear : KairoColors.mutedAdaptive.opacity(0.08), lineWidth: 1)
                    )
                }
            }

            // Custom activity name field
            if showCustomActivity {
                TextField("Activity name (e.g. Piano practice)", text: $customActivityName)
                    .font(.system(size: 15))
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(KairoColors.surfaceAdaptive)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(hex: 0x2980B9).opacity(0.3), lineWidth: 1)
                    )
                    .onChange(of: customActivityName) { _, newValue in
                        selectedActivity = .custom(newValue)
                        if title.isEmpty || title == "Custom" {
                            title = newValue
                        }
                    }
            }
        }
    }

    // MARK: - Time Frame Picker

    private var timeFramePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Time Frame")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(KairoColors.primaryAdaptive)

            HStack(spacing: 10) {
                ForEach(CustomGoal.TimeFrame.allCases, id: \.rawValue) { frame in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTimeFrame = frame
                        }
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: frame.icon)
                                .font(.system(size: 20))
                            Text(frame.displayName)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(selectedTimeFrame == frame ? .white : KairoColors.primaryAdaptive)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedTimeFrame == frame ? frame.color : KairoColors.surfaceAdaptive)
                        )
                    }
                }
            }
        }
    }

    // MARK: - Goal Preview

    private var goalPreview: some View {
        let target = Int(targetValue) ?? 0
        let activityName = showCustomActivity ? customActivityName : selectedActivity.displayName

        return HStack(spacing: 12) {
            Image(systemName: selectedActivity.icon)
                .font(.system(size: 20))
                .foregroundColor(selectedActivity.color)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(selectedActivity.color.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title.isEmpty ? activityName : title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(KairoColors.primaryAdaptive)

                Text("\(target) \(selectedType.displayName.lowercased()) \(selectedTimeFrame.label)")
                    .font(.system(size: 13))
                    .foregroundColor(KairoColors.mutedAdaptive)
            }

            Spacer()

            Text(selectedTimeFrame.displayName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(selectedTimeFrame.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(selectedTimeFrame.color.opacity(0.12)))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(selectedActivity.color.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(selectedActivity.color.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Reminder Section

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Daily Reminder")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(KairoColors.primaryAdaptive)

            HStack {
                Toggle(isOn: $reminderEnabled) {
                    HStack(spacing: 8) {
                        Image(systemName: "bell.fill")
                            .foregroundColor(reminderEnabled ? Color(hex: 0xF39C12) : KairoColors.mutedAdaptive)
                        Text("Remind me daily")
                            .font(.system(size: 15))
                            .foregroundColor(KairoColors.primaryAdaptive)
                    }
                }
                .tint(Color(hex: 0xF39C12))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(KairoColors.surfaceAdaptive)
            )

            if reminderEnabled {
                HStack {
                    Text("Reminder time")
                        .font(.system(size: 14))
                        .foregroundColor(KairoColors.primaryAdaptive)

                    Spacer()

                    Menu {
                        ForEach([6, 7, 8, 9, 10, 12, 14, 17, 19, 21], id: \.self) { hour in
                            Button {
                                reminderHour = hour
                            } label: {
                                Text(formatHour(hour))
                            }
                        }
                    } label: {
                        Text(formatHour(reminderHour))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color(hex: 0xF39C12))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(hex: 0xF39C12).opacity(0.12))
                            )
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(KairoColors.surfaceAdaptive)
                )
            }
        }
    }

    private func formatHour(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let period = hour < 12 ? "AM" : "PM"
        return "\(h):00 \(period)"
    }

    // MARK: - Calendar Section

    private let dayNames = ["S", "M", "T", "W", "T", "F", "S"]
    // Calendar weekday: 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Schedule on Calendar")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(KairoColors.primaryAdaptive)

            // Add to calendar toggle
            Toggle(isOn: $addToCalendar) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .foregroundColor(addToCalendar ? Color(hex: 0x3498DB) : KairoColors.mutedAdaptive)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Add to Calendar")
                            .font(.system(size: 15))
                            .foregroundColor(KairoColors.primaryAdaptive)
                        Text("Block time in your iOS Calendar")
                            .font(.system(size: 11))
                            .foregroundColor(KairoColors.mutedAdaptive)
                    }
                }
            }
            .tint(Color(hex: 0x3498DB))
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(KairoColors.surfaceAdaptive))
            .onChange(of: addToCalendar) { _, on in
                if on && !calendarManager.hasAccess {
                    Task {
                        let granted = await calendarManager.requestAccess()
                        if !granted { addToCalendar = false }
                    }
                }
            }

            if addToCalendar {
                // Day picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Which days?")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(KairoColors.primaryAdaptive)

                    HStack(spacing: 6) {
                        ForEach(1...7, id: \.self) { day in
                            let isSelected = selectedDays.contains(day)
                            Button {
                                if isSelected {
                                    selectedDays.remove(day)
                                } else {
                                    selectedDays.insert(day)
                                }
                            } label: {
                                Text(dayNames[day - 1])
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(isSelected ? .white : KairoColors.primaryAdaptive)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        Circle()
                                            .fill(isSelected ? Color(hex: 0x3498DB) : KairoColors.mutedAdaptive.opacity(0.1))
                                    )
                            }
                        }
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(KairoColors.surfaceAdaptive))

                // Time & Duration
                HStack(spacing: 12) {
                    // Start time
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Start time")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(KairoColors.mutedAdaptive)

                        Menu {
                            ForEach([5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21], id: \.self) { hour in
                                Button(formatHour(hour)) {
                                    sessionStartHour = hour
                                }
                            }
                        } label: {
                            Text(formatHour(sessionStartHour))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: 0x3498DB))
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 10).fill(KairoColors.surfaceAdaptive))
                        }
                    }

                    // Duration
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Duration")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(KairoColors.mutedAdaptive)

                        Menu {
                            ForEach([15, 20, 25, 30, 45, 60, 90, 120], id: \.self) { mins in
                                Button("\(mins) min") {
                                    sessionDuration = mins
                                }
                            }
                        } label: {
                            Text("\(sessionDuration) min")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: 0x3498DB))
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 10).fill(KairoColors.surfaceAdaptive))
                        }
                    }
                }

                // Due date
                Toggle(isOn: $hasDueDate) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(hasDueDate ? Color(hex: 0xE74C3C) : KairoColors.mutedAdaptive)
                        Text("Has a due date")
                            .font(.system(size: 15))
                            .foregroundColor(KairoColors.primaryAdaptive)
                    }
                }
                .tint(Color(hex: 0xE74C3C))
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(KairoColors.surfaceAdaptive))

                if hasDueDate {
                    DatePicker(
                        "Due date",
                        selection: $dueDate,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(KairoColors.surfaceAdaptive))
                }

                // Calendar preview
                VStack(alignment: .leading, spacing: 6) {
                    let daysText = selectedDays.sorted().map { dayNames[$0 - 1] }.joined(separator: ", ")
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: 0x3498DB))
                        Text("Will create events on \(daysText) at \(formatHour(sessionStartHour)) for \(sessionDuration) min")
                            .font(.system(size: 12))
                            .foregroundColor(KairoColors.mutedAdaptive)
                    }
                    if hasDueDate {
                        let formatter = DateFormatter()
                        let _ = formatter.dateFormat = "MMM d, yyyy"
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: 0xE74C3C))
                            Text("Due: \(formatter.string(from: dueDate))")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: 0xE74C3C))
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: 0x3498DB).opacity(0.06))
                )
            }
        }
    }

    // MARK: - Presets

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Goals")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(KairoColors.primaryAdaptive)

            ForEach(presets.indices, id: \.self) { index in
                let preset = presets[index]
                Button {
                    title = preset.0
                    targetValue = "\(preset.1)"
                    selectedType = preset.2
                    selectedTimeFrame = preset.3
                    selectedActivity = preset.4
                    showCustomActivity = false
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: preset.4.icon)
                            .font(.system(size: 14))
                            .foregroundColor(preset.4.color)
                            .frame(width: 24)

                        Text(preset.0)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(KairoColors.primaryAdaptive)

                        Spacer()

                        Text(preset.3.displayName)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(preset.3.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(preset.3.color.opacity(0.12)))
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

    // MARK: - Helpers

    private var currentPlaceholder: String {
        CustomGoal(title: "", targetValue: 0, goalType: selectedType, timeFrame: selectedTimeFrame, activity: selectedActivity).placeholder
    }

    private var canCreate: Bool {
        let hasTitle = !title.trimmingCharacters(in: .whitespaces).isEmpty
        let hasTarget = (Int(targetValue) ?? 0) > 0
        let hasCustomName = !showCustomActivity || !customActivityName.trimmingCharacters(in: .whitespaces).isEmpty
        return hasTitle && hasTarget && hasCustomName
    }

    private func createGoal() {
        guard canCreate, let target = Int(targetValue) else { return }
        let activity: CustomGoal.FocusActivity = showCustomActivity
            ? .custom(customActivityName.trimmingCharacters(in: .whitespaces))
            : selectedActivity
        let goal = CustomGoal(
            title: title.trimmingCharacters(in: .whitespaces),
            targetValue: target,
            goalType: selectedType,
            timeFrame: selectedTimeFrame,
            activity: activity,
            reminderEnabled: reminderEnabled,
            reminderHour: reminderHour
        )
        store.add(goal)

        // Schedule calendar events if enabled
        if addToCalendar && !selectedDays.isEmpty {
            calendarManager.scheduleGoalSessions(
                goal: goal,
                days: Array(selectedDays),
                startHour: sessionStartHour,
                durationMinutes: sessionDuration,
                weeksAhead: goal.timeFrame == .monthly ? 4 : (goal.timeFrame == .weekly ? 1 : 1)
            )

            // Add due date event if set
            if hasDueDate {
                _ = calendarManager.createDeadlineEvent(
                    title: goal.title,
                    dueDate: dueDate,
                    activity: activity,
                    notes: "Goal: \(goal.targetValue) \(goal.goalType.displayName.lowercased()) \(goal.timeFrame.label)"
                )
            }
        }

        dismiss()
    }
}

#Preview {
    CreateGoalSheet(store: CustomGoalStore())
}
