//
//  MenuBarLabelView.swift
//  BlackVoice
//
//  做咩：Menu Bar 圖示（常駐顯示）— App 一 launch 就 load。
//  目的：openWindow 註冊 + 錄音中 REC 指示（唔依賴 WidgetKit timeline）。

import SwiftUI

struct MenuBarLabelView: View {
    @ObservedObject var navigation: AppNavigationState
    @ObservedObject var chatViewModel: ChatViewModel
    var appDelegate: AppDelegate
    @Environment(\.openWindow) private var openWindow

    private var isRecording: Bool { chatViewModel.isListening }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image("MenuBarIcon")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 18, height: 18)
                .colorMultiply(isRecording ? Color(red: 1, green: 0.35, blue: 0.35) : .white)

            if isRecording {
                Text("REC")
                    .font(.system(size: 5, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 2)
                    .padding(.vertical, 1)
                    .background(Color.red, in: Capsule())
                    .offset(x: 5, y: -5)
            }
        }
        .frame(width: 22, height: 18)
        .help(isRecording ? "Recording voice — tap Widget Voice again to stop" : "BlackVoice")
        .onAppear {
            BlackVoiceLog.info(.app, "MenuBarLabelView.onAppear — registering openWindow")
            appDelegate.earlyBind(navigation: navigation, chatViewModel: chatViewModel)
            navigation.configureAppDelegate(appDelegate)
            appDelegate.registerOpenMainWindowHandler {
                openWindow(id: "main")
            }
            appDelegate.presentMainWindowOnLaunchIfNeeded()
        }
    }
}
