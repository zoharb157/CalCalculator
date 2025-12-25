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
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(weekDays) { day in
                WeekDayItem(day: day, onTap: {
                    onDaySelected?(day.date)
                })
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

struct WeekDayItem: View {
    let day: WeekDay
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 6) {
            // Day name
            Text(day.dayName)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(day.isSelected ? .white : (day.isToday ? .primary : .secondary))
            
            // Circular progress
            ZStack {
                if day.isDotted {
                    // Dotted background circle for days with no meals
                    Circle()
                        .strokeBorder(day.isSelected ? Color.white.opacity(0.6) : Color.gray, style: StrokeStyle(lineWidth: 3, dash: [4, 3]))
                } else {
                    // Background circle
                    Circle()
                        .stroke(day.isSelected ? Color.white.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 3)
                    
                    // Progress circle
                    Circle()
                        .trim(from: 0, to: min(day.progress, 1.0))
                        .stroke(day.isSelected ? Color.white : day.progressColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                
                // Day number
                Text("\(day.dayNumber)")
                    .font(.system(size: 12, weight: day.isSelected ? .bold : (day.isToday ? .bold : .medium), design: .rounded))
                    .foregroundColor(day.isSelected ? .white : (day.isToday ? .primary : .secondary))
            }
            .frame(width: 32, height: 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(day.isSelected ? Color.blue : (day.isToday ? Color.blue.opacity(0.1) : Color.clear))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
        let caloriesText = day.hasMeals ? "\(day.caloriesConsumed) calories" : "No meals"
        return "\(dateString), \(caloriesText)"
    }
    
    private var accessibilityHint: String {
        if day.isToday {
            return "Today's progress"
        } else {
            return "Tap to view details for this day"
        }
    }
}

#Preview {
    let calendar = Calendar.current
    let today = Date()
    
    let weekDays = (0..<7).map { offset -> WeekDay in
        let date = calendar.date(byAdding: .day, value: offset - 3, to: today)!
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"
        
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
