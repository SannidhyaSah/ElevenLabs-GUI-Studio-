# ElevenLabs GUI Studio — Native macOS Rewrite Plan

## Strategy

### Git Branching
1. Create `legacy/electron` branch from current `main` — preserves the Electron app
2. Clear `main` and build the SwiftUI app fresh
3. Keep `plans/` directory for reference during development

---

## Phase 1: Project Setup & Foundation

### 1.1 Git housekeeping
- Create `legacy/electron` branch from current HEAD
- Push branch to remote
- On `main`, remove Electron files and scaffold the Xcode project

### 1.2 Xcode project scaffold
- Create `ElevenLabsStudio.xcodeproj` targeting macOS 15.0+ (Sequoia)
- Set up the folder structure:
  ```
  ElevenLabsStudio/
  ├── App/
  ├── Views/
  ├── Components/
  ├── Services/
  ├── Models/
  ├── Resources/
  └── ElevenLabsStudioTests/
  ```
- Configure app icon from existing `assets/logo-11labsgui.png`
- Set bundle identifier: `com.elevenlabs.gui.studio`
- Set deployment target: macOS 15.0 (Sequoia)

### 1.3 App entry point & navigation
- `ElevenLabsStudioApp.swift` — App entry with WindowGroup
- `ContentView.swift` — NavigationSplitView with sidebar
- Sidebar items: Playground, Voices, History, Settings
- SF Symbols for navigation icons

---

## Phase 2: Core Services (Backend Layer)

### 2.1 ElevenLabs API Client — `ElevenLabsAPI.swift`

All endpoints use `URLSession` with `async/await`. Auth via `xi-api-key` header.

#### Endpoints to implement:

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/v1/voices?page_size=100` | List user's voices (paginated, searchable, filterable by voice_type/category) |
| `GET` | `/v1/models` | List available AI models |
| `POST` | `/v1/text-to-speech/{voice_id}` | Generate speech from text |
| `POST` | `/v1/voices/add` | Create IVC (Instant Voice Clone) via multipart form data |
| `GET` | `/v1/shared-voices` | Browse shared voice library (filter by category, gender, age, accent, language) |

#### Text-to-Speech Request Body:
```json
{
  "text": "string (required)",
  "model_id": "string (default: eleven_multilingual_v2)",
  "language_code": "string (optional, ISO 639-1)",
  "voice_settings": {
    "stability": 0.5,
    "similarity_boost": 0.75,
    "style": 0.0,
    "speed": 1.0,
    "use_speaker_boost": false
  },
  "output_format": "mp3_44100_128",
  "seed": "integer (optional, 0-4294967295)",
  "previous_text": "string (optional, for continuity)",
  "next_text": "string (optional, for continuity)",
  "apply_text_normalization": "auto | on | off"
}
```

#### Voice Settings Ranges (from official docs):
- `stability`: 0.0 - 1.0 (lower = more emotional range, higher = more consistent)
- `similarity_boost`: 0.0 - 1.0 (higher = closer to original voice)
- `style`: 0.0 - 1.0 (default: 0, higher = more style exaggeration, increases latency)
- `speed`: 0.5 - 2.0 (default: 1.0)
- `use_speaker_boost`: boolean (default: false, increases latency)

#### Output Formats:
- `mp3_22050_32` — MP3 22.05kHz 32kbps
- `mp3_44100_64` — MP3 44.1kHz 64kbps
- `mp3_44100_128` — MP3 44.1kHz 128kbps (default)
- `mp3_44100_192` — MP3 44.1kHz 192kbps (Creator tier+)
- `pcm_16000` — PCM 16kHz
- `pcm_22050` — PCM 22.05kHz
- `pcm_24000` — PCM 24kHz
- `pcm_44100` — PCM 44.1kHz (Pro tier+)
- `ulaw_8000` — μ-law 8kHz (for Twilio)

#### Voice Clone (POST /v1/voices/add) — Multipart Form Data:
- `name` (string, required) — Display name
- `files` (binary[], required) — Audio recordings
- `description` (string, optional)
- `labels` (map or string, optional) — e.g. language, accent, gender, age
- `remove_background_noise` (boolean, default: false) — Audio isolation

#### Shared Voice Library (GET /v1/shared-voices) — Query Params:
- `page_size` (max 100, default 30)
- `category`: professional, famous, high_quality
- `gender`, `age`, `accent`, `language`, `locale`
- `search` — name/description search
- `use_cases`, `descriptives`
- `featured` (boolean)
- `sort`, `page`

### 2.2 Keychain Service — `KeychainService.swift`
- Wrapper around Security framework
- Store/retrieve/delete API keys securely
- Support multiple named API keys
- No custom encryption needed — OS handles it

### 2.3 Audio Service — `AudioService.swift`
- AVFoundation-based audio handling
- Play audio from Data or file URL
- Pause, resume, seek functionality
- Get duration and current time
- Volume control
- Audio waveform data extraction for visualization

---

## Phase 3: Data Models

### 3.1 API Response Models (Codable)

#### Voice Model
```swift
struct Voice: Codable, Identifiable {
    let voiceId: String
    let name: String
    let description: String?
    let category: String?
    let voiceType: String?
    let highQualityBaseModelIds: [String]?
    let verifiedLanguages: [VerifiedLanguage]?
    let isOwner: Bool?
    let isLegacy: Bool?
    let createdAtUnix: Int?
}
```

#### AI Model
```swift
struct AIModel: Codable, Identifiable {
    let modelId: String
    let name: String
    let canDoTextToSpeech: Bool?
    let description: String?
    let languages: [ModelLanguage]?
}
```

#### Voice Settings
```swift
struct VoiceSettings: Codable {
    var stability: Double = 0.5
    var similarityBoost: Double = 0.75
    var style: Double = 0.0
    var speed: Double = 1.0
    var useSpeakerBoost: Bool = false
}
```

### 3.2 Persistence Models (SwiftData)

#### GenerationHistory
```swift
@Model
class GenerationHistory {
    var id: UUID
    var date: Date
    var text: String
    var voiceId: String
    var voiceName: String
    var modelId: String
    var modelName: String
    var voiceSettings: VoiceSettings
    var audioData: Data?
    var outputFormat: String
}
```

#### VoicePreset
```swift
@Model
class VoicePreset {
    var name: String
    var stability: Double
    var similarityBoost: Double
    var style: Double
    var speed: Double
    var useSpeakerBoost: Bool
    var isDefault: Bool
}
```

### 3.3 App State — `AppState.swift`
- @Observable class for global app state
- currentAPIKeyName, isAPIKeyValid
- voices list, models list
- loading states, error states
- current generation status

---

## Phase 4: Views — Playground (Core Feature)

### 4.1 PlaygroundView
- TextEditor for input text
- Voice picker (Picker with searchable modifier)
- Model picker
- Output format selector
- Language code selector (optional)
- Generate button with loading state (ProgressView)
- Break tag insertion toolbar
- Character count display

### 4.2 VoiceParameterSliders
- 5 controls matching official API:
  - Stability slider (0-1, default 0.5)
  - Similarity Boost slider (0-1, default 0.75)
  - Style Exaggeration slider (0-1, default 0.0)
  - Speed slider (0.5-2.0, default 1.0)
  - Speaker Boost toggle (default off)
- Preset picker dropdown
- Save preset / Delete preset
- Test Settings / Reset buttons

### 4.3 AudioPlayerView
- Custom waveform visualization (AVAudioFile PCM data)
- Play/Pause button with SF Symbol icons
- Scrubable progress bar
- Current time / Duration display
- Volume slider
- Save/Export button with format selection

---

## Phase 5: Views — Voice Management

### 5.1 VoiceManagementView
- Tab-based: My Voices | Clone Voice | Voice Library
- Each tab is a separate child view

### 5.2 MyVoicesView
- List/Grid of voice cards from GET /v1/voices
- Search bar (uses API's search parameter)
- Filter by category: premade, cloned, generated, professional
- Each card: name, description, category, verified languages
- "Use in Playground" action
- Pagination support (has_more + next_page_token)

### 5.3 CloneVoiceView
- Form matching POST /v1/voices/add:
  - Voice name (required)
  - Description (optional)
  - Audio file drop zone — native `.fileImporter` / `.dropDestination`
  - Labels: language, accent, gender, age (key-value pairs)
  - Remove background noise toggle (new feature from API!)
  - Create button with progress indicator
- Success: show new voice_id, refresh voice list

### 5.4 VoiceLibraryView
- Uses GET /v1/shared-voices endpoint (correctly!)
- Filters: category, gender, age, accent, language
- Search bar
- Featured voices toggle
- Voice preview (preview_url from API response)
- Pagination (page-based)

---

## Phase 6: Views — History & Settings

### 6.1 HistoryView
- List of past generations from SwiftData
- Each item: voice name, date, text preview, model, audio status
- Actions: Play, Use Text (loads into Playground), Delete
- Search bar for filtering
- Clear All with confirmation
- Audio stored as Data blob — no temp file fragility

### 6.2 SettingsView
- API Key Management:
  - Add new key (name + key, validated against GET /v1/voices)
  - List saved keys (from Keychain)
  - Set active / Delete actions
  - Status indicator (connected/disconnected)
- Audio Settings:
  - Default output format picker
  - Default voice settings
- About section:
  - Version, credits, links

---

## Phase 7: Polish & Distribution

### 7.1 macOS Integration
- Native menu bar with keyboard shortcuts:
  - ⌘+Enter: Generate speech
  - Space: Play/Pause
  - ⌘+N: New generation
  - ⌘+S: Save audio
  - ⌘+,: Settings
- Window management (min size, restore state)
- App icon in .icns format

### 7.2 Error Handling & UX
- Native alert dialogs for errors
- Loading states with ProgressView
- Empty states with helpful messages
- First-run onboarding (direct to Settings → API key)
- Graceful offline handling
- Rate limit awareness (429 handling with retry-after)

### 7.3 Testing
- Unit tests for ElevenLabsAPI client
- Unit tests for Keychain service
- Unit tests for audio service
- Unit tests for VoiceSettings validation
- UI tests for critical flows

### 7.4 Distribution
- Create .dmg installer (via create-dmg or Xcode archive)
- Code signing (optional — requires Apple Developer account $99/year)
- Notarization (optional — for Gatekeeper)
- GitHub Releases with .dmg artifact
- Update README with new screenshots and installation instructions

---

## Implementation Order

```
Phase 1.1  →  Git: branch current code to legacy/electron
Phase 1.2  →  Scaffold Xcode project
Phase 1.3  →  App shell with NavigationSplitView sidebar
Phase 3.1  →  API response models (Voice, AIModel, VoiceSettings)
Phase 2.2  →  Keychain service
Phase 2.1  →  ElevenLabs API client (voices + models + TTS)
Phase 3.3  →  App state (@Observable)
Phase 4.1  →  Playground view (text input + voice/model pickers)
Phase 4.2  →  Voice parameter sliders + presets
Phase 2.3  →  Audio service (AVFoundation)
Phase 4.3  →  Audio player with waveform
Phase 3.2  →  SwiftData models (history + presets)
Phase 6.1  →  History view
Phase 6.2  →  Settings view
Phase 5.2  →  My Voices view
Phase 5.3  →  Voice cloning
Phase 5.4  →  Voice library (shared voices)
Phase 7.1  →  macOS menus + keyboard shortcuts
Phase 7.2  →  Error handling + polish
Phase 7.3  →  Tests
Phase 7.4  →  .dmg distribution
```

---

## Technology Stack

| Concern | Technology |
|---|---|
| UI Framework | SwiftUI |
| Language | Swift 5.9+ |
| Networking | URLSession + async/await |
| JSON Decoding | JSONDecoder with keyDecodingStrategy .convertFromSnakeCase |
| Secrets | Keychain Services (Security framework) |
| Persistence | SwiftData |
| Audio Playback | AVFoundation (AVAudioPlayer) |
| Audio Waveform | AVAudioFile + AVAudioPCMBuffer |
| State Management | @Observable (Observation framework) |
| File Import | .fileImporter / .dropDestination modifiers |
| Target OS | macOS 15.0+ (Sequoia) |
| IDE | Xcode 16+ |
| Distribution | .dmg via create-dmg or Xcode archive |
