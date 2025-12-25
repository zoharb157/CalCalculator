//
//  MealTemplateTests.swift
//  CalCalculatorTests
//
//  Unit tests for MealTemplate model
//

import XCTest
@testable import playground
import Foundation

final class MealTemplateTests: XCTestCase {
    
    func testMealTemplateInitialization() {
        // Given
        let name = "Oatmeal Breakfast"
        let notes = "Healthy morning meal"
        let items = [
            TemplateMealItem(
                name: "Oatmeal",
                portion: 100,
                unit: "g",
                calories: 389,
                proteinG: 16.9,
                carbsG: 66.3,
                fatG: 6.9
            )
        ]
        
        // When
        let template = MealTemplate(
            name: name,
            notes: notes,
            templateItems: items
        )
        
        // Then
        XCTAssertEqual(template.name, name)
        XCTAssertEqual(template.notes, notes)
        XCTAssertEqual(template.templateItems.count, 1)
        XCTAssertEqual(template.templateItems[0].name, "Oatmeal")
    }
    
    func testMealTemplateCreateMeal() {
        // Given
        let template = MealTemplate(
            name: "Test Meal",
            templateItems: [
                TemplateMealItem(
                    name: "Item 1",
                    portion: 100,
                    unit: "g",
                    calories: 100,
                    proteinG: 10,
                    carbsG: 20,
                    fatG: 5
                )
            ]
        )
        let timestamp = Date()
        
        // When
        let meal = template.createMeal(at: timestamp, category: .breakfast)
        
        // Then
        XCTAssertEqual(meal.name, template.name)
        XCTAssertEqual(meal.timestamp, timestamp)
        XCTAssertEqual(meal.category, .breakfast)
        XCTAssertEqual(meal.items.count, 1)
        XCTAssertEqual(meal.items[0].name, "Item 1")
        XCTAssertEqual(meal.items[0].calories, 100)
    }
    
    func testMealTemplateFromMealItem() {
        // Given
        let mealItem = MealItem(
            name: "Test Item",
            portion: 150,
            unit: "g",
            calories: 200,
            proteinG: 15,
            carbsG: 30,
            fatG: 8
        )
        
        // When
        let templateItem = TemplateMealItem(from: mealItem)
        
        // Then
        XCTAssertEqual(templateItem.name, mealItem.name)
        XCTAssertEqual(templateItem.portion, mealItem.portion)
        XCTAssertEqual(templateItem.unit, mealItem.unit)
        XCTAssertEqual(templateItem.calories, mealItem.calories)
        XCTAssertEqual(templateItem.proteinG, mealItem.proteinG)
        XCTAssertEqual(templateItem.carbsG, mealItem.carbsG)
        XCTAssertEqual(templateItem.fatG, mealItem.fatG)
    }
}
