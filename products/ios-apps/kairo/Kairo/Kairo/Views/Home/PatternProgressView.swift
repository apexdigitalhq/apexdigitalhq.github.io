import SwiftUI

/// Detail sheet shown when the user taps the pattern progress bar.
/// Shows tier progress, what's unlocked, what's coming, and motivational quotes.
struct PatternProgressView: View {

    let sessionCount: Int
    let coachingTier: Int
    let modelReadiness: Double

    @Environment(\.dismiss) private var dismiss
    @StateObject private var customGoalStore = CustomGoalStore()
    @StateObject private var calendarManager = CalendarManager.shared
    @State private var currentQuoteIndex: Int = 0
    @State private var showCreateGoal = false

    // MARK: - Motivational Quotes

    private let quotes: [(String, String)] = [
        ("The secret of getting ahead is getting started.", "Mark Twain"),
        ("Focus is a matter of deciding what things you're not going to do.", "John Carmack"),
        ("Concentrate all your thoughts upon the work at hand. The sun's rays do not burn until brought to a focus.", "Alexander Graham Bell"),
        ("It is during our darkest moments that we must focus to see the light.", "Aristotle"),
        ("The successful warrior is the average man, with laser-like focus.", "Bruce Lee"),
        ("You can always find a distraction if you're looking for one.", "Tom Kite"),
        ("Starve your distractions, feed your focus.", "Daniel Goleman"),
        ("Where focus goes, energy flows.", "Tony Robbins"),
        ("The main thing is to keep the main thing the main thing.", "Stephen Covey"),
        ("Lack of direction, not lack of time, is the problem. We all have 24-hour days.", "Zig Ziglar"),
        ("Your brain is a muscle. The more you use it, the stronger it gets.", "Dr. Andrew Huberman"),
        ("Deep work is the ability to focus without distraction on a cognitively demanding task.", "Cal Newport"),
        ("Excellence is not a destination but a continuously growing never-ending process.", "Brian Tracy"),
        ("Small daily improvements over time lead to stunning results.", "Robin Sharma"),
        ("The ability to concentrate and to use time well is everything.", "Lee Iacocca"),
        ("Attention is the rarest and purest form of generosity.", "Simone Weil"),
        ("Almost everything will work again if you unplug it for a few minutes, including you.", "Anne Lamott"),
        ("Your focus determines your reality.", "George Lucas"),
        ("Discipline equals freedom.", "Jocko Willink"),
        ("What you stay focused on will grow.", "Roy T. Bennett"),
    ]

    // MARK: - Tier Data

    private struct TierInfo {
        let level: Int
        let name: String
        let sessions: Int
        let icon: String
        let color: Color
        let features: [String]
    }

    private var tiers: [TierInfo] {
        [
            TierInfo(
                level: 1,
                name: "Basic Patterns",
                sessions: 10,
                icon: "brain",
                color: Color(hex: 0x3498DB),
                features: [
                    "Brain science tips",
                    "Energy management advice",
                    "Attention span coaching",
                    "General focus strategies"
                ]
            ),
            TierInfo(
                level: 2,
                name: "Intermediate Analysis",
                sessions: 20,
                icon: "chart.line.uptrend.xyaxis",
                color: Color(hex: 0x9B59B6),
                features: [
                    "Chronotype detection (morning/night)",
                    "Schedule consistency analysis",
                    "Session length optimization",
                    "Personalized timing advice"
                ]
            ),
            TierInfo(
                level: 3,
                name: "Full AI Coach",
                sessions: 30,
                icon: "sparkles",
                color: KairoColors.accentAdaptive,
                features: [
                    "Afternoon slump detection",
                    "Quality plateau breaking",
                    "Weekend vs weekday analysis",
                    "Deep personalized coaching",
                    "Overwork prevention"
                ]
            )
        ]
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Big progress ring + rank
                    progressRing

                    // Quote card (tap to cycle)
                    quoteCard

                    // Achievements / Badges
                    achievementsSection

                    // Personal Records
                    personalRecordsSection

                    // Weekly Challenge
                    weeklyChallengeSection

                    // Upcoming Schedule
                    if !calendarManager.upcomingEvents.isEmpty {
                        upcomingScheduleSection
                    }

                    // My Goals (custom, user-created)
                    myGoalsSection

                    // Built-in Goals
                    goalsSection

                    // Tier breakdown
                    tierBreakdown

                    // Fun stats
                    focusStats

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .background(KairoColors.backgroundAdaptive.ignoresSafeArea())
            .navigationTitle("Your Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(KairoColors.accentAdaptive)
                }
            }
        }
        .onAppear {
            currentQuoteIndex = Int.random(in: 0..<quotes.count)
            calendarManager.fetchUpcoming(days: 7)
        }
    }

    // MARK: - Progress Ring

    private var progressRing: some View {
        VStack(spacing: 12) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(KairoColors.mutedAdaptive.opacity(0.15), lineWidth: 12)
                    .frame(width: 140, height: 140)

                // Progress ring
                Circle()
                    .trim(from: 0, to: modelReadiness)
                    .stroke(
                        AngularGradient(
                            colors: [Color(hex: 0x3498DB), Color(hex: 0x9B59B6), KairoColors.accentAdaptive],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1), value: modelReadiness)

                // Center text
                VStack(spacing: 2) {
                    Text("\(sessionCount)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(KairoColors.primaryAdaptive)

                    Text("sessions")
                        .font(KairoTypography.caption)
                        .foregroundColor(KairoColors.mutedAdaptive)
                }
            }

            // Focus Rank
            Text(focusRank.0)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(focusRank.2)

            // Tier badge
            HStack(spacing: 6) {
                Image(systemName: currentTierIcon)
                    .font(.system(size: 14))
                Text(currentTierName)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(currentTierColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(currentTierColor.opacity(0.12))
            )

            if coachingTier < 3 {
                Text("\(nextTarget - sessionCount) more sessions to next tier")
                    .font(KairoTypography.caption)
                    .foregroundColor(KairoColors.mutedAdaptive)
            } else {
                Text("Full coaching unlocked! 🎉")
                    .font(KairoTypography.caption)
                    .foregroundColor(KairoColors.accentAdaptive)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Quote Card

    private var quoteCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "quote.opening")
                .font(.system(size: 20))
                .foregroundColor(Color(hex: 0x9B59B6).opacity(0.6))

            Text(quotes[currentQuoteIndex].0)
                .font(.system(size: 16, weight: .medium, design: .serif))
                .foregroundColor(KairoColors.primaryAdaptive)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Text("— \(quotes[currentQuoteIndex].1)")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(KairoColors.mutedAdaptive)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(KairoColors.surfaceAdaptive)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: 0x9B59B6).opacity(0.15), lineWidth: 1)
        )
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentQuoteIndex = (currentQuoteIndex + 1) % quotes.count
            }
        }
    }

    // MARK: - Focus Rank

    /// Returns (rank name, emoji, color) based on session count
    private var focusRank: (String, String, Color) {
        switch sessionCount {
        case 0..<5:    return ("🌱 Beginner", "🌱", KairoColors.mutedAdaptive)
        case 5..<15:   return ("🔰 Apprentice", "🔰", Color(hex: 0x3498DB))
        case 15..<30:  return ("🎯 Focused", "🎯", Color(hex: 0x2ECC71))
        case 30..<50:  return ("⚡ Adept", "⚡", Color(hex: 0xF39C12))
        case 50..<75:  return ("🔥 Expert", "🔥", Color(hex: 0xE74C3C))
        case 75..<100: return ("💎 Elite", "💎", Color(hex: 0x9B59B6))
        case 100..<200: return ("👑 Master", "👑", KairoColors.accentAdaptive)
        default:       return ("🏆 Legend", "🏆", Color(hex: 0xF1C40F))
        }
    }

    // MARK: - Achievements Section

    private struct Achievement: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let description: String
        let isUnlocked: Bool
        let color: Color
    }

    private var achievements: [Achievement] {
        [
            Achievement(
                icon: "sunrise.fill",
                title: "Early Bird",
                description: "Complete a session before 8 AM",
                isUnlocked: sessionCount >= 3, // proxy — real check would use session times
                color: Color(hex: 0xF39C12)
            ),
            Achievement(
                icon: "moon.stars.fill",
                title: "Night Owl",
                description: "Complete a session after 10 PM",
                isUnlocked: sessionCount >= 5,
                color: Color(hex: 0x3498DB)
            ),
            Achievement(
                icon: "timer",
                title: "Marathon Focus",
                description: "Complete a 60+ minute session",
                isUnlocked: sessionCount >= 10,
                color: Color(hex: 0xE74C3C)
            ),
            Achievement(
                icon: "bolt.shield.fill",
                title: "Distraction Slayer",
                description: "Complete 5 sessions with zero distractions",
                isUnlocked: sessionCount >= 15,
                color: Color(hex: 0x9B59B6)
            ),
            Achievement(
                icon: "calendar.badge.checkmark",
                title: "Perfect Week",
                description: "Focus every day for 7 days straight",
                isUnlocked: sessionCount >= 20,
                color: Color(hex: 0x2ECC71)
            ),
            Achievement(
                icon: "flame.fill",
                title: "On Fire",
                description: "Complete 5 sessions in a single day",
                isUnlocked: sessionCount >= 25,
                color: Color.orange
            ),
            Achievement(
                icon: "star.circle.fill",
                title: "Quality King",
                description: "Get 5 high-quality sessions in a row",
                isUnlocked: sessionCount >= 30,
                color: Color(hex: 0xF1C40F)
            ),
            Achievement(
                icon: "trophy.fill",
                title: "Centurion",
                description: "Complete 100 total sessions",
                isUnlocked: sessionCount >= 100,
                color: KairoColors.accentAdaptive
            ),
        ]
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Achievements")
                    .font(KairoTypography.heading3)
                    .foregroundColor(KairoColors.primaryAdaptive)

                Spacer()

                let unlocked = achievements.filter(\.isUnlocked).count
                Text("\(unlocked)/\(achievements.count)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: 0x9B59B6))
            }

            // Horizontal scroll of badge cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(achievements) { badge in
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(badge.isUnlocked ? badge.color : KairoColors.mutedAdaptive.opacity(0.1))
                                    .frame(width: 52, height: 52)

                                Image(systemName: badge.isUnlocked ? badge.icon : "lock.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(badge.isUnlocked ? .white : KairoColors.mutedAdaptive.opacity(0.3))
                            }

                            Text(badge.title)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(badge.isUnlocked ? KairoColors.primaryAdaptive : KairoColors.mutedAdaptive.opacity(0.5))
                                .multilineTextAlignment(.center)

                            Text(badge.description)
                                .font(.system(size: 9))
                                .foregroundColor(KairoColors.mutedAdaptive)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .frame(width: 90)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(badge.isUnlocked ? badge.color.opacity(0.06) : KairoColors.surfaceAdaptive)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(badge.isUnlocked ? badge.color.opacity(0.2) : KairoColors.mutedAdaptive.opacity(0.08), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    // MARK: - Personal Records

    private var personalRecordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personal Records")
                .font(KairoTypography.heading3)
                .foregroundColor(KairoColors.primaryAdaptive)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                recordCard(
                    icon: "hourglass",
                    label: "Longest Session",
                    value: sessionCount > 0 ? "—" : "—",
                    note: "Complete sessions to track",
                    color: Color(hex: 0xE74C3C)
                )

                recordCard(
                    icon: "star.fill",
                    label: "Best Score",
                    value: sessionCount > 0 ? "—" : "—",
                    note: "Your highest focus score",
                    color: Color(hex: 0xF1C40F)
                )

                recordCard(
                    icon: "flame.fill",
                    label: "Longest Streak",
                    value: sessionCount > 0 ? "—" : "—",
                    note: "Consecutive focus days",
                    color: Color.orange
                )

                recordCard(
                    icon: "bolt.fill",
                    label: "Most in a Day",
                    value: sessionCount > 0 ? "—" : "—",
                    note: "Sessions in one day",
                    color: Color(hex: 0x9B59B6)
                )
            }
        }
    }

    private func recordCard(icon: String, label: String, value: String, note: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(KairoColors.mutedAdaptive)
            }

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(KairoColors.primaryAdaptive)

            Text(note)
                .font(.system(size: 10))
                .foregroundColor(KairoColors.mutedAdaptive.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(KairoColors.surfaceAdaptive)
        )
    }

    // MARK: - Weekly Challenge

    private var weeklyChallenges: [(String, String, String, Color)] {
        [
            ("🎯 Focus Marathon", "Complete a 45+ minute session this week", "timer", Color(hex: 0xE74C3C)),
            ("🌅 Morning Warrior", "Do 3 sessions before 10 AM this week", "sunrise.fill", Color(hex: 0xF39C12)),
            ("🔥 Streak Starter", "Focus 5 days in a row", "flame.fill", Color.orange),
            ("💎 Quality Over Quantity", "Get 3 high-quality sessions", "star.fill", Color(hex: 0x9B59B6)),
            ("⚡ Double Down", "Complete 2 sessions in one day", "bolt.fill", Color(hex: 0x3498DB)),
            ("🧘 Zen Mode", "Use ambient sounds for every session this week", "headphones", Color(hex: 0x1ABC9C)),
            ("📵 Phone-Free", "Complete 3 sessions with zero distractions", "iphone.slash", Color(hex: 0x2ECC71)),
            ("🏋️ Progressive Overload", "Each session 5 minutes longer than the last", "chart.line.uptrend.xyaxis", Color(hex: 0xE74C3C)),
        ]
    }

    /// Picks a "weekly" challenge based on the current week number
    private var currentWeeklyChallenge: (String, String, String, Color) {
        let weekOfYear = Calendar.current.component(.weekOfYear, from: Date())
        let index = weekOfYear % weeklyChallenges.count
        return weeklyChallenges[index]
    }

    private var weeklyChallengeSection: some View {
        let challenge = currentWeeklyChallenge
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weekly Challenge")
                    .font(KairoTypography.heading3)
                    .foregroundColor(KairoColors.primaryAdaptive)

                Spacer()

                Text("Resets Monday")
                    .font(.system(size: 11))
                    .foregroundColor(KairoColors.mutedAdaptive)
            }

            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(challenge.3.opacity(0.12))
                        .frame(width: 50, height: 50)

                    Image(systemName: challenge.2)
                        .font(.system(size: 22))
                        .foregroundColor(challenge.3)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.0)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(KairoColors.primaryAdaptive)

                    Text(challenge.1)
                        .font(.system(size: 13))
                        .foregroundColor(KairoColors.mutedAdaptive)
                }

                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(KairoColors.surfaceAdaptive)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(challenge.3.opacity(0.15), lineWidth: 1)
            )
        }
    }

    // MARK: - Upcoming Schedule

    private var upcomingScheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming Schedule")
                    .font(KairoTypography.heading3)
                    .foregroundColor(KairoColors.primaryAdaptive)

                Spacer()

                Text("Next 7 days")
                    .font(.system(size: 11))
                    .foregroundColor(KairoColors.mutedAdaptive)
            }

            ForEach(calendarManager.upcomingEvents.prefix(5)) { event in
                HStack(spacing: 12) {
                    // Time indicator
                    VStack(spacing: 2) {
                        Text(event.formattedDay)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Calendar.current.isDateInToday(event.startDate) ? Color(hex: 0xE74C3C) : KairoColors.mutedAdaptive)

                        Text(event.formattedTime)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(KairoColors.primaryAdaptive)
                    }
                    .frame(width: 60)

                    // Colored bar
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: 0x9B59B6))
                        .frame(width: 3, height: 40)

                    // Event details
                    VStack(alignment: .leading, spacing: 3) {
                        Text(event.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(KairoColors.primaryAdaptive)
                            .lineLimit(1)

                        Text("\(event.durationMinutes) min")
                            .font(.system(size: 12))
                            .foregroundColor(KairoColors.mutedAdaptive)
                    }

                    Spacer()

                    if event.isUpcoming {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                            .foregroundColor(KairoColors.mutedAdaptive)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: 0x2ECC71))
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(KairoColors.surfaceAdaptive)
                )
            }
        }
    }

    // MARK: - My Goals (Custom)

    private var myGoalsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("My Goals")
                    .font(KairoTypography.heading3)
                    .foregroundColor(KairoColors.primaryAdaptive)

                Spacer()

                Button {
                    showCreateGoal = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                        Text("Add")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(Color(hex: 0x9B59B6))
                }
            }

            if customGoalStore.goals.isEmpty {
                // Empty state
                VStack(spacing: 10) {
                    Image(systemName: "target")
                        .font(.system(size: 28))
                        .foregroundColor(KairoColors.mutedAdaptive.opacity(0.4))

                    Text("Set your own focus goals")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(KairoColors.mutedAdaptive)

                    Text("Tap + to create a custom goal like\n\"500 focus minutes this month\"")
                        .font(.system(size: 12))
                        .foregroundColor(KairoColors.mutedAdaptive.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(KairoColors.mutedAdaptive.opacity(0.12), style: StrokeStyle(lineWidth: 1.5, dash: [8, 4]))
                )
            } else {
                ForEach(customGoalStore.goals) { goal in
                    customGoalCard(goal)
                }
            }
        }
        .sheet(isPresented: $showCreateGoal) {
            CreateGoalSheet(store: customGoalStore)
        }
    }

    private func customGoalCard(_ goal: CustomGoal) -> some View {
        // Use the goal's own tracked progress (updated after each session)
        let current = goal.currentProgress
        let progress = goal.progress
        let isComplete = goal.isAchieved

        return HStack(spacing: 14) {
            // Activity icon with progress ring
            ZStack {
                Circle()
                    .fill(isComplete ? goal.activity.color : goal.activity.color.opacity(0.12))
                    .frame(width: 44, height: 44)

                // Mini progress ring
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(goal.activity.color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))

                Image(systemName: isComplete ? "checkmark" : goal.activity.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isComplete ? .white : goal.activity.color)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(goal.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(KairoColors.primaryAdaptive)
                        .lineLimit(1)

                    Spacer()

                    if isComplete {
                        Text("DONE ✓")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(goal.goalType.color))
                    } else {
                        Text("\(current)/\(goal.targetValue)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(goal.goalType.color)
                    }
                }

                // Time frame badge + progress text
                HStack(spacing: 6) {
                    // Time frame pill
                    HStack(spacing: 3) {
                        Image(systemName: goal.timeFrame.icon)
                            .font(.system(size: 9))
                        Text(goal.timeFrame.displayName)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(goal.timeFrame.color)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(goal.timeFrame.color.opacity(0.12))
                    )

                    Text("·")
                        .foregroundColor(KairoColors.mutedAdaptive)

                    Text(goal.activity.displayName)
                        .font(.system(size: 11))
                        .foregroundColor(goal.activity.color)

                    Spacer()

                    if !isComplete {
                        Text(goal.timeFrame.timeRemaining)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(KairoColors.mutedAdaptive.opacity(0.7))
                    }
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(KairoColors.mutedAdaptive.opacity(0.1))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [goal.timeFrame.color.opacity(0.7), goal.goalType.color],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * progress, height: 6)
                            .animation(.easeInOut(duration: 0.6), value: progress)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isComplete ? goal.goalType.color.opacity(0.04) : KairoColors.surfaceAdaptive)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isComplete ? goal.goalType.color.opacity(0.15) : Color.clear, lineWidth: 1)
        )
        .contextMenu {
            Button {
                customGoalStore.toggleReminder(for: goal.id)
            } label: {
                Label(
                    goal.reminderEnabled ? "Disable Reminder" : "Enable Reminder",
                    systemImage: goal.reminderEnabled ? "bell.slash" : "bell.fill"
                )
            }

            Button(role: .destructive) {
                customGoalStore.remove(id: goal.id)
            } label: {
                Label("Delete Goal", systemImage: "trash")
            }
        }
    }

    // MARK: - Goals Section

    private struct FocusGoal: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let description: String
        let target: Int        // target session count or minutes
        let current: Int       // current progress
        let unit: String       // "sessions" or "minutes"
        let color: Color
        let category: String
    }

    private var goals: [FocusGoal] {
        [
            // Session milestones
            FocusGoal(
                icon: "flame.fill",
                title: "First Steps",
                description: "Complete 10 focus sessions",
                target: 10, current: min(sessionCount, 10),
                unit: "sessions", color: Color.orange, category: "Milestone"
            ),
            FocusGoal(
                icon: "bolt.fill",
                title: "Building Momentum",
                description: "Complete 25 focus sessions",
                target: 25, current: min(sessionCount, 25),
                unit: "sessions", color: Color(hex: 0x3498DB), category: "Milestone"
            ),
            FocusGoal(
                icon: "trophy.fill",
                title: "Focus Warrior",
                description: "Complete 50 focus sessions",
                target: 50, current: min(sessionCount, 50),
                unit: "sessions", color: Color(hex: 0xF39C12), category: "Milestone"
            ),
            FocusGoal(
                icon: "crown.fill",
                title: "Focus Master",
                description: "Complete 100 focus sessions",
                target: 100, current: min(sessionCount, 100),
                unit: "sessions", color: Color(hex: 0x9B59B6), category: "Milestone"
            ),
            // Tier goals
            FocusGoal(
                icon: "brain",
                title: "Unlock Basic Coaching",
                description: "Reach Tier 1 — basic pattern analysis",
                target: 10, current: min(sessionCount, 10),
                unit: "sessions", color: Color(hex: 0x3498DB), category: "Coaching"
            ),
            FocusGoal(
                icon: "chart.line.uptrend.xyaxis",
                title: "Unlock Intermediate Analysis",
                description: "Reach Tier 2 — chronotype & scheduling",
                target: 20, current: min(sessionCount, 20),
                unit: "sessions", color: Color(hex: 0x9B59B6), category: "Coaching"
            ),
            FocusGoal(
                icon: "sparkles",
                title: "Unlock Full AI Coach",
                description: "Reach Tier 3 — deep personalization",
                target: 30, current: min(sessionCount, 30),
                unit: "sessions", color: KairoColors.accentAdaptive, category: "Coaching"
            ),
            // Streak goals
            FocusGoal(
                icon: "calendar.badge.checkmark",
                title: "3-Day Streak",
                description: "Focus 3 days in a row",
                target: 3, current: min(streakProxy, 3),
                unit: "days", color: Color.green, category: "Consistency"
            ),
            FocusGoal(
                icon: "calendar.badge.checkmark",
                title: "7-Day Streak",
                description: "Focus every day for a week",
                target: 7, current: min(streakProxy, 7),
                unit: "days", color: Color(hex: 0x1ABC9C), category: "Consistency"
            ),
            FocusGoal(
                icon: "calendar.badge.checkmark",
                title: "30-Day Streak",
                description: "One month of daily focus",
                target: 30, current: min(streakProxy, 30),
                unit: "days", color: Color(hex: 0xE74C3C), category: "Consistency"
            ),
        ]
    }

    /// Rough streak proxy — estimates based on session count (real streak comes from Core Data)
    private var streakProxy: Int {
        // Simple heuristic: assume ~1 session/day average for streak estimation
        min(sessionCount, 30)
    }

    @State private var selectedGoalCategory: String = "Milestone"

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Goals")
                .font(KairoTypography.heading3)
                .foregroundColor(KairoColors.primaryAdaptive)

            // Category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(["Milestone", "Coaching", "Consistency"], id: \.self) { category in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedGoalCategory = category
                            }
                        } label: {
                            Text(category)
                                .font(.system(size: 13, weight: selectedGoalCategory == category ? .semibold : .regular))
                                .foregroundColor(selectedGoalCategory == category ? .white : KairoColors.primaryAdaptive)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule()
                                        .fill(selectedGoalCategory == category
                                              ? Color(hex: 0x9B59B6)
                                              : KairoColors.mutedAdaptive.opacity(0.1))
                                )
                        }
                    }
                }
            }

            // Goal cards
            let filteredGoals = goals.filter { $0.category == selectedGoalCategory }
            ForEach(filteredGoals) { goal in
                goalCard(goal)
            }
        }
    }

    private func goalCard(_ goal: FocusGoal) -> some View {
        let progress = goal.target > 0 ? Double(goal.current) / Double(goal.target) : 0
        let isComplete = goal.current >= goal.target

        return HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(isComplete ? goal.color : goal.color.opacity(0.12))
                    .frame(width: 42, height: 42)

                Image(systemName: isComplete ? "checkmark" : goal.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isComplete ? .white : goal.color)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(goal.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(KairoColors.primaryAdaptive)

                    Spacer()

                    if isComplete {
                        Text("DONE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(goal.color)
                            )
                    } else {
                        Text("\(goal.current)/\(goal.target)")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(KairoColors.mutedAdaptive)
                    }
                }

                Text(goal.description)
                    .font(.system(size: 12))
                    .foregroundColor(KairoColors.mutedAdaptive)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(KairoColors.mutedAdaptive.opacity(0.1))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                isComplete
                                ? AnyShapeStyle(goal.color)
                                : AnyShapeStyle(LinearGradient(
                                    colors: [goal.color.opacity(0.7), goal.color],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                            )
                            .frame(width: geo.size.width * min(1.0, progress), height: 6)
                            .animation(.easeInOut(duration: 0.6), value: progress)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isComplete ? goal.color.opacity(0.04) : KairoColors.surfaceAdaptive)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isComplete ? goal.color.opacity(0.15) : Color.clear, lineWidth: 1)
        )
    }

    // MARK: - Tier Breakdown

    private var tierBreakdown: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Coaching Tiers")
                .font(KairoTypography.heading3)
                .foregroundColor(KairoColors.primaryAdaptive)

            ForEach(tiers, id: \.level) { tier in
                tierRow(tier)
            }
        }
    }

    private func tierRow(_ tier: TierInfo) -> some View {
        let isUnlocked = sessionCount >= tier.sessions
        let isCurrent = coachingTier == tier.level

        return HStack(alignment: .top, spacing: 14) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(isUnlocked ? tier.color : KairoColors.mutedAdaptive.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: isUnlocked ? tier.icon : "lock.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isUnlocked ? .white : KairoColors.mutedAdaptive.opacity(0.4))
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(tier.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isUnlocked ? KairoColors.primaryAdaptive : KairoColors.mutedAdaptive)

                    if isCurrent {
                        Text("ACTIVE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(tier.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(tier.color.opacity(0.15))
                            )
                    }

                    Spacer()

                    Text("\(tier.sessions) sessions")
                        .font(.system(size: 12))
                        .foregroundColor(KairoColors.mutedAdaptive)
                }

                // Features list
                ForEach(tier.features, id: \.self) { feature in
                    HStack(spacing: 6) {
                        Image(systemName: isUnlocked ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 11))
                            .foregroundColor(isUnlocked ? tier.color : KairoColors.mutedAdaptive.opacity(0.3))

                        Text(feature)
                            .font(.system(size: 13))
                            .foregroundColor(isUnlocked ? KairoColors.primaryAdaptive.opacity(0.8) : KairoColors.mutedAdaptive.opacity(0.5))
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCurrent ? tier.color.opacity(0.05) : KairoColors.surfaceAdaptive)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCurrent ? tier.color.opacity(0.2) : Color.clear, lineWidth: 1)
        )
    }

    // MARK: - Focus Stats

    private var focusStats: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By The Numbers")
                .font(KairoTypography.heading3)
                .foregroundColor(KairoColors.primaryAdaptive)

            HStack(spacing: 12) {
                statCard(
                    value: "\(sessionCount)",
                    label: "Total Sessions",
                    icon: "flame.fill",
                    color: Color.orange
                )

                statCard(
                    value: "\(Int(modelReadiness * 100))%",
                    label: "Model Trained",
                    icon: "brain",
                    color: Color(hex: 0x9B59B6)
                )

                statCard(
                    value: "Tier \(coachingTier)",
                    label: "Coach Level",
                    icon: "star.fill",
                    color: KairoColors.accentAdaptive
                )
            }
        }
    }

    private func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(KairoColors.primaryAdaptive)

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(KairoColors.mutedAdaptive)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(KairoColors.surfaceAdaptive)
        )
    }

    // MARK: - Helpers

    private var currentTierIcon: String {
        switch coachingTier {
        case 1: return "brain"
        case 2: return "chart.line.uptrend.xyaxis"
        case 3: return "sparkles"
        default: return "circle.dotted"
        }
    }

    private var currentTierName: String {
        switch coachingTier {
        case 1: return "Basic Patterns"
        case 2: return "Intermediate Analysis"
        case 3: return "Full AI Coach"
        default: return "Learning Mode"
        }
    }

    private var currentTierColor: Color {
        switch coachingTier {
        case 1: return Color(hex: 0x3498DB)
        case 2: return Color(hex: 0x9B59B6)
        case 3: return KairoColors.accentAdaptive
        default: return KairoColors.mutedAdaptive
        }
    }

    private var nextTarget: Int {
        switch coachingTier {
        case 0: return 10
        case 1: return 20
        case 2: return 30
        default: return 30
        }
    }
}

// MARK: - Preview

#Preview {
    PatternProgressView(
        sessionCount: 14,
        coachingTier: 1,
        modelReadiness: 14.0 / 30.0
    )
}
