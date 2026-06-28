//
//  SettingsView.swift
//  BlackVoice
//
//  做咩：Perplexity API token 同 model 設定。
//  目的：Phase 1 先支援 Perplexity；token 存 Keychain。
//  維護：加 provider → 加 Section 或新 settings store。

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: PerplexitySettingsStore
    @State private var isAPIKeyVisible = false

    var body: some View {
        Form {
            apiTokenSection
            modelsSection
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Settings")
        .task {
            if settings.hasAPIKey, settings.availableModels.isEmpty {
                await settings.refreshModels()
            }
        }
    }

    private var apiTokenSection: some View {
        Section {
            HStack(spacing: 8) {
                LTRTextField(
                    text: $settings.apiKeyDraft,
                    placeholder: "API Token",
                    isSecure: !isAPIKeyVisible
                )
                .id(isAPIKeyVisible)
                .frame(maxWidth: .infinity, minHeight: 28)

                Button {
                    isAPIKeyVisible.toggle()
                } label: {
                    Image(systemName: isAPIKeyVisible ? "eye.slash" : "eye")
                }
                .buttonStyle(.borderless)
                .help(isAPIKeyVisible ? "Hide API token" : "Show API token")
            }

            HStack(spacing: 12) {
                Button("Save") {
                    settings.saveAPIKey()
                }
                .disabled(!settings.hasUnsavedAPIKeyChanges)

                if settings.hasAPIKey {
                    Label("Saved in Keychain", systemImage: "checkmark.seal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if settings.hasUnsavedAPIKeyChanges {
                    Text("Unsaved changes")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            if let message = settings.apiKeySaveMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if !settings.hasAPIKey {
                Text("Get a key at perplexity.ai/settings/api")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Perplexity")
        } footer: {
            Text("Your API token is stored securely in Keychain on this Mac. Press Save after editing.")
        }
    }

    private var modelsSection: some View {
        Section {
            HStack(spacing: 12) {
                Button("Refresh") {
                    Task { await settings.refreshModels() }
                }
                .disabled(!settings.hasAPIKey || settings.isLoadingModels)

                Button("Save") {
                    settings.saveModels()
                }
                .disabled(!settings.hasUnsavedModelChanges)

                if settings.isLoadingModels {
                    ProgressView()
                        .controlSize(.small)
                }

                if !settings.savedEnabledModelIDs.isEmpty {
                    Text("\(settings.savedEnabledModelIDs.count) saved")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if settings.hasUnsavedModelChanges {
                    Text("Unsaved changes")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            if let error = settings.modelsLoadError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if let message = settings.modelsSaveMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if settings.availableModels.isEmpty {
                Text("Save your API token, then tap Refresh to load models from Perplexity.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(settings.availableModels) { model in
                    modelRow(model)
                }
            }
        } header: {
            Text("Models")
        } footer: {
            Text("Models are loaded from GET /v1/models. Chat uses POST /v1/agent with the same model id. Tick models, then Save.")
        }
    }

    @ViewBuilder
    private func modelRow(_ model: PerplexityModelInfo) -> some View {
        Toggle(isOn: enabledBinding(for: model)) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.displayName)
                    .font(.body)
                Text(model.id)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Text("Provider: \(model.ownedBy)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .toggleStyle(.checkbox)
        .padding(.vertical, 2)
    }

    private func enabledBinding(for model: PerplexityModelInfo) -> Binding<Bool> {
        Binding(
            get: { settings.isModelEnabledInDraft(model) },
            set: { settings.setModelEnabledInDraft(model, enabled: $0) }
        )
    }
}

#Preview {
    SettingsView()
        .environmentObject(PerplexitySettingsStore())
        .frame(width: 560, height: 640)
}
