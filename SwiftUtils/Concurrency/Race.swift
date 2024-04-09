//
//  Race.swift
//  SwiftUtils
//
//  Created by Wang Ya on 16/10/23.
//

import Foundation

/// Race for operations. First finished operation wins, cancel the other operations.
public func withRace<R>(
    operations: [@Sendable () async throws -> R]
) async throws -> R {
    return try await withThrowingTaskGroup(of: R.self) { group in
        
        for operation in operations {
            group.addTask(operation: operation)
        }
        
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
