import XCTest
@testable import otracker

class FormulaTests: XCTestCase {
    
    func testNavyBodyFatFormula() {
        // Test values
        let values: [String: Double] = [
            "Waist": 91.0,  // cm
            "Neck": 41.0,   // cm
            "Height": 1.79  // m
        ]
        
        // Formula: 86.010 * log10(Waist - Neck) - 70.041 * log10(Height) + 36.76
        let formula = "86.010 * log10(Waist - Neck) - 70.041 * log10(Height) + 36.76"
        
        // Calculate expected result manually
        let waistNeckDiff = values["Waist"]! - values["Neck"]!
        let log10WaistNeck = log10(waistNeckDiff)
        let log10Height = log10(values["Height"]!)
        let expectedResult = 86.010 * log10WaistNeck - 70.041 * log10Height + 36.76
        
        // Calculate using formula evaluation
        let result = evaluateFormula(formula, values: values)
        
        // Compare results (allowing for small floating point differences)
        XCTAssertEqual(result, expectedResult, accuracy: 0.0001)
    }
    
    func testFormulaWithDifferentValues() {
        // Test with different values
        let values: [String: Double] = [
            "Waist": 85.0,
            "Neck": 38.0,
            "Height": 1.75
        ]
        
        let formula = "86.010 * log10(Waist - Neck) - 70.041 * log10(Height*100) + 36.76"
        
        // Calculate expected result manually
        let waistNeckDiff = values["Waist"]! - values["Neck"]!
        let log10WaistNeck = log10(waistNeckDiff)
        let log10Height = log10(values["Height"]!)
        let expectedResult = 86.010 * log10WaistNeck - 70.041 * log10Height + 36.76
        
        // Calculate using formula evaluation
        let result = evaluateFormula(formula, values: values)
        
        // Compare results
        XCTAssertEqual(result, expectedResult, accuracy: 0.0001)
    }
    
    func testFormulaWithEdgeCases() {
        // Test with edge case values
        let values: [String: Double] = [
            "Waist": 100.0,
            "Neck": 35.0,
            "Height": 2.0
        ]
        
        let formula = "86.010 * log10(Waist - Neck) - 70.041 * log10(Height) + 36.76"
        
        // Calculate expected result manually
        let waistNeckDiff = values["Waist"]! - values["Neck"]!
        let log10WaistNeck = log10(waistNeckDiff)
        let log10Height = log10(values["Height"]!)
        let expectedResult = 86.010 * log10WaistNeck - 70.041 * log10Height + 36.76
        
        // Calculate using formula evaluation
        let result = evaluateFormula(formula, values: values)
        
        // Compare results
        XCTAssertEqual(result, expectedResult, accuracy: 0.0001)
    }
    
    private func evaluateFormula(_ formula: String, values: [String: Double]) -> Double {
        // Replace variable names with their values
        var evaluatedFormula = formula
        for (name, value) in values {
            evaluatedFormula = evaluatedFormula.replacingOccurrences(of: name, with: "\(value)")
        }
        
        // Use NSExpression for safe evaluation
        let expression = NSExpression(format: evaluatedFormula)
        return (expression.expressionValue(with: nil, context: nil) as? Double) ?? 0.0
    }
} 
