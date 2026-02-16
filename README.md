# ElevenLabs Studio v4.0

A native macOS application for interacting with the ElevenLabs text-to-speech API. Built with Swift and SwiftUI.

![Version](https://img.shields.io/badge/version-4.0.0-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![Platform](https://img.shields.io/badge/platform-macOS%2015%2B-lightgrey.svg)
![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)

## What's New in v4.0

Complete rewrite as a **native macOS application** using Swift + SwiftUI. No more Electron/Chromium overhead.

| Feature | v3.0 (Electron) | v4.0 (Native) |
|---|---|---|
| App size | ~200MB | ~5MB |
| Startup time | 2-4 seconds | Instant |
| Memory usage | ~300MB+ | ~30-50MB |
| API key storage | Custom encryption | macOS Keychain |
| Audio player | HTML5 audio | AVFoundation |
| History storage | localStorage | SwiftData |
| UI components | Custom CSS | Native macOS |

## Features

### Core
- **Playground** — Convert text to speech using ElevenLabs' AI voices
- **Voice Management** — Browse, search, and manage your voice library
- **Voice Cloning** — Create custom voice clones by uploading audio samples
- **Voice Library** — Browse the ElevenLabs shared voice library
- **History** — Review, replay, and reuse previous generations

### Voice Controls
- Stability, Similarity Boost, Style Exaggeration, Speed sliders
- Speaker Boost toggle
- Preset management (save, load, delete custom presets)
- Test settings with sample audio

### Audio
- Native waveform visualization
- Full playback controls (play, pause, seek, volume)
- Multiple output format support (MP3, PCM, WAV)
- Export to file

### Security
- API keys stored in macOS Keychain (OS-level encryption)
- App Sandbox enabled
- No third-party dependencies

## Requirements

- macOS 15.0 (Sequoia) or later
- An ElevenLabs API key ([get one here](https://elevenlabs.io))
- Xcode 16+ (for building from source)

## Installation

### Download
Download the latest `.dmg` from the [Releases](https://github.com/SannidhyaSah/ElevenLabs-GUI-Studio-/releases) page.

### Build from Source

1. Clone this repository:
   ```sh
   git clone https://github.com/SannidhyaSah/ElevenLabs-GUI-Studio-.git
   cd ElevenLabs-GUI-Studio-
   ```

2. Generate the Xcode project:
   ```sh
   brew install xcodegen  # if not already installed
   xcodegen generate
   ```

3. Open in Xcode:
   ```sh
   open ElevenLabsStudio.xcodeproj
   ```

4. Build and run (⌘+R)

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| ⌘+Enter | Generate speech |
| ⌘+N | New generation |
| ⌘+S | Save audio |
| ⌘+, | Settings |
| Space | Play/Pause |

## Architecture

```
ElevenLabsStudio/
├── App/           — App entry point & main navigation
├── Views/         — Main screen views (Playground, Voices, History, Settings)
├── Components/    — Reusable UI components (AudioPlayer, Sliders, VoiceCard)
├── Services/      — API client, Keychain, Audio playback
├── Models/        — Data models (Voice, AIModel, VoiceSettings, SwiftData)
└── Resources/     — Asset catalog
```

**Zero third-party dependencies.** Uses only Apple frameworks:
- SwiftUI — UI
- SwiftData — Persistence
- AVFoundation — Audio
- Security — Keychain
- URLSession — Networking

## Previous Version

The Electron-based v3.0 is preserved on the [`legacy/electron`](https://github.com/SannidhyaSah/ElevenLabs-GUI-Studio-/tree/legacy/electron) branch.

## Attribution

Created by [@SannidhyaSah](https://github.com/SannidhyaSah)

## Disclaimer

This is an unofficial application and is not affiliated with ElevenLabs. You must have a valid ElevenLabs API key to use this application. All API usage is subject to ElevenLabs' terms of service.

## License

MIT
