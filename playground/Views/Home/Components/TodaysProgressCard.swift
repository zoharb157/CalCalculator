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
        
        return VStack(spacing: isSmallScreen ? 12 : 16) {
            // Top section - Calories gained vs lost
            HStack(spacing: isSmallScreen ? 12 : 20) {
                // Calories Gained (Consumed)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text(localizationManager.localizedString(for: AppStrings.Home.gained))
                            .font(isSmallScreen ? .caption2 : .caption)
                            
                            .foregroundColor(.secondary)
                    }
                    Text("\(consumed)")
                        .font(.system(size: isSmallScreen ? 24 : 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: consumed)
                }
                
                Spacer()
                
                // Net Calories (Consumed - Burned)
                VStack(alignment: .center, spacing: 4) {
                    Text(localizationManager.localizedString(for: AppStrings.Home.net))
                        .font(isSmallScreen ? .caption2 : .caption)
                        .foregroundColor(.secondary)
                        
                    Text("\(netCalories)")
                        .font(.system(size: isSmallScreen ? 28 : 36, weight: .bold, design: .rounded))
                        .foregroundColor(netCalories >= 0 ? .orange : .green)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: netCalories)
                }
                
                Spacer()
                
                // Calories Lost (Burned)
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(localizationManager.localizedString(for: AppStrings.Home.lost))
                            .font(isSmallScreen ? .caption2 : .caption)
                            
                            .foregroundColor(.secondary)
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    Text("\(burnedCalories)")
                        .font(.system(size: isSmallScreen ? 24 : 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: burnedCalories)
                }
            }
            
            // Bottom section - Remaining calories and progress
            HStack(spacing: isSmallScreen ? 12 : 20) {
                // Left side - Remaining calories
                VStack(alignment: .leading, spacing: isSmallScreen ? 4 : 6) {
                    Text("\(remainingCalories)")
                        .font(.system(size: isSmallScreen ? 28 : 36, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: remainingCalories)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                    
                    Text(localizationManager.localizedString(for: AppStrings.Home.caloriesLeft))
                        .font(isSmallScreen ? .caption : .subheadline)
                        .foregroundColor(.secondary)
                        .minimumScaleFactor(0.9)
                        .lineLimit(1)
                        
                }
                
                Spacer(minLength: isSmallScreen ? 4 : 8)
                
                // Right side - Circular progress
                CircularProgressView(progress: progress)
                    .frame(width: isSmallScreen ? 70 : 90, height: isSmallScreen ? 70 : 90)
            }
        }
        .padding(isSmallScreen ? 12 : 16)
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
