//
//  MealVerificationView.swift
//  playground
//
//  View for verifying meal calories by taking a photo when reminder comes
//

import SwiftUI
import SwiftData

struct MealVerificationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    let scheduledMealId: UUID
    let mealName: String
    let category: MealCategory
    let expectedCalories: Int?
    
    @State private var showingCamera = false
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var isAnalyzing = false
    @State private var analysisResult: Meal?
    @State private var showingResults = false
    @State private var verificationStatus: VerificationStatus?
    
    let scanViewModel: ScanViewModel
    
    private var mealRepository: MealRepository {
        MealRepository(context: modelContext)
    }
    
    private var dietPlanRepository: DietPlanRepository {
        DietPlanRepository(context: modelContext)
    }
    
    enum VerificationStatus {
        case match
        case close
        case mismatch
    }
    
    init(
        scheduledMealId: UUID,
        mealName: String,
        category: MealCategory,
        expectedCalories: Int?,
        scanViewModel: ScanViewModel
    ) {
        self.scheduledMealId = scheduledMealId
        self.mealName = mealName
        self.category = category
        self.expectedCalories = expectedCalories
        self.scanViewModel = scanViewModel
    }
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return NavigationStack {
            ZStack {
                if showingResults, let meal = analysisResult, let status = verificationStatus {
                    verificationResultsView(meal: meal, status: status)
                } else if isAnalyzing {
                    analyzingView
                } else {
                    promptView
                }
            }
            .navigationTitle(localizationManager.localizedString(for: AppStrings.DietPlan.verifyMeal))
                
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraCaptureView(
                    onImageCaptured: { image in
                        selectedImage = image
                        showingCamera = false
                        analyzeImage(image)
                    },
                    onDismiss: {
                        showingCamera = false
                    }
                )
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(
                    selectedImage: $selectedImage,
                    onImageSelected: { image in
                        selectedImage = image
                        showingImagePicker = false
                        if let image = image {
                            analyzeImage(image)
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - Prompt View
    
    private var promptView: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "camera.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue.gradient)
            
            // Title
            Text(String(format: localizationManager.localizedString(for: AppStrings.DietPlan.timeFor), mealName))
                .font(.title)
                .fontWeight(.bold)
            
            // Expected calories info
            if let expected = expectedCalories {
                VStack(spacing: 8) {
                    Text(localizationManager.localizedString(for: AppStrings.DietPlan.expectedCalories))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(expected)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
            
            // Instructions
            Text(localizationManager.localizedString(for: AppStrings.DietPlan.takePhotoToVerify))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Action buttons
            VStack(spacing: 12) {
                Button {
                    showingCamera = true
                } label: {
                    Label(localizationManager.localizedString(for: AppStrings.Scanning.takePhoto), systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                
                Button {
                    showingImagePicker = true
                } label: {
                    Label(localizationManager.localizedString(for: AppStrings.Scanning.chooseFromLibrary), systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }
                
                Button {
                    skipVerification()
                } label: {
                    Text(localizationManager.localizedString(for: AppStrings.DietPlan.skipVerification))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }
    
    // MARK: - Analyzing View
    
    private var analyzingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text(localizationManager.localizedString(for: AppStrings.DietPlan.analyzingYourMeal))
                .font(.headline)
            
            Text(localizationManager.localizedString(for: AppStrings.DietPlan.comparingCalories))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Verification Results
    
    private func verificationResultsView(meal: Meal, status: VerificationStatus) -> some View {
        VStack(spacing: 24) {
            // Status icon
            Group {
                switch status {
                case .match:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                case .close:
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                case .mismatch:
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            }
            .font(.system(size: 80))
            
            // Status message
            Group {
                switch status {
                case .match:
                    Text(localizationManager.localizedString(for: AppStrings.DietPlan.greatCaloriesMatch))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                case .close:
                    Text(localizationManager.localizedString(for: AppStrings.DietPlan.closeMatch))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                case .mismatch:
                    Text(localizationManager.localizedString(for: AppStrings.DietPlan.caloriesDontMatch))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }
            }
            
            // Calorie comparison
            if let expected = expectedCalories {
                VStack(spacing: 12) {
                    HStack {
                        Text(localizationManager.localizedString(for: AppStrings.DietPlan.expected))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(expected) \(localizationManager.localizedString(for: AppStrings.Progress.cal))")
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text(localizationManager.localizedString(for: AppStrings.DietPlan.detected))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(meal.totalCalories) \(localizationManager.localizedString(for: AppStrings.Progress.cal))")
                            .fontWeight(.semibold)
                    }
                    
                    Divider()
                    
                    let difference = abs(meal.totalCalories - expected)
                    HStack {
                        Text(localizationManager.localizedString(for: AppStrings.DietPlan.difference))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(difference) \(localizationManager.localizedString(for: AppStrings.Progress.cal))")
                            .fontWeight(.semibold)
                            .foregroundColor(difference > 100 ? .red : .green)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Meal details
            VStack(alignment: .leading, spacing: 8) {
                Text(localizationManager.localizedString(for: AppStrings.DietPlan.mealDetails))
                    .font(.headline)
                
                Text(meal.name)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Safely access items relationship by creating a local copy first
                let itemsArray = Array(meal.items)
                if !itemsArray.isEmpty {
                    ForEach(itemsArray.prefix(3)) { item in
                        HStack {
                            Text("• \(item.name)")
                            Spacer()
                            Text("\(item.calories) cal")
                                .foregroundColor(.secondary)
                        }
                        .font(.caption)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Action buttons
            VStack(spacing: 12) {
                Button {
                    saveAndComplete()
                } label: {
                    Label(localizationManager.localizedString(for: AppStrings.Food.saveMeal), systemImage: "checkmark.circle.fill")
                        .id("save-meal-label-\(localizationManager.currentLanguage)")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                
                Button {
                    showingResults = false
                    selectedImage = nil
                    analysisResult = nil
                } label: {
                    Text(localizationManager.localizedString(for: AppStrings.DietPlan.takeAnotherPhoto))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }
                
                Button {
                    skipVerification()
                } label: {
                    Text(localizationManager.localizedString(for: AppStrings.DietPlan.skip))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func analyzeImage(_ image: UIImage) {
        isAnalyzing = true
        
        Task {
            // Use ScanViewModel to analyze the image
            await MainActor.run {
                scanViewModel.selectedImage = image
            }
            await scanViewModel.analyzeImage(image)
            
            // Wait for analysis to complete - check status without sleep
            // Analysis will complete when scanViewModel.isAnalyzing becomes false
            if let meal = scanViewModel.pendingMeal {
                await MainActor.run {
                    analysisResult = meal
                    verifyCalories(meal: meal)
                    showingResults = true
                    isAnalyzing = false
                }
            } else if scanViewModel.showingError {
                await MainActor.run {
                    isAnalyzing = false
                    // Show error
                }
            }
        }
    }
    
    private func verifyCalories(meal: Meal) {
        guard let expected = expectedCalories else {
            verificationStatus = nil
            return
        }
        
        let detected = meal.totalCalories
        let difference = abs(detected - expected)
        let percentageDiff = Double(difference) / Double(expected) * 100
        
        if difference <= 50 {
            verificationStatus = .match
        } else if percentageDiff <= 20 {
            verificationStatus = .close
        } else {
            verificationStatus = .mismatch
        }
    }
    
    private func saveAndComplete() {
        guard let meal = analysisResult else { return }
        
        Task {
            do {
                // Save the meal
                // This automatically updates DaySummary and syncs widget data
                try mealRepository.saveMeal(meal)
                
                // Notify other parts of the app about the new meal
                // This triggers HomeView to refresh and update widgets
                NotificationCenter.default.post(name: .foodLogged, object: nil)
                
                // Find the scheduled meal and evaluate goal achievement
                let plans = try dietPlanRepository.fetchAllDietPlans()
                let scheduledMeal = plans.flatMap { $0.scheduledMeals }.first { $0.id == scheduledMealId }
                
                // Mark reminder as completed and evaluate goal
                if let reminder = try dietPlanRepository.fetchMealReminder(
                    by: scheduledMealId,
                    for: Date()
                ) {
                    try dietPlanRepository.updateMealReminderCompletion(reminder, completedMealId: meal.id)
                    
                    // Evaluate goal achievement if scheduled meal has a template
                    if let scheduled = scheduledMeal {
                        let (achieved, deviation) = dietPlanRepository.evaluateMealGoalAchievement(
                            actualMeal: meal,
                            scheduledMeal: scheduled
                        )
                        try dietPlanRepository.updateMealReminderGoalAchievement(
                            reminder,
                            goalAchieved: achieved,
                            goalDeviation: deviation
                        )
                    }
                } else if let scheduled = scheduledMeal {
                    // Create reminder record if it doesn't exist
                    let reminder = MealReminder(
                        scheduledMealId: scheduledMealId,
                        reminderDate: Date(),
                        wasCompleted: true,
                        completedMealId: meal.id,
                        completedAt: Date()
                    )
                    try dietPlanRepository.saveMealReminder(reminder)
                    
                    // Evaluate goal achievement
                    let (achieved, deviation) = dietPlanRepository.evaluateMealGoalAchievement(
                        actualMeal: meal,
                        scheduledMeal: scheduled
                    )
                    try dietPlanRepository.updateMealReminderGoalAchievement(
                        reminder,
                        goalAchieved: achieved,
                        goalDeviation: deviation
                    )
                }
                
                HapticManager.shared.notification(.success)
                dismiss()
            } catch {
                print("Failed to save meal: \(error)")
                HapticManager.shared.notification(.error)
            }
        }
    }
    
    private func skipVerification() {
        Task {
            do {
                // Mark as skipped
                if let reminder = try dietPlanRepository.fetchMealReminder(
                    by: scheduledMealId,
                    for: Date()
                ) {
                    try dietPlanRepository.updateMealReminderCompletion(reminder, completedMealId: nil)
                } else {
                    // Create a reminder record for skipped meal
                    let reminder = MealReminder(
                        scheduledMealId: scheduledMealId,
                        reminderDate: Date(),
                        wasCompleted: true,
                        completedMealId: nil,
                        completedAt: Date()
                    )
                    try dietPlanRepository.saveMealReminder(reminder)
                }
                
                HapticManager.shared.notification(.success)
                dismiss()
            } catch {
                print("Failed to skip verification: \(error)")
                HapticManager.shared.notification(.error)
            }
        }
    }
}

// MARK: - Camera Capture View

struct CameraCaptureView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    let onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onImageCaptured: onImageCaptured, onDismiss: onDismiss)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImageCaptured: (UIImage) -> Void
        let onDismiss: () -> Void
        
        init(onImageCaptured: @escaping (UIImage) -> Void, onDismiss: @escaping () -> Void) {
            self.onImageCaptured = onImageCaptured
            self.onDismiss = onDismiss
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImageCaptured(image)
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onDismiss()
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    let onImageSelected: (UIImage?) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(selectedImage: $selectedImage, onImageSelected: onImageSelected)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        @Binding var selectedImage: UIImage?
        let onImageSelected: (UIImage?) -> Void
        
        init(selectedImage: Binding<UIImage?>, onImageSelected: @escaping (UIImage?) -> Void) {
            self._selectedImage = selectedImage
            self.onImageSelected = onImageSelected
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                selectedImage = image
                onImageSelected(image)
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onImageSelected(nil)
            picker.dismiss(animated: true)
        }
    }
}

#Preview {
    MealVerificationView(
        scheduledMealId: UUID(),
        mealName: "Oatmeal with Berries",
        category: .breakfast,
        expectedCalories: 350,
        scanViewModel: ScanViewModel(
            repository: MealRepository(context: ModelContext(try! ModelContainer(for: Meal.self))),
            analysisService: CaloriesAPIService(),
            imageStorage: .shared
        )
    )
}

