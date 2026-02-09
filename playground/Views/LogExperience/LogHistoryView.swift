//
//  LogHistoryView.swift
//  playground
//
//  Combined view showing meal and exercise logs for a day
//

import SwiftData
import SwiftUI

/// Represents a unified log entry (either meal or exercise)
enum LogEntry: Identifiable {
    case meal(Meal)
    case exercise(Exercise)

    var id: UUID {
        switch self {
        case .meal(let meal): return meal.id
        case .exercise(let exercise): return exercise.id
        }
    }

    var timestamp: Date {
        switch self {
        case .meal(let meal): return meal.timestamp
        case .exercise(let exercise): return exercise.date
        }
    }

    var calories: Int {
        switch self {
        case .meal(let meal): return meal.totalCalories
        case .exercise(let exercise): return exercise.calories
        }
    }

    var isExercise: Bool {
        if case .exercise = self { return true }
        return false
    }
}

struct LogHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var localizationManager = LocalizationManager.shared

    let repository: MealRepository
    let selectedDate: Date

    @State private var meals: [Meal] = []
    @State private var exercises: [Exercise] = []
    @State private var isLoading = true
    @State private var showingDeleteConfirmation = false
    @State private var itemToDelete: LogEntry?

    init(repository: MealRepository, selectedDate: Date = Date()) {
        self.repository = repository
        self.selectedDate = selectedDate
    }

    private var allEntries: [LogEntry] {
        let mealEntries = meals.map { LogEntry.meal($0) }
        let exerciseEntries = exercises.map { LogEntry.exercise($0) }
        // Sort by timestamp descending (newest first) to show most recent activities at the top
        return (mealEntries + exerciseEntries).sorted { $0.timestamp > $1.timestamp }
    }

    private var totalCaloriesConsumed: Int {
        meals.reduce(0) { $0 + $1.totalCalories }
    }

    private var totalCaloriesBurned: Int {
        exercises.reduce(0) { $0 + $1.calories }
    }

    private var netCalories: Int {
        totalCaloriesConsumed - totalCaloriesBurned
    }

    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return NavigationStack {
            VStack(spacing: 0) {
                // Summary header
                summaryHeader

                // Timeline list
                if isLoading {
                    loadingView
                } else if allEntries.isEmpty {
                    emptyStateView
                } else {
                    timelineList
                }
            }
            .navigationTitle(dateTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .task {
                await loadData()
            }
            .confirmationDialog(
                localizationManager.localizedString(for: AppStrings.History.deleteEntry),
                isPresented: $showingDeleteConfirmation,
                presenting: itemToDelete
            ) { entry in
                Button(localizationManager.localizedString(for: AppStrings.Common.delete), role: .destructive) {
                    deleteEntry(entry)
                }
                Button(localizationManager.localizedString(for: AppStrings.Common.cancel), role: .cancel) {}
            } message: { entry in
                switch entry {
                case .meal(let meal):
                    Text(String(format: localizationManager.localizedString(for: AppStrings.History.deleteMealQuestion), meal.name))
                case .exercise(let exercise):
                    Text(String(format: localizationManager.localizedString(for: AppStrings.History.deleteExerciseQuestion), exercise.type.displayName))
                        .id("delete-exercise-\(localizationManager.currentLanguage)")
                }
            }
        }
    }

    // MARK: - Summary Header

    private var summaryHeader: some View {
        let isSmallScreen = UIScreen.main.bounds.width < 375 // iPhone SE and similar small devices
        
        return VStack(spacing: isSmallScreen ? 12 : 16) {
            HStack(spacing: isSmallScreen ? 8 : 32) {
                // Consumed
                VStack(spacing: 4) {
                    HStack(spacing: isSmallScreen ? 2 : 4) {
                        Image(systemName: "flame.fill")
                            .font(isSmallScreen ? .caption2 : .caption)
                            .foregroundColor(.orange)
                        Text("\(totalCaloriesConsumed)")
                            .font(.system(size: isSmallScreen ? 18 : 22, weight: .bold, design: .rounded))
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                    }
                    Text(localizationManager.localizedString(for: AppStrings.Home.consumed))
                        .id("consumed-\(localizationManager.currentLanguage)")
                        .font(isSmallScreen ? .caption2 : .caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                // Divider
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1, height: isSmallScreen ? 30 : 40)

                // Burned
                VStack(spacing: 4) {
                    HStack(spacing: isSmallScreen ? 2 : 4) {
                        Image(systemName: "bolt.fill")
                            .font(isSmallScreen ? .caption2 : .caption)
                            .foregroundColor(.green)
                        Text("\(totalCaloriesBurned)")
                            .font(.system(size: isSmallScreen ? 18 : 22, weight: .bold, design: .rounded))
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                    }
                    Text(localizationManager.localizedString(for: AppStrings.Home.burned))
                        .id("burned-\(localizationManager.currentLanguage)")
                        .font(isSmallScreen ? .caption2 : .caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                // Divider
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1, height: isSmallScreen ? 30 : 40)

                // Net
                VStack(spacing: 4) {
                    HStack(spacing: isSmallScreen ? 2 : 4) {
                        Image(systemName: "equal.circle.fill")
                            .font(isSmallScreen ? .caption2 : .caption)
                            .foregroundColor(.blue)
                        Text("\(netCalories)")
                            .font(.system(size: isSmallScreen ? 16 : 22, weight: .bold, design: .rounded))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                    }
                    Text(localizationManager.localizedString(for: AppStrings.Home.net))
                        .id("net-label-\(localizationManager.currentLanguage)")
                        .font(isSmallScreen ? .caption2 : .caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            // Entry count
            HStack(spacing: 16) {
                Label("\(meals.count) meals", systemImage: "fork.knife")
                Label("\(exercises.count) exercises", systemImage: "figure.run")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
    }

    // MARK: - Timeline List

    private var timelineList: some View {
        List {
            ForEach(allEntries) { entry in
                LogEntryRow(entry: entry)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            itemToDelete = entry
                            showingDeleteConfirmation = true
                        } label: {
                            Label(localizationManager.localizedString(for: AppStrings.Common.delete), systemImage: "trash")
                                .id("delete-label-\(localizationManager.currentLanguage)")
                        }
                    }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
            Text(localizationManager.localizedString(for: "Loading logs..."))
                .id("loading-logs-\(localizationManager.currentLanguage)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text(localizationManager.localizedString(for: AppStrings.History.noLogsYet))
                .id("no-logs-\(localizationManager.currentLanguage)")
                .font(.title2)
                .fontWeight(.semibold)

            Text(localizationManager.localizedString(for: AppStrings.History.startLoggingMeals))
                .id("start-logging-\(localizationManager.currentLanguage)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Date Title

    private var dateTitle: String {
        if Calendar.current.isDateInToday(selectedDate) {
            return localizationManager.localizedString(for: AppStrings.Home.today)
        } else if Calendar.current.isDateInYesterday(selectedDate) {
            return localizationManager.localizedString(for: AppStrings.Home.yesterday)
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: selectedDate)
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            meals = try repository.fetchMeals(for: selectedDate)
            exercises = try repository.fetchExercises(for: selectedDate)
        } catch {
            print("Error loading log history: \(error)")
        }
    }

    // MARK: - Delete Entry

    private func deleteEntry(_ entry: LogEntry) {
        do {
            switch entry {
            case .meal(let meal):
                Pixel.track("food_deleted", type: .interaction)
                try repository.deleteMeal(meal)
                meals.removeAll { $0.id == meal.id }
            case .exercise(let exercise):
                Pixel.track("exercise_deleted", type: .interaction)
                try repository.deleteExercise(exercise)
                exercises.removeAll { $0.id == exercise.id }
                // Notify that an exercise was deleted so HomeViewModel can refresh burned calories
                NotificationCenter.default.post(name: .exerciseDeleted, object: nil)
            }

            HapticManager.shared.notification(.success)
        } catch {
            print("Error deleting entry: \(error)")
            HapticManager.shared.notification(.error)
        }
    }
}

// MARK: - Log Entry Row

struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(spacing: 12) {
            // Timeline indicator
            VStack(spacing: 4) {
                Text(timeString)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Circle()
                    .fill(entry.isExercise ? Color.green : Color.orange)
                    .frame(width: 12, height: 12)
            }
            .frame(width: 50)

            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: entry.isExercise ? "figure.run" : "fork.knife")
                        .font(.caption)
                        .foregroundColor(entry.isExercise ? .green : .orange)

                    Text(entryTitle)
                        .font(.headline)
                        .lineLimit(1)
                }

                HStack(spacing: 12) {
                    if entry.isExercise {
                        Label("\(entry.calories) cal burned", systemImage: "bolt.fill")
                            .foregroundColor(.green)
                    } else {
                        Label("\(entry.calories) cal", systemImage: "flame.fill")
                            .foregroundColor(.orange)
                    }

                    if let details = entryDetails {
                        Text(details)
                            .foregroundColor(.secondary)
                    }
                }
                .font(.caption)
            }

            Spacer()

            // Calorie badge
            Text(entry.isExercise ? "-\(entry.calories)" : "+\(entry.calories)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(entry.isExercise ? .green : .orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    (entry.isExercise ? Color.green : Color.orange).opacity(0.15)
                )
                .cornerRadius(8)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: entry.timestamp)
    }

    private var entryTitle: String {
        switch entry {
        case .meal(let meal):
            return meal.name
        case .exercise(let exercise):
            return exercise.type.displayName
        }
    }

    private var entryDetails: String? {
        switch entry {
        case .meal(let meal):
            // Safely access items relationship by creating a local copy first
            // This prevents InvalidFutureBackingData errors
            let itemsArray = Array(meal.items)
            return "\(itemsArray.count) items"
        case .exercise(let exercise):
            return "\(exercise.duration) min"
        }
    }
}

// MARK: - Previews

#Preview {
    let persistence = PersistenceController.shared
    let repository = MealRepository(context: persistence.mainContext)

    LogHistoryView(repository: repository)
}
