<p align="center">
  <img src="res/logo.png" alt="Neflix Cat" width="200" />
</p>

<h1 align="center">Black Voice</h1>

<p align="center">
  <strong>MacOS · Swift · TypeScript</strong>
</p>

## Overview

Black Voice is a macOS app + widget demo.

- The macOS app is used for settings (API key, model, prompt).
- The widget is used for quick text Q&A.
- SQLite stores local settings for the demo.
- Final output is a distributable `.dmg`.

## Tech Stack

- **UI/App:** SwiftUI (macOS)
- **Widget:** WidgetKit + App Intents
- **Local storage:** SQLite
- **LLM API:** OpenAI (text in / text out)

## Repository Layout

This repository is being prepared for a Swift-first macOS structure:

```text
.
├── apps/
│   └── macos/                  # Xcode project (app + widget)
├── scripts/                    # Build/release helper scripts
├── dist/                       # Build outputs (.app / .dmg)
├── res/                        # Static assets
└── README.md
```

Expected app-level layout under `apps/macos`:

```text
apps/macos/
├── BlackVoice.xcodeproj
├── BlackVoice/                 # Main macOS app target
└── BlackVoiceWidget/           # Widget extension target
```

## Prerequisites

- macOS 14+ recommended
- Xcode 15+
- Apple Developer account (required for full signing/notarization flow)
- `hdiutil` (built-in on macOS)

## Development Setup

### 1) Create/open the macOS project

In Xcode:

1. `File` -> `New` -> `Project` -> `macOS` -> `App`
2. Product Name: `BlackVoice`
3. Interface: `SwiftUI`
4. Language: `Swift`
5. Save under `apps/macos`

### 2) Add the widget target

1. `File` -> `New` -> `Target`
2. Choose `Widget Extension`
3. Name: `BlackVoiceWidget`

### 3) Configure capabilities

For **both** app and widget targets:

- Enable `App Groups` with the same group ID
- Enable outbound network access (for OpenAI calls)

## How to Update Code

### Main app (settings + SQLite)

Update code in:

- `apps/macos/BlackVoice/...`

Core responsibilities:

- Build settings UI (API key, model, prompt)
- Save/load config from SQLite
- Provide shared data for widget display refresh

### Widget (send text and receive text)

Update code in:

- `apps/macos/BlackVoiceWidget/...`

Core responsibilities:

- Read local/shared state
- Trigger text question via intent/service
- Show latest answer in widget UI

## Build and Export

### A) Build and archive `.app` in Xcode

1. Select scheme: `BlackVoice` (main app)
2. `Product` -> `Archive`
3. In Organizer, export `BlackVoice.app`

### B) Build `.dmg` from exported `.app`

Use terminal from repository root:

```bash
mkdir -p dist
hdiutil create -volname "BlackVoice" -srcfolder "path/to/BlackVoice.app" -ov -format UDZO "dist/BlackVoice.dmg"
```

Replace `path/to/BlackVoice.app` with your actual exported app path.

## Recommended Release Flow

1. Build Release archive in Xcode
2. Sign app correctly (Developer ID)
3. Notarize app (for external distribution)
4. Create DMG and distribute `dist/BlackVoice.dmg`

## Troubleshooting

- Widget not updating:
  - Verify both targets use the same App Group
  - Trigger widget timeline reload after saving settings
- OpenAI request failing:
  - Check API key
  - Check model name
  - Check network entitlement/configuration
- App opens on your machine but not others:
  - Confirm signing + notarization completed