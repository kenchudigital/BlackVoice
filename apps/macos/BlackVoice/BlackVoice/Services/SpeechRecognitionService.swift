//
//  SpeechRecognitionService.swift
//  BlackVoice
//
//  做咩：Speech framework STT — click 開始/停止，最長 60 秒。
//  目的：Mic 掣收聲轉文字，交 ChatViewModel.send(text:)。
//  維護：audio engine 喺 userInitiated queue；@Published 只喺 MainActor 更新。

import AVFoundation
import Combine
import Speech

enum SpeechRecognitionError: LocalizedError {
    case notAuthorized
    case microphoneDenied
    case recognizerUnavailable
    case audioEngineFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            "Speech recognition permission denied. Enable it in System Settings → Privacy."
        case .microphoneDenied:
            "Microphone permission denied. Enable it in System Settings → Privacy."
        case .recognizerUnavailable:
            "Speech recognizer is not available for this language."
        case .audioEngineFailed(let detail):
            "Could not start microphone: \(detail)"
        }
    }
}

final class SpeechRecognitionService: ObservableObject {
    static let maxDurationSeconds = 60

    @Published private(set) var isListening = false
    @Published private(set) var partialTranscript = ""
    @Published private(set) var secondsRemaining = maxDurationSeconds

    var localeIdentifier = "en-US"
    var onAutoStop: ((String) async -> Void)?

    private let audioQueue = DispatchQueue(label: "kenchuhk.BlackVoice.speechRecognition", qos: .userInitiated)
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var countdownTask: Task<Void, Never>?
    private var maxDurationTask: Task<Void, Never>?
    private var isTapInstalled = false

    func requestPermissions() async throws {
        let speechOK = await requestSpeechAuthorization()
        guard speechOK else { throw SpeechRecognitionError.notAuthorized }

        let micOK = await requestMicrophoneAccess()
        guard micOK else { throw SpeechRecognitionError.microphoneDenied }
    }

    func startListening() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            audioQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: SpeechRecognitionError.audioEngineFailed("Service deallocated"))
                    return
                }
                do {
                    try self.startListeningOnQueue()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    @discardableResult
    func stopListening() -> String {
        let snapshot: String
        if Thread.isMainThread {
            snapshot = partialTranscript
        } else {
            snapshot = DispatchQueue.main.sync { partialTranscript }
        }
        audioQueue.sync {
            stopListeningOnQueue()
        }
        return snapshot.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func startListeningOnQueue() throws {
        guard !isListening else { return }

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)),
              recognizer.isAvailable else {
            throw SpeechRecognitionError.recognizerUnavailable
        }

        stopListeningOnQueue()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        isTapInstalled = true

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            if isTapInstalled {
                inputNode.removeTap(onBus: 0)
                isTapInstalled = false
            }
            throw SpeechRecognitionError.audioEngineFailed(error.localizedDescription)
        }

        publishOnMainActor(isListening: true, partialTranscript: "", secondsRemaining: Self.maxDurationSeconds)

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                Task { @MainActor in
                    self.partialTranscript = text
                }
            }
            if let error {
                let nsError = error as NSError
                let benignCodes: Set<Int> = [216, 1110]
                if nsError.domain == "kAFAssistantErrorDomain", benignCodes.contains(nsError.code) {
                    BlackVoiceLog.debug(.app, "Speech recognition ended: \(error.localizedDescription)")
                } else {
                    BlackVoiceLog.error(.app, "Speech recognition error: \(error.localizedDescription)")
                }
            }
        }

        countdownTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            for remaining in stride(from: Self.maxDurationSeconds - 1, through: 0, by: -1) {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                let stillListening = await MainActor.run { self.isListening }
                guard stillListening else { return }
                await MainActor.run {
                    self.secondsRemaining = remaining
                }
            }
        }

        maxDurationTask = Task(priority: .userInitiated) { [weak self] in
            try? await Task.sleep(for: .seconds(Self.maxDurationSeconds))
            guard let self, !Task.isCancelled else { return }
            let stillListening = await MainActor.run { self.isListening }
            guard stillListening else { return }
            let transcript = self.stopListening()
            await self.onAutoStop?(transcript)
        }
    }

    private func stopListeningOnQueue() {
        countdownTask?.cancel()
        countdownTask = nil
        maxDurationTask?.cancel()
        maxDurationTask = nil

        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if isTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil

        publishOnMainActor(isListening: false, secondsRemaining: Self.maxDurationSeconds)
    }

    private func publishOnMainActor(isListening: Bool? = nil, partialTranscript: String? = nil, secondsRemaining: Int? = nil) {
        let apply = { [self] in
            if let isListening { self.isListening = isListening }
            if let partialTranscript { self.partialTranscript = partialTranscript }
            if let secondsRemaining { self.secondsRemaining = secondsRemaining }
        }
        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.sync(execute: apply)
        }
    }

    private func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private func requestMicrophoneAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        default:
            return false
        }
    }
}
