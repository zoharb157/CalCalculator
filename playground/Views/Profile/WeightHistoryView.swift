//
//  WeightHistoryView.swift
//
//  Weight History screen with chart and entry management
//

import SwiftUI
import SwiftData
import Charts

struct WeightHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @Query(sort: \WeightEntry.date, order: .reverse) private var weightEntries: [WeightEntry]
    
    @State private var showingAddWeight = false
    @State private var newWeight: Double = 70 // Default in kg, will be converted for display
    @State private var newWeightNote: String = ""
    @State private var selectedDate: Date = Date()
    @State private var selectedTimeRange: TimeRange = .month
    @State private var showingExportOptions = false
    
    private let repository = UserProfileRepository.shared
    
    // Use metric or imperial units based on user preference
    private var useMetricUnits: Bool {
        UserSettings.shared.useMetricUnits
    }
    
    private var weightUnit: String {
        useMetricUnits ? "kg" : "lbs"
    }
    
    /// Convert weight from kg (storage) to display units
    private func displayWeight(_ weightInKg: Double) -> Double {
        useMetricUnits ? weightInKg : weightInKg * 2.20462
    }
    
    /// Convert weight from display units to kg (storage)
    private func storageWeight(_ displayWeight: Double) -> Double {
        useMetricUnits ? displayWeight : displayWeight / 2.20462
    }
    
    enum TimeRange: String, CaseIterable {
        case week = "1W"
        case month = "1M"
        case threeMonths = "3M"
        case sixMonths = "6M"
        case year = "1Y"
        case all = "All"
        
        var days: Int? {
            switch self {
            case .week: return 7
            case .month: return 30
            case .threeMonths: return 90
            case .sixMonths: return 180
            case .year: return 365
            case .all: return nil
            }
        }
    }
    
    private var filteredEntries: [WeightEntry] {
        guard let days = selectedTimeRange.days else {
            return weightEntries
        }
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return weightEntries.filter { $0.date >= cutoffDate }
    }
    
    private var chartEntries: [WeightEntry] {
        // Reverse to get chronological order for chart
        Array(filteredEntries.reversed())
    }
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return NavigationStack {
            Group {
                if weightEntries.isEmpty {
                    emptyStateView
                } else {
                    weightListView
                }
            }
            .navigationTitle(localizationManager.localizedString(for: AppStrings.Profile.weightHistory))
                .id("weight-history-title-\(localizationManager.currentLanguage)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(localizationManager.localizedString(for: AppStrings.Common.done)) {
                        dismiss()
                    }
                    .id("done-weight-history-\(localizationManager.currentLanguage)")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        if !weightEntries.isEmpty {
                            Button {
                                showingExportOptions = true
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                        Button {
                            // getCurrentWeight() returns lbs, convert to display units
                            let weightInLbs = repository.getCurrentWeight()
                            newWeight = useMetricUnits ? (weightInLbs / 2.20462) : weightInLbs
                            newWeightNote = ""
                            selectedDate = Date()
                            showingAddWeight = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddWeight) {
                addWeightSheet
            }
            .confirmationDialog("Export Weight Data", isPresented: $showingExportOptions) {
                Button(localizationManager.localizedString(for: AppStrings.Common.exportAsCSV)) {
                    exportWeightData()
                }
                .id("export-csv-\(localizationManager.currentLanguage)")
                Button(localizationManager.localizedString(for: AppStrings.Common.cancel), role: .cancel) {}
                    .id("cancel-export-\(localizationManager.currentLanguage)")
            }
        }
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "scalemass")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(localizationManager.localizedString(for: AppStrings.Profile.noWeightEntriesYet))
                .id("no-weight-entries-\(localizationManager.currentLanguage)")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(localizationManager.localizedString(for: AppStrings.Profile.startTrackingWeight))
                .id("start-tracking-weight-\(localizationManager.currentLanguage)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                // getCurrentWeight() returns lbs, convert to display units
                let weightInLbs = repository.getCurrentWeight()
                newWeight = useMetricUnits ? (weightInLbs / 2.20462) : weightInLbs
                newWeightNote = ""
                selectedDate = Date()
                showingAddWeight = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text(localizationManager.localizedString(for: AppStrings.Profile.addFirstEntry))
                        .id("add-first-entry-\(localizationManager.currentLanguage)")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(12)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Weight List View
    
    private var weightListView: some View {
        List {
            // Chart Section
            if chartEntries.count >= 2 {
                Section {
                    VStack(spacing: 12) {
                        // Time Range Picker
                        Picker("Time Range", selection: $selectedTimeRange) {
                            ForEach(TimeRange.allCases, id: \.self) { range in
                                Text(range.rawValue).tag(range)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        // Weight Chart
                        weightChart
                            .frame(height: 200)
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                } header: {
                    Text(localizationManager.localizedString(for: AppStrings.Profile.progress))
                        .id("progress-label-\(localizationManager.currentLanguage)")
                }
            }
            
            // Summary Section
            if let latestEntry = weightEntries.first,
               let oldestEntry = weightEntries.last,
               weightEntries.count > 1 {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(localizationManager.localizedString(for: AppStrings.Profile.totalChange))
                                .id("total-change-\(localizationManager.currentLanguage)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            let changeInKg = latestEntry.weight - oldestEntry.weight
                            let changeDisplay = displayWeight(changeInKg)
                            let changeText = changeDisplay >= 0 ? String(format: "+%.1f %@", changeDisplay, weightUnit) : String(format: "%.1f %@", changeDisplay, weightUnit)
                            Text(changeText)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(changeInKg <= 0 ? .green : .red)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .center, spacing: 4) {
                            Text(localizationManager.localizedString(for: AppStrings.Profile.average))
                                .id("average-label-\(localizationManager.currentLanguage)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            let averageInKg = weightEntries.reduce(0) { $0 + $1.weight } / Double(weightEntries.count)
                            Text(String(format: "%.1f %@", displayWeight(averageInKg), weightUnit))
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(localizationManager.localizedString(for: AppStrings.Profile.entries))
                                .id("entries-label-\(localizationManager.currentLanguage)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("\(weightEntries.count)")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            
            // Entries Section
            Section {
                ForEach(weightEntries) { entry in
                    WeightEntryRow(entry: entry, previousEntry: getPreviousEntry(for: entry))
                }
                .onDelete(perform: deleteEntries)
            } header: {
                Text(localizationManager.localizedString(for: AppStrings.Profile.allEntries))
                    .id("all-entries-\(localizationManager.currentLanguage)")
            }
        }
    }
    
    // MARK: - Weight Chart
    
    @ViewBuilder
    private var weightChart: some View {
        // Convert weights to display units for chart
        let displayWeights = chartEntries.map { displayWeight($0.weight) }
        let minWeight = (displayWeights.min() ?? 100) - 5
        let maxWeight = (displayWeights.max() ?? 200) + 5
        
        Chart(chartEntries) { entry in
            LineMark(
                x: .value("Date", entry.date),
                y: .value("Weight", displayWeight(entry.weight))
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.catmullRom)
            
            AreaMark(
                x: .value("Date", entry.date),
                y: .value("Weight", displayWeight(entry.weight))
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [.blue.opacity(0.3), .purple.opacity(0.1), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)
            
            PointMark(
                x: .value("Date", entry.date),
                y: .value("Weight", displayWeight(entry.weight))
            )
            .foregroundStyle(.blue)
            .symbolSize(40)
        }
        .chartYScale(domain: minWeight...maxWeight)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let weight = value.as(Double.self) {
                        Text("\(Int(weight)) \(weightUnit)")
                    }
                }
            }
        }
    }
    
    // MARK: - Add Weight Sheet
    
    // Slider range based on unit preference
    private var sliderMin: Double {
        useMetricUnits ? 30.0 : 80.0
    }
    
    private var sliderMax: Double {
        useMetricUnits ? 200.0 : 440.0
    }
    
    private var addWeightSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Weight Display - newWeight is in display units
                Text("\(Int(newWeight)) \(weightUnit)")
                    .font(.system(size: 56, weight: .bold))
                
                // Weight Slider
                VStack(spacing: 8) {
                    Slider(value: $newWeight, in: sliderMin...sliderMax, step: 1)
                        .padding(.horizontal, 32)
                    
                    HStack {
                        Text("\(Int(sliderMin)) \(weightUnit)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(sliderMax)) \(weightUnit)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 32)
                }
                
                // Date Picker
                DatePicker(
                    "Date",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .padding(.horizontal, 32)
                
                // Note Field
                VStack(alignment: .leading, spacing: 8) {
                    Text(localizationManager.localizedString(for: AppStrings.Profile.noteOptional))
                        .id("note-optional-\(localizationManager.currentLanguage)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("e.g., After workout", text: $newWeightNote)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal, 32)
                
                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle(localizationManager.localizedString(for: AppStrings.Profile.saveWeight))
                .id("save-weight-title-\(localizationManager.currentLanguage)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localizedString(for: AppStrings.Common.cancel)) {
                        showingAddWeight = false
                    }
                    .id("cancel-add-weight-\(localizationManager.currentLanguage)")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizationManager.localizedString(for: AppStrings.Common.save)) {
                        saveWeightEntry()
                    }
                    .id("save-weight-\(localizationManager.currentLanguage)")
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Helper Functions
    
    private func saveWeightEntry() {
        let weightInKg = storageWeight(newWeight)
        let calendar = Calendar.current
        
        if let existingEntry = weightEntries.first(where: { calendar.isDate($0.date, inSameDayAs: selectedDate) }) {
            existingEntry.weight = weightInKg
            existingEntry.date = selectedDate
            existingEntry.note = newWeightNote.isEmpty ? nil : newWeightNote
        } else {
            let entry = WeightEntry(
                weight: weightInKg,
                date: selectedDate,
                note: newWeightNote.isEmpty ? nil : newWeightNote
            )
            modelContext.insert(entry)
        }
        
        if calendar.isDateInToday(selectedDate) {
            repository.setCurrentWeight(weightInKg)
            UserSettings.shared.updateWeight(weightInKg)
        }
        
        HapticManager.shared.notification(.success)
        showingAddWeight = false
    }
    
    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(weightEntries[index])
        }
        HapticManager.shared.notification(.success)
    }
    
    private func getPreviousEntry(for entry: WeightEntry) -> WeightEntry? {
        guard let currentIndex = weightEntries.firstIndex(where: { $0.id == entry.id }),
              currentIndex + 1 < weightEntries.count else {
            return nil
        }
        return weightEntries[currentIndex + 1]
    }
    
    private func exportWeightData() {
        // Export in user's preferred units
        var csvString = "Date,Weight (\(weightUnit)),Note\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for entry in weightEntries.reversed() {
            let date = dateFormatter.string(from: entry.date)
            let weight = String(format: "%.1f", displayWeight(entry.weight))
            let note = entry.note?.replacingOccurrences(of: ",", with: ";") ?? ""
            csvString += "\(date),\(weight),\(note)\n"
        }
        
        let filename = "weight_history_\(dateFormatter.string(from: Date())).csv"
        
        if let data = csvString.data(using: .utf8) {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            do {
                try data.write(to: tempURL)
                let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    rootVC.present(activityVC, animated: true)
                }
                HapticManager.shared.notification(.success)
            } catch {
                print("Failed to export: \(error)")
            }
        }
    }
}

// MARK: - Weight Entry Row

struct WeightEntryRow: View {
    let entry: WeightEntry
    let previousEntry: WeightEntry?
    
    // Use metric or imperial units based on user preference
    private var useMetricUnits: Bool {
        UserSettings.shared.useMetricUnits
    }
    
    private var weightUnit: String {
        useMetricUnits ? "kg" : "lbs"
    }
    
    /// Convert weight from kg (storage) to display units
    private func displayWeight(_ weightInKg: Double) -> Double {
        useMetricUnits ? weightInKg : weightInKg * 2.20462
    }
    
    private var weightChange: Double? {
        guard let previous = previousEntry else { return nil }
        // Return change in kg (will be converted for display)
        return entry.weight - previous.weight
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(String(format: "%.1f %@", displayWeight(entry.weight), weightUnit))
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    // Show change from previous entry
                    if let change = weightChange {
                        let displayChange = displayWeight(abs(change))
                        HStack(spacing: 2) {
                            Image(systemName: change > 0 ? "arrow.up" : change < 0 ? "arrow.down" : "minus")
                                .font(.caption2)
                            Text(String(format: "%.1f %@", displayChange, weightUnit))
                                .font(.caption)
                        }
                        .foregroundColor(change < 0 ? .green : change > 0 ? .red : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            (change < 0 ? Color.green : change > 0 ? Color.red : Color.gray)
                                .opacity(0.15)
                        )
                        .cornerRadius(4)
                    }
                }
                
                Text(entry.date.formatted(date: .long, time: .omitted))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let note = entry.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    WeightHistoryView()
        .modelContainer(for: [WeightEntry.self], inMemory: true)
}
