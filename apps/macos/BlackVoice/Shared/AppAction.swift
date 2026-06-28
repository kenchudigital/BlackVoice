//
//  AppAction.swift
//  BlackVoice (Shared)
//
//  做咩：統一 Widget / Deep Link / 主 App 導航動作 + App Group 檔案通訊。
//  目的：用 Group Container 入面嘅 file 傳 action，避開 UserDefaults CFPrefs 警告。
//  維護：加新掣 → 加 AppAction case + WidgetActionIntents + AppNavigationState.apply。

import Foundation

public enum AppAction: String, Sendable {
    case chat
    case voice
    case settings
    case close

    public nonisolated static let urlScheme = "blackvoice"

    public nonisolated var url: URL {
        URL(string: "\(Self.urlScheme)://\(rawValue)")!
    }

    public nonisolated init?(url: URL) {
        guard url.scheme == Self.urlScheme, let host = url.host else { return nil }
        self.init(rawValue: host)
    }
}

public enum AppActionStore: Sendable {
    public nonisolated static let appGroupID = "group.kenchuhk.BlackVoice"
    nonisolated static let pendingFileName = "pending_action.txt"
    public nonisolated static let darwinNotificationName = "kenchuhk.BlackVoice.widgetAction"

    public nonisolated static func appGroupContainerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    nonisolated static func pendingFileURL() -> URL? {
        appGroupContainerURL()?.appendingPathComponent(pendingFileName)
    }

    public nonisolated static func setPending(_ action: AppAction) {
        BlackVoiceLog.info(.intent, "AppActionStore.setPending(\(action.rawValue))")
        guard let fileURL = pendingFileURL() else {
            BlackVoiceLog.error(.intent, "pendingFileURL nil — App Group container missing")
            return
        }
        do {
            try action.rawValue.write(to: fileURL, atomically: true, encoding: .utf8)
            BlackVoiceLog.info(.intent, "Wrote pending action to \(fileURL.path)")
        } catch {
            BlackVoiceLog.error(.intent, "Write pending action failed: \(error.localizedDescription)")
            return
        }
        let notification = CFNotificationName(darwinNotificationName as CFString)
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            notification,
            nil,
            nil,
            true
        )
    }

    public nonisolated static func peekPending() -> AppAction? {
        readPending(removeAfterRead: false)
    }

    public nonisolated static func consumePending() -> AppAction? {
        readPending(removeAfterRead: true)
    }

    nonisolated private static func readPending(removeAfterRead: Bool) -> AppAction? {
        guard let fileURL = pendingFileURL() else {
            BlackVoiceLog.error(.app, "peek/consume — pendingFileURL nil")
            return nil
        }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        guard let raw = try? String(contentsOf: fileURL, encoding: .utf8),
              let action = AppAction(rawValue: raw.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            BlackVoiceLog.error(.app, "peek/consume — invalid file at \(fileURL.path)")
            return nil
        }
        if removeAfterRead {
            try? FileManager.default.removeItem(at: fileURL)
            BlackVoiceLog.info(.app, "AppActionStore.consumePending → \(action.rawValue)")
        } else {
            BlackVoiceLog.debug(.app, "AppActionStore.peekPending → \(action.rawValue)")
        }
        return action
    }
}
