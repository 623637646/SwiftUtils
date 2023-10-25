//
//  CancellableContinuationTests.swift
//  SwiftUtils
//
//  Created by Wang Ya on 3/10/23.
//

import XCTest
@testable import SwiftUtils

final class CancellableContinuationTests: XCTestCase {
    
    func testNormal() async throws {
        let expectation1 = expectation(description: "started")
        let expectation2 = expectation(description: "finished")
        let result = try await withCheckedThrowingCancellableContinuation { continuation in
            Task {
                expectation1.fulfill()
                try await Task.sleep(nanoseconds: UInt64(0.1 * 1_000_000_000))
                continuation.resume(returning: "Operation Completed")
            }
        }
        XCTAssertEqual(result, "Operation Completed")
        expectation2.fulfill()
        await fulfillment(of: [expectation1, expectation2])
    }
    
    // Test the withCheckedThrowingCancellableContinuation function with cancellation
    func testCancellation() async throws {
        let expectation1 = expectation(description: "started")
        let expectation2 = expectation(description: "finished")
        let task = Task {
            do {
                _ = try await withCheckedThrowingCancellableContinuation { continuation in
                    // Simulate a successful async operation
                    Task {
                        expectation1.fulfill()
                        try await Task.sleep(nanoseconds: UInt64(0.2 * 1_000_000_000))
                        continuation.resume(returning: "Operation Completed")
                    }
                }
                XCTFail()
            } catch is CancellationError {
                expectation2.fulfill()
            } catch {
                XCTFail()
            }
        }
        try await Task.sleep(nanoseconds: UInt64(0.1 * 1_000_000_000))
        task.cancel()
        await fulfillment(of: [expectation1, expectation2])
    }
    
    func testCancelImmediately() async throws {
        let expectation1 = expectation(description: "started")
        let expectation2 = expectation(description: "finished")
        let task = Task {
            // make sure the Task is cancelled
            try? await Task.sleep(nanoseconds: UInt64(0.1 * 1_000_000_000))
            do {
                XCTAssertTrue(Task.isCancelled)
                expectation1.fulfill()
                _ = try await withCheckedThrowingCancellableContinuation { continuation in
                    XCTFail()
                    continuation.resume(returning: "Operation Completed")
                }
                XCTFail()
            } catch is CancellationError {
                expectation2.fulfill()
            } catch {
                XCTFail()
            }
        }
        task.cancel()
        await fulfillment(of: [expectation1, expectation2])
    }
    
    
    /// Test: cancel -> bind -> returning
    func testCancelBindReturning() async throws {
        let expectation1 = self.expectation(description: "started")
        let expectation2 = self.expectation(description: "finished")
        let task = Task {
            do {
                expectation1.fulfill()
                _ = try await withCheckedThrowingCancellableContinuation { continuation in
                    Thread.sleep(forTimeInterval: 0.2)
                    Task {
                        try await Task.sleep(nanoseconds: UInt64(0.1 * 1_000_000_000))
                        continuation.resume(returning: "Operation Completed")
                    }
                }
                XCTFail()
            } catch is CancellationError {
                expectation2.fulfill()
            } catch {
                XCTFail()
            }
        }
        try await Task.sleep(nanoseconds: UInt64(0.1 * 1_000_000_000))
        task.cancel()
        await self.fulfillment(of: [expectation1, expectation2])
        try await Task.sleep(nanoseconds: UInt64(0.5 * 1_000_000_000))
    }
    
    /// Test: cancel -> bind -> throwing
    func testCancelBindThrowing() async throws {
        let expectation1 = self.expectation(description: "started")
        let expectation2 = self.expectation(description: "finished")
        let task = Task {
            do {
                expectation1.fulfill()
                let _: Void = try await withCheckedThrowingCancellableContinuation { continuation in
                    Thread.sleep(forTimeInterval: 0.2)
                    Task {
                        try await Task.sleep(nanoseconds: UInt64(0.1 * 1_000_000_000))
                        continuation.resume(throwing: NSError(domain: "dd", code: 87))
                    }
                }
                XCTFail()
            } catch is CancellationError {
                expectation2.fulfill()
            } catch {
                XCTFail()
            }
        }
        try await Task.sleep(nanoseconds: UInt64(0.1 * 1_000_000_000))
        task.cancel()
        await self.fulfillment(of: [expectation1, expectation2])
        try await Task.sleep(nanoseconds: UInt64(0.5 * 1_000_000_000))
    }
    
}
