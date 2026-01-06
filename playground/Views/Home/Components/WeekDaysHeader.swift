//
//  HistoryView.swift
//  playground
//
//  CalAI Clone - Meal history view
//

import SwiftUI

struct WeekDaysHeader: View {
    let weekDays: [WeekDay]
    var onDaySelected: ((Date) -> Void)? = nil
    @State private var hasAppeared = false
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(weekDays) { day in
                        WeekDayItem(day: day, onTap: {
                            onDaySelected?(day.date)
                            // Scroll to selected day
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(day.id, anchor: .center)
                            }
                        })
                        .id(day.id)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .onAppear {
                if !hasAppeared {
                    hasAppeared = true
                    // Scroll to today or selected day on first appear
                    if let selectedDay = weekDays.first(where: { $0.isSelected || $0.isToday }) {
                        // Use next run loop to ensure layout is complete
                        DispatchQueue.main.async {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(selectedDay.id, anchor: .center)
                            }
                        }
                    }
                }
            }
            .onChange(of: weekDays.first(where: { $0.isSelected })?.id) { _, newValue in
                // Scroll to newly selected day
                if let selectedId = newValue {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(selectedId, anchor: .center)
                    }
                }
            }
        }
    }
}

struct WeekDayItem: View {
    let day: WeekDay
    var onTap: (() -> Void)? = nil
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        VStack(spacing: 6) {
            // Day name (abbreviated)
            Text(day.dayName)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(day.isSelected ? .white : (day.isToday ? .primary : .secondary))
            
            // Circular date indicator (matching reference design)
            ZStack {
                // Background circle - white when selected, clear otherwise
                Circle()
                    .fill(day.isSelected ? Color.white : Color.clear)
                    .frame(width: 36, height: 36)
                
                // Border circle
                if day.isDotted {
                    // Dotted border for days with no meals
                    Circle()
                        .strokeBorder(day.isSelected ? Color.clear : Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [3, 2]))
                        .frame(width: 36, height: 36)
                } else {
                    // Solid border - thicker and more visible for today
                    Circle()
                        .strokeBorder(
                            day.isSelected ? Color.clear : (day.isToday ? Color.blue : Color.gray.opacity(0.3)),
                            lineWidth: day.isToday ? 3 : 2
                        )
                        .frame(width: 36, height: 36)
                    
                    // Progress circle (only show if not selected)
                    if !day.isSelected {
                        Circle()
                            .trim(from: 0, to: min(day.progress, 1.0))
                            .stroke(day.progressColor, style: StrokeStyle(lineWidth: day.isToday ? 3 : 2, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 36, height: 36)
                    }
                }
                
                // Day number - bolder for today
                Text("\(day.dayNumber)")
                    .font(.system(size: 14, weight: day.isSelected ? .bold : (day.isToday ? .bold : .regular), design: .rounded))
                    .foregroundColor(day.isSelected ? .black : (day.isToday ? .blue : .secondary))
            }
            // Add subtle background highlight for today when not selected
            .background(
                day.isToday && !day.isSelected
                    ? Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 40, height: 40)
                    : nil
            )
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.shared.impact(.light)
            onTap?()
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(day.isToday ? [] : .isButton)
    }
    
    private var accessibilityLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateString = formatter.string(from: day.date)
        let caloriesText = day.hasMeals ? "\(day.caloriesConsumed) \(localizationManager.localizedString(for: AppStrings.History.caloriesLabel))" : localizationManager.localizedString(for: AppStrings.History.noMeals)
        return "\(dateString), \(caloriesText)"
    }
    
    private var accessibilityHint: String {
        if day.isToday {
            return localizationManager.localizedString(for: AppStrings.Home.today) + " " + localizationManager.localizedString(for: AppStrings.Progress.title.lowercased())
        } else {
            return localizationManager.localizedString(for: AppStrings.Common.tapToViewDetails)
        }
    }
}

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
        let caloriesConsumed = Int(progress * 2000)
        let calorieGoal = 1800
        let hasMeals = offset != 1 // Day at offset 1 has no meals (for testing dotted ring)
        
        return WeekDay(
            date: date,
            dayName: dayFormatter.string(from: date),
            dayNumber: calendar.component(.day, from: date),
            isToday: isToday,
            isSelected: isToday, // In preview, selected day is today
            progress: progress,
            summary: DaySummary(
                totalCalories: caloriesConsumed,
                totalProteinG: progress * 120,
                totalCarbsG: progress * 200,
                totalFatG: progress * 60,
                mealCount: hasMeals ? Int(progress * 4) : 0
            ),
            caloriesConsumed: caloriesConsumed,
            calorieGoal: calorieGoal,
            hasMeals: hasMeals
        )
    }
    
    WeekDaysHeader(weekDays: weekDays)
        .padding()
}
