//
//  TimeoutTests.swift
//  SwiftUtils
//
//  Created by Wang Ya on 3/10/23.
//

import XCTest
@testable import SwiftUtils

enum SwiftUtilsError: Error {
    case timeout
}

final class TimeoutTests: XCTestCase {
    
    func testNormal() async throws {
        let result = try await withTimeout(seconds: 0.2, timeoutError: SwiftUtilsError.timeout) {
            try await Task.sleep(nanoseconds: UInt64(0.1 * 1_000_000_000))
            return "Operation Completed"
        }
        XCTAssertEqual(result, "Operation Completed")
    }
    
    func testThrow() async throws {
        do {
            try await withTimeout(seconds: 0.2, timeoutError: SwiftUtilsError.timeout) {
                try await Task.sleep(nanoseconds: UInt64(0.1 * 1_000_000_000))
                throw NSError(domain: "ddd", code: 999)
            }
            XCTFail("Expected throw")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, "ddd")
            XCTAssertEqual(error.code, 999)
        }
    }
    
    func testTimeout() async throws {
        do {
            _ = try await withTimeout(seconds: 0.1, timeoutError: SwiftUtilsError.timeout) {
                try await Task.sleep(nanoseconds: UInt64(0.2 * 1_000_000_000))
                return "Operation Completed"
            }
            XCTFail("Expected TimedOutError to be thrown")
        } catch SwiftUtilsError.timeout {
            // Verify that it throws a TimedOutError
        }
    }
    
}
