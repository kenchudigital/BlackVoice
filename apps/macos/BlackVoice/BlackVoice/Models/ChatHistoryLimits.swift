//
//  ChatHistoryLimits.swift
//  BlackVoice
//
//  做咩：Chat History 上限與儲存路徑常數。
//  維護：數值必須與 README-Setting.md → Chat History 一致。

import Foundation

enum ChatHistoryLimits {
    static let maxCount = 1000
    static let questionMaxBytes = 32_768
    static let responseMaxBytes = 131_072
    static let documentVersion = 1
    static let applicationSupportSubpath = "kenchuhk.BlackVoice"
    static let storageFileName = "chat_history.json"

    static func historyFileURL() -> URL? {
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
