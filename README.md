# SwiftUtils

## [Race](SwiftUtils/Concurrency/Race.swift)
Race for async operations. First finished operation wins, cancel the other operations.

## [Timeout](SwiftUtils/Concurrency/Timeout.swift)
Execute an operation in the current task subject to a timeout.

## [withCheckedThrowingCancellableContinuation](SwiftUtils/Concurrency/CancellableContinuation.swift)
The normal swift concurrency API withCheckedThrowingContinuation  will not stop when the Task is cancelled.
This API  withCheckedThrowingCancellableContinuation will throw CancellationError when the Task is cancelled.

## [Publisher waitUntilStop](SwiftUtils/Combine/PublisherExtension.swift)
AnyPublisher to async. ( use AsyncPublisher after iOS 15.)

## [Publisher next](SwiftUtils/Combine/PublisherExtension.swift)
Get the next value from Publisher.

## [ReadOnlyCurrentValueSubject](SwiftUtils/Combine/ReadOnlyCurrentValueSubject.swift)
CurrentValueSubject is readable and writable, ReadOnlyCurrentValueSubjectis only writable in the current module. It's not writable outside the current module.

## [CodableExtension](SwiftUtils/CodableExtension.swift)
Dictionary from or to Model and Array from or to Models
