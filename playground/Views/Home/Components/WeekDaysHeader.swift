//
//  WeekDaysHeader.swift
//  playground
//
//  Week days selector with progress rings
//

import SwiftUI

// MARK: - Ring Colors (matching RingColorsExplainedView)
/// Ring color logic based on calories over goal:
/// - Green: Less than 100 calories over goal (on track)
/// - Yellow: 100-200 calories over goal (moderately over)
/// - Red: More than 200 calories over goal (significantly over)
/// - Gray (dotted): No meals logged that day

struct WeekDaysHeader: View {
    let weekDays: [WeekDay]
    var onDaySelected: ((Date) -> Void)? = nil
    @State private var hasAppeared = false
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(weekDays) { day in
                        WeekDayItem(
                            day: day,
                            onTap: {
                                onDaySelected?(day.date)
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    proxy.scrollTo(day.id, anchor: .center)
                                }
                            }
                        )
                        .id(day.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .onAppear {
                if !hasAppeared {
                    hasAppeared = true
                    // Scroll to today or selected day on first appear
                    if let selectedDay = weekDays.first(where: { $0.isSelected }) ?? weekDays.first(where: { $0.isToday }) {
                        DispatchQueue.main.async {
                            proxy.scrollTo(selectedDay.id, anchor: .center)
                        }
                    }
                }
            }
            .onChange(of: weekDays.first(where: { $0.isSelected })?.id) { _, newValue in
                if let selectedId = newValue {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        proxy.scrollTo(selectedId, anchor: .center)
                    }
                }
            }
        }
    }
}

// MARK: - WeekDayItem

struct WeekDayItem: View {
    let day: WeekDay
    var onTap: (() -> Void)? = nil
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    // Design constants matching RingColorsExplainedView
    private let ringSize: CGFloat = 40
    private let ringLineWidth: CGFloat = 2
    private let selectedLineWidth: CGFloat = 3
    
    /// Ring color based on calories over goal (matching RingColorsExplainedView)
    private var ringColor: Color {
        if !day.hasMeals {
            return .gray
        }
        
        switch day.caloriesOverGoal {
        case 0..<100:
            return .green
        case 100...200:
            return .yellow
        default:
            return .red
        }
    }
    
    var body: some View {
        VStack(spacing: 6) {
            // Day name
            Text(day.dayName.uppercased())
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(dayNameColor)
            
            // Ring with date - matching DateRing from RingColorsExplainedView
            ZStack {
                if day.isDotted {
                    // Dotted ring for days with no meals
                    Circle()
                        .strokeBorder(
                            Color.gray.opacity(0.5),
                            style: StrokeStyle(lineWidth: ringLineWidth, dash: [5])
                        )
                        .frame(width: ringSize, height: ringSize)
                } else {
                    // Progress ring with color
                    ZStack {
                        // Background track
                        Circle()
                            .stroke(Color.gray.opacity(0.15), lineWidth: ringLineWidth)
                            .frame(width: ringSize, height: ringSize)
                        
                        // Progress arc
                        Circle()
                            .trim(from: 0, to: min(day.progress, 1.0))
                            .stroke(
                                ringColor,
                                style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: ringSize, height: ringSize)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: day.progress)
                    }
                }
                                
                // Day number
                Text("\(day.dayNumber)")
                    .font(.headline)
                    .fontWeight(day.isSelected || day.isToday ? .bold : .medium)
                    .foregroundColor(dayNumberColor)
            }
            .frame(width: ringSize + 8, height: ringSize + 8)
        }
        .frame(width: 48)
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.shared.impact(.light)
            onTap?()
        }
        .scaleEffect(day.isSelected ? 1.08 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: day.isSelected)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(day.isSelected ? .isSelected : .isButton)
    }
    
    private var dayNameColor: Color {
        if day.isSelected {
            return .accentColor
        } else if day.isToday {
            return .primary
        } else {
            return .secondary
        }
    }
    
    private var dayNumberColor: Color {
        if day.isToday {
            return .accentColor
        } else {
            return .primary
        }
    }
    
    private var accessibilityLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateString = formatter.string(from: day.date)
        
        var status = ""
        if day.isToday {
            status = localizationManager.localizedString(for: AppStrings.Home.today) + ", "
        }
        
        let caloriesText = day.hasMeals 
            ? "\(day.caloriesConsumed) \(localizationManager.localizedString(for: AppStrings.History.caloriesLabel))" 
            : localizationManager.localizedString(for: AppStrings.History.noMeals)
        
        return "\(status)\(dateString), \(caloriesText)"
    }
    
    private var accessibilityHint: String {
        if day.isSelected {
            return ""
        } else {
            return localizationManager.localizedString(for: AppStrings.Common.tapToViewDetails)
        }
    }
}

// MARK: - Preview

#Preview {
    let calendar = Calendar.current
    let today = Date()
    
    let weekDays = (0..<7).map { offset -> WeekDay in
        let date = calendar.date(byAdding: .day, value: offset - 3, to: today) ?? today
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"
        dayFormatter.locale = Locale(identifier: LocalizationManager.shared.currentLanguage)
        
        let isToday = calendar.isDateInToday(date)
        let progress = Double(offset) / 7.0
        let calorieGoal = 1800
        // Simulate various calorie over states for preview
        let caloriesConsumed: Int
        switch offset {
        case 0: caloriesConsumed = 1750 // Under goal (green)
        case 1: caloriesConsumed = 0    // No meals (dotted)
        case 2: caloriesConsumed = 1900 // 100 over (yellow)
        case 3: caloriesConsumed = 2100 // 300 over (red)
        case 4: caloriesConsumed = 1850 // 50 over (green)
        case 5: caloriesConsumed = 1980 // 180 over (yellow)
        default: caloriesConsumed = 1600 // Under goal (green)
        }
        let hasMeals = caloriesConsumed > 0
        
        return WeekDay(
            date: date,
            dayName: dayFormatter.string(from: date),
            dayNumber: calendar.component(.day, from: date),
            isToday: isToday,
            isSelected: isToday,
            progress: Double(caloriesConsumed) / Double(calorieGoal),
            summary: DaySummary(
                totalCalories: caloriesConsumed,
                totalProteinG: progress * 120,
                totalCarbsG: progress * 200,
                totalFatG: progress * 60,
                mealCount: hasMeals ? Int(progress * 4) + 1 : 0
            ),
            caloriesConsumed: caloriesConsumed,
            calorieGoal: calorieGoal,
            hasMeals: hasMeals
        )
    }
    
    VStack(spacing: 24) {
        // Week header in a card style
        VStack(spacing: 0) {
            WeekDaysHeader(weekDays: weekDays)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
        
        // Color legend
        VStack(alignment: .leading, spacing: 12) {
            Text("Ring Colors:")
                .font(.headline)
            
            HStack(spacing: 20) {
                legendItem(color: .green, text: "On Track")
                legendItem(color: .yellow, text: "100-200 Over")
                legendItem(color: .red, text: ">200 Over")
            }
            
            HStack(spacing: 8) {
                Circle()
                    .strokeBorder(Color.gray, style: StrokeStyle(lineWidth: 2, dash: [5]))
                    .frame(width: 16, height: 16)
                Text("No Meals")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        
        Spacer()
    }
    .background(Color(.systemGroupedBackground))
}

@ViewBuilder
private func legendItem(color: Color, text: String) -> some View {
    HStack(spacing: 6) {
        Circle()
            .fill(color)
            .frame(width: 12, height: 12)
        Text(text)
            .font(.caption)
            .foregroundColor(.secondary)
    }
}
