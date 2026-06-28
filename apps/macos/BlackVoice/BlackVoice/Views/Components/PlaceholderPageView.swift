//
//  PlaceholderPageView.swift
//  BlackVoice
//

import SwiftUI

// MARK: - PlaceholderPageView（骨架空頁）
// 做咩：顯示頁面標題同 icon，提示功能尚未實作。
// 目的：Phase 1 先搭好導航結構，之後逐頁替換成真正 UI。

struct PlaceholderPageView: View {
    let section: AppSection

    var body: some View {
        ContentUnavailableView {
            Label(section.title, systemImage: section.systemImage)
        } description: {
            Text("Coming soon")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(section.title)
    }
}

#Preview {
    PlaceholderPageView(section: .chat)
}
