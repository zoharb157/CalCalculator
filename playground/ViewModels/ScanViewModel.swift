//
//  ScanViewModel.swift
//  playground
//
//  CalAI Clone - View model for scan and analysis functionality
//

import SwiftUI
import AVFoundation

/// View model for camera, photo scanning, and meal analysis
@MainActor
@Observable
final class ScanViewModel {
    // MARK: - Dependencies
    private let repository: MealRepository
    private let analysisService: FoodAnalysisServiceProtocol
    private let imageStorage: ImageStorage
    
    // MARK: - Image Selection State
    var selectedImage: UIImage?
    var showingImagePicker = false
    var showingCamera = false
    var cameraPermissionStatus: AVAuthorizationStatus = .notDetermined
    var photoLibraryPermissionGranted = false
    
    // MARK: - Analysis State
    var isAnalyzing = false
    var analysisProgress: Double = 0
    var pendingMeal: Meal?
    var pendingImage: UIImage?
    var showingResults = false
    
    // MARK: - No Food Detected State
    var showingNoFoodDetected = false
    var noFoodDetectedMessage: String?
    
    // MARK: - Error State
    var error: ScanError?
    var showingError = false
    var errorMessage: String?
    
    init(
        repository: MealRepository,
        analysisService: FoodAnalysisServiceProtocol,
        imageStorage: ImageStorage
    ) {
        self.repository = repository
        self.analysisService = analysisService
        self.imageStorage = imageStorage
        checkCameraPermission()
    }
    
    // MARK: - Permissions
    
    func checkCameraPermission() {
        cameraPermissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }
    
    func requestCameraPermission() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        cameraPermissionStatus = granted ? .authorized : .denied
    }
    
    // MARK: - Camera Actions
    
    func openCamera() async {
        checkCameraPermission()
        
        switch cameraPermissionStatus {
        case .notDetermined:
            await requestCameraPermission()
            if cameraPermissionStatus == .authorized {
                showingCamera = true
            }
        case .authorized:
            showingCamera = true
        case .denied, .restricted:
            error = .cameraPermissionDenied
            showingError = true
        @unknown default:
            break
        }
    }
    
    func openPhotoLibrary() {
        showingImagePicker = true
    }
    
    // MARK: - Image Selection
    
    func handleSelectedImage(_ image: UIImage?) {
        guard let image = image else {
            error = .imageSelectionFailed
            showingError = true
            return
        }
        
        selectedImage = image
        // Reset no food detected state when selecting new image
        showingNoFoodDetected = false
        noFoodDetectedMessage = nil
        HapticManager.shared.impact(.light)
    }
    
    func clearSelection() {
        selectedImage = nil
        showingNoFoodDetected = false
        noFoodDetectedMessage = nil
    }
    
    // MARK: - Meal Analysis
    
    func analyzeImage(_ image: UIImage) async {
        isAnalyzing = true
        analysisProgress = 0
        showingNoFoodDetected = false
        noFoodDetectedMessage = nil
        
        // Simulate progress for better UX
        let progressTask = Task {
            for i in 1...8 {
                try await Task.sleep(nanoseconds: 200_000_000)
                if !Task.isCancelled {
                    await MainActor.run {
                        analysisProgress = Double(i) * 0.1
                    }
                }
            }
        }
        
        do {
            let response = try await analysisService.analyzeFood(image: image)
            progressTask.cancel()
            analysisProgress = 1.0
            
            // Check if food was detected
            guard response.foodDetected, let meal = response.toMeal() else {
                isAnalyzing = false
                showingNoFoodDetected = true
                noFoodDetectedMessage = response.notes ?? "No food detected in the image."
                HapticManager.shared.notification(.warning)
                return
            }
            
            // Save image and get URL
            let imageURL = try imageStorage.saveImage(image, for: meal.id)
            meal.photoURL = imageURL.absoluteString
            
            pendingMeal = meal
            pendingImage = image
            showingResults = true
            
            HapticManager.shared.notification(.success)
        } catch let foodError as FoodAnalysisError {
            progressTask.cancel()
            
            // Handle no food detected specifically
            if foodError.isNoFoodDetected {
                showingNoFoodDetected = true
                noFoodDetectedMessage = foodError.errorDescription
                HapticManager.shared.notification(.warning)
            } else {
                self.errorMessage = foodError.errorDescription
                self.error = mapToScanError(foodError)
                self.showingError = true
                HapticManager.shared.notification(.error)
            }
        } catch {
            progressTask.cancel()
            self.errorMessage = error.localizedDescription
            self.error = .analysisTimeout
            self.showingError = true
            HapticManager.shared.notification(.error)
        }
        
        isAnalyzing = false
    }
    
    // MARK: - Meal Management
    
    func savePendingMeal() async -> Bool {
        guard let meal = pendingMeal else { return false }
        
        do {
            try repository.saveMeal(meal)
            
            pendingMeal = nil
            pendingImage = nil
            showingResults = false
            selectedImage = nil
            
            HapticManager.shared.notification(.success)
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            self.showingError = true
            HapticManager.shared.notification(.error)
            return false
        }
    }
    
    // MARK: - Reset
    
    func reset() {
        selectedImage = nil
        pendingMeal = nil
        pendingImage = nil
        showingResults = false
        isAnalyzing = false
        analysisProgress = 0
        showingNoFoodDetected = false
        noFoodDetectedMessage = nil
    }
    
    /// Retry analysis with the current selected image
    func retryAnalysis() {
        guard let image = selectedImage else { return }
        showingNoFoodDetected = false
        noFoodDetectedMessage = nil
        Task {
            await analyzeImage(image)
        }
    }
    
    // MARK: - Private Helpers
    
    private func mapToScanError(_ foodError: FoodAnalysisError) -> ScanError {
        switch foodError {
        case .authenticationFailed, .missingCredentials:
            return .authenticationRequired
        case .networkError:
            return .networkError
        case .imageProcessingFailed:
            return .imageSelectionFailed
        default:
            return .analysisTimeout
        }
    }
}

// MARK: - Scan Errors

enum ScanError: LocalizedError {
    case cameraPermissionDenied
    case cameraNotAvailable
    case imageSelectionFailed
    case analysisTimeout
    case networkError
    case authenticationRequired
    case noFoodDetected
    
    var errorDescription: String? {
        switch self {
        case .cameraPermissionDenied:
            return "Camera access is required to scan meals. Please enable it in Settings."
        case .cameraNotAvailable:
            return "Camera is not available on this device."
        case .imageSelectionFailed:
            return "Failed to select the image. Please try again."
        case .analysisTimeout:
            return "Analysis took too long. Please try again."
        case .networkError:
            return "Network error. Please check your connection and try again."
        case .authenticationRequired:
            return "Please log in to analyze meals."
        case .noFoodDetected:
            return "No food detected in the image. Please try with a clearer photo."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .cameraPermissionDenied:
            return "Go to Settings > Privacy > Camera to enable access."
        case .networkError:
            return "Check your internet connection and try again."
        case .authenticationRequired:
            return "Log in to continue using the app."
        default:
            return nil
        }
    }
}
