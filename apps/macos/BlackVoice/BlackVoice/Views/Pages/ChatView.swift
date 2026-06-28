//
//  ChatView.swift
//  BlackVoice
//
//  做咩：Perplexity 文字聊天 + Mic STT + Speak TTS。
//  目的：Mic click 開始/停（max 1 min）；Speak toggle 朗讀 assistant 回覆。
//  維護：加 streaming → 擴展 toolbar 同 ViewModel。

import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var settings: PerplexitySettingsStore
    @EnvironmentObject private var viewModel: ChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            if !settings.hasAPIKey {
                missingKeyBanner
            }

            messageList

            if viewModel.isListening {
                listeningBanner
            }

            if viewModel.speechSynthesis.isSpeaking {
                speakingBanner
            }

            if let errorMessage = viewModel.errorMessage {
                errorBanner(errorMessage)
            }

            composer
        }
        .navigationTitle("Chat")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Clear") {
                    viewModel.clearConversation()
                }
                .disabled(viewModel.messages.isEmpty || viewModel.isLoading || viewModel.isListening)
            }
        }
    }

    private var missingKeyBanner: some View {
        ContentUnavailableView {
            Label("API Token Required", systemImage: "key")
        } description: {
            Text("Add your Perplexity API token in Settings to start chatting.")
        }
        .frame(maxHeight: 160)
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
                if settings.chatEnabledModels.isEmpty {
                    Text("Enable models in Settings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Model", selection: $settings.chatModelID) {
                        ForEach(settings.chatEnabledModels) { model in
                            Text("\(model.displayName) · \(model.id)").tag(model.id)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 320)
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
                TextField("Message…", text: $viewModel.inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...6)
                    .disabled(!settings.hasAPIKey || viewModel.isLoading || viewModel.isListening || settings.chatEnabledModels.isEmpty)
                    .onSubmit {
                        Task { await viewModel.send() }
                    }

                Button {
                    Task { await viewModel.toggleMic() }
                } label: {
                    Image(systemName: viewModel.isListening ? "stop.fill" : "mic")
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.isListening ? .red : nil)
                .disabled(!viewModel.canUseMic && !viewModel.isListening)
                .help(viewModel.isListening ? "Stop recording and send" : "Start voice input (max 1 min)")

                Button {
                    Task { await viewModel.send() }
                } label: {
                    Image(systemName: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canSend)
                .keyboardShortcut(.return, modifiers: [.command])
            }
        }
        .padding()
        .background(.bar)
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
            .onAppear { isPulsing = true }
    }
}

private struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 48) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.role == .user ? "You" : "Assistant")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(message.content)
                    .textSelection(.enabled)
                    .padding(10)
                    .background(message.role == .user ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if message.role == .assistant { Spacer(minLength: 48) }
        }
    }
}

#Preview {
    let settings = PerplexitySettingsStore()
    return ChatView()
        .environmentObject(settings)
        .environmentObject(ChatViewModel(settings: settings))
        .frame(width: 720, height: 520)
}
