//
//  PromptTemplatesView.swift
//  BlackVoice
//
//  做咩：Prompt 管理頁 — 列表、模板、自動變數 example、Preview。
//  目的：CRUD prompts；{{PROFILE}} → PROFILE#n；其他 {{var}} → example。
//  維護：上限見 README-Setting.md → Prompts。

import SwiftUI

struct PromptTemplatesView: View {
    @EnvironmentObject private var promptStore: PromptStore
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var settings: PerplexitySettingsStore

    @State private var selectedID: UUID?
    @State private var draftName = ""
    @State private var draftDescription = ""
    @State private var draftContent = ""
    @State private var draftModelID = ""
    @State private var draftExamples: [String: String] = [:]
    @State private var draftProfileBindings: [String: UUID] = [:]
    @State private var showRemoveAlert = false
    @State private var showPreview = false

    private var parsedSlots: PromptParsedSlots {
        PromptVariableEngine.parseSlots(in: draftContent)
    }

    private var profilesByID: [UUID: UserProfile] {
        Dictionary(uniqueKeysWithValues: profileStore.profiles.map { ($0.id, $0) })
    }

    private var previewText: String {
        PromptVariableEngine.renderPreview(
            content: draftContent,
            variableExamples: draftExamples,
            profileBindings: draftProfileBindings,
            profilesByID: profilesByID
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            HStack(spacing: 0) {
                promptList
                    .frame(width: 220)
                Divider()
                promptDetail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Prompts")
        .task {
            selectFirstIfNeeded()
        }
        .onChange(of: promptStore.prompts.map(\.id)) { _, ids in
            Task { @MainActor in
                if let selectedID, !ids.contains(selectedID) {
                    self.selectedID = ids.first
                    loadDraft(for: self.selectedID)
                } else if selectedID == nil {
                    selectFirstIfNeeded()
                }
            }
        }
        .onChange(of: draftContent) { _, newValue in
            Task { @MainActor in
                let truncated = PromptLimits.truncateToMaxBytes(newValue, maxBytes: PromptLimits.contentMaxBytes)
                if truncated != newValue {
                    draftContent = truncated
                }
                syncVariableDrafts()
            }
        }
        .alert("Remove Prompt?", isPresented: $showRemoveAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                if let selectedID {
                    removePrompt(id: selectedID)
                }
            }
        } message: {
            Text("This prompt will be permanently deleted.")
        }
        .sheet(isPresented: $showPreview) {
            previewSheet
        }
    }

    private var headerBar: some View {
        HStack {
            Text("Prompts")
                .font(.title2.weight(.semibold))
            Spacer()
            Button {
                addPrompt()
            } label: {
                Label("Add", systemImage: "plus")
            }
            .disabled(promptStore.prompts.count >= PromptLimits.maxCount)
            .help(promptStore.prompts.count >= PromptLimits.maxCount
                ? PromptValidation.maxCountReached
                : "Add a new prompt")
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private var promptList: some View {
        Group {
            if promptStore.prompts.isEmpty {
                ContentUnavailableView {
                    Label("No Prompts", systemImage: "doc.text")
                } description: {
                    Text("Tap Add to create your first prompt template.")
                }
            } else {
                List(selection: $selectedID) {
                    ForEach(promptStore.prompts) { prompt in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(prompt.name)
                                .font(.body.weight(.medium))
                                .environment(\.layoutDirection, .leftToRight)
                            if !prompt.description.isEmpty {
                                Text(prompt.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .environment(\.layoutDirection, .leftToRight)
                            }
                        }
                        .tag(prompt.id)
                    }
                }
            }
        }
        .onChange(of: selectedID) { _, newID in
            Task { @MainActor in
                loadDraft(for: newID)
            }
        }
    }

    @ViewBuilder
    private var promptDetail: some View {
        if let selectedID, promptStore.prompt(id: selectedID) != nil {
            Form {
                Section {
                    LTRTextField(text: $draftName, placeholder: "", isSecure: false)
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .onChange(of: draftName) { _, newValue in
                            let truncated = String(newValue.prefix(PromptLimits.nameMaxLength))
                            guard truncated != newValue else { return }
                            Task { @MainActor in draftName = truncated }
                        }
                    Text("\(draftName.count)/\(PromptLimits.nameMaxLength)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Name")
                }

                Section {
                    LTRTextField(text: $draftDescription, placeholder: "", isSecure: false)
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .onChange(of: draftDescription) { _, newValue in
                            let truncated = String(newValue.prefix(PromptLimits.descriptionMaxLength))
                            guard truncated != newValue else { return }
                            Task { @MainActor in draftDescription = truncated }
                        }
                    Text("\(draftDescription.count)/\(PromptLimits.descriptionMaxLength)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Description")
                }

                Section {
                    if settings.chatEnabledModels.isEmpty {
                        Text("Enable at least one model in Settings, then return here.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else if settings.chatEnabledModels.contains(where: { $0.id == draftModelID }) {
                        Picker("Model", selection: modelSelection) {
                            ForEach(settings.chatEnabledModels) { model in
                                Text("\(model.displayName) · \(model.id)").tag(model.id)
                            }
                        }
                        .labelsHidden()
                    } else {
                        Text("Preparing model…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .task {
                                ensureDraftModel()
                            }
                    }
                } header: {
                    Text("Model")
                }

                Section {
                    TextEditor(text: $draftContent)
                        .font(.body)
                        .frame(minHeight: 140)
                        .environment(\.layoutDirection, .leftToRight)

                    HStack(spacing: 8) {
                        Button("Insert {{PROFILE}}") {
                            insertToken("{{PROFILE}}")
                        }
                        .disabled(parsedSlots.profileSlotKeys.count >= PromptLimits.maxProfileSlots)

                        Button("Insert {{name}}") {
                            insertToken("{{name}}")
                        }
                    }
                    .controlSize(.small)

                    Text("\(draftContent.utf8.count)/\(PromptLimits.contentMaxBytes) bytes")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Content")
                } footer: {
                    Text("Use {{PROFILE}} for a Profile slot (PROFILE#1…). Other {{variables}} get example fields below.")
                }

                if !parsedSlots.profileSlotKeys.isEmpty || !parsedSlots.textVariableKeys.isEmpty {
                    Section {
                        ForEach(parsedSlots.profileSlotKeys, id: \.self) { slotKey in
                            profileSlotRow(slotKey)
                        }
                        ForEach(parsedSlots.textVariableKeys, id: \.self) { key in
                            textVariableRow(key)
                        }
                    } header: {
                        Text("Variables")
                    } footer: {
                        Text("Examples are used by Preview. PROFILE slots expand to the selected Profile’s content.")
                    }
                }

                if let message = promptStore.lastMessage {
                    Section {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(message.contains("saved") || message.contains("removed") ? Color.secondary : Color.red)
                    }
                }

                Section {
                    HStack(spacing: 12) {
                        Button("Preview") {
                            showPreview = true
                        }
                        .buttonStyle(.bordered)

                        Button("Save") {
                            savePrompt(id: selectedID)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSave)

                        Button("Remove", role: .destructive) {
                            showRemoveAlert = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .formStyle(.grouped)
            .environment(\.layoutDirection, .leftToRight)
        } else {
            ContentUnavailableView {
                Label("Select a Prompt", systemImage: "doc.text")
            } description: {
                Text("Choose a prompt from the list, or tap Add to create one.")
            }
        }
    }

    private func profileSlotRow(_ slotKey: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(slotKey)
                .font(.caption.monospaced())
                .frame(width: 100, alignment: .leading)

            if profileStore.profiles.isEmpty {
                Text("No profiles — create one in Profile")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Picker(slotKey, selection: profileBinding(for: slotKey)) {
                    Text("Not selected").tag(UUID?.none)
                    ForEach(profileStore.profiles) { profile in
                        Text(profile.name).tag(UUID?.some(profile.id))
                    }
                }
                .labelsHidden()
            }
        }
    }

    private func textVariableRow(_ key: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("{{\(key)}}")
                .font(.caption.monospaced())
            TextEditor(text: exampleBinding(for: key))
                .font(.body)
                .frame(minHeight: 48)
                .environment(\.layoutDirection, .leftToRight)
        }
    }

    private var previewSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Preview")
                    .font(.title2.weight(.semibold))
                Spacer()
                if !draftModelID.isEmpty {
                    Text("Model: \(draftModelID)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                Button("Done") {
                    showPreview = false
                }
                .keyboardShortcut(.cancelAction)
            }

            ScrollView {
                Text(previewText)
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

    private var modelSelection: Binding<String> {
        Binding(
            get: { draftModelID },
            set: { newValue in
                guard newValue != draftModelID else { return }
                Task { @MainActor in draftModelID = newValue }
            }
        )
    }

    private func profileBinding(for slotKey: String) -> Binding<UUID?> {
        Binding(
            get: { draftProfileBindings[slotKey] },
            set: { newValue in
                Task { @MainActor in
                    if let newValue {
                        draftProfileBindings[slotKey] = newValue
                    } else {
                        draftProfileBindings.removeValue(forKey: slotKey)
                    }
                }
            }
        )
    }

    private func exampleBinding(for key: String) -> Binding<String> {
        Binding(
            get: { draftExamples[key] ?? "" },
            set: { newValue in
                Task { @MainActor in
                    draftExamples[key] = PromptLimits.truncateToMaxBytes(
                        newValue,
                        maxBytes: PromptLimits.exampleValueMaxBytes
                    )
                }
            }
        )
    }

    private var canSave: Bool {
        PromptValidation.validate(
            name: draftName,
            description: draftDescription,
            content: draftContent,
            modelID: draftModelID,
            enabledModelIDs: settings.savedEnabledModelIDs
        ) == nil
    }

    private func addPrompt() {
        ensureDraftModel()
        guard let prompt = promptStore.add(defaultModelID: draftModelID.isEmpty
            ? (settings.chatEnabledModels.first?.id ?? "")
            : draftModelID) else { return }
        selectedID = prompt.id
        loadDraft(for: prompt.id)
    }

    private func savePrompt(id: UUID) {
        _ = promptStore.update(
            id: id,
            name: draftName,
            description: draftDescription,
            content: draftContent,
            modelID: draftModelID,
            variableExamples: draftExamples,
            profileBindings: draftProfileBindings,
            enabledModelIDs: settings.savedEnabledModelIDs
        )
    }

    private func removePrompt(id: UUID) {
        promptStore.remove(id: id)
        selectedID = promptStore.prompts.first?.id
        loadDraft(for: selectedID)
    }

    private func selectFirstIfNeeded() {
        ensureDraftModel()
        guard selectedID == nil, let first = promptStore.prompts.first else { return }
        selectedID = first.id
        loadDraft(for: first.id)
    }

    private func loadDraft(for id: UUID?) {
        guard let id, let prompt = promptStore.prompt(id: id) else {
            draftName = ""
            draftDescription = ""
            draftContent = ""
            draftModelID = settings.chatEnabledModels.first?.id ?? ""
            draftExamples = [:]
            draftProfileBindings = [:]
            return
        }
        draftName = prompt.name
        draftDescription = prompt.description
        draftContent = prompt.content
        draftModelID = prompt.modelID
        draftExamples = prompt.variableExamples
        draftProfileBindings = prompt.profileBindings
        ensureDraftModel()
        syncVariableDrafts()
    }

    private func syncVariableDrafts() {
        let slots = PromptVariableEngine.parseSlots(in: draftContent)
        draftExamples = PromptVariableEngine.prunedExamples(draftExamples, keeping: slots.textVariableKeys)
        draftProfileBindings = PromptVariableEngine.prunedProfileBindings(
            draftProfileBindings,
            keeping: slots.profileSlotKeys
        )
    }

    private func ensureDraftModel() {
        let enabled = settings.chatEnabledModels
        if enabled.contains(where: { $0.id == draftModelID }) { return }
        if let first = enabled.first {
            draftModelID = first.id
        } else {
            draftModelID = ""
        }
    }

    private func insertToken(_ token: String) {
        if draftContent.isEmpty {
            draftContent = token
        } else if draftContent.hasSuffix(" ") || draftContent.hasSuffix("\n") {
            draftContent += token
        } else {
            draftContent += " " + token
        }
    }
}

#Preview {
    PromptTemplatesView()
        .environmentObject(PromptStore())
        .environmentObject(ProfileStore())
        .environmentObject(PerplexitySettingsStore())
        .frame(width: 860, height: 640)
}
