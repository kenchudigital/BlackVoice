//
//  MenuBarMenuView.swift
//  BlackVoice
//

import AppKit
import SwiftUI

// MARK: - MenuBarMenuView（Menu Bar 圖示下拉選單）
// 做咩：macOS 頂部 Menu Bar 嘅 BlackVoice 圖示，撳落去有快捷入口。
// 目的：對應 PRODUCT.md — Voice 狀態顯示、快捷開 Chat / Settings、Quit。

struct MenuBarMenuView: View {
    @EnvironmentObject private var navigation: AppNavigationState

    var body: some View {
        Button("Chat") {
            navigation.navigate(to: .chat)
        }

        Button("Voice Mode") {
            // 之後：隱藏主視窗、開始聆聽、更新 Menu Bar 狀態
            navigation.navigate(to: .chat)
        }

        Divider()

        Button("Agents") {
            navigation.navigate(to: .agents)
        }

        Button("Prompts") {
            navigation.navigate(to: .prompts)
        }

        Button("Profile") {
            navigation.navigate(to: .profile)
        }

        Button("History") {
            navigation.navigate(to: .history)
        }

        Button("Settings") {
            navigation.navigate(to: .settings)
        }

        Divider()

        Button("Quit BlackVoice") {
            NSApplication.shared.terminate(nil)
        }
    }
}
