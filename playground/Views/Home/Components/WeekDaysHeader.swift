//
//  HistoryView.swift
//  playground
//
//  CalAI Clone - Meal history view
//

import SwiftUI

struct WeekDaysHeader: View {
    let weekDays: [WeekDay]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(weekDays) { day in
                WeekDayItem(day: day)
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
    
    var body: some View {
        VStack(spacing: 6) {
            // Day name
            Text(day.dayName)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(day.isToday ? .primary : .secondary)
            
            // Circular progress
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 3)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: min(day.progress, 1.0))
                    .stroke(day.progressColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                // Day number
                Text("\(day.dayNumber)")
                    .font(.system(size: 12, weight: day.isToday ? .bold : .medium, design: .rounded))
                    .foregroundColor(day.isToday ? .primary : .secondary)
            }
            .frame(width: 32, height: 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(day.isToday ? Color.blue.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
        
        return WeekDay(
            date: date,
            dayName: dayFormatter.string(from: date),
            dayNumber: calendar.component(.day, from: date),
            isToday: isToday,
            progress: progress,
            summary: DaySummary(
                totalCalories: Int(progress * 2000),
                totalProteinG: progress * 120,
                totalCarbsG: progress * 200,
                totalFatG: progress * 60,
                mealCount: Int(progress * 4)
            )
        )
    }
    
    return WeekDaysHeader(weekDays: weekDays)
        .padding()
}
