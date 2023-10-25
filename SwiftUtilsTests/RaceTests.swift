//
//  RaceTests.swift
//  SwiftUtils
//
//  Created by Wang Ya on 3/10/23.
//

import XCTest
@testable import SwiftUtils

final class RaceTests: XCTestCase {
    
    // Test the withRace function
    func testWithRace() async throws {
        // Mock a function that represents an asynchronous operation
        @Sendable func asyncOperation(_ result: Int) async throws -> Int {
            try? await Task.sleep(nanoseconds: UInt64(result * 10_000_000))
            switch result {
            case 1:
                XCTAssertFalse(Task.isCancelled)
            case 2, 3:
                XCTAssertTrue(Task.isCancelled)
            default:
                XCTFail()
            }
            return result
        }
        // Define an array of async operations to race
        let operations: [@Sendable () async throws -> Int] = [
            { try await asyncOperation(2) },
            { try await asyncOperation(3) },
            { try await asyncOperation(1) }
        ]
        
        // Call the withRace function to race the operations
        let result = try await withRace(operations: operations)
        
        // Verify that the result is the value of the first finished operation
        XCTAssertEqual(result, 1, "The first finished operation should win")
    }
    
}
