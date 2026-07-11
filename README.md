<p align="center">
  <img src="res/logo.png" alt="Black Voice" width="200" />
</p>

<h1 align="center">Black Voice</h1>

<p align="center">
  <strong>macOS · SwiftUI · WidgetKit</strong>
</p>

## Overview

Black Voice is a macOS menu-bar app with a WidgetKit extension for voice and text chat with an LLM.

- **App:** Settings (API key, model), chat UI, speech-to-text and text-to-speech, profiles, prompt templates, auto-saved chat history.
- **Widget:** Quick voice toggle; runs chat in the background when the window is hidden.
- **Distribution:** Build a `.app` and package `dist/BlackVoice.dmg` for local sharing.

## Tech Stack

- **UI/App:** SwiftUI (macOS)
- **Widget:** WidgetKit + App Intents
- **LLM API:** Perplexity (`POST /v1/agent`)
- **Speech:** Apple Speech + AVSpeechSynthesizer
- **Storage:** Keychain (API token), Application Support (profiles, prompts, chat history), App Group shared state

## Repository Layout

```text
.
├── apps/macos/BlackVoice/      # Xcode project (app + widget)
├── dist/                       # Build outputs (.dmg) — gitignored
├── res/                        # Static assets
├── README-Setting.md           # App limits, storage paths, validation rules (source of truth)
├── Makefile                    # build + dmg packaging
└── README.md
```

Open in Xcode:

```text
apps/macos/BlackVoice/BlackVoice.xcodeproj
```

## Prerequisites

- macOS 14+ recommended
- Xcode 15+
- `make` and `hdiutil` (built-in on macOS)
- Apple Developer account (optional: required only for App Store / notarized distribution)

## Development

### Open and run

1. Open `apps/macos/BlackVoice/BlackVoice.xcodeproj`
2. Select scheme **BlackVoice**
3. Run (⌘R)

### Capabilities (app + widget)

- **App Groups:** `group.kenchuhk.BlackVoice`
- **Microphone & Speech Recognition** (voice chat)
- **Outgoing network** (Perplexity API)

### Where to edit code

| Area | Path |
|---|---|
| App UI, chat, settings | `apps/macos/BlackVoice/BlackVoice/` |
| Widget | `apps/macos/BlackVoice/BlackVoiceWidget/` |
| Shared intents / App Group | `apps/macos/BlackVoice/Shared/` |

## Build and Package (Makefile)

From the repository root:

```bash
make help                 # list targets
make build                # Release .app
make dmg                  # build + create dist/BlackVoice.dmg
make dmg CONFIG=Debug     # Debug build + DMG (local testing)
make open-app             # open built .app
make open-dmg             # open dist/ folder
make clean                # remove .derivedData and dist/
```

**Outputs:**

- `.app` → `.derivedData/Build/Products/Release/BlackVoice.app`
- `.dmg` → `dist/BlackVoice.dmg`

### Build in Xcode (alternative)

1. Scheme: **BlackVoice**
2. **Product → Archive** (for signed/notarized releases)

## Versioning

Version is set in Xcode (**General → Version / Build**) for both **BlackVoice** and **BlackVoiceWidget** targets:

| Xcode field | Info.plist key | Purpose |
|---|---|---|
| Version | `CFBundleShortVersionString` | User-facing version (e.g. `1.0`) |
| Build | `CFBundleVersion` | Build number (e.g. `1`) |

### Check version of a DMG

```bash
MOUNT=$(hdiutil attach -nobrowse -readonly dist/BlackVoice.dmg | tail -1 | awk '{print $3}')
plutil -p "$MOUNT/BlackVoice.app/Contents/Info.plist" | grep -E 'CFBundleShortVersionString|CFBundleVersion'
hdiutil detach "$MOUNT"
```

Or check the built app directly:

```bash
plutil -p .derivedData/Build/Products/Release/BlackVoice.app/Contents/Info.plist \
  | grep -E 'CFBundleShortVersionString|CFBundleVersion'
```

## Release Flow (git tag + push)

`dist/` is not committed. Tag releases in git and attach the DMG on GitHub Releases (or share the file directly).

1. **Bump version** in Xcode (Version + Build on app and widget targets).
2. **Build and verify:**
   ```bash
   make dmg
   # verify version (see above)
   cp dist/BlackVoice.dmg dist/BlackVoice-1.0.1.dmg   # optional: versioned filename
   ```
3. **Commit and tag:**
   ```bash
   git add -A
   git commit -m "Release v1.0.1"
   git tag -a v1.0.1 -m "BlackVoice v1.0.1"
   git push origin main
   git push origin v1.0.1
   ```
4. **Publish** (GitHub CLI example):
   ```bash
   gh release create v1.0.1 dist/BlackVoice-1.0.1.dmg \
     --title "BlackVoice v1.0.1" \
     --notes "Release notes here."
   ```

Use tag names like `v1.0.0`, `v1.0.1`, matching the app **Version** field.

## Distribution Notes

- **Personal Team / friends:** Share the `.dmg` from `dist/`. Recipients may need to right-click → **Open** the first time (Gatekeeper).
- **Wider distribution:** Requires paid Apple Developer Program, Developer ID signing, and notarization.

## Troubleshooting

- **Widget not updating:** Confirm both targets share the same App Group; reload widget timelines after settings change.
- **Voice / mic not working:** Grant Microphone and Speech Recognition in **System Settings → Privacy & Security**.
- **API errors:** Check Perplexity API key in Settings and network access.
- **App won't open on another Mac:** Expected without Developer ID + notarization; use **Open** from context menu or adjust Gatekeeper for local testing.
