//
//  DietSummaryView.swift
//  playground
//
//  Summary view showing diet adherence and off-diet food
//

import SwiftUI
import SwiftData

struct DietSummaryView: View {
    @Query(filter: #Predicate<DietPlan> { $0.isActive == true }) private var activePlans: [DietPlan]
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedDate = Date()
    @State private var adherenceData: DietAdherenceData?
    @State private var isLoading = false
    
    private var dietPlanRepository: DietPlanRepository {
        DietPlanRepository(context: modelContext)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Date picker
                DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .padding()
                    .background(Color(.systemGroupedBackground))
                
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let data = adherenceData {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Completion rate card
                            completionRateCard(data: data)
                            
                            // Scheduled meals section
                            scheduledMealsSection(data: data)
                            
                            // Off-diet section
                            if data.offDietCalories > 0 {
                                offDietSection(data: data)
                            }
                        }
                        .padding()
                    }
                } else {
                    Text("No active diet plans")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Diet Summary")
            .onChange(of: selectedDate) { _, _ in
                loadAdherenceData()
            }
            .task {
                loadAdherenceData()
            }
        }
    }
    
    private func loadAdherenceData() {
        Task {
            isLoading = true
            defer { isLoading = false }
            
            do {
                adherenceData = try dietPlanRepository.getDietAdherence(
                    for: selectedDate,
                    activePlans: activePlans
                )
            } catch {
                print("Failed to load adherence data: \(error)")
            }
        }
    }
    
    @ViewBuilder
    private func completionRateCard(data: DietAdherenceData) -> some View {
        VStack(spacing: 12) {
            Text("Completion Rate")
                .font(.headline)
            
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                
                Circle()
                    .trim(from: 0, to: data.completionRate)
                    .stroke(
                        data.hasPerfectAdherence ? Color.green : Color.orange,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(data.completionRate * 100))%")
                    .font(.system(size: 32, weight: .bold))
            }
            .frame(width: 120, height: 120)
            
            if data.hasPerfectAdherence {
                Label("Perfect Adherence!", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func scheduledMealsSection(data: DietAdherenceData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scheduled Meals")
                .font(.headline)
            
            ForEach(data.scheduledMeals) { meal in
                HStack {
                    Image(systemName: meal.category.icon)
                        .foregroundColor(.accentColor)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(meal.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(meal.formattedTime)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if data.completedMeals.contains(meal.id) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(8)
            }
        }
    }
    
    @ViewBuilder
    private func offDietSection(data: DietAdherenceData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Off-Diet Food")
                .font(.headline)
                .foregroundColor(.orange)
            
            Text("\(data.offDietCalories) calories")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.orange)
            
            Text("\(data.offDietMeals.count) meals logged outside your diet plan")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ForEach(data.offDietMeals) { meal in
                HStack {
                    Text(meal.name)
                    Spacer()
                    Text("\(meal.totalCalories) cal")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    DietSummaryView()
        .modelContainer(for: [DietPlan.self, ScheduledMeal.self, Meal.self])
}

