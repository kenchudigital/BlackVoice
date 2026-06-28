//
//  PerplexitySettingsStore.swift
//  BlackVoice
//
//  做咩：Perplexity API token（Keychain）同 model 設定（UserDefaults）。
//  目的：Settings 同 Chat 共用同一設定來源。
//  維護：加 provider → 另建 store 或抽象 AgentSettings。

import Combine
import Foundation

@MainActor
final class PerplexitySettingsStore: ObservableObject {
    static let apiKeyAccount = "perplexity.apiKey"
    private static let chatModelKey = "perplexity.chatModelID"
    private static let savedEnabledModelsKey = "perplexity.savedEnabledModels"
    private static let cachedModelsKey = "perplexity.cachedModels"

    @Published var apiKeyDraft: String = ""
    @Published private(set) var savedAPIKey: String = ""
    @Published private(set) var apiKeySaveMessage: String?

    @Published private(set) var availableModels: [PerplexityModelInfo] = []
    @Published var enabledModelIDsDraft: Set<String> = []
    @Published private(set) var savedEnabledModelIDs: Set<String> = []
    @Published private(set) var modelsSaveMessage: String?
    @Published private(set) var modelsLoadError: String?
    @Published private(set) var isLoadingModels = false

    @Published var chatModelID: String = "" {
        didSet { persistChatModelID() }
    }

    init() {
        let storedKey = KeychainStore.load(account: Self.apiKeyAccount) ?? ""
        savedAPIKey = storedKey
        apiKeyDraft = storedKey

        availableModels = loadCachedModels()
        if let savedEnabled = UserDefaults.standard.stringArray(forKey: Self.savedEnabledModelsKey) {
            savedEnabledModelIDs = Set(savedEnabled)
            enabledModelIDsDraft = savedEnabledModelIDs
        } else if let legacyEnabled = UserDefaults.standard.stringArray(forKey: "perplexity.enabledModels") {
            savedEnabledModelIDs = Set(legacyEnabled)
            enabledModelIDsDraft = savedEnabledModelIDs
            UserDefaults.standard.set(Array(savedEnabledModelIDs), forKey: Self.savedEnabledModelsKey)
        }

        if let savedChatModel = UserDefaults.standard.string(forKey: Self.chatModelKey) {
            chatModelID = savedChatModel
        } else if let legacyModel = UserDefaults.standard.string(forKey: "perplexity.selectedModel") {
            chatModelID = legacyModel
        }

        ensureValidChatModel()
    }

    var hasAPIKey: Bool {
        !savedAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasUnsavedAPIKeyChanges: Bool {
        normalized(apiKeyDraft) != normalized(savedAPIKey)
    }

    var hasUnsavedModelChanges: Bool {
        enabledModelIDsDraft != savedEnabledModelIDs
    }

    var chatEnabledModels: [PerplexityModelInfo] {
        sortedModels(availableModels.filter { savedEnabledModelIDs.contains($0.id) })
    }

    func modelInfo(for id: String) -> PerplexityModelInfo? {
        availableModels.first { $0.id == id }
    }

    func isModelEnabledInDraft(_ model: PerplexityModelInfo) -> Bool {
        enabledModelIDsDraft.contains(model.id)
    }

    func setModelEnabledInDraft(_ model: PerplexityModelInfo, enabled: Bool) {
        var updated = enabledModelIDsDraft
        if enabled {
            updated.insert(model.id)
        } else {
            updated.remove(model.id)
        }
        enabledModelIDsDraft = updated
    }

    @discardableResult
    func saveAPIKey() -> Bool {
        let trimmed = normalized(apiKeyDraft)
        do {
            if trimmed.isEmpty {
                try KeychainStore.delete(account: Self.apiKeyAccount)
                savedAPIKey = ""
                apiKeyDraft = ""
                apiKeySaveMessage = "API token cleared."
                BlackVoiceLog.debug(.app, "Perplexity API key cleared from Keychain")
            } else {
                try KeychainStore.save(account: Self.apiKeyAccount, value: trimmed)
                savedAPIKey = trimmed
                apiKeyDraft = trimmed
                apiKeySaveMessage = "API token saved to Keychain."
                BlackVoiceLog.debug(.app, "Perplexity API key saved to Keychain")
            }
            Task { await refreshModels() }
            return true
        } catch {
            apiKeySaveMessage = error.localizedDescription
            BlackVoiceLog.error(.app, "Perplexity API key save failed: \(error.localizedDescription)")
            return false
        }
    }

    @discardableResult
    func saveModels() -> Bool {
        guard !enabledModelIDsDraft.isEmpty else {
            modelsSaveMessage = "Select at least one model."
            return false
        }
        savedEnabledModelIDs = enabledModelIDsDraft
        UserDefaults.standard.set(Array(savedEnabledModelIDs), forKey: Self.savedEnabledModelsKey)
        ensureValidChatModel()
        modelsSaveMessage = "Models saved. \(savedEnabledModelIDs.count) enabled."
        BlackVoiceLog.debug(.app, "Perplexity models saved — count: \(savedEnabledModelIDs.count)")
        return true
    }

    func refreshModels() async {
        guard hasAPIKey else {
            modelsLoadError = "Save your API token first."
            return
        }

        isLoadingModels = true
        modelsLoadError = nil
        defer { isLoadingModels = false }

        do {
            let models = try await PerplexityClient.fetchModels(apiKey: savedAPIKey)
            availableModels = sortedModels(models)
            persistCachedModels()
            pruneDraftSelectionToAvailableModels()
            applyDefaultDraftSelectionIfNeeded()
            BlackVoiceLog.info(.app, "Perplexity models loaded — count: \(availableModels.count)")
        } catch {
            modelsLoadError = error.localizedDescription
            BlackVoiceLog.error(.app, "Perplexity models load failed: \(error.localizedDescription)")
        }
    }

    private func pruneDraftSelectionToAvailableModels() {
        let availableIDs = Set(availableModels.map(\.id))
        guard !availableIDs.isEmpty else { return }

        enabledModelIDsDraft = enabledModelIDsDraft.intersection(availableIDs)
        savedEnabledModelIDs = savedEnabledModelIDs.intersection(availableIDs)
    }

    private func applyDefaultDraftSelectionIfNeeded() {
        guard savedEnabledModelIDs.isEmpty else { return }
        guard enabledModelIDsDraft.isEmpty else { return }
        guard !availableModels.isEmpty else { return }

        let sonarModels = availableModels.filter { $0.id.lowercased().contains("sonar") }
        let picks = Array(sonarModels.prefix(3))
        if picks.isEmpty, let first = availableModels.first {
            enabledModelIDsDraft = [first.id]
        } else {
            enabledModelIDsDraft = Set(picks.map(\.id))
        }
    }

    private func ensureValidChatModel() {
        let enabled = chatEnabledModels
        if enabled.contains(where: { $0.id == chatModelID }) { return }
        if let first = enabled.first {
            chatModelID = first.id
        }
    }

    private func sortedModels(_ models: [PerplexityModelInfo]) -> [PerplexityModelInfo] {
        models.sorted {
            if $0.ownedBy != $1.ownedBy { return $0.ownedBy < $1.ownedBy }
            return $0.id < $1.id
        }
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func persistChatModelID() {
        UserDefaults.standard.set(chatModelID, forKey: Self.chatModelKey)
    }

    private func persistCachedModels() {
        guard let data = try? JSONEncoder().encode(availableModels) else { return }
        UserDefaults.standard.set(data, forKey: Self.cachedModelsKey)
    }

    private func loadCachedModels() -> [PerplexityModelInfo] {
        guard let data = UserDefaults.standard.data(forKey: Self.cachedModelsKey),
              let models = try? JSONDecoder().decode([PerplexityModelInfo].self, from: data) else {
            return []
        }
        return sortedModels(models)
    }
}
