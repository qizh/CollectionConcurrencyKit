/**
*  CollectionConcurrencyKit
*  Copyright (c) John Sundell 2021
*  MIT license, see LICENSE.md file for details
*/

import XCTest

class TestCase: XCTestCase {
    let array = Array(0..<5)
    private(set) var collector: Collector!

    override func setUp() {
        super.setUp()
        collector = Collector()
    }

    func verifyErrorThrown<T>(
        in file: StaticString = #filePath,
        at line: UInt = #line,
        from closure: (Error) async throws -> T
    ) async {
        let expectedError = IdentifiableError()

        do {
            let result = try await closure(expectedError)
            XCTFail("Unexpected result: \(result)", file: file, line: line)
        } catch let error as IdentifiableError {
            XCTAssertEqual(error, expectedError, file: file, line: line)
        } catch {
            XCTFail("Incorrect error thrown: \(error)", file: file, line: line)
        }
    }

    func runAsyncTest(
        named testName: String = #function,
        in file: StaticString = #filePath,
        at line: UInt = #line,
        withTimeout timeout: TimeInterval = 10,
        test: @escaping ([Int], Collector) async throws -> Void
    ) {
        // This method is needed since Linux doesn't yet support async test methods.
        var thrownError: Error?
        let errorHandler = { thrownError = $0 }
        let expectation = expectation(description: testName)

        Task {
            do {
                try await test(array, collector)
            } catch {
                errorHandler(error)
            }

            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout)

        if let error = thrownError {
            XCTFail("Async error thrown: \(error)", file: file, line: line)
        }
    }
}

extension TestCase {
    // Note: This is not an actor because we want it to execute concurrently
    actor Collector {
        var values = [Int]()

        func collect(_ value: Int) {
            values.append(value)
        }

        func collectAndTransform(_ value: Int) -> String {
            collect(value)
            return String(value)
        }

        func collectAndDuplicate(_ value: Int) -> [Int] {
            collect(value)
            return [value, value]
        }

        func tryCollect(
            _ value: Int,
            throwError error: Error? = nil
        ) throws {
            if let error {
                throw error
            }
            
            values.append(value)
        }

        func tryCollectAndTransform(
            _ value: Int,
            throwError error: Error? = nil
        ) async throws -> String {
            try tryCollect(value, throwError: error)
            return String(value)
        }

        func tryCollectAndDuplicate(
            _ value: Int,
            throwError error: Error? = nil
        ) async throws -> [Int] {
            try tryCollect(value, throwError: error)
            return [value, value]
        }
    }
}

private extension TestCase {
    struct IdentifiableError: Error, Equatable {
        let id = UUID()
    }
}
