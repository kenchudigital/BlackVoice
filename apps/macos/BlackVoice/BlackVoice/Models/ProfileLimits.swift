//
//  ProfileLimits.swift
//  BlackVoice
//
//  做咩：Profile 上限與儲存路徑常數。
//  維護：數值必須與 README-Setting.md → Profile 一致。

import Foundation

enum ProfileLimits {
    static let maxCount = 50
    static let nameMaxLength = 64
    static let descriptionMaxLength = 256
    static let contentMaxBytes = 65_536
    static let documentVersion = 1
    static let defaultNewName = "New Profile"
    static let applicationSupportSubpath = "kenchuhk.BlackVoice"
    static let storageFileName = "profiles.json"

    static func profilesFileURL() -> URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return base
            .appendingPathComponent(applicationSupportSubpath, isDirectory: true)
            .appendingPathComponent(storageFileName)
    }
}

enum ProfileValidation {
    static let nameRequired = "Name is required."
    static let nameTooLong = "Name must be at most 64 characters."
    static let descriptionTooLong = "Description must be at most 256 characters."
    static let contentTooLong = "Content must be at most 64 KB."
    static let maxCountReached = "You can save at most 50 profiles."

    static func validate(name: String, description: String, content: String) -> String? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nameRequired }
        guard trimmedName.count <= ProfileLimits.nameMaxLength else { return nameTooLong }
        guard description.count <= ProfileLimits.descriptionMaxLength else { return descriptionTooLong }
        guard content.utf8.count <= ProfileLimits.contentMaxBytes else { return contentTooLong }
        return nil
    }

    static func utf8ByteCount(for text: String) -> Int {
        text.utf8.count
    }
}
