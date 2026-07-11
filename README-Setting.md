# BlackVoice Settings Reference

> Single source of truth for app limits, storage paths, and validation rules.
> When you change a value here, update the matching Swift code in the same PR.

---

## Profile

User-defined personas (name, description, content) for future chat context injection.

### Limits

| Key | Value | Swift constant |
|-----|-------|----------------|
| `maxCount` | `50` | `ProfileLimits.maxCount` |
| `nameMaxLength` | `64` | `ProfileLimits.nameMaxLength` |
| `descriptionMaxLength` | `256` | `ProfileLimits.descriptionMaxLength` |
| `contentMaxBytes` | `65536` (64 KB) | `ProfileLimits.contentMaxBytes` |
| `documentVersion` | `1` | `ProfileLimits.documentVersion` |
| `defaultNewName` | `New Profile` | `ProfileLimits.defaultNewName` |

### Storage

| Key | Value | Swift constant |
|-----|-------|----------------|
| `applicationSupportSubpath` | `kenchuhk.BlackVoice` | `ProfileLimits.applicationSupportSubpath` |
| `storageFileName` | `profiles.json` | `ProfileLimits.storageFileName` |

Full path on macOS:

```text
~/Library/Application Support/kenchuhk.BlackVoice/profiles.json
```

JSON shape:

```json
{
  "version": 1,
  "profiles": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "name": "Work Assistant",
      "description": "Professional tone",
      "content": "You are a professional assistant.",
      "createdAt": "2026-07-11T13:00:00Z",
      "updatedAt": "2026-07-11T13:00:00Z"
    }
  ]
}
```

### Validation messages (EN)

| Rule | Message | Swift constant |
|------|---------|----------------|
| Name required | `Name is required.` | `ProfileValidation.nameRequired` |
| Name too long | `Name must be at most 64 characters.` | `ProfileValidation.nameTooLong` |
| Description too long | `Description must be at most 256 characters.` | `ProfileValidation.descriptionTooLong` |
| Content too long | `Content must be at most 64 KB.` | `ProfileValidation.contentTooLong` |
| Max count | `You can save at most 50 profiles.` | `ProfileValidation.maxCountReached` |

### UI notes

- No user-configurable storage slider in Settings.
- Limits are enforced in code via `ProfileLimits` and `ProfileValidation`.
- Profile page: left list + right detail (not nested `NavigationSplitView`).
- Name / Description use LTR text fields; section header only (no duplicate placeholder label).
- Actions: **Add**, **Save**, **Remove** (delete with confirmation).

---

## Chat History

Auto-saved after each successful Chat reply (question + response + token usage).
Clear Conversation in Chat only clears the live UI — it does not delete stored history.

### Limits

| Key | Value | Swift constant |
|-----|-------|----------------|
| `maxCount` | `1000` | `ChatHistoryLimits.maxCount` |
| `questionMaxBytes` | `32768` (32 KB) | `ChatHistoryLimits.questionMaxBytes` |
| `responseMaxBytes` | `131072` (128 KB) | `ChatHistoryLimits.responseMaxBytes` |
| `documentVersion` | `1` | `ChatHistoryLimits.documentVersion` |

### Storage

| Key | Value | Swift constant |
|-----|-------|----------------|
| `applicationSupportSubpath` | `kenchuhk.BlackVoice` | `ChatHistoryLimits.applicationSupportSubpath` |
| `storageFileName` | `chat_history.json` | `ChatHistoryLimits.storageFileName` |

Full path on macOS:

```text
~/Library/Application Support/kenchuhk.BlackVoice/chat_history.json
```

JSON shape:

```json
{
  "version": 1,
  "entries": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "createdAt": "2026-07-11T15:30:00Z",
      "question": "What is SwiftUI?",
      "response": "SwiftUI is Apple's declarative UI framework.",
      "modelID": "sonar",
      "inputTokens": 20,
      "outputTokens": 222,
      "totalTokens": 242
    }
  ]
}
```

### Behavior

- Append one entry when a Chat API reply succeeds (`createdAt` = reply completion time).
- Do not save failed requests.
- When `maxCount` is exceeded, remove the oldest entries (FIFO).
- Token fields are optional (`null` / UI shows `—`) if the API omits `usage`.
- History UI lives inside the Chat page (toggle panel); no separate History sidebar page.
- No user-configurable storage slider in Settings.

---

## Prompts

User-defined prompt templates with Mustache-style variables. Prompts page stores templates, example values, Profile bindings, and Preview. Chat can run a selected prompt with runtime text variable values.

### Limits

| Key | Value | Swift constant |
|-----|-------|----------------|
| `maxCount` | `50` | `PromptLimits.maxCount` |
| `nameMaxLength` | `64` | `PromptLimits.nameMaxLength` |
| `descriptionMaxLength` | `256` | `PromptLimits.descriptionMaxLength` |
| `contentMaxBytes` | `65536` (64 KB) | `PromptLimits.contentMaxBytes` |
| `exampleValueMaxBytes` | `32768` (32 KB) | `PromptLimits.exampleValueMaxBytes` |
| `maxProfileSlots` | `5` | `PromptLimits.maxProfileSlots` |
| `maxTextVariables` | `20` | `PromptLimits.maxTextVariables` |
| `documentVersion` | `1` | `PromptLimits.documentVersion` |
| `defaultNewName` | `New Prompt` | `PromptLimits.defaultNewName` |
| `profileToken` | `PROFILE` | `PromptLimits.profileToken` |

### Storage

| Key | Value | Swift constant |
|-----|-------|----------------|
| `applicationSupportSubpath` | `kenchuhk.BlackVoice` | `PromptLimits.applicationSupportSubpath` |
| `storageFileName` | `prompts.json` | `PromptLimits.storageFileName` |

Full path on macOS:

```text
~/Library/Application Support/kenchuhk.BlackVoice/prompts.json
```

### Variables

| Syntax | Behavior |
|--------|----------|
| `{{PROFILE}}` | Reserved. Each occurrence becomes slot `PROFILE#1`, `PROFILE#2`, … with a Profile picker. Preview expands to that Profile’s **content** only. |
| `{{name}}`, `{{description}}`, etc. | Generic text variables. Auto-listed below Content with an example value field. |

JSON shape:

```json
{
  "version": 1,
  "prompts": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "name": "Intro Writer",
      "description": "Write intro from a profile",
      "content": "Write an intro for {{PROFILE}}.\nNickname: {{name}}",
      "modelID": "sonar",
      "variableExamples": { "name": "Ken" },
      "profileBindings": { "PROFILE#1": "uuid-of-profile" },
      "createdAt": "2026-07-11T15:30:00Z",
      "updatedAt": "2026-07-11T15:30:00Z"
    }
  ]
}
```

### Validation messages (EN)

| Rule | Message | Swift constant |
|------|---------|----------------|
| Name required | `Name is required.` | `PromptValidation.nameRequired` |
| Name too long | `Name must be at most 64 characters.` | `PromptValidation.nameTooLong` |
| Description too long | `Description must be at most 256 characters.` | `PromptValidation.descriptionTooLong` |
| Content too long | `Content must be at most 64 KB.` | `PromptValidation.contentTooLong` |
| Model required | `Select an enabled model from Settings.` | `PromptValidation.modelRequired` |
| Too many PROFILE slots | `You can use at most 5 {{PROFILE}} placeholders.` | `PromptValidation.tooManyProfileSlots` |
| Too many text variables | `You can use at most 20 text variables.` | `PromptValidation.tooManyTextVariables` |
| Max count | `You can save at most 50 prompts.` | `PromptValidation.maxCountReached` |

### UI notes

- Left list + right detail (same layout pattern as Profile).
- Model picker uses only Settings-enabled models.
- Variables section auto-updates when Content changes.
- Preview renders with example values + selected Profile content (no API call).
- **Chat Use Prompt:** Toolbar **Prompt** menu selects a template by name. When a prompt is active, an **Exit prompt mode** toolbar button (`xmark.circle`) returns to free chat (distinct from **Clear**, which only clears the conversation). Chat shows **Variables** (text placeholders only; empty by default — Prompts-page example values are not copied). `{{PROFILE}}` uses saved bindings — no re-select. Message field is hidden in prompt mode; Variables are taller multiline fields. **Return** sends (same as free chat); **Option-Return** inserts a newline. Mic and Send remain in the composer (Send / mic submit the rendered prompt). **Preview** shows the full rendered text.
- **Free chat composer:** Message field uses taller multiline height (`lineLimit` 3…10). **Return** sends; **Option-Return** inserts a newline; **⌘↩** also sends.

---

## Perplexity (Settings page — document for reference)

| Item | Storage | Notes |
|------|---------|-------|
| API token | Keychain (`perplexity.apiKey`) | Sensitive — never UserDefaults |
| Enabled model IDs | UserDefaults (`perplexity.savedEnabledModels`) | |
| Chat model ID | UserDefaults (`perplexity.chatModelID`) | |
| Cached models | UserDefaults (`perplexity.cachedModels`) | JSON blob |

---

## App Group (Widget shared state)

| File | Purpose |
|------|---------|
| `pending_action.txt` | Widget → app action queue |
| `voice_recording.txt` | Recording state (`0` / `1`) |

App Group ID: `group.kenchuhk.BlackVoice`

---

## Adding new settings

When introducing a new limit, path, or validation rule:

1. Add a section (or row) to this file with **Key**, **Value**, and **Swift constant**.
2. Implement the constant in Swift — do not hard-code undocumented magic numbers.
3. Enforce validation in the relevant store or view model.
