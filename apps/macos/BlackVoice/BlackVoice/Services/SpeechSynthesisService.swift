//
//  SpeechSynthesisService.swift
//  BlackVoice
//
//  做咩：macOS 內置 TTS（AVSpeechSynthesizer，同 say 命令同引擎）。
//  目的：Speak toggle 開時朗讀 assistant 回覆。
//  維護：synthesizer 喺 userInitiated queue，@Published 只喺 MainActor 更新（避 QoS inversion）。

import AVFoundation
import Combine

final class SpeechSynthesisService: NSObject, ObservableObject {
    @Published private(set) var isSpeaking = false

    private let synthesizerQueue = DispatchQueue(label: "kenchuhk.BlackVoice.speechSynthesis", qos: .userInitiated)
    private let synthesizer = AVSpeechSynthesizer()
    private var speakContinuation: CheckedContinuation<Void, Never>?

    var languageCode = "en-US"

    override init() {
        super.init()
        synthesizerQueue.sync {
            synthesizer.delegate = self
        }
    }

    func speak(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        await withCheckedContinuation { continuation in
            synthesizerQueue.async { [weak self] in
                guard let self else {
                    continuation.resume()
                    return
                }
                self.stopOnQueue()
                self.speakContinuation = continuation

                let utterance = AVSpeechUtterance(string: trimmed)
                utterance.voice = AVSpeechSynthesisVoice(language: self.languageCode)
                utterance.rate = AVSpeechUtteranceDefaultSpeechRate

                Task { @MainActor in
                    self.isSpeaking = true
                }
                self.synthesizer.speak(utterance)
            }
        }
    }

    func stop() {
        synthesizerQueue.async { [weak self] in
            self?.stopOnQueue()
        }
    }

    private func stopOnQueue() {
        guard synthesizer.isSpeaking else { return }
        synthesizer.stopSpeaking(at: .immediate)
        finishSpeakingOnQueue()
    }

    private func finishSpeakingOnQueue() {
        guard let continuation = speakContinuation else {
            Task { @MainActor [weak self] in
                self?.isSpeaking = false
            }
            return
        }
        speakContinuation = nil
        continuation.resume()
        Task { @MainActor [weak self] in
            self?.isSpeaking = false
        }
    }
}

extension SpeechSynthesisService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        synthesizerQueue.async { [weak self] in
            self?.finishSpeakingOnQueue()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        synthesizerQueue.async { [weak self] in
            self?.finishSpeakingOnQueue()
        }
    }
}
