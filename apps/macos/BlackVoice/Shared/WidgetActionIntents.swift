//
//  WidgetActionIntents.swift
//  BlackVoice (Shared — 主 App + Widget Extension)
//
//  做咩：Widget 四個掣嘅 AppIntent。
//  目的：perform 寫 AppActionStore；openAppWhenRun 啟動主 App（Voice/Close 見 guideline.md）。
//  維護：加新掣 → 加 Intent struct + BlackVoiceWidget actionButtons + AppAction case。
//  依賴：AppActionStore 喺 Shared/AppAction.swift（同 target 必須 compile 該 file）。

import AppIntents
import Foundation

struct OpenTextModeIntent: AppIntent {
    static var title: LocalizedStringResource = "Text Mode"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        AppActionStore.setPending(.chat)
        return .result()
    }
}

struct OpenVoiceModeIntent: AppIntent {
    static var title: LocalizedStringResource = "Voice Mode"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        BlackVoiceLog.info(.intent, "OpenVoiceModeIntent.perform() — pending voice (store=\(VoiceRecordingStore.isRecording()))")
        AppActionStore.setPending(.voice)
        return .result()
    }
}

struct OpenSettingsIntent: AppIntent {
    static var title: LocalizedStringResource = "Settings"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        AppActionStore.setPending(.settings)
        return .result()
    }
}

struct CloseAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Close"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        AppActionStore.setPending(.close)
        return .result()
    }
}
