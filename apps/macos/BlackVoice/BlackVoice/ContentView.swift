//
//  ContentView.swift
//  BlackVoice
//

import SwiftUI

// MARK: - ContentView（主視窗：Sidebar + 內容區）
// 做咩：左側 Sidebar 揀頁面，右側顯示對應空頁或之後嘅功能 UI。
// 目的：對應 PRODUCT.md 整體佈局（Sidebar | Chat Area / 各管理頁）。

struct ContentView: View {
    @EnvironmentObject private var navigation: AppNavigationState

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView(for: navigation.selectedSection)
        }
        .frame(minWidth: 720, minHeight: 480)
    }

    // 做咩：側邊欄列表，列出六個功能入口。
    // 目的：使用者點選後更新 selectedSection，右側 detail 跟住變。
    private var sidebar: some View {
        List(AppSection.allCases, selection: sectionSelection) { section in
            Label(section.title, systemImage: section.systemImage)
                .tag(section)
        }
        .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 240)
        .navigationTitle("Black Voice")
    }

    private var sectionSelection: Binding<AppSection?> {
        Binding(
            get: { navigation.selectedSection },
            set: { newValue in
                guard let newValue, newValue != navigation.selectedSection else { return }
                Task { @MainActor in
                    navigation.selectedSection = newValue
                }
            }
        )
    }

    @ViewBuilder
    private func detailView(for section: AppSection) -> some View {
        switch section {
        case .chat:
            ChatView()
        case .prompts:
            PromptTemplatesView()
        case .profile:
            ProfileView()
        case .settings:
            SettingsView()
        }
    }
}

#Preview {
    let settings = PerplexitySettingsStore()
    let history = ChatHistoryStore()
    return ContentView()
        .environmentObject(AppNavigationState())
        .environmentObject(settings)
        .environmentObject(ChatViewModel(settings: settings, historyStore: history))
        .environmentObject(history)
        .environmentObject(ProfileStore())
        .environmentObject(PromptStore())
}
