/**
 *  CollectionConcurrencyKit
 *  Copyright (c) John Sundell 2021
 *  MIT license, see LICENSE.md file for details
 */

import Testing
import CollectionConcurrencyKit

// MARK: - Test fixtures -------------------------------------------------------

enum TestError: Error, Equatable { case boom(Int) }

// MARK: - asyncFilter ---------------------------------------------------------

struct AsyncFilterTests {
    
    /// Filters even numbers and keeps their original order.
    @Test
    func basicFiltering() async throws {
        let input  = Array(0...9)
        let result = await input.asyncFilter { $0.isMultiple(of: 2) }
        #expect(result == [0, 2, 4, 6, 8])
    }
    
    /// Confirms the helper doesn’t reshuffle elements.
    @Test
    func preservesOrder() async throws {
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
}

// MARK: - concurrentFilter ----------------------------------------------------

struct ConcurrentFilterTests {
    
    /// Same logic check as above, but on the concurrent variant.
    @Test
    func basicFiltering() async throws {
        let input  = Array(0...9)
        let result = await input.concurrentFilter { $0.isMultiple(of: 2) }
        #expect(result == [0, 2, 4, 6, 8])
    }
    
    /// Ensure order is preserved even when completion order is scrambled.
    @Test
    func preservesOrderDespiteOutOfOrderCompletion() async throws {
        let input = Array(0...9)
        
        let result = try await input.concurrentFilter { value in
            // Sleep *longer* for smaller values so they finish last.
            try await Task.sleep(nanoseconds: UInt64((10 - value) * 1_000_000))
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
    func handlesEmptySequence() async throws {
        let empty: [Int] = []
        let result = await empty.concurrentFilter { _ in true }
        #expect(result.isEmpty)
    }
    
    @Test
    func keepsOptionalElementsThatPass() async throws {
        let input: [Int?] = [1, nil, 3, nil, 5]
        
        let result = await input.concurrentFilter { $0 != nil }
        #expect(result == [1, 3, 5])
    }
}
