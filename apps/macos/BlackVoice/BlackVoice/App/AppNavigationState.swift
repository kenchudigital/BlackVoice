//
//  AppNavigationState.swift
//  BlackVoice
//

import AppKit
import Combine
import SwiftUI

// MARK: - AppNavigationState（全 App 導航狀態）
// 做咩：記住而家開緊邊個側邊欄頁面，並提供跳轉方法。
// 目的：主視窗 Sidebar 同 Menu Bar 掣都共用同一狀態；之後 deep link 都會用。

@MainActor
final class AppNavigationState: ObservableObject {
    @Published var selectedSection: AppSection = .chat

    // 做咩：切換頁面並將主視窗帶到前景。
    // 目的：Menu Bar 撳「Settings」等時，開返 App 視窗並顯示對應頁。
    func navigate(to section: AppSection) {
        selectedSection = section
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.canBecomeMain {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
