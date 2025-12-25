//
//  WidgetDataManager.swift
//  CaloriesCalculatorWidgets
//
//  Manages data sharing between main app and widget using App Groups
//

import Foundation
import WidgetKit

/// Manages shared data between the main app and widget extension
final class WidgetDataManager: Sendable {
    
    // MARK: - Constants
    
    static let shared = WidgetDataManager()
    
    private static let appGroupIdentifier = "group.com.calcalculator.shared"
    private static let macroDataKey = "widget.macroNutrients"
    private static let lastUpdatedKey = "widget.lastUpdated"
    private static let isSubscribedKey = "widget.isSubscribed"
    
    // MARK: - Properties
    
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: Self.appGroupIdentifier)
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Loads macro nutrients data from shared UserDefaults
    /// This decodes data saved by MealRepository.syncWidgetData()
    /// Returns placeholder data if no data exists or data is from a different day
    func loadMacroNutrients() -> MacroNutrients {
        guard let defaults = sharedDefaults else {
            debugPrint("WidgetDataManager: Failed to access shared UserDefaults")
            return .empty
        }
        
        // Check if data is from today
        if let lastUpdated = defaults.object(forKey: Self.lastUpdatedKey) as? Date {
            let calendar = Calendar.current
            if !calendar.isDateInToday(lastUpdated) {
                // Data is stale (from a previous day), return empty
                debugPrint("WidgetDataManager: Data is from a previous day, returning empty")
                return .empty
            }
        }
        
        guard let data = defaults.data(forKey: Self.macroDataKey) else {
            debugPrint("WidgetDataManager: No data found in shared UserDefaults")
            return .empty
        }
        
        do {
            let decoder = JSONDecoder()
            // Decode the WidgetMacroData format saved by MealRepository
            let widgetData = try decoder.decode(WidgetMacroDataDTO.self, from: data)
            
            // Convert to MacroNutrients
            return MacroNutrients(
                calories: widgetData.calories,
                protein: widgetData.protein,
                carbs: widgetData.carbs,
                fats: widgetData.fats,
                calorieGoal: widgetData.calorieGoal,
                proteinGoal: widgetData.proteinGoal,
                carbsGoal: widgetData.carbsGoal,
                fatsGoal: widgetData.fatsGoal
            )
        } catch {
            debugPrint("WidgetDataManager: Failed to decode macro data - \(error)")
            return .empty
        }
    }
    
    /// Returns the last time data was updated
    func lastUpdated() -> Date? {
        sharedDefaults?.object(forKey: Self.lastUpdatedKey) as? Date
    }
    
    /// Checks if the data is from today
    func isDataFromToday() -> Bool {
        guard let lastUpdated = lastUpdated() else { return false }
        return Calendar.current.isDateInToday(lastUpdated)
    }
    
    /// Loads subscription status from shared UserDefaults
    /// Returns false by default if no data exists
    func loadIsSubscribed() -> Bool {
        guard let defaults = sharedDefaults else {
            debugPrint("WidgetDataManager: Failed to access shared UserDefaults for subscription status")
            return false
        }
        return defaults.bool(forKey: Self.isSubscribedKey)
    }
    
    /// Saves subscription status to shared UserDefaults (called from main app)
    func saveIsSubscribed(_ isSubscribed: Bool) {
        guard let defaults = sharedDefaults else {
            debugPrint("WidgetDataManager: Failed to access shared UserDefaults to save subscription status")
            return
        }
        defaults.set(isSubscribed, forKey: Self.isSubscribedKey)
        debugPrint("WidgetDataManager: Saved subscription status: \(isSubscribed)")
    }
}

// MARK: - DTO for decoding data from main app

/// Data Transfer Object that matches the format saved by MealRepository.WidgetMacroData
private struct WidgetMacroDataDTO: Codable {
    let calories: Int
    let protein: Int
    let carbs: Int
    let fats: Int
    let calorieGoal: Int
    let proteinGoal: Int
    let carbsGoal: Int
    let fatsGoal: Int
}
