//
//  AppSection.swift
//  BlackVoice
//

import Foundation

// MARK: - AppSection（側邊欄 / Menu Bar 導航項目）
// 做咩：定義主 App 有邊幾個功能頁面。
// 目的：對應 PRODUCT.md 側邊欄（Chat、Agents、Prompts、Profile、History、Settings）。

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case chat
    case agents
    case prompts
    case profile
    case history
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chat: "Chat"
        case .agents: "Agents"
        case .prompts: "Prompts"
        case .profile: "Profile"
        case .history: "History"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .chat: "bubble.left.and.bubble.right"
        case .agents: "cpu"
        case .prompts: "doc.text"
        case .profile: "person.crop.circle"
        case .history: "clock.arrow.circlepath"
        case .settings: "gearshape"
        }
    }
}
