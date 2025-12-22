//
//  SettingsView.swift
//  playground
//
//  CalAI Clone - Settings and preferences
//

import SwiftUI
import SDK

struct SettingsView: View {
    @Bindable var settings = UserSettings.shared
    @Bindable var viewModel: SettingsViewModel
    @Environment(TheSDK.self) private var sdk
    
    @State private var showingExportSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var exportData: Data?
    
    /// Callback to notify parent when data is deleted
    var onDataDeleted: (() -> Void)?
    
    var body: some View {
        NavigationStack {
            settingsForm
                .navigationTitle("Settings")
                .confirmationDialog(
                    "Delete All Data",
                    isPresented: $showingDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    deleteConfirmationActions
                } message: {
                    deleteConfirmationMessage
                }
                .sheet(isPresented: $showingExportSheet) {
                    exportSheet
                }
        }
    }
    
    // MARK: - Private Views
    
    private var settingsForm: some View {
        Form {
            macroGoalsSection
            unitsSection
            dataManagementSection
            debugSection
            aboutSection
        }
    }
    
    private var macroGoalsSection: some View {
        Section {
            caloriesStepper
            proteinStepper
            carbsStepper
            fatStepper
        } header: {
            Text("Daily Goals")
        } footer: {
            Text("Adjust your daily nutritional targets")
        }
    }
    
    private var caloriesStepper: some View {
        Stepper(value: $settings.calorieGoal, in: 1000...5000, step: 50) {
            HStack {
                Label("Calories", systemImage: "flame.fill")
                    .foregroundColor(.caloriesColor)
                Spacer()
                Text("\(settings.calorieGoal)")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var proteinStepper: some View {
        Stepper(value: $settings.proteinGoal, in: 10...300, step: 5) {
            HStack {
                Label("Protein", systemImage: "p.circle.fill")
                    .foregroundColor(.proteinColor)
                Spacer()
                Text("\(settings.proteinGoal.formattedMacro)g")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var carbsStepper: some View {
        Stepper(value: $settings.carbsGoal, in: 10...500, step: 5) {
            HStack {
                Label("Carbs", systemImage: "c.circle.fill")
                    .foregroundColor(.carbsColor)
                Spacer()
                Text("\(settings.carbsGoal.formattedMacro)g")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var fatStepper: some View {
        Stepper(value: $settings.fatGoal, in: 10...200, step: 5) {
            HStack {
                Label("Fat", systemImage: "f.circle.fill")
                    .foregroundColor(.fatColor)
                Spacer()
                Text("\(settings.fatGoal.formattedMacro)g")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var unitsSection: some View {
        Section {
            Toggle(isOn: $settings.useMetricUnits) {
                Label("Metric Units", systemImage: "ruler")
            }
        } header: {
            Text("Units")
        } footer: {
            Text("Use grams and milliliters for portions")
        }
    }
    
    private var dataManagementSection: some View {
        Section {
            exportDataButton
            deleteDataButton
        } header: {
            Text("Data Management")
        }
    }
    
    private var exportDataButton: some View {
        Button {
            exportDataAction()
        } label: {
            Label("Export Data (JSON)", systemImage: "square.and.arrow.up")
        }
    }
    
    private var deleteDataButton: some View {
        Button(role: .destructive) {
            showingDeleteConfirmation = true
        } label: {
            Label("Delete All Data", systemImage: "trash")
                .foregroundColor(.red)
        }
    }
    
    private var debugSection: some View {
        #if DEBUG
        Section {
            Toggle(isOn: $settings.debugOverrideSubscription) {
                Label("Override Subscription", systemImage: "wrench.and.screwdriver")
            }
            
            if settings.debugOverrideSubscription {
                Toggle(isOn: $settings.debugIsSubscribed) {
                    HStack {
                        Label("Debug: Is Subscribed", systemImage: "crown.fill")
                        Spacer()
                        Text(settings.debugIsSubscribed ? "Premium" : "Free")
                            .font(.caption)
                            .foregroundColor(settings.debugIsSubscribed ? .green : .gray)
                    }
                }
                
                HStack {
                    Text("SDK Status")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(sdk.isSubscribed ? "Subscribed" : "Not Subscribed")
                        .font(.caption)
                        .foregroundColor(sdk.isSubscribed ? .green : .gray)
                }
            }
        } header: {
            Text("Debug")
        } footer: {
            Text("Override subscription status for testing. Only visible in debug builds.")
        }
        #else
        EmptyView()
        #endif
    }
    
    private var aboutSection: some View {
        Section {
            versionRow
            modeRow
        } header: {
            Text("About")
        } footer: {
            Text("CalAI Clone - Photo-based calorie tracking")
        }
    }
    
    private var versionRow: some View {
        HStack {
            Text("Version")
            Spacer()
            Text("1.0.0")
                .foregroundColor(.secondary)
        }
    }
    
    private var modeRow: some View {
        HStack {
            Text("Mode")
            Spacer()
            Text("Real API")
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private var deleteConfirmationActions: some View {
        Button("Delete All", role: .destructive) {
            Task {
                await viewModel.deleteAllData()
                onDataDeleted?()
            }
        }
        Button("Cancel", role: .cancel) {}
    }
    
    private var deleteConfirmationMessage: some View {
        Text("This will permanently delete all your meals, history, and saved photos. This action cannot be undone.")
    }
    
    @ViewBuilder
    private var exportSheet: some View {
        if let exportData = exportData {
            ShareSheet(items: [exportData])
        }
    }
    
    private func exportDataAction() {
        Task {
            if let data = await viewModel.exportData() {
                exportData = data
                showingExportSheet = true
            }
        }
    }
}

#Preview {
    let persistence = PersistenceController.shared
    let repository = MealRepository(context: persistence.mainContext)
    let viewModel = SettingsViewModel(repository: repository, imageStorage: .shared)
    
    SettingsView(viewModel: viewModel)
}
