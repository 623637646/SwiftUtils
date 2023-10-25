//
//  PublisherExtension.swift
//  OneKey-Swift
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
}
