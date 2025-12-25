//
//  ScanView.swift
//  playground
//
//  CalAI Clone - Camera and photo scanning view
//

import SwiftUI
import PhotosUI
import SDK

struct ScanView: View {
    @Bindable var viewModel: ScanViewModel
    @State private var selectedItem: PhotosPickerItem?
    
    @Environment(\.isSubscribed) private var isSubscribed
    @Environment(TheSDK.self) private var sdk
    
    @State private var showPaywall = false
    
    /// Callback when meal is saved successfully
    var onMealSaved: (() -> Void)?
    
    /// Callback to dismiss the sheet
    var onDismiss: (() -> Void)?
    
    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle("Scan Meal")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        if onDismiss != nil {
                            Button {
                                onDismiss?()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
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
                .fullScreenCover(isPresented: $showPaywall) {
                    SDKView(
                        model: sdk,
                        page: .splash,
                        show: $showPaywall,
                        backgroundColor: .white,
                        ignoreSafeArea: true
                    )
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
                onRetake: { viewModel.clearSelection() }
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
                    // Clear selection to allow taking a new photo
                    viewModel.clearSelection()
                },
                onRetake: { 
                    // Clear selection to allow taking a new photo
                    viewModel.clearSelection()
                }
            )
        } else {
            NoFoodDetectedView(
                message: viewModel.noFoodDetectedMessage,
                image: nil,
                onRetry: { viewModel.clearSelection() },
                onRetake: { viewModel.clearSelection() }
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
                
                // Check subscription before analyzing
                guard isSubscribed else {
                    // Store the image first so we can show it when paywall closes
                    switch result {
                    case .image(let image):
                        viewModel.selectedImage = image
                    case .barcode(_, let previewImage):
                        if let image = previewImage {
                            viewModel.selectedImage = image
                        }
                    case .document(let image):
                        viewModel.selectedImage = image
                    case .cancelled:
                        break
                    }
                    showPaywall = true
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
        Button("OK", role: .cancel) {}
        if viewModel.canRetry {
            Button("Retry") {
                if let image = viewModel.selectedImage {
                    viewModel.retryCount += 1
                    Task {
                        await viewModel.analyzeImage(image)
                    }
                }
            }
        }
        if viewModel.error == .cameraPermissionDenied {
            Button("Open Settings") {
                openSettings()
            }
        }
        if viewModel.error == .authenticationRequired {
            Button("Log In") {
                // Navigate to login screen
                // This would be handled by the app's navigation system
            }
        }
    }
    
    private var errorAlertMessage: some View {
        Text(viewModel.errorMessage ?? viewModel.error?.errorDescription ?? "An error occurred")
            .font(.subheadline)
    }
    
    // MARK: - Helper Methods
    
    private func handlePhotoSelection(_ newValue: PhotosPickerItem?) {
        Task {
            if let newValue,
               let data = try? await newValue.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                // Allow selecting photo - check subscription when analyzing/sending
                viewModel.handleSelectedImage(image)
            }
        }
    }
    
    private func openSettings() {
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
        guard isSubscribed else {
            // Don't start analyzing if not subscribed - just show paywall
            // This ensures we return to the image selection screen when paywall closes
            showPaywall = true
            return
        }
        guard let image = viewModel.selectedImage else { return }
        // Set analyzing state immediately - this takes priority in contentBody
        // Even if camera is still dismissing, we'll show analyzing view
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
