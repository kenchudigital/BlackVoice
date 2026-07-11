//
//  AppSection.swift
//  BlackVoice
//

import Foundation

// MARK: - AppSection（側邊欄 / Menu Bar 導航項目）
// 做咩：定義主 App 有邊幾個功能頁面。
// 目的：對應側邊欄（Chat、Prompts、Profile、Settings）。

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case chat
    case prompts
    case profile
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chat: "Chat"
        case .prompts: "Prompts"
        case .profile: "Profile"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .chat: "bubble.left.and.bubble.right"
        case .prompts: "doc.text"
        case .profile: "person.crop.circle"
        case .settings: "gearshape"
        }
    }
}
