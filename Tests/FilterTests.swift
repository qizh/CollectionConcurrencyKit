/**
 *  CollectionConcurrencyKit
 *  Copyright (c) John Sundell 2021
 *  MIT license, see LICENSE.md file for details
 */

import Testing
import CollectionConcurrencyKit

// MARK: - Test fixtures

fileprivate enum TestError: Error, Equatable {
    case boom(Int)
    case outOfOrder
}

fileprivate actor Counter {
    var value = 0
    var maxSeen = 0
    
    func increment() {
        value += 1
        maxSeen = max(maxSeen, value)
    }
    
    func decrement() {
        value -= 1
    }
}

// MARK: - asyncFilter

struct AsyncFilterTests {
    
    /// Filters even numbers and keeps their original order.
    @Test
    func basicFiltering() async {
        let input  = Array(0...9)
        let result = await input.asyncFilter { $0.isMultiple(of: 2) }
        #expect(result == [0, 2, 4, 6, 8])
    }
    
    /// Confirms the helper doesn’t reshuffle elements.
    @Test
    func preservesOrder() async {
        let input  = ["a", "b", "c", "d"]
        let result = await input.asyncFilter { letter in
            await Task.yield()                 // force at least one suspension
            return letter != "c"
        }
        #expect(result == ["a", "b", "d"])
    }
    
    /// The first thrown error should bubble straight out.
    @Test
    func propagatesError() async {
        let input = Array(0...9)
        
        await #expect(throws: TestError.boom(2)) {
            try await input.asyncFilter { value in
                if value == 2 { throw TestError.boom(value) }
                return true
            }
        }
        
    }
    
    @Test
    func runSeriallly() async {
        let counter = Counter()
        let end = 100_000
        let input = Array(0..<end)
        
        let result = await input.asyncFilter { value in
            // This can only be true if we are running serially.
            await #expect(counter.value == value)
            
            await counter.increment()
            return true
        }
        
        await #expect(counter.value == end)
        #expect(result == input)
    }
}

// MARK: - concurrentFilter

struct ConcurrentFilterTests {
    
    /// Same logic check as above, but on the concurrent variant.
    @Test
    func basicFiltering() async {
        let input  = Array(0...9)
        let result = await input.concurrentFilter { $0.isMultiple(of: 2) }
        #expect(result == [0, 2, 4, 6, 8])
    }
    
    /// Ensure order is preserved even when completion order is scrambled.
    @Test
    func preservesOrderDespiteOutOfOrderCompletion() async throws {
        let end = 10
        try #require(end > 0 && end <= 10, "An `end` too large might make the test run for too long. Adjust the sleep duration as well.")
        let input = Array(0..<end)
        
        let result = try await input.concurrentFilter { value in
            // Sleep *longer* for smaller values so they finish last.
            try await Task.sleep(nanoseconds: UInt64((end - value) * 100_000_000))
            return value.isMultiple(of: 2)
        }
        
        #expect(result == [0, 2, 4, 6, 8])     // still ascending
    }
    
    /// concurrentFilter must surface the first error and cancel the rest.
    @Test
    func propagatesError() async {
        let input = ["A", "B", "C"]
        
        await #expect(throws: TestError.boom(42)) {
            try await input.concurrentFilter { letter in
                if letter == "B" { throw TestError.boom(42) }
                return true
            }
        }
    }
    
    /// Edge-case: empty sequences should succeed and yield [].
    @Test
    func handlesEmptySequence() async {
        let empty: [Int] = []
        let result = await empty.concurrentFilter { _ in true }
        #expect(result.isEmpty)
    }
    
    /// Ensure the helper can handle arrays that contain Pptionals.
    @Test
    func keepsOptionalElementsThatPass() async {
        let input: [Int?] = [1, nil, 3, nil, 5]
        
        let result = await input.concurrentFilter { $0 != nil }
        #expect(result == [1, 3, 5])
    }
    
    /// Ensure that the method runs concurrently.
    @Test
    func runConcurrently() async throws {
        let counter = Counter()
        let end = 100_000
        let input = Array(0..<end)
        
        let result = try await input.concurrentFilter { value in
            await counter.increment()
            
            // Each block sleeps for half a second to allow at leats one other task to begin.
            try await Task.sleep(nanoseconds: 500_000_000)
            
            await counter.decrement()
            return true
        }
        
        #expect(result == input)
        await #expect(counter.maxSeen > 1)
    }
}
