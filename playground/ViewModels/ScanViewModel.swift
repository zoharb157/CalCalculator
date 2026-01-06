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
    var canRetry = false
    var retryCount = 0
    private let maxRetries = 2

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
        pendingMeal = nil
        pendingImage = nil
        isAnalyzing = false
        analysisProgress = 0
        showingResults = false
    }

    // MARK: - Meal Analysis

    func analyzeImage(_ image: UIImage, mode: ScanMode = .food, foodHint: String? = nil) async {
        // Note: isAnalyzing and analysisProgress may already be set by the caller
        // to provide immediate feedback. Only set if not already analyzing.
        if !isAnalyzing {
            isAnalyzing = true
            analysisProgress = 0.1
        }
        showingNoFoodDetected = false
        noFoodDetectedMessage = nil

        // Simulate smooth progress that continues until API call completes
        let progressTask = Task {
            var currentProgress: Double = analysisProgress // Start from current progress
            let increment: Double = 0.015 // 1.5% increments
            let interval: UInt64 = 150_000_000 // 150ms intervals (smooth but not too fast)
            let maxProgress: Double = 0.90 // Stop at 90% to leave room for completion
            
            // Ensure we're at least at 10% to show immediate feedback
            if currentProgress < 0.1 {
                await MainActor.run {
                    analysisProgress = 0.1
                }
                currentProgress = 0.1
            }
            
            // Continue progress smoothly up to 90% while waiting for API
            while currentProgress < maxProgress && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: interval)
                
                guard !Task.isCancelled else { break }
                
                currentProgress = min(currentProgress + increment, maxProgress)
                
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.2)) {
                        analysisProgress = currentProgress
                    }
                }
            }
        }

        do {
            print("🔵 [ScanViewModel] Calling analysisService.analyzeFood...")
            let response = try await analysisService.analyzeFood(image: image, mode: mode, foodHint: foodHint)
            print("🟢 [ScanViewModel] Analysis completed successfully")
            print("🟢 [ScanViewModel] Response - foodDetected: \(response.foodDetected)")
            print("🟢 [ScanViewModel] Response - mealName: \(response.mealName ?? "nil")")
            print("🟢 [ScanViewModel] Response - totalCalories: \(response.totalCalories ?? 0)")
            
            // Cancel progress task and smoothly complete to 100%
            progressTask.cancel()
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) {
                    analysisProgress = 1.0
                }
            }

            // Check if food was detected
            guard response.foodDetected, let meal = response.toMeal() else {
                print("⚠️ [ScanViewModel] Food not detected or meal conversion failed")
                isAnalyzing = false
                showingNoFoodDetected = true
                // Use notes from response, or provide default message
                noFoodDetectedMessage = response.notes ?? "No food detected in the image. Please try with a clearer photo of food."
                print("⚠️ [ScanViewModel] Showing no food detected screen with message: \(noFoodDetectedMessage ?? "nil")")
                // Clear any pending meal to prevent saving
                pendingMeal = nil
                pendingImage = nil
                showingResults = false
                HapticManager.shared.notification(.warning)
                return
            }

            print("🟢 [ScanViewModel] Meal created: \(meal.name)")
            
            // Save image and get URL
            let imageURL = try imageStorage.saveImage(image, for: meal.id)
            meal.photoURL = imageURL.absoluteString

            pendingMeal = meal
            pendingImage = image
            showingResults = true

            print("🟢 [ScanViewModel] Analysis complete, showing results")
            HapticManager.shared.notification(.success)
        } catch let foodError as FoodAnalysisError {
            progressTask.cancel()
            print("🔴 [ScanViewModel] FoodAnalysisError caught: \(foodError)")
            print("🔴 [ScanViewModel] Error description: \(foodError.errorDescription ?? "nil")")

            // Reset progress on error
            await MainActor.run {
                analysisProgress = 0
            }

            // Handle no food detected specifically
            if foodError.isNoFoodDetected {
                print("⚠️ [ScanViewModel] No food detected - showing no food message")
                isAnalyzing = false
                showingNoFoodDetected = true
                noFoodDetectedMessage = foodError.errorDescription
                // Clear any pending meal to prevent saving
                pendingMeal = nil
                pendingImage = nil
                showingResults = false
                print("⚠️ [ScanViewModel] No food detected message: \(noFoodDetectedMessage ?? "nil")")
                HapticManager.shared.notification(.warning)
            } else {
                print("🔴 [ScanViewModel] Other error - showing error dialog")
                self.errorMessage = foodError.errorDescription
                self.error = mapToScanError(foodError)
                self.showingError = true
                HapticManager.shared.notification(.error)
            }
        } catch {
            progressTask.cancel()
            print("🔴 [ScanViewModel] Unexpected error: \(error)")
            print("🔴 [ScanViewModel] Error type: \(type(of: error))")
            print("🔴 [ScanViewModel] Error description: \(error.localizedDescription)")
            
            // Reset progress on error
            await MainActor.run {
                analysisProgress = 0
            }
            
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

        // Set analyzing state FIRST to ensure analyzing view shows immediately
        // This takes priority in contentBody, so it shows even if showingResults is still true
        isAnalyzing = true
        analysisProgress = 0.1
        
        // Close results view after setting analyzing state
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

            // Notify that food was logged so HomeViewModel can refresh
            NotificationCenter.default.post(name: .foodLogged, object: nil)
            
            // Sync widget data after saving meal
            repository.syncWidgetData()

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
            // Start analyzing immediately - this will show analyzing view
            // Camera dismissal is handled by SwiftUI automatically via the binding
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
            return "Camera access denied. To scan your meals, please enable camera permissions in Settings."
        case .cameraNotAvailable:
            return "Camera is not available on this device. Please use a device with a camera."
        case .imageSelectionFailed:
            return "Failed to select the image. Please try selecting a different image."
        case .analysisTimeout:
            return "Analysis took too long. Please check your internet connection and try again."
        case .networkError:
            return "Network error. Please check your internet connection and try again."
        case .authenticationRequired:
            return "Please log in to analyze meals."
        case .noFoodDetected:
            return "No food detected in the image. Please try with a clearer photo of food."
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
