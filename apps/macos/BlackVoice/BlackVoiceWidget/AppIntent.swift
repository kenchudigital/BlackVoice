//
//  AppIntent.swift
//  BlackVoiceWidget
//
//  Created by Tsz Kan Chu on 28/6/2026.
//

import WidgetKit
import AppIntents

// MARK: - ConfigurationAppIntent（Edit Widget 設定）
// 做咩：使用者喺「Edit Widget」面板可以改嘅設定（WidgetConfigurationIntent）。
// 目的：之後會加 Text / Voice 各自用邊個 Prompt Template；
//       同撳掣嘅 action intent 唔同——呢個係「設定」，唔係「撳掣做咩」。
// 注意：Profile / 對話歷史預設係主 App Settings 管，唔係呢度。

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Configuration" }
    static var description: IntentDescription { "BlackVoice Widget" }
}

// MARK: - Action Intents（四個掣各自嘅動作）
// 做咩：使用者撳 Widget 上嘅掣時，系統會 call perform()。
// 目的：openAppWhenRun = true 表示撳掣會開主 App；之後 perform() 入面加 deep link
//       （例如 blackvoice://chat）同 App Group 傳 template id。

struct OpenTextModeIntent: AppIntent {
    static var title: LocalizedStringResource = "Text Mode"
    static var openAppWhenRun: Bool = true // 目的：開 App 入文字聊天

    func perform() async throws -> some IntentResult {
        // 之後：寫入 App Group + 開 blackvoice://chat
        .result()
    }
}

struct OpenVoiceModeIntent: AppIntent {
    static var title: LocalizedStringResource = "Voice Mode"
    static var openAppWhenRun: Bool = true // 目的：開 App 直入語音模式

    func perform() async throws -> some IntentResult {
        // 之後：開 blackvoice://voice，主 App 隱藏視窗開始聆聽
        .result()
    }
}

struct OpenSettingsIntent: AppIntent {
    static var title: LocalizedStringResource = "Settings"
    static var openAppWhenRun: Bool = true // 目的：開 App 入設定頁

    func perform() async throws -> some IntentResult {
        // 之後：開 blackvoice://settings
        .result()
    }
}

struct CloseAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Close"
    static var openAppWhenRun: Bool = true // 目的：要主 App process 執行關閉（Widget 自己關唔到 App）

    func perform() async throws -> some IntentResult {
        // 之後：通知主 App call NSApplication.shared.terminate(nil)
        .result()
    }
}
