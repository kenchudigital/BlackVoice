//
//  PromptVariableEngine.swift
//  BlackVoice
//
//  做咩：掃描 {{var}}、將 {{PROFILE}} 編成 PROFILE#n、Preview 渲染。
//  維護：保留字 / 上限見 README-Setting.md → Prompts。

import Foundation

struct PromptParsedSlots: Equatable, Sendable {
    /// Ordered unique text variable names (excludes PROFILE).
    var textVariableKeys: [String]
    /// Ordered profile slot keys: PROFILE#1, PROFILE#2, …
    var profileSlotKeys: [String]
}

enum PromptVariableEngine {
    private static let tokenPattern = #"\{\{([A-Za-z_][A-Za-z0-9_]*)\}\}"#

    static func parseSlots(in content: String) -> PromptParsedSlots {
        guard let regex = try? NSRegularExpression(pattern: tokenPattern) else {
            return PromptParsedSlots(textVariableKeys: [], profileSlotKeys: [])
        }

        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        let matches = regex.matches(in: content, options: [], range: range)

        var textKeys: [String] = []
        var textSeen = Set<String>()
        var profileCount = 0

        for match in matches {
            guard match.numberOfRanges >= 2,
                  let tokenRange = Range(match.range(at: 1), in: content) else { continue }
            let token = String(content[tokenRange])

            if token == PromptLimits.profileToken {
                profileCount += 1
            } else if !textSeen.contains(token) {
                textSeen.insert(token)
                textKeys.append(token)
            }
        }

        let profileKeys: [String]
        if profileCount > 0 {
            profileKeys = (1...profileCount).map { "\(PromptLimits.profileToken)#\($0)" }
        } else {
            profileKeys = []
        }

        return PromptParsedSlots(
            textVariableKeys: textKeys,
            profileSlotKeys: profileKeys
        )
    }

    /// Renders template for Preview. PROFILE slots expand to Profile.content.
    static func renderPreview(
        content: String,
        variableExamples: [String: String],
        profileBindings: [String: UUID],
        profilesByID: [UUID: UserProfile]
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: tokenPattern) else { return content }

        var profileOccurrence = 0
        let nsContent = content as NSString
        let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: nsContent.length))

        var result = ""
        var lastIndex = 0

        for match in matches {
            let fullRange = match.range
            if fullRange.location > lastIndex {
                result += nsContent.substring(with: NSRange(location: lastIndex, length: fullRange.location - lastIndex))
            }

            guard match.numberOfRanges >= 2,
                  let tokenRange = Range(match.range(at: 1), in: content) else {
                result += nsContent.substring(with: fullRange)
                lastIndex = fullRange.location + fullRange.length
                continue
            }

            let token = String(content[tokenRange])
            if token == PromptLimits.profileToken {
                profileOccurrence += 1
                let slotKey = "\(PromptLimits.profileToken)#\(profileOccurrence)"
                if let profileID = profileBindings[slotKey],
                   let profile = profilesByID[profileID] {
                    result += profile.content
                } else {
                    result += "[\(slotKey) not selected]"
                }
            } else {
                let example = variableExamples[token] ?? ""
                result += example.isEmpty ? "[\(token)]" : example
            }

            lastIndex = fullRange.location + fullRange.length
        }

        if lastIndex < nsContent.length {
            result += nsContent.substring(with: NSRange(location: lastIndex, length: nsContent.length - lastIndex))
        }
        return result
    }

    static func prunedExamples(
        _ examples: [String: String],
        keeping keys: [String]
    ) -> [String: String] {
        var result: [String: String] = [:]
        for key in keys {
            if let value = examples[key] {
                result[key] = PromptLimits.truncateToMaxBytes(value, maxBytes: PromptLimits.exampleValueMaxBytes)
            } else {
                result[key] = ""
            }
        }
        return result
    }

    static func prunedProfileBindings(
        _ bindings: [String: UUID],
        keeping keys: [String]
    ) -> [String: UUID] {
        var result: [String: UUID] = [:]
        for key in keys {
            if let value = bindings[key] {
                result[key] = value
            }
        }
        return result
    }
}
