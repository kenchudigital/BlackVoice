//
//  ChatView.swift
//  BlackVoice
//
//  做咩：Perplexity 文字聊天 + Mic STT + Speak TTS。
//  目的：Mic click 開始/停（max 1 min）；Speak toggle 朗讀 assistant 回覆。
//  維護：加 streaming → 擴展 toolbar 同 ViewModel。

import AppKit
import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var navigation: AppNavigationState
    @EnvironmentObject private var settings: PerplexitySettingsStore
    @EnvironmentObject private var viewModel: ChatViewModel
    @EnvironmentObject private var historyStore: ChatHistoryStore
    @EnvironmentObject private var promptStore: PromptStore
    @EnvironmentObject private var profileStore: ProfileStore

    @State private var showHistory = false
    @State private var selectedHistoryID: UUID?
    @State private var showClearHistoryConfirm = false
    @State private var showPromptPreview = false

    private var selectedHistoryEntry: ChatHistoryEntry? {
        guard let selectedHistoryID else { return nil }
        return historyStore.entry(id: selectedHistoryID)
    }

    private var selectedPrompt: PromptTemplate? {
        guard let id = viewModel.activePromptID else { return nil }
        return promptStore.prompt(id: id)
    }

    private var isPromptMode: Bool { viewModel.isPromptMode }

    private var profilesByID: [UUID: UserProfile] {
        Dictionary(uniqueKeysWithValues: profileStore.profiles.map { ($0.id, $0) })
    }

    private var renderedPromptText: String {
        viewModel.renderedPrompt(profilesByID: profilesByID)
    }

    private var canSendNow: Bool {
        if isPromptMode {
            return viewModel.canSendPrompt(profilesByID: profilesByID)
        }
        return viewModel.canSend
    }

    var body: some View {
        HStack(spacing: 0) {
            if showHistory {
                historySidebar
                    .frame(width: 260)
                Divider()
            }

            VStack(spacing: 0) {
                if !settings.hasAPIKey {
                    missingKeyBanner
                } else if settings.chatEnabledModels.isEmpty {
                    missingModelsBanner
                }

                if let entry = selectedHistoryEntry {
                    historyDetail(entry)
                } else {
                    messageList
                }

                if viewModel.isListening {
                    listeningBanner
                }

                if viewModel.speechSynthesis.isSpeaking {
                    speakingBanner
                }

                if let errorMessage = viewModel.errorMessage {
                    errorBanner(errorMessage)
                }

                if selectedHistoryEntry == nil {
                    if isPromptMode {
                        promptVariablesBar
                    }
                    composer
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Chat")
        .task {
            settings.ensureValidChatModel()
            viewModel.profilesForPromptRender = profilesByID
        }
        .onChange(of: profileStore.profiles) { _, _ in
            Task { @MainActor in
                viewModel.profilesForPromptRender = profilesByID
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if isPromptMode {
                    Button {
                        viewModel.clearPrompt()
                    } label: {
                        Label("Exit prompt mode", systemImage: "xmark.circle")
                    }
                    .help("Exit prompt mode — use free chat")
                }

                promptMenu
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showHistory.toggle()
                    if !showHistory {
                        selectedHistoryID = nil
                    }
                } label: {
                    Label("History", systemImage: showHistory ? "clock.fill" : "clock")
                }
                .help(showHistory ? "Hide chat history" : "Show chat history")

                Button("Clear") {
                    viewModel.clearConversation()
                    selectedHistoryID = nil
                }
                .disabled(viewModel.messages.isEmpty || viewModel.isLoading || viewModel.isListening)
            }
        }
        .alert("Clear All History?", isPresented: $showClearHistoryConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                historyStore.clearAll()
                selectedHistoryID = nil
            }
        } message: {
            Text("This permanently deletes all saved chat history. The current conversation is not affected.")
        }
        .sheet(isPresented: $showPromptPreview) {
            promptPreviewSheet
        }
    }

    private var promptMenu: some View {
        Menu {
            if promptStore.prompts.isEmpty {
                Text("No prompts — create one in Prompts")
            } else {
                ForEach(promptStore.prompts) { prompt in
                    Button {
                        viewModel.profilesForPromptRender = profilesByID
                        viewModel.activatePrompt(prompt)
                    } label: {
                        if viewModel.activePromptID == prompt.id {
                            Label(prompt.name, systemImage: "checkmark")
                        } else {
                            Text(prompt.name)
                        }
                    }
                }
            }
        } label: {
            Label(
                selectedPrompt?.name ?? "Prompt",
                systemImage: isPromptMode ? "doc.text.fill" : "doc.text"
            )
        }
        .help(isPromptMode ? "Using prompt — fill variables below" : "Select a prompt template")
    }

    private var promptVariablesBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Variables")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if let selectedPrompt {
                    Text(selectedPrompt.name)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                Spacer()
                Button("Preview") {
                    showPromptPreview = true
                }
                .controlSize(.small)
                .buttonStyle(.bordered)
            }

            if viewModel.promptTextKeys.isEmpty {
                Text("No text variables — Send uses the prompt as saved (PROFILE bindings applied).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.promptTextKeys, id: \.self) { key in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("{{\(key)}}")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                        TextField(key, text: promptVariableBinding(for: key), axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...10)
                            .environment(\.layoutDirection, .leftToRight)
                            .disabled(viewModel.isLoading || viewModel.isListening)
                            .onSubmit {
                                Task { await sendFromComposer() }
                            }
                            .help("Return to send · Option-Return for newline")
                    }
                }
            }

            if !viewModel.promptModelIsAvailable {
                Text("Prompt model “\(viewModel.activePromptModelIDValue)” is not enabled in Settings.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.08))
    }

    private var promptPreviewSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Preview")
                    .font(.title2.weight(.semibold))
                Spacer()
                if isPromptMode {
                    Text("Model: \(viewModel.activePromptModelIDValue)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                Button("Done") {
                    showPromptPreview = false
                }
                .keyboardShortcut(.cancelAction)
            }

            ScrollView {
                Text(renderedPromptText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .environment(\.layoutDirection, .leftToRight)
                    .padding(4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
        .frame(minWidth: 520, minHeight: 420)
    }

    private var historySidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("History")
                    .font(.headline)
                Spacer()
                Button("Clear All", role: .destructive) {
                    showClearHistoryConfirm = true
                }
                .disabled(historyStore.entries.isEmpty)
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if historyStore.entries.isEmpty {
                ContentUnavailableView {
                    Label("No History", systemImage: "clock")
                } description: {
                    Text("Successful chats are saved here automatically.")
                }
            } else {
                List(selection: $selectedHistoryID) {
                    ForEach(historyStore.entries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(entry.question)
                                .font(.body)
                                .lineLimit(2)
                                .environment(\.layoutDirection, .leftToRight)
                            Text(entry.usageSummary)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .tag(entry.id)
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                historyStore.remove(id: entry.id)
                                if selectedHistoryID == entry.id {
                                    selectedHistoryID = nil
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func historyDetail(_ entry: ChatHistoryEntry) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.createdAt.formatted(date: .complete, time: .standard))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(entry.modelID)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Back to Chat") {
                        selectedHistoryID = nil
                    }
                }

                Group {
                    Text("Question")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(entry.question)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .environment(\.layoutDirection, .leftToRight)
                }

                Divider()

                Group {
                    Text("Response")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(entry.response)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .environment(\.layoutDirection, .leftToRight)
                }

                Divider()

                Group {
                    Text("Token Usage")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    LabeledContent("Input", value: tokenText(entry.inputTokens))
                    LabeledContent("Output", value: tokenText(entry.outputTokens))
                    LabeledContent("Total", value: tokenText(entry.totalTokens))
                }
            }
            .padding()
        }
    }

    private func tokenText(_ value: Int?) -> String {
        guard let value else { return "—" }
        return "\(value)"
    }

    private var chatModelSelection: Binding<String> {
        Binding(
            get: { settings.chatModelID },
            set: { newValue in
                guard newValue != settings.chatModelID else { return }
                Task { @MainActor in
                    settings.chatModelID = newValue
                }
            }
        )
    }

    private var missingKeyBanner: some View {
        ContentUnavailableView {
            Label("API Token Required", systemImage: "key")
        } description: {
            Text("Please go to Settings and add your Perplexity API token to start chatting.")
        } actions: {
            Button("Go to Settings") {
                Task { @MainActor in
                    navigation.selectedSection = .settings
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxHeight: 180)
    }

    private var missingModelsBanner: some View {
        ContentUnavailableView {
            Label("Chat Model Required", systemImage: "cpu")
        } description: {
            Text("Please go to Settings, enable at least one model under Models, then tap Save.")
        } actions: {
            Button("Go to Settings") {
                Task { @MainActor in
                    navigation.selectedSection = .settings
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxHeight: 180)
    }

    private var listeningBanner: some View {
        HStack(spacing: 10) {
            RecordingIndicator()
            VStack(alignment: .leading, spacing: 2) {
                Text("Recording your voice · \(formatSeconds(viewModel.listeningSecondsRemaining))")
                    .font(.caption.weight(.semibold))
                if !viewModel.liveTranscript.isEmpty {
                    Text("“\(viewModel.liveTranscript)”")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text("Speak now, then tap Stop")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Button("Stop") {
                Task { await viewModel.toggleMic() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.small)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.red.opacity(0.1))
    }

    private var speakingBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "speaker.wave.2.fill")
                .foregroundStyle(Color.accentColor)
            Text("Speaking reply…")
                .font(.caption.weight(.medium))
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.1))
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if viewModel.messages.isEmpty && !viewModel.isListening {
                        ContentUnavailableView {
                            Label("Start a conversation", systemImage: "text.bubble")
                        } description: {
                            Text("Type a message, or tap the mic to speak (up to 1 minute).")
                        }
                        .frame(maxWidth: .infinity, minHeight: 280)
                    } else if viewModel.messages.isEmpty && viewModel.isListening {
                        recordingPlaceholder
                    } else {
                        ForEach(viewModel.messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }
                    }

                    if viewModel.isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Thinking…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 4)
                        .id("loading")
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.isLoading) { _, isLoading in
                if isLoading {
                    scrollToBottom(proxy: proxy, anchor: "loading")
                }
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Model")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if isPromptMode {
                    Text(viewModel.activePromptModelIDValue)
                        .font(.caption.monospaced())
                        .foregroundStyle(viewModel.promptModelIsAvailable ? Color.secondary : Color.orange)
                } else if settings.chatEnabledModels.isEmpty {
                    Text("No model enabled — go to Settings → Models")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else if settings.chatEnabledModels.contains(where: { $0.id == settings.chatModelID }) {
                    Picker("Model", selection: chatModelSelection) {
                        ForEach(settings.chatEnabledModels) { model in
                            Text("\(model.displayName) · \(model.id)").tag(model.id)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 320)
                } else {
                    Text("Preparing model…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .task {
                            settings.ensureValidChatModel()
                        }
                }

                Spacer()

                Button {
                    viewModel.toggleSpeakReplies()
                } label: {
                    Label(
                        viewModel.isSpeakRepliesEnabled ? "Speak on" : "Speak off",
                        systemImage: viewModel.isSpeakRepliesEnabled ? "speaker.wave.2.fill" : "speaker.slash"
                    )
                    .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(viewModel.isSpeakRepliesEnabled ? Color.accentColor : Color.secondary)
                .help(viewModel.isSpeakRepliesEnabled
                    ? "Assistant replies will be spoken aloud"
                    : "Turn on to speak assistant replies")
            }

            HStack(alignment: .bottom, spacing: 10) {
                if !isPromptMode {
                    TextField("Message…", text: $viewModel.inputText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...10)
                        .disabled(!settings.hasAPIKey || viewModel.isLoading || viewModel.isListening || settings.chatEnabledModels.isEmpty)
                        .onSubmit {
                            Task { await sendFromComposer() }
                        }
                        .help("Return to send · Option-Return for newline")
                } else {
                    Spacer(minLength: 0)
                }

                Button {
                    Task {
                        viewModel.profilesForPromptRender = profilesByID
                        await viewModel.toggleMic()
                    }
                } label: {
                    Image(systemName: viewModel.isListening ? "stop.fill" : "mic")
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.isListening ? .red : nil)
                .disabled(!viewModel.canUseMic && !viewModel.isListening)
                .help(
                    isPromptMode
                        ? (viewModel.isListening ? "Stop and send rendered prompt" : "Voice fills first variable, then sends prompt")
                        : (viewModel.isListening ? "Stop recording and send" : "Start voice input (max 1 min)")
                )

                Button {
                    Task { await sendFromComposer() }
                } label: {
                    Image(systemName: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSendNow)
                .keyboardShortcut(.return, modifiers: [.command])
                .help("Send (⌘↩)")
            }
        }
        .padding()
        .background(.bar)
    }

    private func promptVariableBinding(for key: String) -> Binding<String> {
        Binding(
            get: { viewModel.promptVariableValues[key] ?? "" },
            set: { newValue in
                Task { @MainActor in
                    viewModel.setPromptVariable(key, value: newValue)
                }
            }
        )
    }

    private func sendFromComposer() async {
        viewModel.profilesForPromptRender = profilesByID
        if isPromptMode {
            await viewModel.sendPrompt(profilesByID: profilesByID)
        } else {
            await viewModel.send()
        }
    }

    private func formatSeconds(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private var recordingPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "mic.fill")
                .font(.system(size: 36))
                .foregroundStyle(.red)
            Text("Recording your voice")
                .font(.headline)
            Text(formatSeconds(viewModel.listeningSecondsRemaining))
                .font(.title3.monospacedDigit())
                .foregroundStyle(.secondary)
            if !viewModel.liveTranscript.isEmpty {
                Text("“\(viewModel.liveTranscript)”")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            Text("Tap Stop when finished")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 280)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.12))
    }

    private func scrollToBottom(proxy: ScrollViewProxy, anchor: String? = nil) {
        withAnimation(.easeOut(duration: 0.2)) {
            if let anchor {
                proxy.scrollTo(anchor, anchor: .bottom)
            } else if let last = viewModel.messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}

private struct RecordingIndicator: View {
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 10, height: 10)
            .scaleEffect(isPulsing ? 1.25 : 0.85)
            .opacity(isPulsing ? 1 : 0.55)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear {
                Task { @MainActor in
                    isPulsing = true
                }
            }
    }
}

private struct ChatBubble: View {
    let message: ChatMessage
    @State private var didCopy = false

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 48) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(message.role == .user ? "You" : "Assistant")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Button {
                        copyMessage()
                    } label: {
                        Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                            .font(.caption2)
                    }
                    .buttonStyle(.borderless)
                    .help(didCopy ? "Copied" : "Copy message")
                }

                Text(message.content)
                    .textSelection(.enabled)
                    .padding(10)
                    .background(message.role == .user ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if message.role == .assistant { Spacer(minLength: 48) }
        }
    }

    private func copyMessage() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.content, forType: .string)
        didCopy = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            didCopy = false
        }
    }
}

#Preview {
    let settings = PerplexitySettingsStore()
    let history = ChatHistoryStore()
    return ChatView()
        .environmentObject(AppNavigationState())
        .environmentObject(settings)
        .environmentObject(ChatViewModel(settings: settings, historyStore: history))
        .environmentObject(history)
        .environmentObject(PromptStore())
        .environmentObject(ProfileStore())
        .frame(width: 720, height: 520)
}
