//
//  ChatHistoryEntry.swift
//  BlackVoice
//
//  做咩：單次 Chat 問答歷史紀錄。
//  目的：datetime、question、response、token usage；上限見 README-Setting.md。

import Foundation

struct TokenUsage: Codable, Hashable, Sendable {
    var inputTokens: Int
    var outputTokens: Int
    var totalTokens: Int
}

struct ChatHistoryEntry: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let createdAt: Date
    let question: String
    let response: String
    let modelID: String
    let inputTokens: Int?
    let outputTokens: Int?
    let totalTokens: Int?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        question: String,
        response: String,
        modelID: String,
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        totalTokens: Int? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.question = question
        self.response = response
        self.modelID = modelID
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
    }

    var usageSummary: String {
        guard let inputTokens, let outputTokens, let totalTokens else {
            return "Tokens: —"
        }
        return "in \(inputTokens) · out \(outputTokens) · total \(totalTokens)"
    }
}

struct ChatHistoryDocument: Codable, Sendable {
    var version: Int
    var entries: [ChatHistoryEntry]
}
