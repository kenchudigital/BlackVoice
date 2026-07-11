//
//  ProfileView.swift
//  BlackVoice
//
//  做咩：Profile 管理頁 — 左側列表、右側編輯（Add / Save / Remove）。
//  目的：CRUD 使用者 persona；上限見 README-Setting.md。
//  維護：改 UI 行為或上限 → 先改 README-Setting.md。

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var profileStore: ProfileStore

    @State private var selectedID: UUID?
    @State private var draftName = ""
    @State private var draftDescription = ""
    @State private var draftContent = ""
    @State private var showRemoveAlert = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            Divider()

            HStack(spacing: 0) {
                profileList
                    .frame(width: 220)
                    .layoutPriority(0)

                Divider()

                profileDetail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Profile")
        .task {
            selectFirstIfNeeded()
        }
        .onChange(of: profileStore.profiles.map(\.id)) { _, ids in
            Task { @MainActor in
                if let selectedID, !ids.contains(selectedID) {
                    self.selectedID = ids.first
                    loadDraft(for: self.selectedID)
                } else if selectedID == nil {
                    selectFirstIfNeeded()
                }
            }
        }
        .alert("Remove Profile?", isPresented: $showRemoveAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                if let selectedID {
                    removeProfile(id: selectedID)
                }
            }
        } message: {
            Text("This profile will be permanently deleted.")
        }
    }

    private var headerBar: some View {
        HStack {
            Text("Profile")
                .font(.title2.weight(.semibold))
            Spacer()
            Button {
                addProfile()
            } label: {
                Label("Add", systemImage: "plus")
            }
            .disabled(profileStore.profiles.count >= ProfileLimits.maxCount)
            .help(profileStore.profiles.count >= ProfileLimits.maxCount
                ? ProfileValidation.maxCountReached
                : "Add a new profile")
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private var profileList: some View {
        Group {
            if profileStore.profiles.isEmpty {
                ContentUnavailableView {
                    Label("No Profiles", systemImage: "person.crop.circle")
                } description: {
                    Text("Tap Add to create your first profile.")
                }
            } else {
                List(selection: $selectedID) {
                    ForEach(profileStore.profiles) { profile in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.name)
                                .font(.body.weight(.medium))
                                .environment(\.layoutDirection, .leftToRight)
                            if !profile.description.isEmpty {
                                Text(profile.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .environment(\.layoutDirection, .leftToRight)
                            }
                        }
                        .tag(profile.id)
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
    private var profileDetail: some View {
        if let selectedID, profileStore.profile(id: selectedID) != nil {
            Form {
                Section {
                    LTRTextField(text: $draftName, placeholder: "", isSecure: false)
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .onChange(of: draftName) { _, newValue in
                            let truncated = String(newValue.prefix(ProfileLimits.nameMaxLength))
                            guard truncated != newValue else { return }
                            Task { @MainActor in draftName = truncated }
                        }
                    Text("\(draftName.count)/\(ProfileLimits.nameMaxLength)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Name")
                }

                Section {
                    LTRTextField(text: $draftDescription, placeholder: "", isSecure: false)
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .onChange(of: draftDescription) { _, newValue in
                            let truncated = String(newValue.prefix(ProfileLimits.descriptionMaxLength))
                            guard truncated != newValue else { return }
                            Task { @MainActor in draftDescription = truncated }
                        }
                    Text("\(draftDescription.count)/\(ProfileLimits.descriptionMaxLength)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Description")
                }

                Section {
                    TextEditor(text: $draftContent)
                        .font(.body)
                        .frame(minHeight: 160)
                        .environment(\.layoutDirection, .leftToRight)
                        .onChange(of: draftContent) { _, newValue in
                            let truncated = truncateToMaxBytes(newValue, maxBytes: ProfileLimits.contentMaxBytes)
                            guard truncated != newValue else { return }
                            Task { @MainActor in draftContent = truncated }
                        }
                    Text("\(ProfileValidation.utf8ByteCount(for: draftContent))/\(ProfileLimits.contentMaxBytes) bytes")
                        .font(.caption2)
                        .foregroundStyle(contentByteCount > ProfileLimits.contentMaxBytes ? Color.red : Color.secondary)
                } header: {
                    Text("Content")
                }

                if let message = profileStore.lastMessage {
                    Section {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(message.contains("saved") || message.contains("removed") ? Color.secondary : Color.red)
                    }
                }

                Section {
                    HStack(spacing: 12) {
                        Button("Save") {
                            saveProfile(id: selectedID)
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
                Label("Select a Profile", systemImage: "person.crop.circle")
            } description: {
                Text("Choose a profile from the list, or tap Add to create one.")
            }
        }
    }

    private var contentByteCount: Int {
        ProfileValidation.utf8ByteCount(for: draftContent)
    }

    private var canSave: Bool {
        ProfileValidation.validate(
            name: draftName,
            description: draftDescription,
            content: draftContent
        ) == nil
    }

    private func addProfile() {
        guard let profile = profileStore.add() else { return }
        selectedID = profile.id
        loadDraft(for: profile.id)
    }

    private func saveProfile(id: UUID) {
        _ = profileStore.update(id: id, name: draftName, description: draftDescription, content: draftContent)
    }

    private func removeProfile(id: UUID) {
        profileStore.remove(id: id)
        selectedID = profileStore.profiles.first?.id
        loadDraft(for: selectedID)
    }

    private func selectFirstIfNeeded() {
        guard selectedID == nil, let first = profileStore.profiles.first else { return }
        selectedID = first.id
        loadDraft(for: first.id)
    }

    private func loadDraft(for id: UUID?) {
        guard let id, let profile = profileStore.profile(id: id) else {
            draftName = ""
            draftDescription = ""
            draftContent = ""
            return
        }
        draftName = profile.name
        draftDescription = profile.description
        draftContent = profile.content
    }

    private func truncateToMaxBytes(_ text: String, maxBytes: Int) -> String {
        guard ProfileValidation.utf8ByteCount(for: text) > maxBytes else { return text }
        var result = ""
        for character in text {
            let candidate = result + String(character)
            if ProfileValidation.utf8ByteCount(for: candidate) > maxBytes {
                break
            }
            result = candidate
        }
        return result
    }
}

#Preview {
    ProfileView()
        .environmentObject(ProfileStore())
        .frame(width: 720, height: 520)
}
