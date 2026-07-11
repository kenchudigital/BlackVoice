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

    /// Active Chat prompt template (nil = normal free-text chat).
    @Published private(set) var activePromptID: UUID?
    @Published var promptVariableValues: [String: String] = [:]

    private var activePromptContent: String = ""
    private var activePromptModelID: String = ""
    private var activePromptProfileBindings: [String: UUID] = [:]
    private var activePromptTextKeys: [String] = []

    let speechRecognition = SpeechRecognitionService()
    let speechSynthesis = SpeechSynthesisService()

    private let settings: PerplexitySettingsStore
    private let historyStore: ChatHistoryStore
    private var cancellables = Set<AnyCancellable>()
    private var recordingStartedAt: Date?

    /// 做咩：Widget stop 防抖 — 開始錄音後短時間內忽略 stop。
    static let widgetVoiceStopDebounceSeconds: TimeInterval = 0.9

    var canStopWidgetVoiceYet: Bool {
        guard isListening, let recordingStartedAt else { return true }
        return Date().timeIntervalSince(recordingStartedAt) >= Self.widgetVoiceStopDebounceSeconds
    }

    var isPromptMode: Bool { activePromptID != nil }

    var promptTextKeys: [String] { activePromptTextKeys }

    init(settings: PerplexitySettingsStore, historyStore: ChatHistoryStore) {
        self.settings = settings
        self.historyStore = historyStore
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

    func canSendPrompt(profilesByID: [UUID: UserProfile]) -> Bool {
        guard isPromptMode, !isLoading, !isListening, settings.hasAPIKey else { return false }
        guard settings.chatEnabledModels.contains(where: { $0.id == activePromptModelID }) else { return false }
        let rendered = renderedPrompt(profilesByID: profilesByID)
        return !rendered.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canUseMic: Bool {
        settings.hasAPIKey
            && !settings.chatEnabledModels.isEmpty
            && !isLoading
    }

    var promptModelIsAvailable: Bool {
        guard isPromptMode else { return true }
        return settings.chatEnabledModels.contains(where: { $0.id == activePromptModelID })
    }

    var activePromptModelIDValue: String { activePromptModelID }

    func activatePrompt(_ prompt: PromptTemplate) {
        activePromptID = prompt.id
        activePromptContent = prompt.content
        activePromptModelID = prompt.modelID
        activePromptProfileBindings = prompt.profileBindings
        activePromptTextKeys = PromptVariableEngine.parseSlots(in: prompt.content).textVariableKeys
        promptVariableValues = Dictionary(uniqueKeysWithValues: activePromptTextKeys.map { ($0, "") })
        inputText = ""
        BlackVoiceLog.info(.app, "Chat prompt activated — id: \(prompt.id), name: \(prompt.name)")
    }

    func clearPrompt() {
        activePromptID = nil
        activePromptContent = ""
        activePromptModelID = ""
        activePromptProfileBindings = [:]
        activePromptTextKeys = []
        promptVariableValues = [:]
        BlackVoiceLog.info(.app, "Chat prompt cleared")
    }

    func renderedPrompt(profilesByID: [UUID: UserProfile]) -> String {
        guard isPromptMode else { return "" }
        return PromptVariableEngine.renderPreview(
            content: activePromptContent,
            variableExamples: promptVariableValues,
            profileBindings: activePromptProfileBindings,
            profilesByID: profilesByID
        )
    }

    func setPromptVariable(_ key: String, value: String) {
        promptVariableValues[key] = PromptLimits.truncateToMaxBytes(
            value,
            maxBytes: PromptLimits.exampleValueMaxBytes
        )
    }

    func sendPrompt(profilesByID: [UUID: UserProfile]) async {
        guard isPromptMode else { return }
        guard settings.chatEnabledModels.contains(where: { $0.id == activePromptModelID }) else {
            errorMessage = "Prompt model “\(activePromptModelID)” is not enabled in Settings."
            return
        }
        let text = renderedPrompt(profilesByID: profilesByID)
        await send(text: text, modelID: activePromptModelID)
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
            errorMessage = "Please go to Settings, enable at least one model under Models, then tap Save."
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
        await send(text: trimmed, modelID: nil)
    }

    func send(text: String, modelID: String? = nil) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isLoading, !isListening else { return }

        errorMessage = nil
        messages.append(ChatMessage(role: .user, content: trimmed))
        isLoading = true
        defer { isLoading = false }

        do {
            let resolvedModelID: String
            if let modelID,
               !modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                resolvedModelID = modelID.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                resolvedModelID = settings.chatModelID
            }
            guard let model = settings.modelInfo(for: resolvedModelID) else {
                errorMessage = "Selected model is not available. Refresh models in Settings."
                return
            }
            let result = try await PerplexityClient.chat(
                apiKey: settings.savedAPIKey,
                model: model,
                messages: messages
            )
            messages.append(ChatMessage(role: .assistant, content: result.text))
            historyStore.append(
                question: trimmed,
                response: result.text,
                modelID: result.modelID,
                usage: result.usage
            )
            if isSpeakRepliesEnabled {
                await speechSynthesis.speak(result.text)
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
        if isPromptMode {
            if let firstKey = activePromptTextKeys.first {
                setPromptVariable(firstKey, value: transcript)
            }
            // profilesByID must be supplied by caller for PROFILE expansion — use empty and
            // re-send from view if needed. Store last profiles via pending flag.
            await sendPromptPendingMicTranscript()
        } else {
            await send(text: transcript, modelID: nil)
        }
    }

    /// Filled by ChatView before mic stop completes PROFILE render.
    var profilesForPromptRender: [UUID: UserProfile] = [:]

    private func sendPromptPendingMicTranscript() async {
        await sendPrompt(profilesByID: profilesForPromptRender)
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
