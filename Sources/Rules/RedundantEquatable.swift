// Created by Cal Stephens on 9/25/24.
// Copyright © 2024 Airbnb Inc. All rights reserved.

public extension FormatRule {
    static let redundantEquatable = FormatRule(
        help: "Omit a hand-written Equatable implementation when the compiler-synthesized conformance would be equivalent.",
        disabledByDefault: true,
        options: ["equatablemacro"]
    ) { formatter in
        // Find all of the types with an `Equatable` conformance and a manually-implemented `static func ==` implementation.
        let declarations = formatter.parseDeclarations()
        let typesManuallyImplementingEquatableConformance = formatter.manuallyImplementedEquatableTypes(in: declarations)

        // To avoid invalidating indices within the `typesManuallyImplementingEquatableConformance`,
        // compute all of the modifications we need to make and then apply them in reverse order at the end.
        var modificationsByIndex = [Int: () -> Void]()
        var importsToAddIfNeeded = Set<String>()

        for equatableType in typesManuallyImplementingEquatableConformance {
            let isEligibleForAutoEquatableConformance: Bool
            switch equatableType.typeDeclaration.keyword {
            case "struct":
                // The compiler automatically synthesizes Equatable implementations for structs
                isEligibleForAutoEquatableConformance = true
            case "class":
                // Projects can define an `@Equatable` macro that generates the Equatable implementation for classes
                isEligibleForAutoEquatableConformance = formatter.options.equatableMacroInfo != nil
            default:
                // This rule doesn't support other kinds of types.
                isEligibleForAutoEquatableConformance = false
            }

            guard isEligibleForAutoEquatableConformance,
                  let typeBody = equatableType.typeDeclaration.body,
                  let typeKeywordIndex = equatableType.typeDeclaration.originalKeywordIndex(in: formatter)
            else { continue }

            // Find all of the stored instance properties in this type.
            // The synthesized Equatable implementation would compare each of these.
            let storedInstanceProperties = Set(typeBody.filter(\.isStoredInstanceProperty).map(\.name))

            // Find all of the properties compared using `lhs.{property} == rhs.{property}`
            let comparedProperties = formatter.parseComparedProperties(inEquatableImplementation: equatableType.equatableFunction)

            // If the set of compared properties match the set of stored instance properties,
            // then the manually implemented `==` function is redundant and can be removed.
            guard comparedProperties == storedInstanceProperties else {
                continue
            }

            // The compiler automatically synthesizes Equatable implementations for structs
            if equatableType.typeDeclaration.keyword == "struct" {
                let rangeToRemove = equatableType.equatableFunction.originalRange
                modificationsByIndex[rangeToRemove.lowerBound] = {
                    formatter.removeTokens(in: rangeToRemove)
                }
            }

            // In projects using an `@Equatable` macro, the Equatable implementation
            // can be generated by that macro instead of written manually.
            else if let equatableMacroInfo = formatter.options.equatableMacroInfo {
                let conformanceIndex = equatableType.equatableConformanceIndex

                // Exclude cases where the Equatable conformance is defined in an extension with a where clause,
                // since this wouldn't usually be captured in the generated conformance.
                if let startOfExtensionTypeBody = formatter.index(of: .startOfScope("{"), after: conformanceIndex),
                   formatter.index(of: .keyword("where"), in: conformanceIndex ..< startOfExtensionTypeBody) != nil
                {
                    continue
                }

                // Remove the `==` implementation
                let rangeToRemove = equatableType.equatableFunction.originalRange
                modificationsByIndex[rangeToRemove.lowerBound] = {
                    formatter.removeTokens(in: rangeToRemove)
                }

                // Remove the `: Equatable` conformance.
                //  - If this type uses as `: Hashable` conformance, we have to preserve that.
                if formatter.tokens[conformanceIndex] == .identifier("Equatable") {
                    modificationsByIndex[conformanceIndex] = {
                        formatter.removeConformance(at: conformanceIndex)
                    }
                }

                // Add the `@Equatable` macro
                modificationsByIndex[typeKeywordIndex] = {
                    let startOfModifiers = formatter.startOfModifiers(at: typeKeywordIndex, includingAttributes: true)

                    formatter.insert(
                        [.keyword(equatableMacroInfo.macro), .space(" ")],
                        at: startOfModifiers
                    )
                }

                // Import the module that defines the `@Equatable` macro if needed
                importsToAddIfNeeded.insert(equatableMacroInfo.moduleName)
            }
        }

        // Apply the modifications in backwards order to avoid invalidating existing indices
        for (_, applyModification) in modificationsByIndex.sorted(by: { $0.key < $1.key }).reversed() {
            applyModification()
        }

        formatter.addImports(importsToAddIfNeeded)
    } examples: {
        """
        ```diff
          struct Foo: Equatable {
              let bar: Bar
              let baaz: Baaz

        -     static func ==(lhs: Foo, rhs: Foo) -> Bool {
        -         lhs.bar == rhs.bar 
        -             && lhs.baaz == rhs.baaz
        -     }
          }

          class Bar: Equatable {
              let baaz: Baaz

              static func ==(lhs: Bar, rhs: Bar) -> Bool {
                  lhs.baaz == rhs.baaz
              }
          }
        ```

        If your project includes a macro that generates the `static func ==` implementation
        for the attached class, you can specify `--equatablemacro @Equatable,MyMacroLib`
        and this rule will also migrate eligible classes to use your macro instead of
        a hand-written Equatable conformance:

        ```diff
          // --equatablemacro @Equatable,MyMacroLib
          import FooLib
        + import MyMacroLib

        + @Equatable
          class Bar {
              let baaz: Baaz
          }

        - extension Bar: Equatable {
        -     static func ==(lhs: Bar, rhs: Bar) -> Bool {
        -         lhs.baaz == rhs.baaz
        -     }
        - }
        ```
        """
    }
}

extension Formatter {
    struct EquatableType {
        /// The main type declaration of the type that has an Equatable conformance
        let typeDeclaration: Declaration
        /// The Equatable `static func ==` implementation, which could be defined in an extension.
        let equatableFunction: Declaration
        /// The index of the `: Equatable` conformance, which could be defined in an extension.
        let equatableConformanceIndex: Int
    }

    /// Finds all of the types in the current file with an Equatable conformance,
    /// which also have a manually-implemented `static func ==` method.
    func manuallyImplementedEquatableTypes(in declarations: [Declaration]) -> [EquatableType] {
        var typeDeclarationsByFullyQualifiedName: [String: Declaration] = [:]
        var typesWithEquatableConformances: [(fullyQualifiedTypeName: String, equatableConformanceIndex: Int)] = []
        var equatableImplementationsByFullyQualifiedName: [String: Declaration] = [:]

        declarations.forEachRecursiveDeclaration { declaration, parentDeclarations in
            guard let declarationName = declaration.name else { return }
            let fullyQualifiedName = declaration.fullyQualifiedName(parentDeclarations: parentDeclarations)

            if declaration.definesType, let fullyQualifiedName = fullyQualifiedName {
                typeDeclarationsByFullyQualifiedName[fullyQualifiedName] = declaration
            }

            // Support the Equatable conformance being declared in an extension
            // separately from the Equatable
            if declaration.definesType || declaration.keyword == "extension",
               let keywordIndex = declaration.originalKeywordIndex(in: self),
               let fullyQualifiedName = fullyQualifiedName
            {
                let conformances = parseConformancesOfType(atKeywordIndex: keywordIndex)

                // Both an Equatable and Hashable conformance will cause the Equatable conformance to be synthesized
                if let equatableConformance = conformances.first(where: {
                    $0.conformance == "Equatable" || $0.conformance == "Hashable"
                }) {
                    typesWithEquatableConformances.append((
                        fullyQualifiedTypeName: fullyQualifiedName,
                        equatableConformanceIndex: equatableConformance.index
                    ))
                }
            }

            if declaration.keyword == "func",
               declarationName == "==",
               let funcKeywordIndex = declaration.originalKeywordIndex(in: self),
               modifiersForDeclaration(at: funcKeywordIndex, contains: "static"),
               let startOfArguments = index(of: .startOfScope("("), after: funcKeywordIndex)
            {
                let functionArguments = parseFunctionDeclarationArguments(startOfScope: startOfArguments)

                if functionArguments.count == 2,
                   // The external label doesn't matter, it can be `_` or `lhs/rhs`.
                   functionArguments[0].internalLabel == "lhs",
                   functionArguments[1].internalLabel == "rhs",
                   functionArguments[0].type == functionArguments[1].type
                {
                    var comparedTypeName = functionArguments[0].type

                    if let parentDeclaration = parentDeclarations.last {
                        // If the function uses `Self`, resolve that to the name of the parent type
                        if comparedTypeName == "Self",
                           let parentDeclarationName = parentDeclaration.fullyQualifiedName(parentDeclarations: parentDeclarations.dropLast())
                        {
                            comparedTypeName = parentDeclarationName
                        }

                        // If the function uses `Bar` in an extension `Foo.Bar`, then resolve
                        // the name of the compared type to be the fully-qualified `Foo.Bar` type.
                        if parentDeclaration.keyword == "extension",
                           let extendedType = parentDeclaration.name,
                           comparedTypeName != extendedType,
                           extendedType.hasSuffix("." + comparedTypeName)
                        {
                            comparedTypeName = extendedType
                        }

                        // If the function uses `Bar` in a type `Bar`, then resolve the
                        // the name of the compared type to be the fully-qualified parent type.
                        //  - For example, `Bar` could be defined in a parent `Foo` type.
                        if comparedTypeName == parentDeclaration.name,
                           let parentDeclarationName = parentDeclaration.fullyQualifiedName(parentDeclarations: parentDeclarations.dropLast())
                        {
                            comparedTypeName = parentDeclarationName
                        }
                    }

                    equatableImplementationsByFullyQualifiedName[comparedTypeName] = declaration
                }
            }
        }

        return typesWithEquatableConformances.compactMap { typeName, equatableConformanceIndex in
            guard let typeDeclaration = typeDeclarationsByFullyQualifiedName[typeName],
                  let equatableImplementation = equatableImplementationsByFullyQualifiedName[typeName]
            else { return nil }

            return EquatableType(
                typeDeclaration: typeDeclaration,
                equatableFunction: equatableImplementation,
                equatableConformanceIndex: equatableConformanceIndex
            )
        }
    }

    /// Finds the set of properties that are compared in the given Equatable `func`,
    /// following the pattern `lhs.{property} == rhs.{property}`.
    ///  - Returns `nil` if there are any comparisons that don't match this pattern.
    func parseComparedProperties(inEquatableImplementation equatableImplementation: Declaration) -> Set<String>? {
        guard let funcIndex = equatableImplementation.originalKeywordIndex(in: self),
              let startOfBody = index(of: .startOfScope("{"), after: funcIndex),
              let firstIndexInBody = index(of: .nonSpaceOrCommentOrLinebreak, after: startOfBody),
              let endOfBody = endOfScope(at: startOfBody)
        else { return nil }

        var validComparedProperties = Set<String>()
        var currentIndex = firstIndexInBody

        // Skip over any `return` keyword that may be present
        if tokens[currentIndex] == .keyword("return"),
           let nextIndex = index(of: .nonSpaceOrCommentOrLinebreak, after: currentIndex)
        {
            currentIndex = nextIndex
        }

        while currentIndex < endOfBody {
            // Parse the current `lhs.{property} == rhs.{property}` pattern
            guard tokens[currentIndex] == .identifier("lhs"),
                  let lhsDotIndex = index(of: .nonSpaceOrCommentOrLinebreak, after: currentIndex),
                  tokens[lhsDotIndex] == .operator(".", .infix),
                  let lhsPropertyName = index(of: .nonSpaceOrCommentOrLinebreak, after: lhsDotIndex),
                  tokens[lhsPropertyName].isIdentifierOrKeyword,
                  let equalsIndex = index(of: .nonSpaceOrCommentOrLinebreak, after: lhsPropertyName),
                  tokens[equalsIndex] == .operator("==", .infix),
                  let rhsIndex = index(of: .nonSpaceOrCommentOrLinebreak, after: equalsIndex),
                  tokens[rhsIndex] == .identifier("rhs"),
                  let rhsDotIndex = index(of: .nonSpaceOrCommentOrLinebreak, after: rhsIndex),
                  tokens[rhsDotIndex] == .operator(".", .infix),
                  let rhsPropertyName = index(of: .nonSpaceOrCommentOrLinebreak, after: rhsDotIndex),
                  tokens[rhsPropertyName] == tokens[lhsPropertyName],
                  let indexAfterComparison = index(of: .nonSpaceOrCommentOrLinebreak, after: rhsPropertyName)
            else {
                // If we find a non-matching comparison, we have to avoid modifying this declaration
                return nil
            }

            validComparedProperties.insert(tokens[lhsPropertyName].string)

            // Skip over any `&&` operators connecting two comparisons
            if tokens[indexAfterComparison] == .operator("&&", .infix),
               let indexAfterAndOperator = index(of: .nonSpaceOrCommentOrLinebreak, after: indexAfterComparison)
            {
                currentIndex = indexAfterAndOperator
            }

            else {
                currentIndex = indexAfterComparison
            }
        }

        return validComparedProperties
    }

    /// Removes the protocol conformance at the given index.
    /// e.g. can remove `Foo` from `Type: Foo, Bar {` (becomes `Type: Bar {`).
    func removeConformance(at conformanceIndex: Int) {
        guard let previousToken = index(of: .nonSpaceOrCommentOrLinebreak, before: conformanceIndex),
              let nextToken = index(of: .nonSpaceOrCommentOrLinebreak, after: conformanceIndex)
        else { return }

        // The first conformance will be preceded by a colon.
        // Every conformance but the last one will be followed by a comma.
        //  - for example: `Type: Foo, Bar, Baaz {`
        let isFirstConformance = tokens[previousToken] == .delimiter(":")
        let isLastConformance = tokens[nextToken] != .delimiter(",")
        let isOnlyConformance = isFirstConformance && isLastConformance

        if isLastConformance || isOnlyConformance {
            removeTokens(in: previousToken ... conformanceIndex)
        } else {
            // When changing `Foo, Bar` to just `Bar`, also remove the space between them
            if token(at: nextToken + 1)?.isSpace == true {
                removeTokens(in: conformanceIndex ... (nextToken + 1))
            } else {
                removeTokens(in: conformanceIndex ... (nextToken + 1))
            }
        }
    }

    /// Adds imports for the given list of modules to this file if not already present
    func addImports(_ importsToAddIfNeeded: Set<String>) {
        let importRanges = parseImports()
        let currentImports = Set(importRanges.flatMap { $0.map(\.module) })

        for importToAddIfNeeded in importsToAddIfNeeded {
            guard !currentImports.contains(importToAddIfNeeded) else { continue }

            let newImport: [Token] = [.keyword("import"), .space(" "), .identifier(importToAddIfNeeded)]

            // If there are any existing imports, add the new import in the existing group
            if let firstImportIndex = index(of: .keyword("import"), after: -1) {
                insert(newImport + [linebreakToken(for: firstImportIndex)], at: firstImportIndex)
            }

            // Otherwise if there are no imports:
            //  - Make sure to insert the comment after any header comment if present
            //  - Include a blank line after the import
            else {
                let insertionIndex: Int
                if let headerCommentRange = headerCommentTokenRange(), !headerCommentRange.isEmpty {
                    insertionIndex = headerCommentRange.upperBound
                } else {
                    insertionIndex = 0
                }

                let newImportWithBlankLine = newImport + [
                    linebreakToken(for: insertionIndex),
                    linebreakToken(for: insertionIndex),
                ]

                insert(newImportWithBlankLine, at: insertionIndex)
            }
        }
    }
}
