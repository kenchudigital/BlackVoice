//
//  UserProfile.swift
//  BlackVoice
//
//  做咩：使用者 Profile 資料模型。
//  目的：Profile 頁 CRUD；每項有唯一 id、name、description、content。
//  維護：上限見 README-Setting.md → Profile。

import Foundation

struct UserProfile: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var description: String
    var content: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        content: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct ProfileDocument: Codable, Sendable {
    var version: Int
    var profiles: [UserProfile]
}
