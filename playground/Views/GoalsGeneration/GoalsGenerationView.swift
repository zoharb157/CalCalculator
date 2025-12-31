//
//  GoalsGenerationView.swift
//  playground
//
//  View for generating and displaying personalized nutrition goals
//

import SwiftUI

struct GoalsGenerationView: View {
    @State private var viewModel: GoalsGenerationViewModel
    let onComplete: () -> Void
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    init(onboardingData: [String: Any], onComplete: @escaping () -> Void) {
        self._viewModel = State(initialValue: GoalsGenerationViewModel(onboardingData: onboardingData))
        self.onComplete = onComplete
    }
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return ZStack {
            // Background gradient
            backgroundGradient
            
            VStack(spacing: 0) {
                Spacer()
                
                if viewModel.isGenerating {
                    generatingContent
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                } else if viewModel.isCompleted {
                    completedContent
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity
                        ))
                }
                
                Spacer()
                
                if viewModel.isCompleted {
                    continueButton
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding()
        }
        .onAppear {
            viewModel.startGeneration()
        }
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.blue.opacity(0.1),
                Color.white
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Generating Content
    
    private var generatingContent: some View {
        VStack(spacing: 40) {
            // Animated circles
            AnimatedLoadingView()
                .frame(width: 200, height: 200)
            
            // Status message
            VStack(spacing: 12) {
                Text(localizationManager.localizedString(for: AppStrings.GoalsGeneration.generatingYourPlan))
                    .id("generating-plan-\(localizationManager.currentLanguage)")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(viewModel.currentMessage)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.currentMessage)
                    .contentTransition(.numericText())
            }
        }
    }
    
    // MARK: - Completed Content
    
    private var completedContent: some View {
        VStack(spacing: 32) {
            // Success checkmark
            SuccessCheckmarkView()
                .frame(width: 80, height: 80)
            
            // Title
            VStack(spacing: 8) {
                Text(localizationManager.localizedString(for: AppStrings.GoalsGeneration.yourPersonalizedGoals))
                    .id("personalized-goals-\(localizationManager.currentLanguage)")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(localizationManager.localizedString(for: AppStrings.GoalsGeneration.basedOnProfile))
                    .id("based-on-profile-\(localizationManager.currentLanguage)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Goals cards
            if let goals = viewModel.generatedGoals {
                GoalsCardsView(goals: goals)
            }
        }
    }
    
    // MARK: - Continue Button
    
    private var continueButton: some View {
        Button {
            viewModel.saveAndContinue()
            onComplete()
        } label: {
            Text(localizationManager.localizedString(for: AppStrings.Common.continue_))
                .id("continue-goals-\(localizationManager.currentLanguage)")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .padding(.horizontal)
        .padding(.bottom, 32)
    }
}

// MARK: - Animated Loading View

struct AnimatedLoadingView: View {
    @State private var rotation: Double = 0
    @State private var scale1: CGFloat = 1.0
    @State private var scale2: CGFloat = 0.8
    @State private var scale3: CGFloat = 0.6
    
    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.blue.opacity(0.3), .blue.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 8
                )
                .scaleEffect(scale1)
            
            // Middle ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.blue.opacity(0.5), .blue.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 6
                )
                .scaleEffect(scale2)
            
            // Inner ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.blue, .blue.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 4
                )
                .scaleEffect(scale3)
            
            // Rotating arc
            Circle()
                .trim(from: 0, to: 0.3)
                .stroke(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(rotation))
            
            // Center icon
            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(scale2)
        }
        .onAppear {
            // Continuous rotation
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            
            // Pulsing scales
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                scale1 = 1.05
                scale2 = 0.9
                scale3 = 0.7
            }
        }
    }
}

// MARK: - Success Checkmark View

struct SuccessCheckmarkView: View {
    @State private var isAnimated = false
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.green.opacity(0.2), .green.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(isAnimated ? 1.0 : 0.5)
            
            // Checkmark
            Image(systemName: "checkmark")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.green)
                .scaleEffect(isAnimated ? 1.0 : 0.0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                isAnimated = true
            }
        }
    }
}

// MARK: - Goals Cards View

struct GoalsCardsView: View {
    let goals: GeneratedGoals
    @State private var appearedCards: Set<Int> = []
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        VStack(spacing: 16) {
            // Calories card (main)
            GoalCard(
                title: localizationManager.localizedString(for: AppStrings.Goals.dailyCalories),
                value: "\(goals.calories)",
                unit: "kcal",
                icon: "flame.fill",
                color: .orange,
                isLarge: true
            )
            .opacity(appearedCards.contains(0) ? 1 : 0)
            .offset(y: appearedCards.contains(0) ? 0 : 20)
            
            // Macros row
            HStack(spacing: 12) {
                GoalCard(
                    title: "Protein",
                    value: String(format: "%.0f", goals.proteinG),
                    unit: "g",
                    icon: "fish.fill",
                    color: .red,
                    isLarge: false
                )
                .opacity(appearedCards.contains(1) ? 1 : 0)
                .offset(y: appearedCards.contains(1) ? 0 : 20)
                
                GoalCard(
                    title: "Carbs",
                    value: String(format: "%.0f", goals.carbsG),
                    unit: "g",
                    icon: "leaf.fill",
                    color: .green,
                    isLarge: false
                )
                .opacity(appearedCards.contains(2) ? 1 : 0)
                .offset(y: appearedCards.contains(2) ? 0 : 20)
                
                GoalCard(
                    title: "Fat",
                    value: String(format: "%.0f", goals.fatG),
                    unit: "g",
                    icon: "drop.fill",
                    color: .yellow,
                    isLarge: false
                )
                .opacity(appearedCards.contains(3) ? 1 : 0)
                .offset(y: appearedCards.contains(3) ? 0 : 20)
            }
        }
        .padding(.horizontal)
        .onAppear {
            animateCards()
        }
    }
    
    private func animateCards() {
        // Animate all cards immediately
        for i in 0...3 {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                _ = appearedCards.insert(i)
            }
        }
    }
}

// MARK: - Goal Card

struct GoalCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    let isLarge: Bool
    
    var body: some View {
        VStack(spacing: isLarge ? 12 : 8) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: isLarge ? 28 : 20))
                .foregroundStyle(color)
            
            // Value
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(isLarge ? .system(size: 36, weight: .bold, design: .rounded) : .system(size: 24, weight: .bold, design: .rounded))
                
                Text(unit)
                    .font(isLarge ? .subheadline : .caption)
                    .foregroundStyle(.secondary)
            }
            
            // Title
            Text(title)
                .font(isLarge ? .subheadline : .caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, isLarge ? 24 : 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.background)
                .shadow(color: color.opacity(0.2), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Previews

#Preview("Generating") {
    GoalsGenerationView(
        onboardingData: ["goal": "lose_weight", "activity_level": "moderate"],
        onComplete: {}
    )
}

#Preview("Animated Loading") {
    AnimatedLoadingView()
        .frame(width: 200, height: 200)
        .padding()
}

#Preview("Success Checkmark") {
    SuccessCheckmarkView()
        .frame(width: 80, height: 80)
        .padding()
}

#Preview("Goals Cards") {
    GoalsCardsView(
        goals: GeneratedGoals(
            calories: 2000,
            proteinG: 150,
            carbsG: 200,
            fatG: 67
        )
    )
    .padding()
}

#Preview("Goal Card - Large") {
    GoalCard(
        title: "Daily Calories",
        value: "2000",
        unit: "kcal",
        icon: "flame.fill",
        color: .orange,
        isLarge: true
    )
    .padding()
}

#Preview("Goal Card - Small") {
    HStack(spacing: 12) {
        GoalCard(
            title: "Protein",
            value: "150",
            unit: "g",
            icon: "fish.fill",
            color: .red,
            isLarge: false
        )
        GoalCard(
            title: "Carbs",
            value: "200",
            unit: "g",
            icon: "leaf.fill",
            color: .green,
            isLarge: false
        )
        GoalCard(
            title: "Fat",
            value: "67",
            unit: "g",
            icon: "drop.fill",
            color: .yellow,
            isLarge: false
        )
    }
    .padding()
}
