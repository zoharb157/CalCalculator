//
//  HistoryViewModel.swift
//  playground
//
//  View model for HistoryView
//

import SwiftUI
import SwiftData

/// View model managing history screen state and actions
@MainActor
@Observable
final class HistoryViewModel {
    // MARK: - Dependencies
    private let repository: MealRepository
    
    // MARK: - State
    var allDaySummaries: [DaySummary] = []
    var isLoading = false
    var error: Error?
    
    // MARK: - Error State
    var showError = false
    var errorMessage: String?
    
    init(repository: MealRepository) {
        self.repository = repository
    }
    
    // MARK: - Data Loading
    
    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            allDaySummaries = try repository.fetchAllDaySummaries()
        } catch {
            self.error = error
            self.errorMessage = error.localizedDescription
            self.showError = true
        }
    }
    
    func fetchMeals(for date: Date) async -> [Meal] {
        do {
            return try repository.fetchMeals(for: date)
        } catch {
            self.error = error
            return []
        }
    }
}
