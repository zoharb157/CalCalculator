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
        // Fruits
        QuickAddFood(name: "Apple", emoji: "🍎", calories: 95, proteinG: 0.5, carbsG: 25, fatG: 0.3),
        QuickAddFood(name: "Banana", emoji: "🍌", calories: 105, proteinG: 1.3, carbsG: 27, fatG: 0.4),
        QuickAddFood(name: "Orange", emoji: "🍊", calories: 62, proteinG: 1.2, carbsG: 15, fatG: 0.2),
        QuickAddFood(name: "Strawberries", emoji: "🍓", calories: 32, proteinG: 0.7, carbsG: 7.7, fatG: 0.3),
        QuickAddFood(name: "Blueberries", emoji: "🫐", calories: 57, proteinG: 0.7, carbsG: 14, fatG: 0.3),
        QuickAddFood(name: "Grapes", emoji: "🍇", calories: 62, proteinG: 0.6, carbsG: 16, fatG: 0.2),
        QuickAddFood(name: "Watermelon", emoji: "🍉", calories: 30, proteinG: 0.6, carbsG: 7.6, fatG: 0.2),
        QuickAddFood(name: "Avocado", emoji: "🥑", calories: 160, proteinG: 2, carbsG: 9, fatG: 15),
        
        // Proteins
        QuickAddFood(name: "Egg", emoji: "🥚", calories: 78, proteinG: 6, carbsG: 0.6, fatG: 5),
        QuickAddFood(name: "Chicken Breast", emoji: "🍗", calories: 165, proteinG: 31, carbsG: 0, fatG: 3.6),
        QuickAddFood(name: "Salmon", emoji: "🐟", calories: 208, proteinG: 20, carbsG: 0, fatG: 13),
        QuickAddFood(name: "Tuna", emoji: "🐟", calories: 144, proteinG: 30, carbsG: 0, fatG: 1),
        QuickAddFood(name: "Turkey Breast", emoji: "🦃", calories: 135, proteinG: 30, carbsG: 0, fatG: 1),
        QuickAddFood(name: "Ground Beef (90/10)", emoji: "🥩", calories: 250, proteinG: 26, carbsG: 0, fatG: 17),
        QuickAddFood(name: "Greek Yogurt", emoji: "🥛", calories: 100, proteinG: 17, carbsG: 6, fatG: 0.7),
        QuickAddFood(name: "Cottage Cheese", emoji: "🧀", calories: 98, proteinG: 11, carbsG: 3.4, fatG: 4.3),
        QuickAddFood(name: "Protein Shake", emoji: "🥤", calories: 150, proteinG: 25, carbsG: 5, fatG: 2),
        
        // Grains & Carbs
        QuickAddFood(name: "Rice (1 cup)", emoji: "🍚", calories: 206, proteinG: 4.3, carbsG: 45, fatG: 0.4),
        QuickAddFood(name: "Quinoa (1 cup)", emoji: "🌾", calories: 222, proteinG: 8, carbsG: 39, fatG: 3.6),
        QuickAddFood(name: "Oatmeal (1 cup)", emoji: "🥣", calories: 158, proteinG: 6, carbsG: 27, fatG: 3),
        QuickAddFood(name: "Bread Slice", emoji: "🍞", calories: 79, proteinG: 2.7, carbsG: 15, fatG: 1),
        QuickAddFood(name: "Pasta (1 cup)", emoji: "🍝", calories: 220, proteinG: 8, carbsG: 43, fatG: 1.3),
        QuickAddFood(name: "Sweet Potato", emoji: "🍠", calories: 103, proteinG: 2, carbsG: 24, fatG: 0.2),
        QuickAddFood(name: "Potato", emoji: "🥔", calories: 161, proteinG: 4.3, carbsG: 37, fatG: 0.2),
        
        // Vegetables
        QuickAddFood(name: "Salad", emoji: "🥗", calories: 120, proteinG: 3, carbsG: 12, fatG: 7),
        QuickAddFood(name: "Broccoli", emoji: "🥦", calories: 55, proteinG: 4, carbsG: 11, fatG: 0.6),
        QuickAddFood(name: "Spinach", emoji: "🥬", calories: 23, proteinG: 2.9, carbsG: 3.6, fatG: 0.4),
        QuickAddFood(name: "Carrots", emoji: "🥕", calories: 41, proteinG: 0.9, carbsG: 10, fatG: 0.2),
        QuickAddFood(name: "Tomato", emoji: "🍅", calories: 18, proteinG: 0.9, carbsG: 3.9, fatG: 0.2),
        
        // Nuts & Seeds
        QuickAddFood(name: "Almonds (1oz)", emoji: "🥜", calories: 164, proteinG: 6, carbsG: 6, fatG: 14),
        QuickAddFood(name: "Peanuts (1oz)", emoji: "🥜", calories: 161, proteinG: 7, carbsG: 4.6, fatG: 14),
        QuickAddFood(name: "Walnuts (1oz)", emoji: "🌰", calories: 185, proteinG: 4.3, carbsG: 3.9, fatG: 18),
        QuickAddFood(name: "Chia Seeds (1oz)", emoji: "🌱", calories: 138, proteinG: 4.7, carbsG: 12, fatG: 8.7),
        
        // Dairy
        QuickAddFood(name: "Milk (1 cup)", emoji: "🥛", calories: 103, proteinG: 8, carbsG: 12, fatG: 2.4),
        QuickAddFood(name: "Cheese (1oz)", emoji: "🧀", calories: 113, proteinG: 7, carbsG: 0.4, fatG: 9),
        QuickAddFood(name: "Yogurt", emoji: "🥛", calories: 100, proteinG: 17, carbsG: 6, fatG: 0.7),
        
        // Beverages
        QuickAddFood(name: "Coffee", emoji: "☕", calories: 2, proteinG: 0.3, carbsG: 0, fatG: 0),
        QuickAddFood(name: "Green Tea", emoji: "🍵", calories: 2, proteinG: 0, carbsG: 0, fatG: 0),
        QuickAddFood(name: "Smoothie", emoji: "🥤", calories: 200, proteinG: 5, carbsG: 40, fatG: 2),
        
        // Snacks
        QuickAddFood(name: "Hummus (2 tbsp)", emoji: "🥄", calories: 50, proteinG: 2.4, carbsG: 4.4, fatG: 2.4),
        QuickAddFood(name: "Peanut Butter (2 tbsp)", emoji: "🥜", calories: 188, proteinG: 8, carbsG: 6, fatG: 16),
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

    // Text logging / Search
    var textInput: String = ""
    var searchQuery: String = "" // Separate search query for filtering
    var analyzedFoods: [FoodLogEntry] = []

    // Manual entry
    var manualFoodName: String = ""
    var manualCalories: String = ""
    var manualProtein: String = ""
    var manualCarbs: String = ""
    var manualFat: String = ""
    var manualPortion: String = "1"
    var manualUnit: String = "serving"
    var saveToQuickAdd: Bool = false // Option to save to quick add

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

    init(repository: MealRepository, analysisService: FoodAnalysisServiceProtocol? = nil, initialCategory: MealCategory? = nil) {
        self.repository = repository
        self.analysisService = analysisService
        loadRecentFoods()
        loadSavedFoods()
        
        // Use provided category or infer from time
        if let category = initialCategory {
            self.selectedCategory = category
        } else {
            inferCategory()
        }
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

        // Set initial progress
        analysisProgress = 0.1

        // If we have an analysis service, use it
        // For now, we'll create a simple estimate based on text
        let foods = estimateFoodsFromText(textInput)

        analysisProgress = 1.0

        analyzedFoods = foods

        if foods.isEmpty {
            errorMessage = "Could not identify any foods. Please try again with more details."
            showError = true
        } else {
            HapticManager.shared.notification(.success)
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
            // Only match if the pattern is a complete word (not a substring)
            // This prevents matching partial words like "egg" in "leg" or "apple" in "pineapple"
            let wordBoundaryPattern = "\\b\(NSRegularExpression.escapedPattern(for: pattern))\\b"
            if let regex = try? NSRegularExpression(pattern: wordBoundaryPattern, options: .caseInsensitive) {
                let range = NSRange(lowercased.startIndex..<lowercased.endIndex, in: lowercased)
                let matches = regex.matches(in: lowercased, options: [], range: range)
                
                if !matches.isEmpty {
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
            // If user wants to save to quick add, add it
            if saveToQuickAdd {
                addToQuickAdd(entry)
            }
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
        saveToQuickAdd = false
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
            // Pass the meal ID so listeners can link to this specific meal
            NotificationCenter.default.post(name: .foodLogged, object: meal.id)

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
            // Pass the meal ID so listeners can link to this specific meal
            NotificationCenter.default.post(name: .foodLogged, object: meal.id)

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
    
    /// Add a custom food to quick add (saved foods)
    /// This allows users to add their own foods to the quick add list
    func addToQuickAdd(_ entry: FoodLogEntry) {
        saveToFavorites(entry)
    }
    
    /// Get all quick add foods (common + saved, without duplicates)
    /// Returns the last 2 saved foods (most recent) + common foods
    var allQuickAddFoods: [QuickAddFood] {
        var foods: [QuickAddFood] = []
        
        // Add saved foods (converted to QuickAddFood) - last 2 without duplicates
        let uniqueSavedFoods = Array(Set(savedFoods.map { $0.name.lowercased() }))
            .compactMap { name -> FoodLogEntry? in
                savedFoods.first { $0.name.lowercased() == name }
            }
            .suffix(2)
            .reversed()
        
        for savedFood in uniqueSavedFoods {
            foods.append(QuickAddFood(
                name: savedFood.name,
                emoji: "⭐", // Custom food indicator
                calories: savedFood.calories,
                proteinG: savedFood.proteinG,
                carbsG: savedFood.carbsG,
                fatG: savedFood.fatG
            ))
        }
        
        // Add common foods, excluding duplicates
        let savedNames = Set(foods.map { $0.name.lowercased() })
        for commonFood in QuickAddFood.commonFoods {
            if !savedNames.contains(commonFood.name.lowercased()) {
                foods.append(commonFood)
            }
        }
        
        return foods
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
    /// Safely handles division by zero
    func updateAnalyzedFoodPortion(_ food: FoodLogEntry, multiplier: Double) {
        guard let index = analyzedFoods.firstIndex(where: { $0.id == food.id }) else { return }
        guard multiplier > 0 else { return }

        let originalFood = analyzedFoods[index]
        
        // Safely calculate new values, avoiding division by zero
        guard originalFood.portion > 0 else {
            print("⚠️ [LogExperienceViewModel] Cannot update portion: original portion is 0")
            return
        }
        
        let ratio = multiplier / originalFood.portion
        analyzedFoods[index] = FoodLogEntry(
            id: originalFood.id,
            name: originalFood.name,
            calories: Int(Double(originalFood.calories) * ratio),
            proteinG: originalFood.proteinG * ratio,
            carbsG: originalFood.carbsG * ratio,
            fatG: originalFood.fatG * ratio,
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
    
    // MARK: - Search Filtering
    
    /// Check if search is active
    var isSearchActive: Bool {
        !textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Filtered quick add foods based on search query
    var filteredQuickAddFoods: [QuickAddFood] {
        guard isSearchActive else { return allQuickAddFoods }
        let query = textInput.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return allQuickAddFoods.filter { $0.name.lowercased().contains(query) }
    }
    
    /// Filtered recent foods based on search query
    var filteredRecentFoods: [FoodLogEntry] {
        guard isSearchActive else { return recentFoods }
        let query = textInput.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return recentFoods.filter { $0.name.lowercased().contains(query) }
    }
    
    /// Filtered saved foods based on search query
    var filteredSavedFoods: [FoodLogEntry] {
        guard isSearchActive else { return savedFoods }
        let query = textInput.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return savedFoods.filter { $0.name.lowercased().contains(query) }
    }
    
    /// Check if any filtered results exist
    var hasFilteredResults: Bool {
        !filteredQuickAddFoods.isEmpty || !filteredRecentFoods.isEmpty || !filteredSavedFoods.isEmpty
    }
    
    // MARK: - Food Categories for Quick Add
    
    enum FoodCategory: String, CaseIterable {
        case fruits = "Fruits"
        case proteins = "Proteins"
        case grains = "Grains & Carbs"
        case vegetables = "Vegetables"
        case nuts = "Nuts & Seeds"
        case dairy = "Dairy"
        case beverages = "Beverages"
        case snacks = "Snacks"
        
        var icon: String {
            switch self {
            case .fruits: return "leaf.fill"
            case .proteins: return "fork.knife"
            case .grains: return "takeoutbag.and.cup.and.straw.fill"
            case .vegetables: return "carrot.fill"
            case .nuts: return "tree.fill"
            case .dairy: return "cup.and.saucer.fill"
            case .beverages: return "mug.fill"
            case .snacks: return "birthday.cake.fill"
            }
        }
        
        var color: String {
            switch self {
            case .fruits: return "red"
            case .proteins: return "orange"
            case .grains: return "brown"
            case .vegetables: return "green"
            case .nuts: return "yellow"
            case .dairy: return "blue"
            case .beverages: return "cyan"
            case .snacks: return "purple"
            }
        }
    }
    
    /// Get categorized quick add foods
    var categorizedQuickAddFoods: [FoodCategory: [QuickAddFood]] {
        var result: [FoodCategory: [QuickAddFood]] = [:]
        
        // Initialize empty arrays for all categories
        for category in FoodCategory.allCases {
            result[category] = []
        }
        
        // Categorize foods based on their position in the commonFoods array
        let foods = filteredQuickAddFoods
        for food in foods {
            let category = categorize(food: food)
            result[category, default: []].append(food)
        }
        
        return result
    }
    
    /// Categorize a food item
    private func categorize(food: QuickAddFood) -> FoodCategory {
        let name = food.name.lowercased()
        
        // Fruits
        if ["apple", "banana", "orange", "strawberries", "blueberries", "grapes", "watermelon", "avocado"].contains(where: { name.contains($0) }) {
            return .fruits
        }
        
        // Proteins
        if ["egg", "chicken", "salmon", "tuna", "turkey", "beef", "yogurt", "cottage", "protein shake", "steak", "fish"].contains(where: { name.contains($0) }) {
            return .proteins
        }
        
        // Grains
        if ["rice", "quinoa", "oatmeal", "bread", "pasta", "potato", "sweet potato", "cereal", "toast"].contains(where: { name.contains($0) }) {
            return .grains
        }
        
        // Vegetables
        if ["salad", "broccoli", "spinach", "carrots", "tomato", "vegetable"].contains(where: { name.contains($0) }) {
            return .vegetables
        }
        
        // Nuts
        if ["almonds", "peanuts", "walnuts", "chia", "peanut butter", "nut"].contains(where: { name.contains($0) }) {
            return .nuts
        }
        
        // Dairy
        if ["milk", "cheese", "yogurt"].contains(where: { name.contains($0) }) {
            return .dairy
        }
        
        // Beverages
        if ["coffee", "tea", "smoothie", "shake", "juice", "water"].contains(where: { name.contains($0) }) {
            return .beverages
        }
        
        // Snacks
        if ["hummus", "chips", "cookie", "candy", "snack"].contains(where: { name.contains($0) }) {
            return .snacks
        }
        
        // Default to snacks for custom/unknown foods
        return .snacks
    }
}
