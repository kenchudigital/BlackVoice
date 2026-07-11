//
//  ProfileStore.swift
//  BlackVoice
//
//  做咩：Profile CRUD 與 JSON 持久化。
//  目的：Application Support 存 profiles.json；驗證見 README-Setting.md。
//  維護：改上限 → 先改 README-Setting.md，再改 ProfileLimits。

import Combine
import Foundation

@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var profiles: [UserProfile] = []
    @Published private(set) var lastMessage: String?

    init() {
        load()
    }

    func profile(id: UUID) -> UserProfile? {
        profiles.first { $0.id == id }
    }

    @discardableResult
    func add() -> UserProfile? {
        guard profiles.count < ProfileLimits.maxCount else {
            lastMessage = ProfileValidation.maxCountReached
            return nil
        }

        let profile = UserProfile(name: ProfileLimits.defaultNewName)
        profiles.append(profile)
        sortProfiles()
        persist()
        lastMessage = nil
        BlackVoiceLog.info(.app, "Profile added — id: \(profile.id), count: \(profiles.count)")
        return profile
    }

    @discardableResult
    func update(id: UUID, name: String, description: String, content: String) -> Bool {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return false }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let error = ProfileValidation.validate(name: trimmedName, description: description, content: content) {
            lastMessage = error
            return false
        }

        var profile = profiles[index]
        profile.name = trimmedName
        profile.description = description
        profile.content = content
        profile.updatedAt = Date()
        profiles[index] = profile
        sortProfiles()
        persist()
        lastMessage = "Profile saved."
        BlackVoiceLog.info(.app, "Profile updated — id: \(id)")
        return true
    }

    @discardableResult
    func remove(id: UUID) -> Bool {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return false }
        profiles.remove(at: index)
        persist()
        lastMessage = "Profile removed."
        BlackVoiceLog.info(.app, "Profile removed — id: \(id), count: \(profiles.count)")
        return true
    }

    func clearMessage() {
        lastMessage = nil
    }

    private func load() {
        guard let fileURL = ProfileLimits.profilesFileURL() else {
            BlackVoiceLog.error(.app, "ProfileStore.load — profilesFileURL nil")
            return
        }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            profiles = []
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let document = try decoder.decode(ProfileDocument.self, from: data)
            profiles = document.profiles
            sortProfiles()
            BlackVoiceLog.info(.app, "ProfileStore.load — \(profiles.count) profile(s) from \(fileURL.path)")
        } catch {
            profiles = []
            lastMessage = "Failed to load profiles."
            BlackVoiceLog.error(.app, "ProfileStore.load failed: \(error.localizedDescription)")
        }
    }

    private func persist() {
        guard let fileURL = ProfileLimits.profilesFileURL() else {
            lastMessage = "Failed to save profiles."
            BlackVoiceLog.error(.app, "ProfileStore.persist — profilesFileURL nil")
            return
        }

        let directory = fileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let document = ProfileDocument(version: ProfileLimits.documentVersion, profiles: profiles)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(document)

            let tempURL = directory.appendingPathComponent(".profiles-\(UUID().uuidString).tmp")
            try data.write(to: tempURL, options: .atomic)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            try FileManager.default.moveItem(at: tempURL, to: fileURL)
        } catch {
            lastMessage = "Failed to save profiles."
            BlackVoiceLog.error(.app, "ProfileStore.persist failed: \(error.localizedDescription)")
        }
    }

    private func sortProfiles() {
        profiles.sort {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}
