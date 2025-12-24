//
//  ScanViewModel.swift
//  playground
//
//  CalAI Clone - View model for scan and analysis functionality
//

import AVFoundation
import SwiftUI

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
    
    // MARK: - Barcode State
    var scannedBarcode: String?
    var lastCaptureMode: CaptureMode = .photo

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

    func analyzeImage(_ image: UIImage, mode: ScanMode = .food, foodHint: String? = nil) async {
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
            let response = try await analysisService.analyzeFood(image: image, mode: mode, foodHint: foodHint)
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

    /// Re-analyze the current image with a food hint to fix incorrect results
    /// - Parameter foodHint: A description of what the food actually is (e.g., "This is a chicken caesar salad")
    func analyzeWithHint(_ foodHint: String) async {
        guard let image = pendingImage ?? selectedImage else {
            error = .imageSelectionFailed
            showingError = true
            return
        }

        // Close results view before re-analyzing
        showingResults = false
        pendingMeal = nil

        // Use the last capture mode to determine the scan mode
        let mode = lastCaptureMode.toScanMode()
        await analyzeImage(image, mode: mode, foodHint: foodHint)
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
        let mode = lastCaptureMode.toScanMode()
        Task {
            await analyzeImage(image, mode: mode)
        }
    }
    
    // MARK: - Capture Result Handling
    
    /// Handle the result from CustomCameraView
    /// - Parameters:
    ///   - result: The capture result (image, barcode, document, or cancelled)
    ///   - hint: Optional food hint/description provided by the user
    func handleCaptureResult(_ result: CaptureResult, hint: String?) async {
        switch result {
        case .image(let image):
            lastCaptureMode = .photo
            selectedImage = image
            await analyzeImage(image, mode: .food, foodHint: hint)
            
        case .barcode(let barcodeValue, let previewImage):
            lastCaptureMode = .barcode
            scannedBarcode = barcodeValue
            if let image = previewImage {
                selectedImage = image
            }
            // For barcodes, use the barcode value as food hint to help API identify the product
            let barcodeHint = buildBarcodeHint(barcode: barcodeValue, userHint: hint)
            if let image = previewImage {
                await analyzeImage(image, mode: .barcode, foodHint: barcodeHint)
            } else {
                // If no preview image, show error - we need an image for the API
                error = .imageSelectionFailed
                errorMessage = "Could not capture product image. Please try again."
                showingError = true
            }
            
        case .document(let image):
            lastCaptureMode = .document
            selectedImage = image
            // For documents (menus, labels), use the label mode
            let documentHint = buildDocumentHint(userHint: hint)
            await analyzeImage(image, mode: .label, foodHint: documentHint)
            
        case .cancelled:
            // User cancelled, do nothing
            break
        }
    }
    
    /// Build a food hint for barcode scanning
    private func buildBarcodeHint(barcode: String, userHint: String?) -> String {
        var hints: [String] = []
        hints.append("Product barcode: \(barcode)")
        if let userHint = userHint, !userHint.isEmpty {
            hints.append("User description: \(userHint)")
        }
        return hints.joined(separator: ". ")
    }
    
    /// Build a food hint for document capture
    private func buildDocumentHint(userHint: String?) -> String {
        var hints: [String] = []
        hints.append("This is a photo of a menu, receipt, or food label")
        if let userHint = userHint, !userHint.isEmpty {
            hints.append("User notes: \(userHint)")
        }
        return hints.joined(separator: ". ")
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
