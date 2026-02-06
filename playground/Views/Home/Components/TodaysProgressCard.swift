//
//  HistoryView.swift
//  playground
//
//  CalAI Clone - Meal history view
//

import SwiftUI
import UIKit

struct TodaysProgressCard: View {
    let summary: DaySummary?
    let calorieGoal: Int
    let remainingCalories: Int
    let progress: Double
    var goalAdjustment: String? = nil
    var burnedCalories: Int = 0 // Calories burned from exercise
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    private var consumed: Int {
        summary?.totalCalories ?? 0
    }
    
    private var netCalories: Int {
        consumed - burnedCalories
    }
    
    private var isSmallScreen: Bool {
        UIScreen.main.bounds.width < 375 // iPhone SE and similar small devices
    }
    
    private var calorieFontSize: CGFloat {
        isSmallScreen ? 32 : 42
    }
    
    private var progressSize: CGFloat {
        isSmallScreen ? 80 : 100
    }
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return VStack(spacing: isSmallScreen ? 16 : 24) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(remainingCalories.formattedCalories)
                        .font(.system(size: isSmallScreen ? 36 : 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: remainingCalories)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                    
                    Text(localizationManager.localizedString(for: AppStrings.Home.caloriesLeft))
                        .font(isSmallScreen ? .caption : .subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                CircularProgressView(progress: progress)
                    .frame(width: isSmallScreen ? 80 : 100, height: isSmallScreen ? 80 : 100)
            }
            .padding(.horizontal, isSmallScreen ? 4 : 8)
            
            Rectangle()
                .fill(Color.primary.opacity(0.05))
                .frame(height: 1)
            
            HStack(spacing: 0) {
                VStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                        Text(localizationManager.localizedString(for: AppStrings.Home.gained))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(consumed.formattedCalories)
                        .font(.system(size: isSmallScreen ? 18 : 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity)
                
                Rectangle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 1, height: 30)
                
                VStack(spacing: 6) {
                    Text(localizationManager.localizedString(for: AppStrings.Home.net))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                    Text(netCalories.formattedCalories)
                        .font(.system(size: isSmallScreen ? 18 : 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(netCalories >= 0 ? .orange : .green)
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity)
                
                Rectangle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 1, height: 30)
                
                VStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Text(localizationManager.localizedString(for: AppStrings.Home.lost))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                    }
                    Text(burnedCalories.formattedCalories)
                        .font(.system(size: isSmallScreen ? 18 : 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 4)
        }
        .padding(isSmallScreen ? 16 : 24)
        .cardStyle(background: Color(.secondarySystemGroupedBackground))
    }
}

#Preview("Calories Remaining") {
    TodaysProgressCard(
        summary: DaySummary(
            totalCalories: 1500,
            totalProteinG: 85.5,
            totalCarbsG: 180.2,
            totalFatG: 45.8,
            mealCount: 3
        ),
        calorieGoal: 2000,
        remainingCalories: 500,
        progress: 0.75,
        burnedCalories: 300
    )
    .padding()
}

#Preview("Goal Reached") {
    TodaysProgressCard(
        summary: DaySummary(
            totalCalories: 2000,
            totalProteinG: 120,
            totalCarbsG: 200,
            totalFatG: 60,
            mealCount: 4
        ),
        calorieGoal: 2000,
        remainingCalories: 0,
        progress: 1.0,
        burnedCalories: 200
    )
    .padding()
}

#Preview("Over Goal") {
    TodaysProgressCard(
        summary: DaySummary(
            totalCalories: 2300,
            totalProteinG: 140,
            totalCarbsG: 230,
            totalFatG: 70,
            mealCount: 5
        ),
        calorieGoal: 2000,
        remainingCalories: -300,
        progress: 1.15,
        burnedCalories: 100
    )
    .padding()
}
