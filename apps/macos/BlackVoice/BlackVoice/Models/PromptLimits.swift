//
//  PromptLimits.swift
//  BlackVoice
//
//  做咩：Prompt 上限與儲存路徑常數。
//  維護：數值必須與 README-Setting.md → Prompts 一致。

import Foundation

enum PromptLimits {
    static let maxCount = 50
    static let nameMaxLength = 64
    static let descriptionMaxLength = 256
    static let contentMaxBytes = 65_536
    static let exampleValueMaxBytes = 32_768
    static let maxProfileSlots = 5
    static let maxTextVariables = 20
    static let documentVersion = 1
    static let defaultNewName = "New Prompt"
    static let profileToken = "PROFILE"
    static let applicationSupportSubpath = "kenchuhk.BlackVoice"
    static let storageFileName = "prompts.json"

    static func promptsFileURL() -> URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return base
            .appendingPathComponent(applicationSupportSubpath, isDirectory: true)
            .appendingPathComponent(storageFileName)
    }

    static func truncateToMaxBytes(_ text: String, maxBytes: Int) -> String {
        guard text.utf8.count > maxBytes else { return text }
        var result = ""
        for character in text {
            let candidate = result + String(character)
            if candidate.utf8.count > maxBytes { break }
            result = candidate
        }
        return result
    }
}

enum PromptValidation {
    static let nameRequired = "Name is required."
    static let nameTooLong = "Name must be at most 64 characters."
    static let descriptionTooLong = "Description must be at most 256 characters."
    static let contentTooLong = "Content must be at most 64 KB."
    static let modelRequired = "Select an enabled model from Settings."
    static let tooManyProfileSlots = "You can use at most 5 {{PROFILE}} placeholders."
    static let tooManyTextVariables = "You can use at most 20 text variables."
    static let maxCountReached = "You can save at most 50 prompts."

    static func validate(
        name: String,
        description: String,
        content: String,
        modelID: String,
        enabledModelIDs: Set<String>
    ) -> String? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nameRequired }
        guard trimmedName.count <= PromptLimits.nameMaxLength else { return nameTooLong }
        guard description.count <= PromptLimits.descriptionMaxLength else { return descriptionTooLong }
        guard content.utf8.count <= PromptLimits.contentMaxBytes else { return contentTooLong }

        let slots = PromptVariableEngine.parseSlots(in: content)
        if slots.profileSlotKeys.count > PromptLimits.maxProfileSlots {
            return tooManyProfileSlots
        }
        if slots.textVariableKeys.count > PromptLimits.maxTextVariables {
            return tooManyTextVariables
        }

        let trimmedModel = modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedModel.isEmpty, enabledModelIDs.contains(trimmedModel) else {
            return modelRequired
        }
        return nil
    }
}
