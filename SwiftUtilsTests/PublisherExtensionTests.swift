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
    
    func testFlatMapAndDropUntilLastCompleted() async throws {
        let subject = PassthroughSubject<Int, Never>()
        Task {
            for i in 0 ... 10 {
                try await Task.sleep(nanoseconds: 10_000_000)
                subject.send(i)
            }
            subject.send(completion: .finished)
        }
        let publisher = subject.flatMapAndDropUntilLastCompleted { i in
            let subject = PassthroughSubject<Int, Never>()
            Task {
                try await Task.sleep(nanoseconds: UInt64(15_000_000))
                subject.send(i)
                subject.send(-i)
                subject.send(completion: .finished)
            }
            return subject
        }
        var result = [Int]()
        for await value in publisher.values {
            result.append(value)
        }
        XCTAssertEqual(result, [0, 0, 2, -2, 4, -4, 6, -6, 8, -8, 10, -10])
    }
    
    func testFlatMapAndDropUntilLastCompletedFailure() async throws {
        let subject = PassthroughSubject<Int, NSError>()
        Task {
            for i in 0 ... 10 {
                try await Task.sleep(nanoseconds: 10_000_000)
                subject.send(i)
            }
            subject.send(completion: .finished)
        }
        let publisher = subject.flatMapAndDropUntilLastCompleted { i in
            let subject = PassthroughSubject<Int, NSError>()
            Task {
                try await Task.sleep(nanoseconds: UInt64(15_000_000))
                subject.send(i)
                try await Task.sleep(nanoseconds: UInt64(1_000_000))
                subject.send(-i)
                try await Task.sleep(nanoseconds: UInt64(1_000_000))
                if i == 4 {
                    subject.send(completion: .failure(NSError(domain: "cc", code: 78)))
                } else {
                    subject.send(completion: .finished)
                }
            }
            return subject
        }
        var result = [Int]()
        do {
            for try await value in publisher.values {
                result.append(value)
            }
        } catch {
            XCTAssertEqual(result, [0, 0, 2, -2, 4, -4])
            XCTAssertEqual(error as NSError, NSError(domain: "cc", code: 78))
        }
    }
    
    func testDropUntilTaskCompleted() async throws {
        let subject = PassthroughSubject<Int, Never>()
        Task {
            for i in 0 ... 10 {
                try await Task.sleep(nanoseconds: 10_000_000)
                subject.send(i)
            }
            subject.send(completion: .finished)
        }
        let publisher = subject.dropUntilTaskCompleted { i in
            try! await Task.sleep(nanoseconds: UInt64(15_000_000))
            return i
        }
        var result = [Int]()
        for await value in publisher.values {
            result.append(value)
        }
        XCTAssertEqual(result, [0, 2, 4, 6, 8, 10])
    }
    
    func testDropUntilTaskCompletedCancelled() throws {
        let subject = PassthroughSubject<Int, Never>()
        Task {
            try await Task.sleep(nanoseconds: 10_000_000)
            subject.send(0)
            try await Task.sleep(nanoseconds: 10_000_000)
            subject.send(1)
            try await Task.sleep(nanoseconds: 10_000_000)
            subject.send(2)
            try await Task.sleep(nanoseconds: 10_000_000)
            subject.send(3)
            try await Task.sleep(nanoseconds: 10_000_000)
            subject.send(completion: .finished)
        }
        let exp3rd = expectation(description: "3rd is run")
        let publisher = subject.dropUntilTaskCompleted { i in
            switch i {
            case 0:
                try! await Task.sleep(nanoseconds: UInt64(15_000_000))
                break
            case 1:
                XCTFail()
                break
            case 2:
                break
            case 3:
                do {
                    try await Task.sleep(nanoseconds: UInt64(10_000_000))
                    XCTFail()
                } catch {
                    XCTAssertEqual(error is CancellationError, true)
                }
                XCTAssertEqual(Task.isCancelled, true)
                exp3rd.fulfill()
                break
            default :
                break
            }
            return i
        }
        
        var result = [Int]()
        var cancellable: AnyCancellable?
        let expSink = expectation(description: "sink finish or cancelled")
        cancellable = publisher.handleEvents(receiveCancel: {
            expSink.fulfill()
        }).sink(receiveCompletion: { completion in
            switch completion {
            case .finished:
                expSink.fulfill()
            }
        }, receiveValue: { value in
            result.append(value)
            if value == 2 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.015, execute: {
                    cancellable?.cancel()
                })
            }
        })
        waitForExpectations(timeout: 3)
        XCTAssertEqual(result, [0, 2])
    }
    
    func testDropUntilThrowingTaskCompleted() async throws {
        let subject = PassthroughSubject<Int, Error>()
        Task {
            for i in 0 ... 10 {
                try await Task.sleep(nanoseconds: 10_000_000)
                subject.send(i)
            }
            subject.send(completion: .finished)
        }
        let publisher = subject.dropUntilThrowingTaskCompleted { i in
            try await Task.sleep(nanoseconds: UInt64(15_000_000))
            return i
        }
        var result = [Int]()
        for try await value in publisher.values {
            result.append(value)
        }
        XCTAssertEqual(result, [0, 2, 4, 6, 8, 10])
    }
    
    func testDropUntilThrowingTaskCompletedFailure() async throws {
        let subject = PassthroughSubject<Int, Error>()
        Task {
            for i in 0 ... 10 {
                try await Task.sleep(nanoseconds: 10_000_000)
                subject.send(i)
            }
            subject.send(completion: .finished)
        }
        let publisher = subject.dropUntilThrowingTaskCompleted { i in
            try await Task.sleep(nanoseconds: UInt64(15_000_000))
            if i == 4 {
                throw NSError(domain: "kk", code: 889)
            }
            return i
        }
        var result = [Int]()
        do {
            for try await value in publisher.values {
                result.append(value)
            }
        } catch {
            XCTAssertEqual(result, [0, 2])
            XCTAssertEqual(error as NSError, NSError(domain: "kk", code: 889))
        }
    }
    
    func testDropUntilThrowingTaskCompletedCancelled() throws {
        let subject = PassthroughSubject<Int, Error>()
        Task {
            try await Task.sleep(nanoseconds: 10_000_000)
            subject.send(0)
            try await Task.sleep(nanoseconds: 10_000_000)
            subject.send(1)
            try await Task.sleep(nanoseconds: 10_000_000)
            subject.send(2)
            try await Task.sleep(nanoseconds: 10_000_000)
            subject.send(3)
            try await Task.sleep(nanoseconds: 10_000_000)
            subject.send(completion: .finished)
        }
        let exp3rd = expectation(description: "3rd is run")
        let publisher = subject.dropUntilThrowingTaskCompleted { i in
            switch i {
            case 0:
                try await Task.sleep(nanoseconds: UInt64(15_000_000))
                break
            case 1:
                XCTFail()
                break
            case 2:
                break
            case 3:
                do {
                    try await Task.sleep(nanoseconds: UInt64(10_000_000))
                    XCTFail()
                } catch {
                    XCTAssertEqual(error is CancellationError, true)
                }
                XCTAssertEqual(Task.isCancelled, true)
                exp3rd.fulfill()
                break
            default :
                break
            }
            return i
        }
        
        var result = [Int]()
        var cancellable: AnyCancellable?
        let expSink = expectation(description: "sink finish or cancelled")
        cancellable = publisher.handleEvents(receiveCancel: {
            expSink.fulfill()
        }).sink(receiveCompletion: { completion in
            switch completion {
            case .finished:
                expSink.fulfill()
            case .failure(_):
                XCTFail()
            }
        }, receiveValue: { value in
            result.append(value)
            if value == 2 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.015, execute: {
                    cancellable?.cancel()
                })
            }
        })
        waitForExpectations(timeout: 3)
        XCTAssertEqual(result, [0, 2])
    }
    
    func testCombineLatestArrayNormal() {
        let obs1 = PassthroughSubject<Int,Never>()
        let obs2 = PassthroughSubject<Int,Never>()
        let obs3 = PassthroughSubject<Int,Never>()
        
        let arr = [obs1, obs2, obs3]
        let pub = Publishers.CombineLatestArray(publishers: arr)
        
        var lastValue: [Int]?
        var completion: Subscribers.Completion<Never>?
        
        let cancellable = pub.sink(receiveCompletion: { r in
            completion = r
        }, receiveValue: { value in
            lastValue = value
        })
        _ = cancellable
        
        XCTAssertEqual(lastValue, nil)
        XCTAssertEqual(completion, nil)
        
        obs1.send(5)
        XCTAssertEqual(lastValue, nil)
        XCTAssertEqual(completion, nil)
        
        obs2.send(10)
        XCTAssertEqual(lastValue, nil)
        XCTAssertEqual(completion, nil)
        
        obs3.send(1)
        XCTAssertEqual(lastValue, [5, 10, 1])
        XCTAssertEqual(completion, nil)
        
        obs1.send(12)
        XCTAssertEqual(lastValue, [12, 10, 1])
        XCTAssertEqual(completion, nil)
        
        obs3.send(20)
        XCTAssertEqual(lastValue, [12, 10, 20])
        XCTAssertEqual(completion, nil)
    }
    
    func testCombineLatestArrayEmpty() {
        let pub = Publishers.CombineLatestArray(publishers: [PassthroughSubject<Int,Never>]())
        
        var lastValue: [Int]?
        var completion: Subscribers.Completion<Never>?
        
        let cancellable = pub.sink(receiveCompletion: { r in
            completion = r
        }, receiveValue: { value in
            lastValue = value
        })
        _ = cancellable
        
        XCTAssertEqual(lastValue, nil)
        XCTAssertEqual(completion, .finished)
    }
    
    func testCombineLatestArrayOne() {
        let obs1 = PassthroughSubject<Int,Never>()
        
        let arr = [obs1]
        let pub = Publishers.CombineLatestArray(publishers: arr)
        
        var lastValue: [Int]?
        var completion: Subscribers.Completion<Never>?
        
        let cancellable = pub.sink(receiveCompletion: { r in
            completion = r
        }, receiveValue: { value in
            lastValue = value
        })
        _ = cancellable
        
        XCTAssertEqual(lastValue, nil)
        XCTAssertEqual(completion, nil)
        
        obs1.send(5)
        XCTAssertEqual(lastValue, [5])
        XCTAssertEqual(completion, nil)
        
        obs1.send(12)
        XCTAssertEqual(lastValue, [12])
        XCTAssertEqual(completion, nil)
    }
    
}
