//
//  GoalsGenerationViewModel.swift
//  playground
//
//  ViewModel for the goals generation flow
//

import Foundation
import SwiftUI

/// Represents the current state of goals generation
enum GoalsGenerationState: Equatable {
    case generating
    case completed(GeneratedGoals)
    case error(String)
}

/// ViewModel for managing the goals generation flow
@MainActor
@Observable
final class GoalsGenerationViewModel {
    // MARK: - Properties
    
    private(set) var state: GoalsGenerationState = .generating
    private(set) var currentAnimationPhase: Int = 0
    private(set) var animationMessages: [String] = [
        "Analyzing your profile...",
        "Calculating your metabolism...",
        "Determining optimal macros...",
        "Personalizing your goals..."
    ]
    
    var currentMessage: String {
        guard currentAnimationPhase < animationMessages.count else {
            return animationMessages.last ?? ""
        }
        return animationMessages[currentAnimationPhase]
    }
    
    var isGenerating: Bool {
        if case .generating = state { return true }
        return false
    }
    
    var isCompleted: Bool {
        if case .completed = state { return true }
        return false
    }
    
    var generatedGoals: GeneratedGoals? {
        if case .completed(let goals) = state { return goals }
        return nil
    }
    
    private let repository: GoalsRepository
    private let onboardingData: [String: Any]
    private nonisolated(unsafe) var animationTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init(onboardingData: [String: Any], repository: GoalsRepository = .shared) {
        self.onboardingData = onboardingData
        self.repository = repository
    }
    
    deinit {
        animationTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Start generating goals
    func startGeneration() {
        state = .generating
        currentAnimationPhase = 0
        
        // Start animation cycle
        startAnimationCycle()
        
        // Start actual generation
        Task {
            do {
                let goals = try await repository.generateGoals(from: onboardingData)
                
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    state = .completed(goals)
                }
            } catch {
                withAnimation {
                    state = .error(error.localizedDescription)
                }
            }
        }
    }
    
    /// Save the generated goals and complete onboarding
    func saveAndContinue() {
        guard let goals = generatedGoals else { return }
        
        // Save goals to UserDefaults
        repository.saveGoals(goals)
        
        // Mark onboarding as complete
        UserSettings.shared.completeOnboarding()
    }
    
    // MARK: - Private Methods
    
    private func startAnimationCycle() {
        animationTask?.cancel()
        // Animation cycle removed - animation will be driven by actual generation progress
        // If animation is needed, it should be tied to actual progress updates
    }
}
