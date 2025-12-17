//
//  HistoryView.swift
//  playground
//
//  CalAI Clone - Meal history view with modern UI
//

import SwiftUI

struct HistoryView: View {
    @Bindable var viewModel: HistoryViewModel
    let repository: MealRepository
    
    @State private var selectedDate: SelectedDate?
    
    var body: some View {
        NavigationStack {
            content
                .navigationTitle("History")
                .background(Color(.systemGroupedBackground))
                .refreshable {
                    await viewModel.loadData()
                }
                .fullScreenCover(item: $selectedDate) { selected in
                    MealsListSheet(
                        selectedDate: selected.date,
                        repository: repository,
                        onDismiss: {
                            selectedDate = nil
                        }
                    )
                }
                .task {
                    await viewModel.loadData()
                }
        }
    }
    
    // MARK: - Private Views
    
    @ViewBuilder
    private var content: some View {
        if viewModel.allDaySummaries.isEmpty {
            emptyStateView
        } else {
            historyList
        }
    }
    
    private var historyList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.allDaySummaries, id: \.id) { summary in
                    DaySummaryCard(summary: summary)
                        .onTapGesture {
                            selectedDate = SelectedDate(date: summary.date)
                        }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text("No History Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Your meal history will appear here\nonce you start tracking")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Day Summary Card

struct DaySummaryCard: View {
    let summary: DaySummary
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with date
            headerSection
            
            Divider()
                .padding(.horizontal)
            
            // Content
            contentSection
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(dayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(dateString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Meal count badge
            HStack(spacing: 4) {
                Image(systemName: "fork.knife")
                    .font(.caption)
                Text("\(summary.mealCount)")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(.green)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.green.opacity(0.15))
            .clipShape(Capsule())
        }
        .padding()
    }
    
    private var contentSection: some View {
        HStack(spacing: 0) {
            // Calories - Primary focus
            caloriesSection
            
            // Vertical divider
            Rectangle()
                .fill(Color(.separator))
                .frame(width: 1)
                .padding(.vertical, 12)
            
            // Macros
            macrosSection
        }
        .padding(.vertical, 12)
    }
    
    private var caloriesSection: some View {
        VStack(spacing: 4) {
            Text("\(summary.totalCalories)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text("calories")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var macrosSection: some View {
        HStack(spacing: 16) {
            MacroPill(value: summary.totalProteinG, label: "Protein", color: .proteinColor)
            MacroPill(value: summary.totalCarbsG, label: "Carbs", color: .carbsColor)
            MacroPill(value: summary.totalFatG, label: "Fat", color: .fatColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
    }
    
    // MARK: - Helper Properties
    
    private var dayName: String {
        if Calendar.current.isDateInToday(summary.date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(summary.date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: summary.date)
        }
    }
    
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: summary.date)
    }
}

// MARK: - Macro Pill

struct MacroPill: View {
    let value: Double
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(Int(value))g")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Helper Types

struct SelectedDate: Identifiable {
    let id = UUID()
    let date: Date
}

#Preview {
    let persistence = PersistenceController.shared
    let repository = MealRepository(context: persistence.mainContext)
    let viewModel = HistoryViewModel(repository: repository)
    
    HistoryView(viewModel: viewModel, repository: repository)
}
