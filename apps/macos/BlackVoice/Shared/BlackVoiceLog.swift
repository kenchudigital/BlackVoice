//
//  BlackVoiceLog.swift
//  BlackVoice (Shared)
//
//  做咩：統一 debug log（public 俾 Shared 其他 file 跨 file 使用）。
//  維護：Release 只寫 os.Logger；Debug 額外 print。
//  注意：nonisolated static — 俾 AppIntent perform() 等 background context 用到。

import Foundation
import os

public enum BlackVoiceLog: Sendable {
    public nonisolated static let subsystem = "kenchuhk.BlackVoice"

    public enum Category: String, Sendable {
        case app
        case widget
        case intent
        case deeplink
    }

    public nonisolated static func info(_ category: Category, _ message: String) {
        #if DEBUG
        print("[BlackVoice|\(category.rawValue)] \(message)")
        #endif
        Logger(subsystem: subsystem, category: category.rawValue).info("\(message)")
    }

    public nonisolated static func error(_ category: Category, _ message: String) {
        #if DEBUG
        print("[BlackVoice|\(category.rawValue)] ERROR: \(message)")
        #endif
        Logger(subsystem: subsystem, category: category.rawValue).error("\(message)")
    }

    public nonisolated static func debug(_ category: Category, _ message: String) {
        #if DEBUG
        print("[BlackVoice|\(category.rawValue)] \(message)")
        #endif
        Logger(subsystem: subsystem, category: category.rawValue).debug("\(message)")
    }
}
