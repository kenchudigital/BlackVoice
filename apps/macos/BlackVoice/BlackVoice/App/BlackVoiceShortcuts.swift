//
//  BlackVoiceShortcuts.swift
//  BlackVoice
//
//  做咩：向 Shortcuts / linkd 註冊 App 支援嘅 Intent。
//  目的：非 Widget 必需，但有助系統 index metadata。

import AppIntents

struct BlackVoiceShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenTextModeIntent(),
            phrases: ["Open chat in \(.applicationName)"],
            shortTitle: "Chat",
            systemImageName: "text.bubble"
        )
        AppShortcut(
            intent: OpenSettingsIntent(),
            phrases: ["Open settings in \(.applicationName)"],
            shortTitle: "Settings",
            systemImageName: "gearshape"
        )
    }
}
