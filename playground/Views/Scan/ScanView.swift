//
//  ScanView.swift
//  playground
//
//  CalAI Clone - Camera and photo scanning view
//

import SwiftUI
import PhotosUI

struct ScanView: View {
    @Bindable var viewModel: ScanViewModel
    @State private var selectedItem: PhotosPickerItem?
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    
    @State private var previousViewState: ViewState? // Store previous view state before opening settings
    
    enum ViewState {
        case selectedImage
        case noFoodDetected
        case captureOptions
    }
    
    /// Callback when meal is saved successfully
    var onMealSaved: (() -> Void)?
    
    /// Callback to dismiss the sheet
    var onDismiss: (() -> Void)?
    
    var body: some View {
        // Explicitly reference currentLanguage to ensure SwiftUI tracks the dependency
        let _ = localizationManager.currentLanguage
        
        return NavigationStack {
            mainContent
                .navigationTitle(localizationManager.localizedString(for: AppStrings.Scanning.scanMeal))
                    .id("scan-meal-title-\(localizationManager.currentLanguage)")
                .navigationBarTitleDisplayMode(.inline)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    // When app returns from settings, viewModel state is automatically maintained
                    // The view will automatically show the correct screen based on viewModel state
                    // No explicit restoration needed - SwiftUI handles it
                    previousViewState = nil // Clear stored state
                }
                .fullScreenCover(isPresented: $viewModel.showingCamera) {
                    cameraSheet
                }
                .photosPicker(
                    isPresented: $viewModel.showingImagePicker,
                    selection: $selectedItem,
                    matching: .images
                )
                .onChange(of: selectedItem) { oldValue, newValue in
                    handlePhotoSelection(newValue)
                }
                .sheet(isPresented: $viewModel.showingResults) {
                    resultsSheet
                }
                .alert("Error", isPresented: $viewModel.showingError) {
                    errorAlertActions
                } message: {
                    errorAlertMessage
                }
        }
    }
    
    // MARK: - Private Views
    
    private var mainContent: some View {
        VStack(spacing: 24) {
            contentBody
        }
    }
    
    @ViewBuilder
    private var contentBody: some View {
        // Priority order: analyzing > results sheet > no food > selected image > camera > capture options
        // Analyzing takes priority - show it even if camera is still dismissing
        if viewModel.isAnalyzing {
            AnalyzingView(progress: viewModel.analysisProgress)
        } else if viewModel.showingResults {
            // Hide content when results sheet is showing/dismissing
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.showingCamera {
            // Hide content when camera is showing/dismissing (but not if analyzing)
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.showingNoFoodDetected {
            noFoodDetectedContent
        } else if let image = viewModel.selectedImage {
            SelectedImageView(
                image: image,
                onAnalyze: analyzeImage,
                onRetake: { 
                    viewModel.clearSelection()
                    // Reopen camera after clearing selection
                    Task {
                        await viewModel.openCamera()
                    }
                }
            )
        } else {
            CaptureOptionsView(
                onCamera: { Task { await viewModel.openCamera() } },
                onPhotoLibrary: { viewModel.openPhotoLibrary() }
            )
        }
    }
    
    @ViewBuilder
    private var noFoodDetectedContent: some View {
        if let image = viewModel.selectedImage {
            NoFoodDetectedView(
                message: viewModel.noFoodDetectedMessage,
                image: Image(uiImage: image),
                onRetry: { 
                    // Clear selection and reopen camera to allow taking a new photo
                    viewModel.clearSelection()
                    Task {
                        await viewModel.openCamera()
                    }
                },
                onRetake: { 
                    // Clear selection and reopen camera to allow taking a new photo
                    viewModel.clearSelection()
                    Task {
                        await viewModel.openCamera()
                    }
                }
            )
        } else {
            NoFoodDetectedView(
                message: viewModel.noFoodDetectedMessage,
                image: nil,
                onRetry: { 
                    viewModel.clearSelection()
                    Task {
                        await viewModel.openCamera()
                    }
                },
                onRetake: { 
                    viewModel.clearSelection()
                    Task {
                        await viewModel.openCamera()
                    }
                }
            )
        }
    }
    
    private var cameraSheet: some View {
        CustomCameraView { result, hint in
            // Handle capture result from the custom camera
            Task {
                // If cancelled, just return
                if case .cancelled = result {
                    return
                }
                
                await viewModel.handleCaptureResult(result, hint: hint)
            }
        }
    }
    
    @ViewBuilder
    private var resultsSheet: some View {
        if let meal = viewModel.pendingMeal {
            ResultsView(
                viewModel: viewModel,
                meal: meal,
                onMealSaved: {
                    viewModel.clearSelection()
                    onMealSaved?()
                }
            )
        }
    }
    
    @ViewBuilder
    private var errorAlertActions: some View {
        Button(localizationManager.localizedString(for: AppStrings.Common.ok), role: .cancel) {}
            .id("ok-scan-\(localizationManager.currentLanguage)")
        if viewModel.canRetry {
            Button(localizationManager.localizedString(for: AppStrings.Common.retry)) {
                if let image = viewModel.selectedImage {
                    viewModel.retryCount += 1
                    Task {
                        await viewModel.analyzeImage(image)
                    }
                }
            }
            .id("retry-scan-\(localizationManager.currentLanguage)")
        }
        if viewModel.error == .cameraPermissionDenied {
            Button(localizationManager.localizedString(for: AppStrings.Common.openSettings)) {
                openSettings()
            }
            .id("open-settings-\(localizationManager.currentLanguage)")
        }
        if viewModel.error == .authenticationRequired {
            Button(localizationManager.localizedString(for: AppStrings.Common.logIn)) {
                // Navigate to login screen
                // This would be handled by the app's navigation system
            }
            .id("log-in-\(localizationManager.currentLanguage)")
        }
    }
    
    private var errorAlertMessage: some View {
        Text(viewModel.errorMessage ?? viewModel.error?.errorDescription ?? localizationManager.localizedString(for: AppStrings.Common.errorOccurred))
            .id("error-alert-\(localizationManager.currentLanguage)")
            .font(.subheadline)
    }
    
    // MARK: - Helper Methods
    
    private func handlePhotoSelection(_ newValue: PhotosPickerItem?) {
        Task {
            if let newValue,
               let data = try? await newValue.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                viewModel.handleSelectedImage(image)
            }
        }
    }
    
    private func openSettings() {
        // Store current view state before opening settings
        if viewModel.selectedImage != nil {
            previousViewState = .selectedImage
        } else if viewModel.showingNoFoodDetected {
            previousViewState = .noFoodDetected
        } else {
            previousViewState = .captureOptions
        }
        
        // Direct approach: Open Settings app to the app's settings page
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            print("❌ [ScanView] Failed to create settings URL")
            return
        }
        
        print("🔵 [ScanView] Opening settings: \(settingsURL.absoluteString)")
        
        // Use the synchronous open method with completion handler for better reliability
        if UIApplication.shared.canOpenURL(settingsURL) {
            UIApplication.shared.open(settingsURL) { success in
                if success {
                    print("✅ [ScanView] Successfully opened settings")
                } else {
                    print("❌ [ScanView] Failed to open settings")
                }
            }
        } else {
            print("❌ [ScanView] Cannot open settings URL")
        }
    }
    
    private func analyzeImage() {
        // All features are free - no limit check needed
        guard let image = viewModel.selectedImage else { return }
        
        viewModel.isAnalyzing = true
        viewModel.analysisProgress = 0.1
        Task {
            await viewModel.analyzeImage(image)
        }
    }
}

#Preview {
    let persistence = PersistenceController.shared
    let repository = MealRepository(context: persistence.mainContext)
    let viewModel = ScanViewModel(
        repository: repository,
        analysisService: CaloriesAPIService(),
        imageStorage: .shared
    )
    
    ScanView(viewModel: viewModel)
}
