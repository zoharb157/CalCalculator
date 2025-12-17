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
                .sheet(isPresented: $viewModel.showingCamera) {
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
        if viewModel.isAnalyzing {
            AnalyzingView(progress: viewModel.analysisProgress)
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
                onRetry: { viewModel.retryAnalysis() },
                onRetake: { viewModel.clearSelection() }
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
        CameraView { image in
            viewModel.handleSelectedImage(image)
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
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    private func analyzeImage() {
        guard let image = viewModel.selectedImage else { return }
        Task {
            await viewModel.analyzeImage(image)
        }
    }
}

#Preview {
    let persistence = PersistenceController.shared
    let repository = MealRepository(context: persistence.mainContext)
    let viewModel = ScanViewModel(repository: repository)
    
    ScanView(viewModel: viewModel)
}
