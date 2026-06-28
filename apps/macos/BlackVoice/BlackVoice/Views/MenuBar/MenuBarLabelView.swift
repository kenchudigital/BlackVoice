//
//  MenuBarLabelView.swift
//  BlackVoice
//
//  做咩：Menu Bar 圖示（常駐顯示）— App 一 launch 就 load。
//  目的：openWindow 必須喺 label 註冊；MenuBarMenuView 下拉內容要撳 icon 先 load。

import SwiftUI

struct MenuBarLabelView: View {
    @ObservedObject var navigation: AppNavigationState
    var appDelegate: AppDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image("MenuBarIcon")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: 18, height: 18)
            .onAppear {
                BlackVoiceLog.info(.app, "MenuBarLabelView.onAppear — registering openWindow")
                appDelegate.earlyBind(navigation: navigation)
                navigation.configureAppDelegate(appDelegate)
                appDelegate.registerOpenMainWindowHandler {
                    openWindow(id: "main")
                }
                appDelegate.presentMainWindowOnLaunchIfNeeded()
            }
    }
}
