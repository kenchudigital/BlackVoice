//
//  WidgetVoiceRecordingObserver.swift
//  BlackVoiceWidget
//
//  做咩：聽 App 寫 voice_recording.txt 後嘅 Darwin notify，reload widget timeline。
//  目的：主 App call WidgetCenter 未必 wake extension；extension 自己 reload 先可靠。

import Foundation
import WidgetKit

final class WidgetVoiceRecordingObserver {
    static let shared = WidgetVoiceRecordingObserver()

    private var isRegistered = false

    private init() {
        registerIfNeeded()
    }

    func registerIfNeeded() {
        guard !isRegistered else { return }
        isRegistered = true
        BlackVoiceLog.info(.widget, "WidgetVoiceRecordingObserver — Darwin observer registered")

        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterAddObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer else { return }
                let observerObject = Unmanaged<WidgetVoiceRecordingObserver>.fromOpaque(observer).takeUnretainedValue()
                observerObject.handleRecordingStateChanged()
            },
            VoiceRecordingStore.darwinNotificationName as CFString,
            nil,
            .deliverImmediately
        )
    }

    private func handleRecordingStateChanged() {
        Task { @MainActor in
            let isRecording = VoiceRecordingStore.isRecording()
            BlackVoiceLog.info(.widget, "Darwin voiceRecording notify — isRecording=\(isRecording), reloading timeline")
            BlackVoiceWidgetReloader.reloadTimelinesNow()
        }
    }
}
