//
//  redundantExtensionACL.swift
//  SwiftFormat
//
//  Created by Cal Stephens on 7/28/24.
//  Copyright © 2024 Nick Lockwood. All rights reserved.
//

public extension FormatRule {
    /// Remove redundant access control level modifiers in extensions
    static let redundantExtensionACL = FormatRule(
        help: "Remove redundant access control modifiers."
    ) { formatter in
        formatter.forEach(.keyword("extension")) { i, _ in
            var acl = ""
            guard formatter.modifiersForDeclaration(at: i, contains: {
                acl = $1
                return _FormatRules.aclModifiers.contains(acl)
            }), let startIndex = formatter.index(of: .startOfScope("{"), after: i),
            var endIndex = formatter.index(of: .endOfScope("}"), after: startIndex) else {
                return
            }
            if acl == "private" { acl = "fileprivate" }
            while let aclIndex = formatter.lastIndex(of: .keyword(acl), in: startIndex + 1 ..< endIndex) {
                formatter.removeToken(at: aclIndex)
                if formatter.token(at: aclIndex)?.isSpace == true {
                    formatter.removeToken(at: aclIndex)
                }
                endIndex = aclIndex
            }
        }
    }
}
