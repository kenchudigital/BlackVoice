//
//  BlackVoiceApp.swift
//  BlackVoice
//
//  Created by Tsz Kan Chu on 28/6/2026.
//

import SwiftUI

@main
struct BlackVoiceApp: App {
    // 做咩：全 App 共用嘅導航狀態（Sidebar + Menu Bar 都用）。
    // 目的：喺 Menu Bar 撳 Settings 時，主視窗可以跳去對應頁。
    @StateObject private var navigation = AppNavigationState()

    var body: some Scene {
        // 做咩：主視窗 — Sidebar + 各功能空頁。
        // 目的：Phase 1 骨架；日常開發用 BlackVoice scheme Run 呢個。
        WindowGroup {
            ContentView()
                .environmentObject(navigation)
        }
        .defaultSize(width: 960, height: 640)

        // 做咩：macOS 頂部 Menu Bar 常駐圖示同下拉選單。
        // 目的：用 App Logo 做 Menu Bar icon；快捷開各頁。
        MenuBarExtra {
            MenuBarMenuView()
                .environmentObject(navigation)
        } label: {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
        }
        .menuBarExtraStyle(.menu)
    }
}
