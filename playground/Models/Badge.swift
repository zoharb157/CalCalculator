//
//  Badge.swift
//  playground
//
//  Badge/Achievement model and tracking system
//

import Foundation
import SwiftUI

// MARK: - Badge Types

enum BadgeType: String, CaseIterable, Codable {
    case firstMeal = "first_meal"
    case weekStreak = "week_streak"
    case hitCalorieGoal = "hit_calorie_goal"
    case tenMeals = "ten_meals"
    case twentyFiveMeals = "twenty_five_meals"
    case fiftyMeals = "fifty_meals"
    case hundredMeals = "hundred_meals"
    case firstExercise = "first_exercise"
    case perfectWeek = "perfect_week"
    case proteinChampion = "protein_champion"
    
    var displayName: String {
        let localizationManager = LocalizationManager.shared
        switch self {
        case .firstMeal: return localizationManager.localizedString(for: AppStrings.Badge.firstBite)
        case .weekStreak: return localizationManager.localizedString(for: AppStrings.Badge.weekWarrior)
        case .hitCalorieGoal: return localizationManager.localizedString(for: AppStrings.Badge.goalGetter)
        case .tenMeals: return localizationManager.localizedString(for: AppStrings.Badge.gettingStarted)
        case .twentyFiveMeals: return localizationManager.localizedString(for: AppStrings.Badge.consistentLogger)
        case .fiftyMeals: return localizationManager.localizedString(for: AppStrings.Badge.dedicatedTracker)
        case .hundredMeals: return localizationManager.localizedString(for: AppStrings.Badge.centurion)
        case .firstExercise: return localizationManager.localizedString(for: AppStrings.Badge.activeStart)
        case .perfectWeek: return localizationManager.localizedString(for: AppStrings.Badge.perfectWeek)
        case .proteinChampion: return localizationManager.localizedString(for: AppStrings.Badge.proteinChampion)
        }
    }
    
    var description: String {
        switch self {
        case .firstMeal: return "Log your first meal"
        case .weekStreak: return "Log meals for 7 days in a row"
        case .hitCalorieGoal: return "Hit your calorie goal exactly (+/- 50 cal)"
        case .tenMeals: return "Log 10 meals total"
        case .twentyFiveMeals: return "Log 25 meals total"
        case .fiftyMeals: return "Log 50 meals total"
        case .hundredMeals: return "Log 100 meals total"
        case .firstExercise: return "Log your first exercise"
        case .perfectWeek: return "Hit calorie goal every day for a week"
        case .proteinChampion: return "Hit protein goal 5 days in a row"
        }
    }
    
    var icon: String {
        switch self {
        case .firstMeal: return "fork.knife.circle.fill"
        case .weekStreak: return "flame.fill"
        case .hitCalorieGoal: return "target"
        case .tenMeals: return "10.circle.fill"
        case .twentyFiveMeals: return "25.circle.fill"
        case .fiftyMeals: return "50.circle.fill"
        case .hundredMeals: return "checkmark.seal.fill"
        case .firstExercise: return "figure.run.circle.fill"
        case .perfectWeek: return "star.circle.fill"
        case .proteinChampion: return "bolt.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .firstMeal: return .green
        case .weekStreak: return .orange
        case .hitCalorieGoal: return .blue
        case .tenMeals: return .purple
        case .twentyFiveMeals: return .pink
        case .fiftyMeals: return .cyan
        case .hundredMeals: return .yellow
        case .firstExercise: return .red
        case .perfectWeek: return .yellow
        case .proteinChampion: return .indigo
        }
    }
}

// MARK: - Earned Badge

struct EarnedBadge: Codable, Identifiable {
    var id: String { type.rawValue }
    let type: BadgeType
    let earnedDate: Date
}

// MARK: - Badge Manager

@MainActor
@Observable
final class BadgeManager {
    static let shared = BadgeManager()
    
    private let earnedBadgesKey = "earnedBadges"
    private let lastCheckDateKey = "badgeLastCheckDate"
    
    var earnedBadges: [EarnedBadge] = []
    var newlyEarnedBadge: BadgeType?
    var showBadgeAlert = false
    
    private init() {
        loadEarnedBadges()
    }
    
    // MARK: - Badge Checking
    
    func checkForNewBadges(
        totalMeals: Int,
        todaysSummary: DaySummary?,
        weekSummaries: [Date: DaySummary],
        totalExercises: Int,
        calorieGoal: Int,
        proteinGoal: Double
    ) {
        var newBadges: [BadgeType] = []
        
        // First Meal
        if totalMeals >= 1 && !hasBadge(.firstMeal) {
            newBadges.append(.firstMeal)
        }
        
        // Meal milestones
        if totalMeals >= 10 && !hasBadge(.tenMeals) {
            newBadges.append(.tenMeals)
        }
        if totalMeals >= 25 && !hasBadge(.twentyFiveMeals) {
            newBadges.append(.twentyFiveMeals)
        }
        if totalMeals >= 50 && !hasBadge(.fiftyMeals) {
            newBadges.append(.fiftyMeals)
        }
        if totalMeals >= 100 && !hasBadge(.hundredMeals) {
            newBadges.append(.hundredMeals)
        }
        
        // First Exercise
        if totalExercises >= 1 && !hasBadge(.firstExercise) {
            newBadges.append(.firstExercise)
        }
        
        // Hit Calorie Goal (within +/- 50 calories)
        if let summary = todaysSummary {
            let difference = abs(summary.totalCalories - calorieGoal)
            if difference <= 50 && summary.totalCalories > 0 && !hasBadge(.hitCalorieGoal) {
                newBadges.append(.hitCalorieGoal)
            }
        }
        
        // Week Streak (7 days in a row with meals)
        if checkWeekStreak(weekSummaries) && !hasBadge(.weekStreak) {
            newBadges.append(.weekStreak)
        }
        
        // Perfect Week (hit calorie goal every day)
        if checkPerfectWeek(weekSummaries, calorieGoal: calorieGoal) && !hasBadge(.perfectWeek) {
            newBadges.append(.perfectWeek)
        }
        
        // Protein Champion (hit protein goal 5 days in a row)
        if checkProteinChampion(weekSummaries, proteinGoal: proteinGoal) && !hasBadge(.proteinChampion) {
            newBadges.append(.proteinChampion)
        }
        
        // Award new badges
        for badge in newBadges {
            awardBadge(badge)
        }
        
        // Show first new badge (others will be shown later)
        if let firstBadge = newBadges.first {
            if UserProfileRepository.shared.getBadgeCelebrations() {
                newlyEarnedBadge = firstBadge
                showBadgeAlert = true
            }
        }
    }
    
    private func checkWeekStreak(_ summaries: [Date: DaySummary]) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Check last 7 days
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                return false
            }
            let dayStart = calendar.startOfDay(for: date)
            guard let summary = summaries[dayStart], summary.mealCount > 0 else {
                return false
            }
        }
        return true
    }
    
    private func checkPerfectWeek(_ summaries: [Date: DaySummary], calorieGoal: Int) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                return false
            }
            let dayStart = calendar.startOfDay(for: date)
            guard let summary = summaries[dayStart], summary.totalCalories > 0 else {
                return false
            }
            let difference = abs(summary.totalCalories - calorieGoal)
            if difference > 50 {
                return false
            }
        }
        
        return true
    }
    
    private func checkProteinChampion(_ summaries: [Date: DaySummary], proteinGoal: Double) -> Bool {
        guard proteinGoal > 0 else { return false }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        for dayOffset in 0..<5 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                return false
            }
            let dayStart = calendar.startOfDay(for: date)
            guard let summary = summaries[dayStart], summary.totalProteinG >= proteinGoal else {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Badge Management
    
    func hasBadge(_ type: BadgeType) -> Bool {
        earnedBadges.contains { $0.type == type }
    }
    
    func awardBadge(_ type: BadgeType) {
        guard !hasBadge(type) else { return }
        
        let badge = EarnedBadge(type: type, earnedDate: Date())
        earnedBadges.append(badge)
        saveEarnedBadges()
        
        HapticManager.shared.notification(.success)
    }
    
    func dismissBadgeAlert() {
        showBadgeAlert = false
        newlyEarnedBadge = nil
    }
    
    // MARK: - Persistence
    
    private func loadEarnedBadges() {
        if let data = UserDefaults.standard.data(forKey: earnedBadgesKey),
           let badges = try? JSONDecoder().decode([EarnedBadge].self, from: data) {
            earnedBadges = badges
        }
    }
    
    private func saveEarnedBadges() {
        if let data = try? JSONEncoder().encode(earnedBadges) {
            UserDefaults.standard.set(data, forKey: earnedBadgesKey)
        }
    }
    
    // MARK: - Computed Properties
    
    var unlockedBadgeCount: Int {
        earnedBadges.count
    }
    
    var totalBadgeCount: Int {
        BadgeType.allCases.count
    }
    
    var progressText: String {
        "\(unlockedBadgeCount)/\(totalBadgeCount)"
    }
}

// MARK: - Badge Alert View

struct BadgeAlertView: View {
    let badge: BadgeType
    let onDismiss: () -> Void
    
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            // Card
            VStack(spacing: 20) {
                // Icon
                Image(systemName: badge.icon)
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [badge.color, badge.color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: badge.color.opacity(0.5), radius: 10)
                
                // Title
                Text(localizationManager.localizedString(for: AppStrings.Badge.badgeEarned))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                // Badge Name
                Text(badge.displayName)
                    .font(.title)
                    .fontWeight(.heavy)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [badge.color, badge.color.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                // Description
                Text(badge.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Dismiss Button
                Button {
                    onDismiss()
                } label: {
                    Text("Awesome!")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [badge.color, badge.color.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: .black.opacity(0.2), radius: 20)
            )
            .padding(32)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    scale = 1.0
                    opacity = 1.0
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    BadgeAlertView(badge: .firstMeal) {
        print("Dismissed")
    }
}
