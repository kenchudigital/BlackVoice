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
    @StateObject private var chatViewModel: ChatViewModel

    init() {
        let settings = PerplexitySettingsStore()
        _perplexitySettings = StateObject(wrappedValue: settings)
        _chatViewModel = StateObject(wrappedValue: ChatViewModel(settings: settings))
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            RootView(
                navigation: navigation,
                perplexitySettings: perplexitySettings,
                chatViewModel: chatViewModel,
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
    let appDelegate: AppDelegate

    var body: some View {
        ContentView()
            .environmentObject(navigation)
            .environmentObject(perplexitySettings)
            .environmentObject(chatViewModel)
            .onAppear {
                BlackVoiceLog.info(.app, "RootView.onAppear — ContentView visible")
                appDelegate.bind(navigation: navigation, chatViewModel: chatViewModel)
            }
    }
}
