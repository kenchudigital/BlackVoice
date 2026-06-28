//
//  BlackVoiceApp.swift
//  BlackVoice
//

import SwiftUI

@main
struct BlackVoiceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var navigation = AppNavigationState()

    var body: some Scene {
        WindowGroup(id: "main") {
            RootView(navigation: navigation, appDelegate: appDelegate)
        }
        .defaultSize(width: 960, height: 640)
        .defaultLaunchBehavior(.suppressed)
        .handlesExternalEvents(matching: Set(arrayLiteral: "blackvoice"))

        MenuBarExtra {
            MenuBarMenuView()
        } label: {
            MenuBarLabelView(navigation: navigation, appDelegate: appDelegate)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct RootView: View {
    @ObservedObject var navigation: AppNavigationState
    let appDelegate: AppDelegate

    var body: some View {
        ContentView()
            .environmentObject(navigation)
            .onAppear {
                BlackVoiceLog.info(.app, "RootView.onAppear — ContentView visible")
                appDelegate.bind(navigation: navigation)
            }
    }
}
