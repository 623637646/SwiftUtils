//
//  Timeout.swift
//  OKBase
//
//  Created by Wang Ya on 16/10/23.
//

import Foundation

/// https://forums.swift.org/t/running-an-async-task-with-a-timeout/49733/12
/// Execute an operation in the current task subject to a timeout.
///
/// - Parameters:
///   - seconds: The duration in seconds `operation` is allowed to run before timing out.
///   - operation: The async operation to perform.
/// - Returns: Returns the result of `operation` if it completed in time.
/// - Throws: Throws ``TimedOutError`` if the timeout expires before `operation` completes.
///   If `operation` throws an error before the timeout expires, that error is propagated to the caller.
public func withTimeout<R>(
    seconds: TimeInterval,
    timeoutError: Error,
    operation: @escaping @Sendable () async throws -> R
) async throws -> R {
    guard seconds > 0 else {
        return try await operation()
    }
    let deadline = Date(timeIntervalSinceNow: seconds)
    
    return try await withRace(operations: [
        // Start actual work.
        operation,
        // Start timeout child task.
        {
            let interval = deadline.timeIntervalSinceNow
            if interval > 0 {
                try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
            // We’ve reached the timeout.
            throw timeoutError
        }
    ])
}
