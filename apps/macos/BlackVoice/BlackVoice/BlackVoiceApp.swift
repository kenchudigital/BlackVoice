//
//  BlackVoiceApp.swift
//  BlackVoice
//

import SwiftUI

@main
struct BlackVoiceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var navigation = AppNavigationState()
    @StateObject private var perplexitySettings: PerplexitySettingsStore
    @StateObject private var chatHistoryStore: ChatHistoryStore
    @StateObject private var chatViewModel: ChatViewModel
    @StateObject private var profileStore = ProfileStore()
    @StateObject private var promptStore = PromptStore()

    init() {
        let settings = PerplexitySettingsStore()
        let history = ChatHistoryStore()
        _perplexitySettings = StateObject(wrappedValue: settings)
        _chatHistoryStore = StateObject(wrappedValue: history)
        _chatViewModel = StateObject(wrappedValue: ChatViewModel(settings: settings, historyStore: history))
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            RootView(
                navigation: navigation,
                perplexitySettings: perplexitySettings,
                chatViewModel: chatViewModel,
                chatHistoryStore: chatHistoryStore,
                profileStore: profileStore,
                promptStore: promptStore,
                appDelegate: appDelegate
            )
        }
        .defaultSize(width: 960, height: 640)
        .defaultLaunchBehavior(.suppressed)
        .handlesExternalEvents(matching: Set(arrayLiteral: "blackvoice"))

        MenuBarExtra {
            MenuBarMenuView()
        } label: {
            MenuBarLabelView(
                navigation: navigation,
                chatViewModel: chatViewModel,
                appDelegate: appDelegate
            )
        }
        .menuBarExtraStyle(.window)
    }
}

private struct RootView: View {
    @ObservedObject var navigation: AppNavigationState
    @ObservedObject var perplexitySettings: PerplexitySettingsStore
    @ObservedObject var chatViewModel: ChatViewModel
    @ObservedObject var chatHistoryStore: ChatHistoryStore
    @ObservedObject var profileStore: ProfileStore
    @ObservedObject var promptStore: PromptStore
    let appDelegate: AppDelegate

    var body: some View {
        ContentView()
            .environmentObject(navigation)
            .environmentObject(perplexitySettings)
            .environmentObject(chatViewModel)
            .environmentObject(chatHistoryStore)
            .environmentObject(profileStore)
            .environmentObject(promptStore)
            .onAppear {
                BlackVoiceLog.info(.app, "RootView.onAppear — ContentView visible")
                appDelegate.bind(navigation: navigation, chatViewModel: chatViewModel)
            }
    }
}
