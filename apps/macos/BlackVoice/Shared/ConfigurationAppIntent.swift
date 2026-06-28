//
//  ConfigurationAppIntent.swift
//  BlackVoice (Shared — 主 App + Widget Extension)
//
//  做咩：Widget 設定 intent（Edit Widget gallery 用）。
//  目的：兩邊 target 都要有，避免 ConfigurationAppIntent not found error。

import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Configuration" }
    static var description: IntentDescription { "BlackVoice Widget" }
}
