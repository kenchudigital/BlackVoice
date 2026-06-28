//
//  PerplexityModel.swift
//  BlackVoice
//
//  做咩：Perplexity GET /v1/models 返回嘅 model 資料。
//  目的：Settings 同 Chat 共用；Chat 一律 POST /v1/agent，直接用 id。
//  維護：API schema 變 → 更新 Codable struct。

import Foundation

struct PerplexityModelInfo: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let ownedBy: String

    enum CodingKeys: String, CodingKey {
        case id
        case ownedBy = "owned_by"
    }

    /// 做咩：顯示用短名（例如 perplexity/sonar → sonar）。
    var displayName: String {
        if let slash = id.firstIndex(of: "/") {
            return String(id[id.index(after: slash)...])
        }
        return id
    }
}
