//
//  RedundantThrowsTests.swift
//  SwiftFormatTests
//
//  Created by Cal Stephens on 2025-09-16.
//  Copyright © 2024 Nick Lockwood. All rights reserved.
//

import XCTest
@testable import SwiftFormat

class RedundantThrowsTests: XCTestCase {
    // MARK: - Tests-only mode (default)

    func testRemovesThrowsFromXCTestFunction() {
        let input = """
        import XCTest

        class TestCase: XCTestCase {
            func test_something() throws {
                XCTAssertEqual(1, 1)
            }
        }
        """
        let output = """
        import XCTest

        class TestCase: XCTestCase {
            func test_something() {
                XCTAssertEqual(1, 1)
            }
        }
        """
        let options = FormatOptions(redundantThrows: .testsOnly)
        testFormatting(for: input, output, rule: .redundantThrows, options: options)
    }

    func testRemovesThrowsFromSwiftTestingFunction() {
        let input = """
        import Testing

        @Test func something() throws {
            #expect(1 == 1)
        }
        """
        let output = """
        import Testing

        @Test func something() {
            #expect(1 == 1)
        }
        """
        let options = FormatOptions(redundantThrows: .testsOnly)
        testFormatting(for: input, output, rule: .redundantThrows, options: options)
    }

    func testIgnoresNonTestFunctionsInTestsOnlyMode() {
        let input = """
        import XCTest

        class TestCase: XCTestCase {
            func helper() throws {
                // This is not a test function, should not be modified
            }

            func test_something() throws {
                XCTAssertEqual(1, 1)
            }
        }
        """
        let output = """
        import XCTest

        class TestCase: XCTestCase {
            func helper() throws {
                // This is not a test function, should not be modified
            }

            func test_something() {
                XCTAssertEqual(1, 1)
            }
        }
        """
        let options = FormatOptions(redundantThrows: .testsOnly)
        testFormatting(for: input, output, rule: .redundantThrows, options: options)
    }

    // MARK: - Always mode

    func testRemovesThrowsFromAnyFunctionInAlwaysMode() {
        let input = """
        func foo() throws -> Int {
            return 0
        }
        """
        let output = """
        func foo() -> Int {
            return 0
        }
        """
        let options = FormatOptions(redundantThrows: .always)
        testFormatting(for: input, output, rule: .redundantThrows, options: options)
    }

    func testRemovesTypedThrowsInAlwaysMode() {
        let input = """
        func foo() throws(MyError) -> Int {
            return 0
        }
        """
        let output = """
        func foo() -> Int {
            return 0
        }
        """
        let options = FormatOptions(redundantThrows: .always)
        testFormatting(for: input, output, rule: .redundantThrows, options: options)
    }

    // MARK: - Override functions

    func testDoesNotModifyOverrideFunctions() {
        let input = """
        class TestCase {
            override func setUpWithError() throws {
                // Setup code that doesn't actually throw
            }
        }
        """
        let options = FormatOptions(redundantThrows: .always)
        testFormatting(for: input, rule: .redundantThrows, options: options)
    }

    // MARK: - Functions that actually throw

    func testPreservesThrowsWhenFunctionContainsTry() {
        let input = """
        func baz() throws -> Int {
            try somethingThatThrows()
            return 0
        }
        """
        let options = FormatOptions(redundantThrows: .always)
        testFormatting(for: input, rule: .redundantThrows, options: options)
    }

    func testPreservesThrowsWhenFunctionContainsThrowStatement() {
        let input = """
        func foo() throws -> Int {
            guard someCondition else {
                throw MyError.invalidInput
            }

            return 0
        }
        """
        let options = FormatOptions(redundantThrows: .always)
        testFormatting(for: input, rule: .redundantThrows, options: options)
    }

    func testRemovesThrowsWhenOnlyTryExclamationAndTryQuestion() {
        let input = """
        func foo() throws -> Int {
            try! nonThrowingCall()
            try? anotherCall()
            return 0
        }
        """
        let output = """
        func foo() -> Int {
            try! nonThrowingCall()
            try? anotherCall()
            return 0
        }
        """
        let options = FormatOptions(redundantThrows: .always)
        testFormatting(for: input, output, rule: .redundantThrows, options: options)
    }

    // MARK: - Scoping

    func testRemovesThrowsWhenTryInNestedClosure() {
        let input = """
        func foo() throws -> Int {
            let closure = {
                try somethingThatThrows()
            }
            return 0
        }
        """
        let output = """
        func foo() -> Int {
            let closure = {
                try somethingThatThrows()
            }
            return 0
        }
        """
        let options = FormatOptions(redundantThrows: .always)
        testFormatting(for: input, output, rule: .redundantThrows, options: options)
    }

    func testPreservesThrowsWhenTryInControlFlow() {
        let input = """
        func foo() throws -> Int {
            if someCondition {
                try somethingThatThrows()
            }
            return 0
        }
        """
        let options = FormatOptions(redundantThrows: .always)
        testFormatting(for: input, rule: .redundantThrows, options: options)
    }
}
