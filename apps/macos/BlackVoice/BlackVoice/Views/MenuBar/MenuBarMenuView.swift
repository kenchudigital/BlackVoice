//
//  MenuBarMenuView.swift
//  BlackVoice
//
//  做咩：Menu Bar 下拉內容（Quit）。
//  注意：呢個 view 要撳 Menu Bar icon 先 load — openWindow 唔放喺呢度。

import AppKit
import SwiftUI

struct MenuBarMenuView: View {
    var body: some View {
        Button("Quit BlackVoice") {
            NSApplication.shared.terminate(nil)
        }
        .padding(8)
    }
}
