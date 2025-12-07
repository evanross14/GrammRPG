// SpellChecker.swift
// GrammRPG
// Extracted sentence-level spellchecking with protection for inventory terms and quoted/bracketed text.

import Foundation
import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct SpellChecker {
    // Returns (attributed result with corrections colored, remaining count, corrected string)
    static func analyze(text: String, protectedTerms: Set<String>) -> (AttributedString, Int, String) {
        let domainTerms: Set<String> = Set(protectedTerms.compactMap { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        let domainLower: Set<String> = Set(domainTerms.map { $0.lowercased() })

        // Sentence-level spellchecking: operate on the whole string and replace specific ranges
        var working = text
        var cursor = 0
        var mistakes = 0
        var attributed = AttributedString("")

        #if os(iOS)
        let checker = UITextChecker()
        #elseif os(macOS)
        let checker = NSSpellChecker.shared
        let docTag = NSSpellChecker.uniqueSpellDocumentTag()
        #endif

        func isInsideProtectedDelimiters(original: NSString, range: NSRange) -> Bool {
            // Protect tokens inside quotes "..." or brackets [...] to avoid altering explicit inputs
            let full = original as String
            let before = full.prefix(range.location)
            let afterIndex = range.location + range.length
            let after = afterIndex <= original.length ? full.suffix(original.length - afterIndex) : ""
            let openQuotes = before.filter { $0 == "\"" }.count
            let closeQuotes = after.filter { $0 == "\"" }.count
            if openQuotes % 2 == 1 && closeQuotes % 2 == 1 { return true }
            let openBrackets = before.filter { $0 == "[" }.count
            let closeBrackets = after.filter { $0 == "]" }.count
            if openBrackets % 2 == 1 && closeBrackets % 2 == 1 { return true }
            return false
        }

        func bestSuggestion(for token: String, missRange: NSRange, in source: NSString) -> String? {
            // If token is a protected domain term or inside quotes/brackets, do not change
            if domainLower.contains(token.lowercased()) { return nil }
            if domainTerms.contains(token) { return nil }
            if isInsideProtectedDelimiters(original: source, range: missRange) { return nil }

            #if os(iOS)
            let guesses = checker.guesses(forWordRange: missRange, in: source as String, language: Locale.current.identifier) ?? []
            #elseif os(macOS)
            let guesses = (checker.guesses(forWordRange: missRange, in: source as String, language: Locale.current.identifier, inSpellDocumentWithTag: docTag) as? [String]) ?? []
            #endif

            // Prefer suggestions that exactly match a known domain term (case-insensitive)
            if let domainMatch = guesses.first(where: { domainLower.contains($0.lowercased()) }) {
                return domainMatch
            }
            return guesses.first
        }

        while true {
            #if os(iOS)
            let miss = checker.rangeOfMisspelledWord(
                in: working,
                range: NSRange(location: 0, length: (working as NSString).length),
                startingAt: cursor,
                wrap: false,
                language: Locale.current.identifier
            )
            #else
            let miss = checker.checkSpelling(
                of: working,
                startingAt: cursor,
                language: Locale.current.identifier,
                wrap: false,
                inSpellDocumentWithTag: docTag,
                wordCount: nil
            )
            #endif

            if miss.location == NSNotFound {
                // Append the remainder and finish
                let remainder = (working as NSString).substring(from: cursor)
                attributed.append(AttributedString(remainder))
                break
            }

            let ns = working as NSString
            // Append the untouched text before the misspelled range
            if miss.location > cursor {
                let before = ns.substring(with: NSRange(location: cursor, length: miss.location - cursor))
                attributed.append(AttributedString(before))
            }

            let token = ns.substring(with: miss)
            let suggestion = bestSuggestion(for: token, missRange: miss, in: ns) ?? token

            if suggestion != token { mistakes += 1 }

            var sugAttr = AttributedString(suggestion)
            if suggestion != token {
                sugAttr.foregroundColor = SwiftUI.Color.red
            }
            attributed.append(sugAttr)

            // Apply the replacement to keep subsequent ranges correct
            working = ns.replacingCharacters(in: miss, with: suggestion)
            cursor = miss.location + (suggestion as NSString).length
        }

        let remaining = max(0, 5 - mistakes)
        return (attributed, remaining, working)
    }
}
