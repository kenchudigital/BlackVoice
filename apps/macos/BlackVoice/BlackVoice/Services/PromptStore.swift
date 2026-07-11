//
//  PromptStore.swift
//  BlackVoice
//
//  做咩：Prompt CRUD 與 JSON 持久化。
//  目的：Application Support 存 prompts.json；驗證見 README-Setting.md。
//  維護：改上限 → 先改 README-Setting.md，再改 PromptLimits。

import Combine
import Foundation

@MainActor
final class PromptStore: ObservableObject {
    @Published private(set) var prompts: [PromptTemplate] = []
    @Published private(set) var lastMessage: String?

    init() {
        load()
    }

    func prompt(id: UUID) -> PromptTemplate? {
        prompts.first { $0.id == id }
    }

    @discardableResult
    func add(defaultModelID: String) -> PromptTemplate? {
        guard prompts.count < PromptLimits.maxCount else {
            lastMessage = PromptValidation.maxCountReached
            return nil
        }

        let prompt = PromptTemplate(
            name: PromptLimits.defaultNewName,
            modelID: defaultModelID
        )
        prompts.append(prompt)
        sortPrompts()
        persist()
        lastMessage = nil
        BlackVoiceLog.info(.app, "Prompt added — id: \(prompt.id), count: \(prompts.count)")
        return prompt
    }

    @discardableResult
    func update(
        id: UUID,
        name: String,
        description: String,
        content: String,
        modelID: String,
        variableExamples: [String: String],
        profileBindings: [String: UUID],
        enabledModelIDs: Set<String>
    ) -> Bool {
        guard let index = prompts.firstIndex(where: { $0.id == id }) else { return false }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let error = PromptValidation.validate(
            name: trimmedName,
            description: description,
            content: content,
            modelID: modelID,
            enabledModelIDs: enabledModelIDs
        ) {
            lastMessage = error
            return false
        }

        let slots = PromptVariableEngine.parseSlots(in: content)
        var prompt = prompts[index]
        prompt.name = trimmedName
        prompt.description = description
        prompt.content = content
        prompt.modelID = modelID
        prompt.variableExamples = PromptVariableEngine.prunedExamples(variableExamples, keeping: slots.textVariableKeys)
        prompt.profileBindings = PromptVariableEngine.prunedProfileBindings(profileBindings, keeping: slots.profileSlotKeys)
        prompt.updatedAt = Date()
        prompts[index] = prompt
        sortPrompts()
        persist()
        lastMessage = "Prompt saved."
        BlackVoiceLog.info(.app, "Prompt updated — id: \(id)")
        return true
    }

    @discardableResult
    func remove(id: UUID) -> Bool {
        guard let index = prompts.firstIndex(where: { $0.id == id }) else { return false }
        prompts.remove(at: index)
        persist()
        lastMessage = "Prompt removed."
        BlackVoiceLog.info(.app, "Prompt removed — id: \(id), count: \(prompts.count)")
        return true
    }

    func clearMessage() {
        lastMessage = nil
    }

    private func load() {
        guard let fileURL = PromptLimits.promptsFileURL() else {
            BlackVoiceLog.error(.app, "PromptStore.load — promptsFileURL nil")
            return
        }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            prompts = []
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let document = try decoder.decode(PromptDocument.self, from: data)
            prompts = document.prompts
            sortPrompts()
            BlackVoiceLog.info(.app, "PromptStore.load — \(prompts.count) prompt(s) from \(fileURL.path)")
        } catch {
            prompts = []
            lastMessage = "Failed to load prompts."
            BlackVoiceLog.error(.app, "PromptStore.load failed: \(error.localizedDescription)")
        }
    }

    private func persist() {
        guard let fileURL = PromptLimits.promptsFileURL() else {
            lastMessage = "Failed to save prompts."
            BlackVoiceLog.error(.app, "PromptStore.persist — promptsFileURL nil")
            return
        }

        let directory = fileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let document = PromptDocument(version: PromptLimits.documentVersion, prompts: prompts)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(document)

            let tempURL = directory.appendingPathComponent(".prompts-\(UUID().uuidString).tmp")
            try data.write(to: tempURL, options: .atomic)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            try FileManager.default.moveItem(at: tempURL, to: fileURL)
        } catch {
            lastMessage = "Failed to save prompts."
            BlackVoiceLog.error(.app, "PromptStore.persist failed: \(error.localizedDescription)")
        }
    }

    private func sortPrompts() {
        prompts.sort {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}
