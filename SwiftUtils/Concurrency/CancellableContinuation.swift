//
//  CancellableContinuation.swift
//  OKBase
//
//  Created by Wang Ya on 16/10/23.
//

import Foundation

/// Cancellable withCheckedThrowingContinuation
/// - Parameters:
///   - function: A string identifying the declaration that is the notional
///     source for the continuation, used to identify the continuation in
///     runtime diagnostics related to misuse of this continuation.
///   - body: A closure that takes a `CancellableCheckedContinuation` parameter.
///     You must resume the continuation exactly once.
/// - Throws: Throw `CancellationError` if the Task is be cancelled. Throws error if withCheckedThrowingContinuation throws.
/// - Returns: withCheckedThrowingContinuation's return
public func withCheckedThrowingCancellableContinuation<T>(function: String = #function, body: (CancellableCheckedContinuation<T, Error>) -> Void) async throws -> T {
    let cancellableCheckedContinuation = CancellableCheckedContinuation<T, Error>()
    try Task.checkCancellation()
    return try await withTaskCancellationHandler(operation: {
        try Task.checkCancellation()
        return try await withCheckedThrowingContinuation(function: function) { continuation in
            body(cancellableCheckedContinuation)
            Task {
                await cancellableCheckedContinuation.bindCheckedContinuation(continuation)
            }
        }
    }, onCancel: {
        cancellableCheckedContinuation.resume(throwing: CancellationError())
    })
}

public actor CancellableCheckedContinuation<T, E> : Sendable where E : Error {
    
    enum State {
        case initialize
        case pending(continuation: CheckedContinuation<T, E>)
        case returning(result: T)
        case throwing(error: E)
        case returned
        case thrown(error: E)
    }
    
    private var state = State.initialize
    
    func bindCheckedContinuation(_ checkedContinuation: CheckedContinuation<T, E>){
        switch self.state {
        case .initialize:
            // call `bindCheckedContinuation` first
            self.state = .pending(continuation: checkedContinuation)
        case .pending(_):
            assertionFailure("Duplicated bindCheckedContinuation")
            break
        case .returning(result: let result):
            // call `returning` first, then call `bindCheckedContinuation`
            checkedContinuation.resume(returning: result)
            self.state = .returned
        case .throwing(error: let error):
            // call `throwing` first, then call `bindCheckedContinuation`
            checkedContinuation.resume(throwing: error)
            self.state = .thrown(error: error)
        case .returned:
            assertionFailure("Call bindCheckedContinuation after returned")
        case .thrown:
            assertionFailure("Call bindCheckedContinuation after thrown")
        }
    }
    
    /// Resume the task awaiting the continuation by having it return normally
    /// from its suspension point.
    ///
    /// - Parameter value: The value to return from the continuation.
    ///
    /// A continuation must be resumed exactly once. If the continuation has
    /// already been resumed through this object, then the attempt to resume
    /// the continuation will trap.
    ///
    /// After `resume` enqueues the task, control immediately returns to
    /// the caller. The task continues executing when its executor is
    /// able to reschedule it.
    func isolatedResume(returning value: T) {
        switch self.state {
        case .initialize:
            // call `returning` first
            self.state = .returning(result: value)
        case .pending(continuation: let continuation):
            // call `bindCheckedContinuation` first, then call `returning`
            continuation.resume(returning: value)
            self.state = .returned
        case .returning(result: _):
            assertionFailure("Duplicated returning")
            break
        case .throwing(error: let error):
            switch error {
            case is CancellationError:
                // call `cancel` first, then call `returning`
                break
            default:
                // call `throwing` first, then call `returning`
                assertionFailure("Call returning after throwing")
                break
            }
        case .returned:
            assertionFailure("Call returning after returned")
            break
        case .thrown(error: let error):
            switch error {
            case is CancellationError:
                // cancelled, then call `returning`
                break
            default:
                // thrown, then call `returning`
                assertionFailure("Call returning after thrown")
                break
            }
        }
    }
    
    public nonisolated func resume(returning value: T) {
        Task {
            await self.isolatedResume(returning: value)
        }
    }
    
    /// Resume the task awaiting the continuation by having it throw an error
    /// from its suspension point.
    ///
    /// - Parameter error: The error to throw from the continuation.
    ///
    /// A continuation must be resumed exactly once. If the continuation has
    /// already been resumed through this object, then the attempt to resume
    /// the continuation will trap.
    ///
    /// After `resume` enqueues the task, control immediately returns to
    /// the caller. The task continues executing when its executor is
    /// able to reschedule it.
    private func isolatedResume(throwing error: E) {
        switch error {
        case is CancellationError:
            switch self.state {
            case .initialize:
                // call `cancel` first
                self.state = .throwing(error: error)
            case .pending(continuation: let continuation):
                // call `bindCheckedContinuation` first, then call `cancel`
                continuation.resume(throwing: error)
                self.state = .thrown(error: error)
            case .returning(result: _):
                // call `returning` first, then call `cancel`
                break
            case .throwing(error: _):
                // call `throwing` first, then call `cancel`
                break
            case .returned:
                // returned, then call `cancel`
                break
            case .thrown:
                // thrown, then call `cancel`
                break
            }
        default:
            switch self.state {
            case .initialize:
                // call `throwing` first
                self.state = .throwing(error: error)
            case .pending(continuation: let continuation):
                // call `bindCheckedContinuation` first, then call `throwing`
                continuation.resume(throwing: error)
                self.state = .thrown(error: error)
            case .returning:
                // call `returning` first, then call `throwing`
                assertionFailure("Call throwing after returning")
                break
            case .throwing(error: let errorInState):
                switch errorInState {
                case is CancellationError:
                    // call `cancel` first, then call `throwing`
                    break
                default:
                    // call `throwing` first, then call `throwing`
                    assertionFailure("Call throwing after throwing")
                    break
                }
            case .returned:
                // returned, then call `throwing`
                assertionFailure("returned, then call `throwing`")
                break
            case .thrown:
                // thrown, then call `throwing`
                assertionFailure("thrown, then call `throwing`")
                break
            }
        }
    }
    
    public nonisolated func resume(throwing error: E) {
        Task {
            await self.isolatedResume(throwing: error)
        }
    }
}
