//
//  RedundantThrows.swift
//  SwiftFormat
//
//  Created by Cal Stephens on 2025-09-16.
//  Copyright © 2024 Nick Lockwood. All rights reserved.
//

import Foundation

public extension FormatRule {
    static let redundantThrows = FormatRule(
        help: "Remove `throws` from function declarations that don't contain any `try` expressions or `throw` statements. Note: Using `always` mode can cause build failures if the function signature is required to match a protocol or parent class."
    ) { formatter in
        // Detect test framework once outside the loops
        let testFramework = formatter.detectTestingFramework()

        // Process func keywords
        formatter.forEach(.keyword("func")) { keywordIndex, _ in
            guard let functionDecl = formatter.parseFunctionDeclaration(keywordIndex: keywordIndex),
                  functionDecl.effects.contains(where: { $0.hasPrefix("throws") }),
                  let bodyRange = functionDecl.bodyRange
            else { return }

            // Don't modify override functions - they need to match their parent's signature
            if formatter.modifiersForDeclaration(at: keywordIndex, contains: "override") {
                return
            }

            // Check if we should process this function based on the mode
            let shouldProcess: Bool
            switch formatter.options.redundantThrows {
            case .always:
                shouldProcess = true
            case .testsOnly:
                // Only process test functions
                guard let testFramework else {
                    return
                }

                switch testFramework {
                case .xcTest:
                    shouldProcess = functionDecl.name?.starts(with: "test") == true
                case .swiftTesting:
                    shouldProcess = formatter.modifiersForDeclaration(at: keywordIndex, contains: "@Test")
                }
            }

            guard shouldProcess else { return }

            // Check if the function body contains any try keywords (excluding try! and try?) or throw statements
            var bodyContainsThrowingCode = false
            for index in bodyRange {
                if formatter.tokens[index] == .keyword("try") {
                    // Skip if this is part of a type annotation (e.g., "let foo: Foo!" where ! is an unwrap operator on the type)
                    // Check if we're in a type context by looking for a preceding colon after let/var
                    var isInTypeAnnotation = false
                    if let colonIndex = formatter.index(of: .delimiter(":"), before: index) {
                        // Look for let/var before the colon
                        if let declarationIndex = formatter.index(of: .nonSpaceOrCommentOrLinebreak, before: colonIndex),
                           formatter.tokens[declarationIndex] == .identifier("_") || formatter.tokens[declarationIndex].isIdentifier {
                            // Found identifier before colon, now check if there's let/var before that
                            if let keywordIndex = formatter.index(of: .nonSpaceOrCommentOrLinebreak, before: declarationIndex),
                               ["let", "var"].contains(formatter.tokens[keywordIndex].string) {
                                isInTypeAnnotation = true
                            }
                        }
                    }

                    if isInTypeAnnotation {
                        continue // Skip try keywords in type annotations
                    }

                    // Check if this try is followed by ! or ? (which means it doesn't need throws)
                    if let nextTokenIndex = formatter.index(of: .nonSpaceOrCommentOrLinebreak, after: index),
                       formatter.tokens[nextTokenIndex].isUnwrapOperator {
                        continue // Skip try! and try?
                    }

                    // Only count try keywords that are directly in this function's body
                    // (not in nested closures or functions)
                    if formatter.isInFunctionBody(of: functionDecl, at: index) {
                        bodyContainsThrowingCode = true
                        break
                    }
                } else if formatter.tokens[index] == .keyword("throw") {
                    // Only count throw statements that are directly in this function's body
                    // (not in nested closures or functions)
                    if formatter.isInFunctionBody(of: functionDecl, at: index) {
                        bodyContainsThrowingCode = true
                        break
                    }
                }
            }

            // If the body doesn't contain any throwing code, remove the throws
            if !bodyContainsThrowingCode {
                guard let effectsRange = functionDecl.effectsRange else { return }

                // Find the throws keyword in the effects range
                for index in effectsRange {
                    if formatter.tokens[index] == .keyword("throws") {
                        var endIndex = index

                        // Check if there's typed throws (throws(...))
                        if let nextTokenIndex = formatter.index(of: .nonSpaceOrCommentOrLinebreak, after: index),
                           formatter.tokens[nextTokenIndex] == .startOfScope("("),
                           let endOfScope = formatter.endOfScope(at: nextTokenIndex)
                        {
                            endIndex = endOfScope
                        }

                        // Include trailing whitespace if present
                        if endIndex + 1 < formatter.tokens.count,
                           formatter.tokens[endIndex + 1].isSpace
                        {
                            endIndex += 1
                        }

                        formatter.removeTokens(in: index ... endIndex)
                        break // Only remove the first throws found
                    }
                }
            }
        }

        // Process init keywords
        formatter.forEach(.keyword("init")) { keywordIndex, _ in
            guard let functionDecl = formatter.parseFunctionDeclaration(keywordIndex: keywordIndex),
                  functionDecl.effects.contains(where: { $0.hasPrefix("throws") }),
                  let bodyRange = functionDecl.bodyRange
            else { return }

            // Don't modify override functions - they need to match their parent's signature
            if formatter.modifiersForDeclaration(at: keywordIndex, contains: "override") {
                return
            }

            // Check if we should process this function based on the mode
            let shouldProcess: Bool
            switch formatter.options.redundantThrows {
            case .always:
                shouldProcess = true
            case .testsOnly:
                // Only process test functions
                guard let testFramework else {
                    return
                }

                switch testFramework {
                case .xcTest:
                    shouldProcess = functionDecl.name?.starts(with: "test") == true
                case .swiftTesting:
                    shouldProcess = formatter.modifiersForDeclaration(at: keywordIndex, contains: "@Test")
                }
            }

            guard shouldProcess else { return }

            // Check if the function body contains any try keywords (excluding try! and try?) or throw statements
            var bodyContainsThrowingCode = false
            for index in bodyRange {
                if formatter.tokens[index] == .keyword("try") {
                    // Skip if this is part of a type annotation (e.g., "let foo: Foo!" where ! is an unwrap operator on the type)
                    // Check if we're in a type context by looking for a preceding colon after let/var
                    var isInTypeAnnotation = false
                    if let colonIndex = formatter.index(of: .delimiter(":"), before: index) {
                        // Look for let/var before the colon
                        if let declarationIndex = formatter.index(of: .nonSpaceOrCommentOrLinebreak, before: colonIndex),
                           formatter.tokens[declarationIndex] == .identifier("_") || formatter.tokens[declarationIndex].isIdentifier {
                            // Found identifier before colon, now check if there's let/var before that
                            if let keywordIndex = formatter.index(of: .nonSpaceOrCommentOrLinebreak, before: declarationIndex),
                               ["let", "var"].contains(formatter.tokens[keywordIndex].string) {
                                isInTypeAnnotation = true
                            }
                        }
                    }

                    if isInTypeAnnotation {
                        continue // Skip try keywords in type annotations
                    }

                    // Check if this try is followed by ! or ? (which means it doesn't need throws)
                    if let nextTokenIndex = formatter.index(of: .nonSpaceOrCommentOrLinebreak, after: index),
                       formatter.tokens[nextTokenIndex].isUnwrapOperator {
                        continue // Skip try! and try?
                    }

                    // Only count try keywords that are directly in this function's body
                    // (not in nested closures or functions)
                    if formatter.isInFunctionBody(of: functionDecl, at: index) {
                        bodyContainsThrowingCode = true
                        break
                    }
                } else if formatter.tokens[index] == .keyword("throw") {
                    // Only count throw statements that are directly in this function's body
                    // (not in nested closures or functions)
                    if formatter.isInFunctionBody(of: functionDecl, at: index) {
                        bodyContainsThrowingCode = true
                        break
                    }
                }
            }

            // If the body doesn't contain any throwing code, remove the throws
            if !bodyContainsThrowingCode {
                guard let effectsRange = functionDecl.effectsRange else { return }

                // Find the throws keyword in the effects range
                for index in effectsRange {
                    if formatter.tokens[index] == .keyword("throws") {
                        var endIndex = index

                        // Check if there's typed throws (throws(...))
                        if let nextTokenIndex = formatter.index(of: .nonSpaceOrCommentOrLinebreak, after: index),
                           formatter.tokens[nextTokenIndex] == .startOfScope("("),
                           let endOfScope = formatter.endOfScope(at: nextTokenIndex)
                        {
                            endIndex = endOfScope
                        }

                        // Include trailing whitespace if present
                        if endIndex + 1 < formatter.tokens.count,
                           formatter.tokens[endIndex + 1].isSpace
                        {
                            endIndex += 1
                        }

                        formatter.removeTokens(in: index ... endIndex)
                        break // Only remove the first throws found
                    }
                }
            }
        }

        // Process subscript keywords
        formatter.forEach(.keyword("subscript")) { keywordIndex, _ in
            guard let functionDecl = formatter.parseFunctionDeclaration(keywordIndex: keywordIndex),
                  functionDecl.effects.contains(where: { $0.hasPrefix("throws") }),
                  let bodyRange = functionDecl.bodyRange
            else { return }

            // Don't modify override functions - they need to match their parent's signature
            if formatter.modifiersForDeclaration(at: keywordIndex, contains: "override") {
                return
            }

            // Check if we should process this function based on the mode
            let shouldProcess: Bool
            switch formatter.options.redundantThrows {
            case .always:
                shouldProcess = true
            case .testsOnly:
                // Only process test functions
                guard let testFramework else {
                    return
                }

                switch testFramework {
                case .xcTest:
                    shouldProcess = functionDecl.name?.starts(with: "test") == true
                case .swiftTesting:
                    shouldProcess = formatter.modifiersForDeclaration(at: keywordIndex, contains: "@Test")
                }
            }

            guard shouldProcess else { return }

            // Check if the function body contains any try keywords (excluding try! and try?) or throw statements
            var bodyContainsThrowingCode = false
            for index in bodyRange {
                if formatter.tokens[index] == .keyword("try") {
                    // Skip if this is part of a type annotation (e.g., "let foo: Foo!" where ! is an unwrap operator on the type)
                    // Check if we're in a type context by looking for a preceding colon after let/var
                    var isInTypeAnnotation = false
                    if let colonIndex = formatter.index(of: .delimiter(":"), before: index) {
                        // Look for let/var before the colon
                        if let declarationIndex = formatter.index(of: .nonSpaceOrCommentOrLinebreak, before: colonIndex),
                           formatter.tokens[declarationIndex] == .identifier("_") || formatter.tokens[declarationIndex].isIdentifier {
                            // Found identifier before colon, now check if there's let/var before that
                            if let keywordIndex = formatter.index(of: .nonSpaceOrCommentOrLinebreak, before: declarationIndex),
                               ["let", "var"].contains(formatter.tokens[keywordIndex].string) {
                                isInTypeAnnotation = true
                            }
                        }
                    }

                    if isInTypeAnnotation {
                        continue // Skip try keywords in type annotations
                    }

                    // Check if this try is followed by ! or ? (which means it doesn't need throws)
                    if let nextTokenIndex = formatter.index(of: .nonSpaceOrCommentOrLinebreak, after: index),
                       formatter.tokens[nextTokenIndex].isUnwrapOperator {
                        continue // Skip try! and try?
                    }

                    // Only count try keywords that are directly in this function's body
                    // (not in nested closures or functions)
                    if formatter.isInFunctionBody(of: functionDecl, at: index) {
                        bodyContainsThrowingCode = true
                        break
                    }
                } else if formatter.tokens[index] == .keyword("throw") {
                    // Only count throw statements that are directly in this function's body
                    // (not in nested closures or functions)
                    if formatter.isInFunctionBody(of: functionDecl, at: index) {
                        bodyContainsThrowingCode = true
                        break
                    }
                }
            }

            // If the body doesn't contain any throwing code, remove the throws
            if !bodyContainsThrowingCode {
                guard let effectsRange = functionDecl.effectsRange else { return }

                // Find the throws keyword in the effects range
                for index in effectsRange {
                    if formatter.tokens[index] == .keyword("throws") {
                        var endIndex = index

                        // Check if there's typed throws (throws(...))
                        if let nextTokenIndex = formatter.index(of: .nonSpaceOrCommentOrLinebreak, after: index),
                           formatter.tokens[nextTokenIndex] == .startOfScope("("),
                           let endOfScope = formatter.endOfScope(at: nextTokenIndex)
                        {
                            endIndex = endOfScope
                        }

                        // Include trailing whitespace if present
                        if endIndex + 1 < formatter.tokens.count,
                           formatter.tokens[endIndex + 1].isSpace
                        {
                            endIndex += 1
                        }

                        formatter.removeTokens(in: index ... endIndex)
                        break // Only remove the first throws found
                    }
                }
            }
        }
    } examples: {
        """
        ```diff
        // With --redundant-throws tests-only (default)
        import XCTest

        class TestCase: XCTestCase {
        -    func test_something() throws {
        +    func test_something() {
                 XCTAssertEqual(1, 1)
             }
        }
        ```

        ```diff
        // With --redundant-throws always
        - func foo() throws -> Int {
        + func foo() -> Int {
              return 0
          }

        - func bar() throws(MyError) -> Int {
        + func bar() -> Int {
              return 42
          }
        ```

        ```diff
        // Functions that actually throw are preserved
          func baz() throws -> Int {
              try somethingThatThrows()
              return 0
          }

          func qux() throws -> Int {
              guard someCondition else {
                  throw MyError.failed
              }
              return 1
          }
        ```
        """
    }
}
