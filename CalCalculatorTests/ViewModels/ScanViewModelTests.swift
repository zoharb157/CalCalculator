//
//  ScanViewModelTests.swift
//  CalCalculatorTests
//
//  Unit tests for ScanViewModel
//

import XCTest
@testable import playground
import AVFoundation

@MainActor
final class ScanViewModelTests: XCTestCase {
    
    var container: ModelContainer!
    var context: ModelContext!
    var repository: MealRepository!
    var mockAnalysisService: MockFoodAnalysisService!
    var viewModel: ScanViewModel!
    
    override func setUpWithError() throws {
        let schema = Schema([Meal.self, MealItem.self, DaySummary.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
        repository = MealRepository(context: context)
        mockAnalysisService = MockFoodAnalysisService()
        viewModel = ScanViewModel(
            repository: repository,
            analysisService: mockAnalysisService,
            imageStorage: .shared
        )
    }
    
    override func tearDownWithError() throws {
        container = nil
        context = nil
        repository = nil
        mockAnalysisService = nil
        viewModel = nil
    }
    
    func testInitialState() {
        // Then
        XCTAssertNil(viewModel.selectedImage)
        XCTAssertFalse(viewModel.showingImagePicker)
        XCTAssertFalse(viewModel.showingCamera)
        XCTAssertFalse(viewModel.isAnalyzing)
        XCTAssertEqual(viewModel.analysisProgress, 0)
        XCTAssertNil(viewModel.pendingMeal)
        XCTAssertFalse(viewModel.showingResults)
        XCTAssertFalse(viewModel.showingNoFoodDetected)
        XCTAssertNil(viewModel.error)
    }
    
    func testCheckCameraPermission() {
        // When
        viewModel.checkCameraPermission()
        
        // Then
        // Permission status should be set (actual value depends on test environment)
        XCTAssertNotNil(viewModel.cameraPermissionStatus)
    }
    
    func testHandleSelectedImage() {
        // Given
        let image = createTestImage()
        
        // When
        viewModel.handleSelectedImage(image)
        
        // Then
        XCTAssertNotNil(viewModel.selectedImage)
        XCTAssertEqual(viewModel.selectedImage, image)
    }
    
    func testHandleSelectedImageNil() {
        // When
        viewModel.handleSelectedImage(nil)
        
        // Then
        XCTAssertNil(viewModel.selectedImage)
    }
    
    func testOpenPhotoLibrary() {
        // When
        viewModel.openPhotoLibrary()
        
        // Then
        XCTAssertTrue(viewModel.showingImagePicker)
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage() -> UIImage {
        // Create a simple 1x1 test image
        let size = CGSize(width: 1, height: 1)
        UIGraphicsBeginImageContext(size)
        let image = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        return image
    }
}

// MARK: - Mock Food Analysis Service

class MockFoodAnalysisService: FoodAnalysisServiceProtocol {
    var shouldSucceed = true
    var mockResult: FoodAnalysisResult?
    var mockError: Error?
    
    func analyzeFood(image: UIImage, mode: ScanMode, foodHint: String?) async throws -> FoodAnalysisResult {
        if shouldSucceed {
            return mockResult ?? FoodAnalysisResult(
                foodDetected: true,
                mealName: "Test Meal",
                brand: nil,
                totalCalories: 500,
                confidence: nil,
                breakdown: nil,
                servingSize: nil,
                items: nil,
                source: nil,
                barcode: nil,
                ingredients: nil,
                labelType: nil,
                notes: nil
            )
        } else {
            throw mockError ?? FoodAnalysisError.imageProcessingFailed
        }
    }
}

