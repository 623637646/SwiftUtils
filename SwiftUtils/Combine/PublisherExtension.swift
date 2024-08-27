//
//  PublisherExtension.swift
//  SwiftUtils
//
//  Created by Wang Ya on 18/8/23.
//

import Foundation
import Combine

extension Publisher {
    
    /// AnyPublisher to async. ( use AsyncPublisher after iOS 15.)
    /// Refer to: https://medium.com/geekculture/from-combine-to-async-await-c08bf1d15b77
    /// - Parameter stop: chekc if stop, returnning nil means continue.
    /// - Throws: Throw `CancellationError` if the Task is be cancelled. Throws error if Publisher throws.
    /// - Returns: Return nil if the Publisher is finished. Return T if stopped.
    public func waitUntilStop<T>(stop: @escaping ((_ value: Output) throws -> T?)) async throws -> T? {
        var cancellable: AnyCancellable?
        defer {
            cancellable?.cancel()
        }
        return try await withCheckedThrowingCancellableContinuation { continuation in
            var resumed = false
            cancellable = self.sink(receiveCompletion: { result in
                guard !resumed else { return }
                resumed = true
                switch result {
                case .finished:
                    continuation.resume(returning: nil)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }, receiveValue: { value in
                guard !resumed else { return }
                do {
                    guard let result = try stop(value) else { return }
                    // Stop
                    resumed = true
                    continuation.resume(returning: result)
                } catch {
                    resumed = true
                    continuation.resume(throwing: error)
                }
            })
        }
    }
    
    /// Get next value.
    /// - Throws: Throw `CancellationError` if the Task is be cancelled. Throws error if Publisher throws.
    /// - Returns: Return nil if the Publisher is finished. Return Output if get value.
    public func next() async throws -> Output? {
        try await self.waitUntilStop { $0 }
    }
    
    /// Applies a transformation to each element emitted by the publisher, but drops all subsequent elements until the last transformation completes.
    /// - Parameter transform: A closure that takes an element emitted by the publisher and returns a new publisher.
    /// - Returns: A publisher that emits elements from the last completed transformation.
    public func flatMapAndDropUntilLastCompleted<P>(_ transform: @escaping (Self.Output) -> P) -> AnyPublisher<P.Output, P.Failure> where P: Publisher, Self.Failure == P.Failure {
        var drop = false
        return self.flatMap { output in
            if drop {
                return Empty<P.Output, P.Failure>().eraseToAnyPublisher()
            } else {
                drop = true
                return transform(output).handleEvents(receiveCompletion: { _ in
                    drop = false
                }).eraseToAnyPublisher()
            }
        }.eraseToAnyPublisher()
    }
    
    
    ///  Drops elements emitted by the publisher until the asynchronous task associated with each element is completed.
    /// - Parameter task: A closure that takes an element emitted by the publisher and returns an asynchronous task.
    /// - Returns: A publisher that emits the results of the completed tasks.
    public func dropUntilTaskCompleted<T>(_ task: @escaping (Self.Output) async -> T) -> AnyPublisher<T, Self.Failure> {
        flatMapAndDropUntilLastCompleted { output in
            var token: Task<(), Never>?
            return Future<T, Self.Failure> { promise in
                token = Task {
                    let result = await task(output)
                    promise(.success(result))
                }
            }.handleEvents(receiveCancel: {
                token?.cancel()
            })
        }
    }

    ///  Drops elements emitted by the publisher until the asynchronous task associated with each element is completed or throws.
    /// - Parameter task: A closure that takes an element emitted by the publisher and returns an asynchronous task.
    /// - Returns: A publisher that emits the results of the completed tasks.
    public func dropUntilThrowingTaskCompleted<T>(_ task: @escaping (Self.Output) async throws -> T) -> AnyPublisher<T, Error> where Self.Failure == Error {
        flatMapAndDropUntilLastCompleted { output in
            var token: Task<(), Never>?
            return Future<T, Self.Failure> { promise in
                token = Task {
                    do {
                        let result = try await task(output)
                        promise(.success(result))
                    } catch {
                        promise(.failure(error))
                    }
                }
            }.handleEvents(receiveCancel: {
                token?.cancel()
            })
        }
    }
}

extension Publishers {
    
    /// `CombineLatestArray` is a custom Publisher that takes an array of Publishers and combines their latest outputs into a single array. Refer to: https://stackoverflow.com/a/67099668/9315497
    public struct CombineLatestArray<P>: Publisher where P: Publisher {
        public typealias Output = [P.Output]
        public typealias Failure = P.Failure
        
        let publishers: [P]
        
        init(publishers: [P]) {
            self.publishers = publishers
        }
        
        public func receive<S>(subscriber: S) where S : Subscriber, P.Failure == S.Failure, [P.Output] == S.Input {
            guard !publishers.isEmpty else {
                subscriber.receive(completion: .finished)
                return
            }
            publishers.dropFirst().reduce(into: publishers[0].map{[$0]}.eraseToAnyPublisher()) {
                res, ob in
                res = res.combineLatest(ob) {
                    i1, i2 -> [P.Output] in
                    return i1 + [i2]
                }.eraseToAnyPublisher()
            }.subscribe(subscriber)
        }
    }
    
}
