//
//  LogExperienceViewModel.swift
//  playground
//
//  ViewModel for managing the log experience feature
//

import Foundation
import SwiftUI

/// Represents a food log entry that can be created manually or via AI
struct FoodLogEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var calories: Int
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var portion: Double
    var unit: String
    var timestamp: Date
    var source: LogSource

    init(
        id: UUID = UUID(),
        name: String,
        calories: Int,
        proteinG: Double = 0,
        carbsG: Double = 0,
        fatG: Double = 0,
        portion: Double = 1,
        unit: String = "serving",
        timestamp: Date = Date(),
        source: LogSource = .manual
    ) {
        self.id = id
        self.name = name
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.portion = portion
        self.unit = unit
        self.timestamp = timestamp
        self.source = source
    }

    /// Convert to MealItem for saving
    func toMealItem() -> MealItem {
        MealItem(
            name: name,
            portion: portion,
            unit: unit,
            calories: calories,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG
        )
    }
}

enum LogSource: String, Codable {
    case manual = "manual"
    case aiText = "ai_text"
    case voice = "voice"
    case quickAdd = "quick_add"
    case scan = "scan"
}

/// Quick add food options for common foods
struct QuickAddFood: Identifiable {
    let id = UUID()
    let name: String
    let emoji: String
    let calories: Int
    let proteinG: Double
    let carbsG: Double
    let fatG: Double

    static let commonFoods: [QuickAddFood] = [
        QuickAddFood(name: "Apple", emoji: "🍎", calories: 95, proteinG: 0.5, carbsG: 25, fatG: 0.3),
        QuickAddFood(
            name: "Banana", emoji: "🍌", calories: 105, proteinG: 1.3, carbsG: 27, fatG: 0.4),
        QuickAddFood(name: "Egg", emoji: "🥚", calories: 78, proteinG: 6, carbsG: 0.6, fatG: 5),
        QuickAddFood(
            name: "Chicken Breast", emoji: "🍗", calories: 165, proteinG: 31, carbsG: 0, fatG: 3.6),
        QuickAddFood(
            name: "Rice (1 cup)", emoji: "🍚", calories: 206, proteinG: 4.3, carbsG: 45, fatG: 0.4),
        QuickAddFood(
            name: "Bread Slice", emoji: "🍞", calories: 79, proteinG: 2.7, carbsG: 15, fatG: 1),
        QuickAddFood(name: "Coffee", emoji: "☕", calories: 2, proteinG: 0.3, carbsG: 0, fatG: 0),
        QuickAddFood(
            name: "Protein Shake", emoji: "🥤", calories: 150, proteinG: 25, carbsG: 5, fatG: 2),
        QuickAddFood(name: "Salad", emoji: "🥗", calories: 120, proteinG: 3, carbsG: 12, fatG: 7),
        QuickAddFood(name: "Yogurt", emoji: "🥛", calories: 100, proteinG: 17, carbsG: 6, fatG: 0.7),
        QuickAddFood(
            name: "Almonds (1oz)", emoji: "🥜", calories: 164, proteinG: 6, carbsG: 6, fatG: 14),
        QuickAddFood(name: "Avocado", emoji: "🥑", calories: 160, proteinG: 2, carbsG: 9, fatG: 15),
    ]
}

/// View model for the log experience feature
@MainActor
@Observable
final class LogExperienceViewModel {
    // MARK: - Dependencies
    private let repository: MealRepository
    private let analysisService: FoodAnalysisServiceProtocol?

    // MARK: - State
    var isLoading = false
    var isAnalyzing = false
    var analysisProgress: Double = 0

    // Text logging
    var textInput: String = ""
    var analyzedFoods: [FoodLogEntry] = []

    // Manual entry
    var manualFoodName: String = ""
    var manualCalories: String = ""
    var manualProtein: String = ""
    var manualCarbs: String = ""
    var manualFat: String = ""
    var manualPortion: String = "1"
    var manualUnit: String = "serving"

    // Recent and saved foods
    var recentFoods: [FoodLogEntry] = []
    var savedFoods: [FoodLogEntry] = []

    // Error handling
    var error: Error?
    var showError = false
    var errorMessage: String?

    // Success state
    var showSuccess = false
    var successMessage: String?

    // Category selection
    var selectedCategory: MealCategory = .snack

    // MARK: - UserDefaults keys
    private let recentFoodsKey = "log_experience_recent_foods"
    private let savedFoodsKey = "log_experience_saved_foods"

    init(repository: MealRepository, analysisService: FoodAnalysisServiceProtocol? = nil) {
        self.repository = repository
        self.analysisService = analysisService
        loadRecentFoods()
        loadSavedFoods()
        inferCategory()
    }

    // MARK: - Category Inference

    /// Infer meal category based on current time
    func inferCategory() {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11:
            selectedCategory = .breakfast
        case 11..<16:
            selectedCategory = .lunch
        case 16..<21:
            selectedCategory = .dinner
        default:
            selectedCategory = .snack
        }
    }

    // MARK: - Text Analysis

    /// Analyze text description of food using AI
    func analyzeTextInput() async {
        guard !textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter a food description"
            showError = true
            return
        }

        isAnalyzing = true
        analysisProgress = 0.1

        // Simulate progress
        let progressTask = Task {
            var currentProgress: Double = 0.1
            while currentProgress < 0.9 && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)
                currentProgress = min(currentProgress + 0.02, 0.9)
                await MainActor.run {
                    analysisProgress = currentProgress
                }
            }
        }

        do {
            // If we have an analysis service, use it
            // For now, we'll create a simple estimate based on text
            let foods = estimateFoodsFromText(textInput)

            progressTask.cancel()
            analysisProgress = 1.0

            try? await Task.sleep(nanoseconds: 200_000_000)

            analyzedFoods = foods

            if foods.isEmpty {
                errorMessage = "Could not identify any foods. Please try again with more details."
                showError = true
            }

            HapticManager.shared.notification(.success)
        } catch {
            progressTask.cancel()
            self.error = error
            self.errorMessage = error.localizedDescription
            self.showError = true
            HapticManager.shared.notification(.error)
        }

        isAnalyzing = false
        analysisProgress = 0
    }

    /// Simple text parsing to estimate foods (can be replaced with AI service)
    private func estimateFoodsFromText(_ text: String) -> [FoodLogEntry] {
        let lowercased = text.lowercased()
        var foods: [FoodLogEntry] = []

        // Check for common food keywords and create entries
        let foodPatterns: [(pattern: String, food: FoodLogEntry)] = [
            (
                "egg",
                FoodLogEntry(
                    name: "Egg", calories: 78, proteinG: 6, carbsG: 0.6, fatG: 5, source: .aiText)
            ),
            (
                "toast",
                FoodLogEntry(
                    name: "Toast", calories: 79, proteinG: 2.7, carbsG: 15, fatG: 1, source: .aiText
                )
            ),
            (
                "bread",
                FoodLogEntry(
                    name: "Bread", calories: 79, proteinG: 2.7, carbsG: 15, fatG: 1, source: .aiText
                )
            ),
            (
                "coffee",
                FoodLogEntry(
                    name: "Coffee", calories: 2, proteinG: 0.3, carbsG: 0, fatG: 0, source: .aiText)
            ),
            (
                "rice",
                FoodLogEntry(
                    name: "Rice", calories: 206, proteinG: 4.3, carbsG: 45, fatG: 0.4,
                    source: .aiText)
            ),
            (
                "chicken",
                FoodLogEntry(
                    name: "Chicken", calories: 165, proteinG: 31, carbsG: 0, fatG: 3.6,
                    source: .aiText)
            ),
            (
                "salad",
                FoodLogEntry(
                    name: "Salad", calories: 120, proteinG: 3, carbsG: 12, fatG: 7, source: .aiText)
            ),
            (
                "apple",
                FoodLogEntry(
                    name: "Apple", calories: 95, proteinG: 0.5, carbsG: 25, fatG: 0.3,
                    source: .aiText)
            ),
            (
                "banana",
                FoodLogEntry(
                    name: "Banana", calories: 105, proteinG: 1.3, carbsG: 27, fatG: 0.4,
                    source: .aiText)
            ),
            (
                "milk",
                FoodLogEntry(
                    name: "Milk", calories: 103, proteinG: 8, carbsG: 12, fatG: 2.4, source: .aiText
                )
            ),
            (
                "yogurt",
                FoodLogEntry(
                    name: "Yogurt", calories: 100, proteinG: 17, carbsG: 6, fatG: 0.7,
                    source: .aiText)
            ),
            (
                "sandwich",
                FoodLogEntry(
                    name: "Sandwich", calories: 350, proteinG: 15, carbsG: 40, fatG: 12,
                    source: .aiText)
            ),
            (
                "burger",
                FoodLogEntry(
                    name: "Burger", calories: 540, proteinG: 25, carbsG: 40, fatG: 29,
                    source: .aiText)
            ),
            (
                "pizza",
                FoodLogEntry(
                    name: "Pizza Slice", calories: 285, proteinG: 12, carbsG: 36, fatG: 10,
                    source: .aiText)
            ),
            (
                "pasta",
                FoodLogEntry(
                    name: "Pasta", calories: 220, proteinG: 8, carbsG: 43, fatG: 1.3,
                    source: .aiText)
            ),
            (
                "steak",
                FoodLogEntry(
                    name: "Steak", calories: 271, proteinG: 26, carbsG: 0, fatG: 18, source: .aiText
                )
            ),
            (
                "fish",
                FoodLogEntry(
                    name: "Fish", calories: 136, proteinG: 20, carbsG: 0, fatG: 6, source: .aiText)
            ),
            (
                "salmon",
                FoodLogEntry(
                    name: "Salmon", calories: 208, proteinG: 20, carbsG: 0, fatG: 13,
                    source: .aiText)
            ),
            (
                "oatmeal",
                FoodLogEntry(
                    name: "Oatmeal", calories: 158, proteinG: 6, carbsG: 27, fatG: 3,
                    source: .aiText)
            ),
            (
                "cereal",
                FoodLogEntry(
                    name: "Cereal", calories: 150, proteinG: 3, carbsG: 33, fatG: 1, source: .aiText
                )
            ),
            (
                "smoothie",
                FoodLogEntry(
                    name: "Smoothie", calories: 200, proteinG: 5, carbsG: 40, fatG: 2,
                    source: .aiText)
            ),
            (
                "protein shake",
                FoodLogEntry(
                    name: "Protein Shake", calories: 150, proteinG: 25, carbsG: 5, fatG: 2,
                    source: .aiText)
            ),
            (
                "avocado",
                FoodLogEntry(
                    name: "Avocado", calories: 160, proteinG: 2, carbsG: 9, fatG: 15,
                    source: .aiText)
            ),
            (
                "cheese",
                FoodLogEntry(
                    name: "Cheese", calories: 113, proteinG: 7, carbsG: 0.4, fatG: 9,
                    source: .aiText)
            ),
        ]

        // Check for quantity modifiers
        let quantityPatterns: [(pattern: String, multiplier: Int)] = [
            ("two", 2), ("2", 2),
            ("three", 3), ("3", 3),
            ("four", 4), ("4", 4),
            ("five", 5), ("5", 5),
            ("half", 0),  // Special case handled separately
            ("double", 2),
        ]

        for (pattern, baseFood) in foodPatterns {
            if lowercased.contains(pattern) {
                var food = baseFood

                // Check for quantity modifiers
                for (quantityPattern, multiplier) in quantityPatterns {
                    if lowercased.contains(quantityPattern) && lowercased.contains(pattern) {
                        // Check if the quantity is near the food word
                        if let patternRange = lowercased.range(of: pattern),
                            let quantityRange = lowercased.range(of: quantityPattern)
                        {
                            let distance = abs(
                                lowercased.distance(
                                    from: quantityRange.lowerBound, to: patternRange.lowerBound))
                            if distance < 20 {  // Within 20 characters
                                if multiplier == 0 {  // Half
                                    food.calories = Int(Double(food.calories) * 0.5)
                                    food.proteinG *= 0.5
                                    food.carbsG *= 0.5
                                    food.fatG *= 0.5
                                    food.portion = 0.5
                                } else {
                                    food.calories *= multiplier
                                    food.proteinG *= Double(multiplier)
                                    food.carbsG *= Double(multiplier)
                                    food.fatG *= Double(multiplier)
                                    food.portion = Double(multiplier)
                                }
                                break
                            }
                        }
                    }
                }

                foods.append(food)
            }
        }

        // If no foods found, create a generic entry based on the text
        if foods.isEmpty && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Make a best guess based on common meal sizes
            let words = text.split(separator: " ")
            let name = words.prefix(5).joined(separator: " ").capitalized
            foods.append(
                FoodLogEntry(
                    name: name.isEmpty ? "Food" : name,
                    calories: 200,
                    proteinG: 10,
                    carbsG: 20,
                    fatG: 8,
                    source: .aiText
                ))
        }

        return foods
    }

    // MARK: - Manual Entry

    /// Validate and save manual food entry
    func saveManualEntry() async -> Bool {
        guard !manualFoodName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter a food name"
            showError = true
            return false
        }

        guard let calories = Int(manualCalories), calories >= 0 else {
            errorMessage = "Please enter valid calories"
            showError = true
            return false
        }

        let protein = Double(manualProtein) ?? 0
        let carbs = Double(manualCarbs) ?? 0
        let fat = Double(manualFat) ?? 0
        let portion = Double(manualPortion) ?? 1

        let entry = FoodLogEntry(
            name: manualFoodName.trimmingCharacters(in: .whitespacesAndNewlines),
            calories: calories,
            proteinG: protein,
            carbsG: carbs,
            fatG: fat,
            portion: portion,
            unit: manualUnit,
            source: .manual
        )

        let success = await saveFoodEntry(entry)

        if success {
            clearManualEntry()
        }

        return success
    }

    /// Clear manual entry fields
    func clearManualEntry() {
        manualFoodName = ""
        manualCalories = ""
        manualProtein = ""
        manualCarbs = ""
        manualFat = ""
        manualPortion = "1"
        manualUnit = "serving"
    }

    // MARK: - Quick Add

    /// Quick add a predefined food
    func quickAddFood(_ food: QuickAddFood) async -> Bool {
        let entry = FoodLogEntry(
            name: food.name,
            calories: food.calories,
            proteinG: food.proteinG,
            carbsG: food.carbsG,
            fatG: food.fatG,
            source: .quickAdd
        )

        return await saveFoodEntry(entry)
    }

    // MARK: - Save Operations

    /// Save a single food entry as a meal
    func saveFoodEntry(_ entry: FoodLogEntry) async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            let mealItem = entry.toMealItem()
            let meal = Meal(
                name: entry.name,
                timestamp: entry.timestamp,
                category: selectedCategory,
                items: [mealItem]
            )

            try repository.saveMeal(meal)

            // Add to recent foods
            addToRecentFoods(entry)

            // Notify that food was logged so HomeViewModel can refresh
            NotificationCenter.default.post(name: .foodLogged, object: nil)

            successMessage = "\(entry.name) logged successfully!"
            showSuccess = true

            HapticManager.shared.notification(.success)
            return true
        } catch {
            self.error = error
            self.errorMessage = "Failed to save: \(error.localizedDescription)"
            self.showError = true
            HapticManager.shared.notification(.error)
            return false
        }
    }

    /// Save multiple analyzed foods as a single meal
    func saveAnalyzedFoods() async -> Bool {
        guard !analyzedFoods.isEmpty else {
            errorMessage = "No foods to save"
            showError = true
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let items = analyzedFoods.map { $0.toMealItem() }
            let mealName =
                analyzedFoods.count == 1
                ? analyzedFoods[0].name
                : "\(selectedCategory.displayName) - \(analyzedFoods.count) items"

            let meal = Meal(
                name: mealName,
                timestamp: Date(),
                category: selectedCategory,
                items: items
            )

            try repository.saveMeal(meal)

            // Add all to recent foods
            for entry in analyzedFoods {
                addToRecentFoods(entry)
            }

            // Notify that food was logged so HomeViewModel can refresh
            NotificationCenter.default.post(name: .foodLogged, object: nil)

            // Clear analyzed foods
            analyzedFoods = []
            textInput = ""

            successMessage = "Meal logged successfully!"
            showSuccess = true

            HapticManager.shared.notification(.success)
            return true
        } catch {
            self.error = error
            self.errorMessage = "Failed to save: \(error.localizedDescription)"
            self.showError = true
            HapticManager.shared.notification(.error)
            return false
        }
    }

    // MARK: - Recent & Saved Foods

    /// Add a food to recent foods list
    private func addToRecentFoods(_ entry: FoodLogEntry) {
        // Remove if already exists
        recentFoods.removeAll { $0.name.lowercased() == entry.name.lowercased() }

        // Add to beginning
        recentFoods.insert(entry, at: 0)

        // Keep only last 20
        if recentFoods.count > 20 {
            recentFoods = Array(recentFoods.prefix(20))
        }

        saveRecentFoods()
    }

    /// Save a food to saved foods
    func saveToFavorites(_ entry: FoodLogEntry) {
        // Remove if already exists
        savedFoods.removeAll { $0.name.lowercased() == entry.name.lowercased() }

        // Add to beginning
        savedFoods.insert(entry, at: 0)

        saveSavedFoods()

        HapticManager.shared.impact(.light)
    }

    /// Remove from saved foods
    func removeFromFavorites(_ entry: FoodLogEntry) {
        savedFoods.removeAll { $0.id == entry.id }
        saveSavedFoods()
    }

    /// Check if a food is saved
    func isSaved(_ entry: FoodLogEntry) -> Bool {
        savedFoods.contains { $0.name.lowercased() == entry.name.lowercased() }
    }

    // MARK: - Persistence

    private func loadRecentFoods() {
        guard let data = UserDefaults.standard.data(forKey: recentFoodsKey),
            let foods = try? JSONDecoder().decode([FoodLogEntry].self, from: data)
        else {
            return
        }
        recentFoods = foods
    }

    private func saveRecentFoods() {
        guard let data = try? JSONEncoder().encode(recentFoods) else { return }
        UserDefaults.standard.set(data, forKey: recentFoodsKey)
    }

    private func loadSavedFoods() {
        guard let data = UserDefaults.standard.data(forKey: savedFoodsKey),
            let foods = try? JSONDecoder().decode([FoodLogEntry].self, from: data)
        else {
            return
        }
        savedFoods = foods
    }

    private func saveSavedFoods() {
        guard let data = try? JSONEncoder().encode(savedFoods) else { return }
        UserDefaults.standard.set(data, forKey: savedFoodsKey)
    }

    // MARK: - Computed Properties

    /// Total calories from analyzed foods
    var totalAnalyzedCalories: Int {
        analyzedFoods.reduce(0) { $0 + $1.calories }
    }

    /// Total macros from analyzed foods
    var totalAnalyzedMacros: MacroData {
        analyzedFoods.reduce(MacroData.zero) { result, entry in
            MacroData(
                calories: result.calories + entry.calories,
                proteinG: result.proteinG + entry.proteinG,
                carbsG: result.carbsG + entry.carbsG,
                fatG: result.fatG + entry.fatG
            )
        }
    }

    /// Check if manual entry is valid
    var isManualEntryValid: Bool {
        !manualFoodName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && Int(manualCalories) != nil && (Int(manualCalories) ?? -1) >= 0
    }

    /// Update a specific analyzed food's portion
    func updateAnalyzedFoodPortion(_ food: FoodLogEntry, multiplier: Double) {
        guard let index = analyzedFoods.firstIndex(where: { $0.id == food.id }) else { return }

        let originalFood = analyzedFoods[index]
        analyzedFoods[index] = FoodLogEntry(
            id: originalFood.id,
            name: originalFood.name,
            calories: Int(Double(originalFood.calories) * multiplier / originalFood.portion),
            proteinG: originalFood.proteinG * multiplier / originalFood.portion,
            carbsG: originalFood.carbsG * multiplier / originalFood.portion,
            fatG: originalFood.fatG * multiplier / originalFood.portion,
            portion: multiplier,
            unit: originalFood.unit,
            timestamp: originalFood.timestamp,
            source: originalFood.source
        )
    }

    /// Remove a food from analyzed foods
    func removeAnalyzedFood(_ food: FoodLogEntry) {
        analyzedFoods.removeAll { $0.id == food.id }
    }
}
