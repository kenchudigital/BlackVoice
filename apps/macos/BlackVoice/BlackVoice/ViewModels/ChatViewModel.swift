//
//  ChatViewModel.swift
//  BlackVoice
//
//  做咩：Chat 狀態、Perplexity 送收、Mic STT、Speak TTS。
//  目的：ChatView 只負責 UI；Mic click 開始/停，Speak toggle 朗讀回覆。
//  維護：加 streaming / history → 擴展 send() 同 messages 來源。

import Combine
import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    private static let speakRepliesKey = "chat.speakRepliesEnabled"

    @Published private(set) var messages: [ChatMessage] = []
    @Published var inputText = ""
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    @Published var isSpeakRepliesEnabled: Bool {
        didSet { UserDefaults.standard.set(isSpeakRepliesEnabled, forKey: Self.speakRepliesKey) }
    }

    @Published private(set) var isListening = false
    @Published private(set) var listeningSecondsRemaining = SpeechRecognitionService.maxDurationSeconds
    @Published private(set) var liveTranscript = ""

    let speechRecognition = SpeechRecognitionService()
    let speechSynthesis = SpeechSynthesisService()

    private let settings: PerplexitySettingsStore
    private var cancellables = Set<AnyCancellable>()
    private var recordingStartedAt: Date?

    /// 做咩：Widget stop 防抖 — 開始錄音後短時間內忽略 stop。
    static let widgetVoiceStopDebounceSeconds: TimeInterval = 0.9

    var canStopWidgetVoiceYet: Bool {
        guard isListening, let recordingStartedAt else { return true }
        return Date().timeIntervalSince(recordingStartedAt) >= Self.widgetVoiceStopDebounceSeconds
    }

    init(settings: PerplexitySettingsStore) {
        self.settings = settings
        isSpeakRepliesEnabled = UserDefaults.standard.bool(forKey: Self.speakRepliesKey)

        speechRecognition.onAutoStop = { [weak self] transcript in
            await self?.finishListening(with: transcript, autoStopped: true)
        }

        speechSynthesis.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    var canSend: Bool {
        !isLoading
            && !isListening
            && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !settings.chatModelID.isEmpty
            && !settings.chatEnabledModels.isEmpty
    }

    var canUseMic: Bool {
        settings.hasAPIKey
            && !settings.chatEnabledModels.isEmpty
            && !isLoading
    }

    func toggleVoiceSessionFromWidget() async {
        BlackVoiceLog.info(.app, "toggleVoiceSessionFromWidget — isListening=\(isListening) store=\(VoiceRecordingStore.isRecording())")

        if isListening {
            guard canStopWidgetVoiceYet else {
                BlackVoiceLog.info(.app, "toggleVoiceSessionFromWidget — stop ignored (debounce \(Self.widgetVoiceStopDebounceSeconds)s)")
                return
            }
            BlackVoiceLog.info(.app, "toggleVoiceSessionFromWidget — stop mic + send")
            await toggleMic()
            return
        }

        BlackVoiceLog.info(.app, "toggleVoiceSessionFromWidget — speak ON + start mic")
        isSpeakRepliesEnabled = true

        guard settings.hasAPIKey else {
            errorMessage = "Add your Perplexity API token in Settings to use voice."
            publishRecordingState(false)
            return
        }
        guard !settings.chatEnabledModels.isEmpty else {
            errorMessage = "Enable at least one model in Settings to use voice."
            publishRecordingState(false)
            return
        }
        guard canUseMic else {
            BlackVoiceLog.info(.app, "toggleVoiceSessionFromWidget — cannot use mic (isLoading=\(isLoading))")
            publishRecordingState(false)
            return
        }

        publishRecordingState(true)
        recordingStartedAt = Date()
        await startListening()
        BlackVoiceLog.info(.app, "toggleVoiceSessionFromWidget — after startListening isListening=\(isListening) store=\(VoiceRecordingStore.isRecording())")
    }

    func toggleSpeakReplies() {
        isSpeakRepliesEnabled.toggle()
    }

    func toggleMic() async {
        if isListening {
            let transcript = speechRecognition.stopListening()
            recordingStartedAt = nil
            syncListeningState()
            await finishListening(with: transcript, autoStopped: false)
        } else {
            recordingStartedAt = Date()
            await startListening()
        }
    }

    func send() async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        inputText = ""
        await send(text: trimmed)
    }

    func send(text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isLoading, !isListening else { return }

        errorMessage = nil
        messages.append(ChatMessage(role: .user, content: trimmed))
        isLoading = true
        defer { isLoading = false }

        do {
            guard let model = settings.modelInfo(for: settings.chatModelID) else {
                errorMessage = "Selected model is not available. Refresh models in Settings."
                return
            }
            let reply = try await PerplexityClient.chat(
                apiKey: settings.savedAPIKey,
                model: model,
                messages: messages
            )
            messages.append(ChatMessage(role: .assistant, content: reply))
            if isSpeakRepliesEnabled {
                await speechSynthesis.speak(reply)
            }
        } catch {
            errorMessage = error.localizedDescription
            BlackVoiceLog.error(.app, "Chat send failed: \(error.localizedDescription)")
        }
    }

    func clearConversation() {
        speechRecognition.stopListening()
        speechSynthesis.stop()
        syncListeningState()
        messages = []
        errorMessage = nil
        liveTranscript = ""
        publishRecordingState(false)
    }

    private func startListening() async {
        guard canUseMic else {
            BlackVoiceLog.info(.app, "startListening — blocked (canUseMic=false, isLoading=\(isLoading))")
            publishRecordingState(false)
            return
        }
        errorMessage = nil
        liveTranscript = ""

        do {
            BlackVoiceLog.info(.app, "startListening — requesting permissions")
            try await speechRecognition.requestPermissions()
            try await speechRecognition.startListening()
            BlackVoiceLog.info(.app, "startListening — started, service.isListening=\(speechRecognition.isListening)")
            syncListeningState()
        } catch {
            errorMessage = error.localizedDescription
            BlackVoiceLog.error(.app, "startListening — failed: \(error.localizedDescription)")
            syncListeningState()
        }
    }

    private func finishListening(with transcript: String, autoStopped: Bool) async {
        syncListeningState()
        liveTranscript = transcript

        guard !transcript.isEmpty else {
            if autoStopped {
                errorMessage = "Reached 1 minute limit with no speech detected."
            } else {
                errorMessage = "No speech detected."
            }
            return
        }

        inputText = ""
        await send(text: transcript)
    }

    private func syncListeningState() {
        isListening = speechRecognition.isListening
        listeningSecondsRemaining = speechRecognition.secondsRemaining
        liveTranscript = speechRecognition.partialTranscript
        BlackVoiceLog.debug(.app, "syncListeningState — isListening=\(isListening)")
        publishRecordingState(isListening)

        if isListening {
            observePartialTranscript()
        }
    }

    private func publishRecordingState(_ recording: Bool) {
        VoiceRecordingStore.setRecording(recording)
        if !recording {
            recordingStartedAt = nil
        }
        BlackVoiceLog.info(.app, "publishRecordingState(\(recording)) verified store=\(VoiceRecordingStore.isRecording())")
        BlackVoiceWidgetReloader.reloadTimelinesNow()
    }

    private func observePartialTranscript() {
        Task { [weak self] in
            guard let self else { return }
            while speechRecognition.isListening {
                liveTranscript = speechRecognition.partialTranscript
                listeningSecondsRemaining = speechRecognition.secondsRemaining
                try? await Task.sleep(for: .milliseconds(200))
            }
            syncListeningState()
        }
    }
}
