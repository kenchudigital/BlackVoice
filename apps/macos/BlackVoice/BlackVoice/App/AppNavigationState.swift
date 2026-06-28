//
//  AppNavigationState.swift
//  BlackVoice
//
//  做咩：主 App 導航狀態（邊一頁、主視窗 show/hide）。
//  目的：Sidebar selectedSection + Widget/URL 觸發嘅視窗行為。
//  維護：新頁面加 AppSection；新 Widget 掣加 AppAction + apply(action:) case。

import AppKit
import Combine
import SwiftUI

@MainActor
final class AppNavigationState: ObservableObject {
    @Published var selectedSection: AppSection = .chat

    /// 做咩：開主視窗經 AppDelegate.openMainWindow()（handler 只 register 一次）。
    private weak var appDelegate: AppDelegate?
    private var bringToFrontTask: Task<Void, Never>?

    func configureAppDelegate(_ delegate: AppDelegate) {
        appDelegate = delegate
        BlackVoiceLog.debug(.app, "configureAppDelegate — linked")
    }

    /// 做咩：處理 blackvoice:// URL（Terminal `open`、將來外部連結）。
    func handle(url: URL) {
        BlackVoiceLog.info(.deeplink, "handle(url: \(url.absoluteString))")
        guard let action = AppAction(url: url) else {
            BlackVoiceLog.error(.deeplink, "Failed to parse AppAction from \(url.absoluteString)")
            return
        }
        apply(action: action)
    }

    /// 做咩：Widget / AppDelegate 傳入嘅 action。
    func apply(action: AppAction) {
        BlackVoiceLog.info(.app, "apply(action: \(action.rawValue))")
        switch action {
        case .chat:
            selectedSection = .chat
            showMainWindows()
        case .voice:
            applyVoiceBackgroundMode()
        case .settings:
            selectedSection = .settings
            showMainWindows()
        case .close:
            NSApplication.shared.terminate(nil)
        }
    }

    /// 做咩：Widget Voice — 揀 Chat、hide 主視窗（背景錄音，唔 activate）。
    func applyVoiceBackgroundMode() {
        BlackVoiceLog.info(.app, "applyVoiceBackgroundMode — chat hidden, background voice")
        selectedSection = .chat
        hideMainWindows()
    }

    func ensureMainWindowsHidden() {
        hideMainWindows()
    }

    private func showMainWindows(retryIfNoHandler: Bool = true) {
        NSApp.activate(ignoringOtherApps: true)
        let windows = mainAppWindows()
        BlackVoiceLog.debug(.app, "showMainWindows — found \(windows.count) window(s)")

        if windows.isEmpty {
            guard let appDelegate, appDelegate.canOpenMainWindow else {
                if retryIfNoHandler {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(150))
                        showMainWindows(retryIfNoHandler: false)
                    }
                } else {
                    BlackVoiceLog.error(.app, "openMainWindow handler still nil after retry")
                }
                return
            }
            BlackVoiceLog.info(.app, "No main window — calling openMainWindow")
            appDelegate.openMainWindow()
            bringMainWindowsToFront(retry: true)
            return
        }

        for window in windows {
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func hideMainWindows() {
        bringToFrontTask?.cancel()
        bringToFrontTask = nil
        let windows = mainAppWindows()
        for window in windows {
            window.orderOut(nil)
        }
        BlackVoiceLog.debug(.app, "hideMainWindows — hid \(windows.count) window(s)")
    }

    private func bringMainWindowsToFront(retry: Bool) {
        guard retry else { return }
        bringToFrontTask?.cancel()
        bringToFrontTask = Task { @MainActor in
            for attempt in 1...8 {
                try? await Task.sleep(for: .milliseconds(50 * attempt))
                guard !Task.isCancelled else { return }
                let windows = mainAppWindows()
                if !windows.isEmpty {
                    for window in windows {
                        window.makeKeyAndOrderFront(nil)
                    }
                    return
                }
            }
            if !Task.isCancelled {
                BlackVoiceLog.error(.app, "Main window not found after openWindow retries")
            }
        }
    }

    private func mainAppWindows() -> [NSWindow] {
        NSApp.windows.filter { window in
            window.canBecomeMain
                && window.level == .normal
                && !(window is NSPanel)
                && window.frame.width >= 400
        }
    }
}
