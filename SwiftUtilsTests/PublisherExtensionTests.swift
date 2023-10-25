//
//  PublisherExtensionTests.swift
//  SwiftUtils
//
//  Created by Wang Ya on 3/10/23.
//

import XCTest
import Combine
@testable import SwiftUtils

final class PublisherExtensionTests: XCTestCase {
    
    // Test waitUntilStop with a successful completion
    func testWaitUntilStop() async throws {
        // Create a publisher that emits values and completes successfully
        let publisher = [1, 2, 3].publisher
        
        var testValues = [Int]()
        // Call waitUntilStop to wait for values
        let result = try await publisher.waitUntilStop { value in
            testValues.append(value)
            // Check if the value is equal to 2, if yes, stop and return the value
            if value == 2 {
                return value
            } else {
                return nil // Continue
            }
        }
        XCTAssertEqual(testValues, [1, 2])
        // Verify that the result is as expected
        XCTAssertEqual(result, 2)
    }
    
    // Test next with a successful value
    func testNext() async throws {
        // Create a publisher that emits values
        let subject = PassthroughSubject<Int, Never>()
        
        Task {
            try await Task.sleep(nanoseconds: UInt64(0.1 * 1_000_000_000))
            subject.send(1)
            try await Task.sleep(nanoseconds: UInt64(0.1 * 1_000_000_000))
            subject.send(2)
            try await Task.sleep(nanoseconds: UInt64(0.1 * 1_000_000_000))
            subject.send(3)
            try await Task.sleep(nanoseconds: UInt64(0.1 * 1_000_000_000))
            subject.send(completion: Subscribers.Completion<Never>.finished)
        }
        
        // Call next to get the next value
        let result1 = try await subject.next()
        XCTAssertEqual(result1, 1)
        let result2 = try await subject.next()
        XCTAssertEqual(result2, 2)
        let result3 = try await subject.next()
        XCTAssertEqual(result3, 3)
        let result4 = try await subject.next()
        XCTAssertEqual(result4, nil)
    }
    
}
