//
//  MealAnalysisOptionsView.swift
//  playground
//
//  Beautiful sheet for analyzing a scheduled meal with 3 options:
//  1. Scan/Analyze image
//  2. Select from saved foods
//  3. Describe the food (text)
//
//  Enhanced with proper meal linking and improved UI/UX
//

import SwiftUI
import SwiftData

struct MealAnalysisOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    let scheduledMealId: UUID
    let mealName: String
    let category: MealCategory
    
    /// Callback when meal is successfully logged with the saved meal info
    var onMealLogged: ((Meal) -> Void)?
    
    @State private var showingScanView = false
    @State private var showingLogFoodView = false
    @State private var showingTextLogView = false
    @State private var isProcessing = false
    @State private var lastSavedMealId: UUID?
    
    private var mealRepository: MealRepository {
        MealRepository(context: modelContext)
    }
    
    private var dietPlanRepository: DietPlanRepository {
        DietPlanRepository(context: modelContext)
    }
    
    private var scanViewModel: ScanViewModel {
        ScanViewModel(
            repository: mealRepository,
            analysisService: CaloriesAPIService(),
            imageStorage: .shared,
            overrideCategory: category
        )
    }
    
    var body: some View {
        let _ = localizationManager.currentLanguage
        
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    // Header with meal info
                    mealHeader
                    
                    // Options
                    ScrollView {
                        VStack(spacing: 16) {
                            // Scan/Analyze option - Primary
                            AnalysisOptionCard(
                                icon: "camera.fill",
                                title: localizationManager.localizedString(for: AppStrings.Home.scanFood),
                                subtitle: localizationManager.localizedString(for: AppStrings.DietPlan.openCameraToScan),
                                gradientColors: [.blue, .cyan],
                                isPrimary: true
                            ) {
                                HapticManager.shared.impact(.medium)
                                showingScanView = true
                            }
                            
                            // Select from saved foods
                            AnalysisOptionCard(
                                icon: "bookmark.fill",
                                title: localizationManager.localizedString(for: AppStrings.Food.logFood),
                                subtitle: localizationManager.localizedString(for: AppStrings.Food.searchOrCreate),
                                gradientColors: [.green, .mint],
                                isPrimary: false
                            ) {
                                HapticManager.shared.impact(.medium)
                                showingLogFoodView = true
                            }
                            
                            // Describe the food
                            AnalysisOptionCard(
                                icon: "text.bubble.fill",
                                title: localizationManager.localizedString(for: AppStrings.Food.textLog),
                                subtitle: localizationManager.localizedString(for: AppStrings.Food.textLogDescription),
                                gradientColors: [.purple, .indigo],
                                isPrimary: false
                            ) {
                                HapticManager.shared.impact(.medium)
                                showingTextLogView = true
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 40)
                    }
                }
                .background(Color(.systemGroupedBackground))
                
                // Processing overlay
                if isProcessing {
                    processingOverlay
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.gray.opacity(0.6))
                    }
                    .disabled(isProcessing)
                }
            }
            .sheet(isPresented: $showingScanView) {
                ScanView(
                    viewModel: scanViewModel,
                    onMealSaved: {
                        showingScanView = false
                        // Linking is now handled by the .foodLogged notification with meal ID
                    },
                    onDismiss: {
                        showingScanView = false
                    }
                )
            }
            .sheet(isPresented: $showingLogFoodView) {
                LogFoodView(initialCategory: category)
            }
            .sheet(isPresented: $showingTextLogView) {
                TextFoodLogView(initialCategory: category)
            }
            .onReceive(NotificationCenter.default.publisher(for: .foodLogged)) { notification in
                // Only link if we received a meal ID - this means a meal was actually saved
                guard let mealId = notification.object as? UUID else { return }
                
                // A meal was saved, link it to the scheduled meal
                Task {
                    await linkMealById(mealId)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
    }
    
    // MARK: - Meal Header
    
    private var mealHeader: some View {
        VStack(spacing: 16) {
            // Meal icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [category.color.opacity(0.2), category.color.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)
                
                Image(systemName: category.icon)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [category.color, category.color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 6) {
                Text(mealName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(localizationManager.localizedString(for: AppStrings.DietPlan.howWouldYouLikeToLog))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 24)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Processing Overlay
    
    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text(localizationManager.localizedString(for: AppStrings.DietPlan.linkingMeal))
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
    }
    
    // MARK: - Helper Methods
    
    /// Link a meal by its ID to the scheduled meal
    private func linkMealById(_ mealId: UUID) async {
        // Avoid linking the same meal multiple times
        guard mealId != lastSavedMealId else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            // Fetch the meal by ID
            let descriptor = FetchDescriptor<Meal>(
                predicate: #Predicate<Meal> { meal in
                    meal.id == mealId
                }
            )
            
            guard let meal = try modelContext.fetch(descriptor).first else {
                print("Could not find meal with ID: \(mealId)")
                return
            }
            
            lastSavedMealId = meal.id
            try await linkMealToScheduledMeal(meal)
        } catch {
            print("Failed to link meal by ID: \(error)")
        }
    }
    
    /// Link a saved meal to the scheduled meal by updating the reminder
    private func linkMealToScheduledMeal(_ meal: Meal) async throws {
        // First, find or create a reminder for today
        var reminder = try dietPlanRepository.fetchMealReminder(
            by: scheduledMealId,
            for: Date()
        )
        
        if reminder == nil {
            // Create a new reminder
            let newReminder = MealReminder(
                scheduledMealId: scheduledMealId,
                reminderDate: Date(),
                wasCompleted: false
            )
            try dietPlanRepository.saveMealReminder(newReminder)
            reminder = newReminder
        }
        
        if let reminder = reminder {
            // Update the reminder with the completed meal
            try dietPlanRepository.updateMealReminderCompletion(reminder, completedMealId: meal.id)
            
            // Fetch the scheduled meal to evaluate goal achievement
            if let scheduledMeal = try fetchScheduledMeal(by: scheduledMealId) {
                let (achieved, deviation) = dietPlanRepository.evaluateMealGoalAchievement(
                    actualMeal: meal,
                    scheduledMeal: scheduledMeal
                )
                try dietPlanRepository.updateMealReminderGoalAchievement(
                    reminder,
                    goalAchieved: achieved,
                    goalDeviation: deviation
                )
            }
        }
        
        HapticManager.shared.notification(.success)
        
        // Notify callback
        onMealLogged?(meal)
        
        // Dismiss the sheet
        dismiss()
    }
    
    /// Fetch scheduled meal by ID
    private func fetchScheduledMeal(by id: UUID) throws -> ScheduledMeal? {
        let descriptor = FetchDescriptor<ScheduledMeal>(
            predicate: #Predicate<ScheduledMeal> { meal in
                meal.id == id
            }
        )
        return try modelContext.fetch(descriptor).first
    }
}

// MARK: - Analysis Option Card

private struct AnalysisOptionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let gradientColors: [Color]
    let isPrimary: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon with gradient background
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: isPrimary ? 56 : 48, height: isPrimary ? 56 : 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: isPrimary ? 24 : 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(isPrimary ? .headline : .subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(isPrimary ? 20 : 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isPrimary 
                            ? LinearGradient(colors: gradientColors.map { $0.opacity(0.3) }, startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom),
                        lineWidth: isPrimary ? 2 : 0
                    )
            )
            .shadow(
                color: isPrimary ? gradientColors[0].opacity(0.15) : .clear,
                radius: isPrimary ? 8 : 0,
                x: 0,
                y: isPrimary ? 4 : 0
            )
        }
        .buttonStyle(MealOptionScaleButtonStyle())
    }
}

// MARK: - Meal Option Scale Button Style

private struct MealOptionScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    MealAnalysisOptionsView(
        scheduledMealId: UUID(),
        mealName: "Breakfast",
        category: .breakfast
    )
}
