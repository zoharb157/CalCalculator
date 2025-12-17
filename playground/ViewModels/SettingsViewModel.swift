//
//  SettingsViewModel.swift
//  playground
//
//  View model for SettingsView
//

import SwiftUI
import SwiftData

/// View model managing settings screen state and actions
@MainActor
@Observable
final class SettingsViewModel {
    // MARK: - Dependencies
    private let repository: MealRepository
    private let imageStorage: ImageStorage
    
    // MARK: - State
    var isLoading = false
    var error: Error?
    
    // MARK: - Error State
    var showError = false
    var errorMessage: String?
    
    init(
        repository: MealRepository,
        imageStorage: ImageStorage = .shared
    ) {
        self.repository = repository
        self.imageStorage = imageStorage
    }
    
    // MARK: - Data Management
    
    func exportData() async -> Data? {
        do {
            return try repository.exportAllMeals()
        } catch {
            self.error = error
            self.errorMessage = error.localizedDescription
            self.showError = true
            return nil
        }
    }
    
    func deleteAllData() async {
        do {
            try repository.deleteAllData()
            try imageStorage.deleteAllImages()
            
            HapticManager.shared.notification(.success)
        } catch {
            self.error = error
            self.errorMessage = error.localizedDescription
            self.showError = true
            HapticManager.shared.notification(.error)
        }
    }
}
