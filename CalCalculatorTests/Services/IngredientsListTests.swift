//
//  IngredientsListTests.swift
//  CalCalculatorTests
//
//  Unit tests for IngredientsList enum
//

import XCTest
@testable import playground

final class IngredientsListTests: XCTestCase {
    
    func testIngredientsListFromString() throws {
        // Given
        let jsonString = """
        "flour, sugar, eggs"
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        // When
        let ingredients = try decoder.decode(IngredientsList.self, from: data)
        
        // Then
        if case .string(let value) = ingredients {
            XCTAssertEqual(value, "flour, sugar, eggs")
        } else {
            XCTFail("Expected string case")
        }
    }
    
    func testIngredientsListFromArray() throws {
        // Given
        let jsonString = """
        ["flour", "sugar", "eggs"]
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        // When
        let ingredients = try decoder.decode(IngredientsList.self, from: data)
        
        // Then
        if case .array(let values) = ingredients {
            XCTAssertEqual(values.count, 3)
            XCTAssertEqual(values[0], "flour")
            XCTAssertEqual(values[1], "sugar")
            XCTAssertEqual(values[2], "eggs")
        } else {
            XCTFail("Expected array case")
        }
    }
    
    func testIngredientsListAsString() {
        // Given
        let stringIngredients = IngredientsList.string("flour, sugar, eggs")
        let arrayIngredients = IngredientsList.array(["flour", "sugar", "eggs"])
        
        // When
        let stringResult = stringIngredients.asString
        let arrayResult = arrayIngredients.asString
        
        // Then
        XCTAssertEqual(stringResult, "flour, sugar, eggs")
        XCTAssertEqual(arrayResult, "flour, sugar, eggs")
    }
    
    func testIngredientsListAsArray() {
        // Given
        let stringIngredients = IngredientsList.string("flour, sugar, eggs")
        let arrayIngredients = IngredientsList.array(["flour", "sugar", "eggs"])
        
        // When
        let stringResult = stringIngredients.asArray
        let arrayResult = arrayIngredients.asArray
        
        // Then
        XCTAssertEqual(stringResult, ["flour, sugar, eggs"])
        XCTAssertEqual(arrayResult, ["flour", "sugar", "eggs"])
    }
}

