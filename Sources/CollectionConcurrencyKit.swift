/**
*  CollectionConcurrencyKit
*  Copyright (c) John Sundell 2021
*  MIT license, see LICENSE.md file for details
*/

/// Minimum changes required to make the code compilable using `Xcode 16.4` and `Swift 6.0`
#if swift(<6.2)
/// Equals to `Any` when Swift version is less than `6.2`
public typealias SendableMetatype = Any
#endif

// MARK: - ForEach

public extension Sequence where Element: Sendable, Self: SendableMetatype {
    /// Run an async closure for each element within the sequence.
    ///
    /// The closure calls will be performed in order, by waiting for
    /// each call to complete before proceeding with the next one. If
    /// any of the closure calls throw an error, then the iteration
    /// will be terminated and the error rethrown.
    ///
    /// - parameter operation: The closure to run for each element.
    /// - throws: Rethrows any error thrown by the passed closure.
    func asyncForEach(
        _ operation: (Element) async throws -> Void
    ) async rethrows {
        for element in self {
            try await operation(element)
        }
    }

    /// Run an async closure for each element within the sequence.
    ///
    /// The closure calls will be performed concurrently, but the call
    /// to this function won't return until all of the closure calls
    /// have completed.
    ///
    /// - parameter priority: Any specific `TaskPriority` to assign to
    ///   the async tasks that will perform the closure calls. The
    ///   default is `nil` (meaning that the system picks a priority).
    /// - parameter operation: The closure to run for each element.
    func concurrentForEach(
        withPriority priority: TaskPriority? = nil,
        _ operation: @Sendable (Element) async -> Void
    ) async {
        await withoutActuallyEscaping(operation) { escapableOperation in
            await withTaskGroup(of: Void.self) { group in
                for element in self {
                    group.addTask(priority: priority) {
                        await escapableOperation(element)
                    }
                }
            }
        }
    }

    /// Run an async closure for each element within the sequence.
    ///
    /// The closure calls will be performed concurrently, but the call
    /// to this function won't return until all of the closure calls
    /// have completed. If any of the closure calls throw an error,
    /// then the first error will be rethrown once all closure calls have
    /// completed.
    ///
    /// - parameter priority: Any specific `TaskPriority` to assign to
    ///   the async tasks that will perform the closure calls. The
    ///   default is `nil` (meaning that the system picks a priority).
    /// - parameter operation: The closure to run for each element.
    /// - throws: Rethrows any error thrown by the passed closure.
    func concurrentForEach(
        withPriority priority: TaskPriority? = nil,
        _ operation: @Sendable (Element) async throws -> Void
    ) async throws {
        try await withoutActuallyEscaping(operation) { escapableOperation in
            try await withThrowingTaskGroup(of: Void.self) { group in
                for element in self {
                    group.addTask(priority: priority) {
                        try await escapableOperation(element)
                    }
                }

                // Propagate any errors thrown by the group's tasks:
                for try await _ in group {}
            }
        }
    }
}

// MARK: - Map

public extension Sequence where Element: Sendable, Self: SendableMetatype {
    /// Transform the sequence into an array of new values using
    /// an async closure.
    ///
    /// The closure calls will be performed in order, by waiting for
    /// each call to complete before proceeding with the next one. If
    /// any of the closure calls throw an error, then the iteration
    /// will be terminated and the error rethrown.
    ///
    /// - parameter transform: The transform to run on each element.
    /// - returns: The transformed values as an array. The order of
    ///   the transformed values will match the original sequence.
    /// - throws: Rethrows any error thrown by the passed closure.
	func asyncMap<T: Sendable>(
        _ transform: (Element) async throws -> T,
        isolation: isolated (any Actor)? = #isolation
    ) async rethrows -> [T] {
        var values = [T]()

        for element in self {
            try await values.append(transform(element))
        }

        return values
    }

    /// Transform the sequence into an array of new values using
    /// an async closure.
    ///
    /// The closure calls will be performed concurrently, but the call
    /// to this function won't return until all of the closure calls
    /// have completed.
    ///
    /// - parameter priority: Any specific `TaskPriority` to assign to
    ///   the async tasks that will perform the closure calls. The
    ///   default is `nil` (meaning that the system picks a priority).
    /// - parameter transform: The transform to run on each element.
    /// - returns: The transformed values as an array. The order of
    ///   the transformed values will match the original sequence.
    func concurrentMap<T: Sendable>(
        withPriority priority: TaskPriority? = nil,
        _ transform: @Sendable (Element) async -> T
    ) async -> [T] {
        await withoutActuallyEscaping(transform) { escapableTransform in
            let tasks = map { element in
                Task(priority: priority) {
                    await escapableTransform(element)
                }
            }

            return await tasks.asyncMap { task in
                await task.value
            }
        }
    }

    /// Transform the sequence into an array of new values using
    /// an async closure.
    ///
    /// The closure calls will be performed concurrently, but the call
    /// to this function won't return until all of the closure calls
    /// have completed. If any of the closure calls throw an error,
    /// then the first error will be rethrown once all closure calls have
    /// completed.
    ///
    /// - parameter priority: Any specific `TaskPriority` to assign to
    ///   the async tasks that will perform the closure calls. The
    ///   default is `nil` (meaning that the system picks a priority).
    /// - parameter transform: The transform to run on each element.
    /// - returns: The transformed values as an array. The order of
    ///   the transformed values will match the original sequence.
    /// - throws: Rethrows any error thrown by the passed closure.
    func concurrentMap<T: Sendable>(
        withPriority priority: TaskPriority? = nil,
        _ transform: @Sendable (Element) async throws -> T
    ) async throws -> [T] {
        try await withoutActuallyEscaping(transform) { escapableTransform in
            let tasks = map { element in
                Task(priority: priority) {
                    try await escapableTransform(element)
                }
            }

            return try await tasks.asyncMap { task in
                try await task.value
            }
        }
    }
}

// MARK: - CompactMap

public extension Sequence where Element: Sendable, Self: SendableMetatype {
    /// Transform the sequence into an array of new values using
    /// an async closure that returns optional values. Only the
    /// non-`nil` return values will be included in the new array.
    ///
    /// The closure calls will be performed in order, by waiting for
    /// each call to complete before proceeding with the next one. If
    /// any of the closure calls throw an error, then the iteration
    /// will be terminated and the error rethrown.
    ///
    /// - parameter transform: The transform to run on each element.
    /// - returns: The transformed values as an array. The order of
    ///   the transformed values will match the original sequence,
    ///   except for the values that were transformed into `nil`.
    /// - throws: Rethrows any error thrown by the passed closure.
	func asyncCompactMap<T: Sendable>(
        _ transform: (Element) async throws -> T?,
        isolation: isolated (any Actor)? = #isolation
    ) async rethrows -> [T] {
        var values = [T]()

        for element in self {
            guard let value = try await transform(element) else {
                continue
            }

            values.append(value)
        }

        return values
    }

    /// Transform the sequence into an array of new values using
    /// an async closure that returns optional values. Only the
    /// non-`nil` return values will be included in the new array.
    ///
    /// The closure calls will be performed concurrently, but the call
    /// to this function won't return until all of the closure calls
    /// have completed.
    ///
    /// - parameter priority: Any specific `TaskPriority` to assign to
    ///   the async tasks that will perform the closure calls. The
    ///   default is `nil` (meaning that the system picks a priority).
    /// - parameter transform: The transform to run on each element.
    /// - returns: The transformed values as an array. The order of
    ///   the transformed values will match the original sequence,
    ///   except for the values that were transformed into `nil`.
    func concurrentCompactMap<T: Sendable>(
        withPriority priority: TaskPriority? = nil,
        _ transform: @Sendable (Element) async -> T?
    ) async -> [T] {
        await withoutActuallyEscaping(transform) { escapableTransform in
            let tasks = map { element in
                Task(priority: priority) {
                    await escapableTransform(element)
                }
            }

            return await tasks.asyncCompactMap { task in
                await task.value
            }
        }
    }

    /// Transform the sequence into an array of new values using
    /// an async closure that returns optional values. Only the
    /// non-`nil` return values will be included in the new array.
    ///
    /// The closure calls will be performed concurrently, but the call
    /// to this function won't return until all of the closure calls
    /// have completed. If any of the closure calls throw an error,
    /// then the first error will be rethrown once all closure calls have
    /// completed.
    ///
    /// - parameter priority: Any specific `TaskPriority` to assign to
    ///   the async tasks that will perform the closure calls. The
    ///   default is `nil` (meaning that the system picks a priority).
    /// - parameter transform: The transform to run on each element.
    /// - returns: The transformed values as an array. The order of
    ///   the transformed values will match the original sequence,
    ///   except for the values that were transformed into `nil`.
    /// - throws: Rethrows any error thrown by the passed closure.
    func concurrentCompactMap<T: Sendable>(
        withPriority priority: TaskPriority? = nil,
        _ transform: @Sendable (Element) async throws -> T?
    ) async throws -> [T] {
        try await withoutActuallyEscaping(transform) { escapableTransform in
            let tasks = map { element in
                Task(priority: priority) {
                    try await escapableTransform(element)
                }
            }

            return try await tasks.asyncCompactMap { task in
                try await task.value
            }
        }
    }
}

// MARK: - FlatMap

public extension Sequence where Element: Sendable, Self: SendableMetatype {
    /// Transform the sequence into an array of new values using
    /// an async closure that returns sequences. The returned sequences
    /// will be flattened into the array returned from this function.
    ///
    /// The closure calls will be performed in order, by waiting for
    /// each call to complete before proceeding with the next one. If
    /// any of the closure calls throw an error, then the iteration
    /// will be terminated and the error rethrown.
    ///
    /// - parameter transform: The transform to run on each element.
    /// - returns: The transformed values as an array. The order of
    ///   the transformed values will match the original sequence,
    ///   with the results of each closure call appearing in-order
    ///   within the returned array.
    /// - throws: Rethrows any error thrown by the passed closure.
	func asyncFlatMap<T: Sequence & Sendable>(
        _ transform: (Element) async throws -> T,
        isolation: isolated (any Actor)? = #isolation
    ) async rethrows -> [T.Element] {
        var values = [T.Element]()

        for element in self {
            try await values.append(contentsOf: transform(element))
        }

        return values
    }

    /// Transform the sequence into an array of new values using
    /// an async closure that returns sequences. The returned sequences
    /// will be flattened into the array returned from this function.
    ///
    /// The closure calls will be performed concurrently, but the call
    /// to this function won't return until all of the closure calls
    /// have completed.
    ///
    /// - parameter priority: Any specific `TaskPriority` to assign to
    ///   the async tasks that will perform the closure calls. The
    ///   default is `nil` (meaning that the system picks a priority).
    /// - parameter transform: The transform to run on each element.
    /// - returns: The transformed values as an array. The order of
    ///   the transformed values will match the original sequence,
    ///   with the results of each closure call appearing in-order
    ///   within the returned array.
    func concurrentFlatMap<T: Sequence & Sendable>(
        withPriority priority: TaskPriority? = nil,
        _ transform: @Sendable (Element) async -> T
    ) async -> [T.Element] {
        await withoutActuallyEscaping(transform) { escapableTransform in
            let tasks = map { element in
                Task(priority: priority) {
                    await escapableTransform(element)
                }
            }

            return await tasks.asyncFlatMap { task in
                await task.value
            }
        }
    }

    /// Transform the sequence into an array of new values using
    /// an async closure that returns sequences. The returned sequences
    /// will be flattened into the array returned from this function.
    ///
    /// The closure calls will be performed concurrently, but the call
    /// to this function won't return until all of the closure calls
    /// have completed. If any of the closure calls throw an error,
    /// then the first error will be rethrown once all closure calls have
    /// completed.
    ///
    /// - parameter priority: Any specific `TaskPriority` to assign to
    ///   the async tasks that will perform the closure calls. The
    ///   default is `nil` (meaning that the system picks a priority).
    /// - parameter transform: The transform to run on each element.
    /// - returns: The transformed values as an array. The order of
    ///   the transformed values will match the original sequence,
    ///   with the results of each closure call appearing in-order
    ///   within the returned array.
    /// - throws: Rethrows any error thrown by the passed closure.
    func concurrentFlatMap<T: Sequence & Sendable>(
        withPriority priority: TaskPriority? = nil,
        _ transform: @Sendable (Element) async throws -> T
    ) async throws -> [T.Element] {
        try await withoutActuallyEscaping(transform) { escapableTransform in
            let tasks = map { element in
                Task(priority: priority) {
                    try await escapableTransform(element)
                }
            }

            return try await tasks.asyncFlatMap { task in
                try await task.value
            }
        }
    }
}

// MARK: - Filter

public extension Sequence where Element: Sendable, Self: SendableMetatype {
    /// Filter the sequence into an array of new values using
    /// an async predicate closure that returns booleans.
    ///
    /// The closure calls will be performed in order, by waiting for
    /// each call to complete before proceeding with the next one. If
    /// any of the closure calls throw an error, then the iteration
    /// will be terminated and the error rethrown.
    ///
    /// - Parameter isIncluded: A closure that takes an element of the sequence as its argument and returns a Boolean value indicating whether the element should be included in the returned array.
    ///
    /// - Returns: An array of the elements that isIncluded allowed.
    func asyncFilter(_ isIncluded: (Element) async throws -> Bool) async rethrows -> [Element] {
        var result: [Element] = []
        
        for element in self where try await isIncluded(element) {
            result.append(element)
        }
        
        return result
    }
    
    /// Filter the sequence into an array of new values using
    /// an async predicate closure that returns booleans.
    ///
    /// - Parameters:
    ///   - withPriority: Any specific `TaskPriority` to assign to
    ///   the async tasks that will perform the closure calls. The
    ///   default is `nil` (meaning that the system picks a priority).
    ///   - isIncluded: A closure that takes an element of the
    ///   sequence as its argument and returns a Boolean value indicating
    ///   whether the element should be included in the returned array.
    ///
    /// - Returns: An array of the elements that isIncluded allowed.
	func concurrentFilter(
		withPriority priority: TaskPriority? = nil,
		_ isIncluded: @Sendable (Element) async throws -> Bool
	) async rethrows -> [Element] {
		try await withoutActuallyEscaping(isIncluded) { escapableIsIncluded in
			try await withThrowingTaskGroup { group in
				let enumeration = self.enumerated()
				
				var count = 0
				for (index, element) in enumeration {
					count += 1
					
					group.addTask(priority: priority) {
						try await (index, escapableIsIncluded(element))
					}
				}
				
				var indexedPredicate = Array(repeating: false, count: count)
				for try await (index, shouldInclude) in group {
					indexedPredicate[index] = shouldInclude
				}
				
				var output = [Element]()
				for (index, element) in enumeration where indexedPredicate[index] {
					output.append(element)
				}
				return output
			}
		}
    }
}

