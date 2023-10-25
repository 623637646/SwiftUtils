# SwiftUtils

## [Race](Concurrency/Race.swift)
Race for async operations. First finished operation wins, cancel the other operations.

## Timeout
Execute an operation in the current task subject to a timeout.

## withCheckedThrowingCancellableContinuation
The normal swift concurrency API withCheckedThrowingContinuation  will not stop when the Task is cancelled.
This API  withCheckedThrowingCancellableContinuation will throw CancellationError when the Task is cancelled.

## Publisher waitUntilStop
AnyPublisher to async. ( use AsyncPublisher after iOS 15.)

## Publisher next
Get the next value from Publisher.

## ReadOnlyCurrentValueSubject
CurrentValueSubject is readable and writable, ReadOnlyCurrentValueSubjectis only writable in the current module. It's not writable outside the current module.

## CodableExtension
Dictionary from or to Model and Array from or to Models
