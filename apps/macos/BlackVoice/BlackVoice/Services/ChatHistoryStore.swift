//
//  ChatHistoryStore.swift
//  BlackVoice
//
//  做咩：Chat 問答歷史 CRUD 與 JSON 持久化。
//  目的：Application Support 存 chat_history.json；上限見 README-Setting.md。
//  維護：改上限 → 先改 README-Setting.md，再改 ChatHistoryLimits。

import Combine
import Foundation

@MainActor
final class ChatHistoryStore: ObservableObject {
    @Published private(set) var entries: [ChatHistoryEntry] = []

    init() {
        load()
    }

    func entry(id: UUID) -> ChatHistoryEntry? {
        entries.first { $0.id == id }
    }

    func append(
        question: String,
        response: String,
        modelID: String,
        usage: TokenUsage?
    ) {
        let truncatedQuestion = ChatHistoryLimits.truncateToMaxBytes(
            question,
            maxBytes: ChatHistoryLimits.questionMaxBytes
        )
        let truncatedResponse = ChatHistoryLimits.truncateToMaxBytes(
            response,
            maxBytes: ChatHistoryLimits.responseMaxBytes
        )

        let entry = ChatHistoryEntry(
            createdAt: .now,
            question: truncatedQuestion,
            response: truncatedResponse,
            modelID: modelID,
            inputTokens: usage?.inputTokens,
            outputTokens: usage?.outputTokens,
            totalTokens: usage?.totalTokens
        )

        entries.insert(entry, at: 0)
        trimToMaxCount()
        persist()
        BlackVoiceLog.info(
            .app,
            "ChatHistory appended — id: \(entry.id), total: \(entries.count), tokens: \(entry.usageSummary)"
        )
    }

    @discardableResult
    func remove(id: UUID) -> Bool {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return false }
        entries.remove(at: index)
        persist()
        BlackVoiceLog.info(.app, "ChatHistory removed — id: \(id), count: \(entries.count)")
        return true
    }

    func clearAll() {
        entries = []
        persist()
        BlackVoiceLog.info(.app, "ChatHistory cleared")
    }

    private func trimToMaxCount() {
        guard entries.count > ChatHistoryLimits.maxCount else { return }
        entries = Array(entries.prefix(ChatHistoryLimits.maxCount))
    }

    private func load() {
        guard let fileURL = ChatHistoryLimits.historyFileURL() else {
            BlackVoiceLog.error(.app, "ChatHistoryStore.load — historyFileURL nil")
            return
        }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            entries = []
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let document = try decoder.decode(ChatHistoryDocument.self, from: data)
            entries = document.entries.sorted { $0.createdAt > $1.createdAt }
            BlackVoiceLog.info(.app, "ChatHistoryStore.load — \(entries.count) entr(y/ies) from \(fileURL.path)")
        } catch {
            entries = []
            BlackVoiceLog.error(.app, "ChatHistoryStore.load failed: \(error.localizedDescription)")
        }
    }

    private func persist() {
        guard let fileURL = ChatHistoryLimits.historyFileURL() else {
            BlackVoiceLog.error(.app, "ChatHistoryStore.persist — historyFileURL nil")
            return
        }

        let directory = fileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let document = ChatHistoryDocument(version: ChatHistoryLimits.documentVersion, entries: entries)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(document)

            let tempURL = directory.appendingPathComponent(".chat-history-\(UUID().uuidString).tmp")
            try data.write(to: tempURL, options: .atomic)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            try FileManager.default.moveItem(at: tempURL, to: fileURL)
        } catch {
            BlackVoiceLog.error(.app, "ChatHistoryStore.persist failed: \(error.localizedDescription)")
        }
    }
}
