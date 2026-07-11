//
//  PromptTemplate.swift
//  BlackVoice
//
//  做咩：Prompt 模板資料模型（變數 example + Profile 綁定）。
//  維護：上限見 README-Setting.md → Prompts。

import Foundation

struct PromptTemplate: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var description: String
    var content: String
    var modelID: String
    /// Text variable examples, e.g. ["name": "Ken"].
    var variableExamples: [String: String]
    /// Profile slot bindings, e.g. ["PROFILE#1": uuid].
    var profileBindings: [String: UUID]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        content: String = "",
        modelID: String = "",
        variableExamples: [String: String] = [:],
        profileBindings: [String: UUID] = [:],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.content = content
        self.modelID = modelID
        self.variableExamples = variableExamples
        self.profileBindings = profileBindings
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct PromptDocument: Codable, Sendable {
    var version: Int
    var prompts: [PromptTemplate]
}
