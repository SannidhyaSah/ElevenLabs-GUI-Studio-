# ElevenLabs GUI Studio — Codebase Review & Improvement Plan

## 🔴 Bugs & Critical Issues

### 1. Voice Cloning Is Broken — Scope Bug
**Files:** [`renderer.js`](renderer.js:373), [`renderer.js`](renderer.js:1520)

`uploadedFiles` is declared with `let` inside the `DOMContentLoaded` callback (line 373), but the `createCloneBtn` click handler (line 1520) and `renderFileList()` (line 411) are referenced from **outside** that closure at global scope. When the clone button is clicked, `uploadedFiles` is `undefined` → `ReferenceError`.

**Fix:** Move `uploadedFiles` to module/global scope, or move the clone button handler inside `DOMContentLoaded`.

---

### 2. Sanitized Path Is Never Used — Security Bypass
**File:** [`main.js`](main.js:677-678)

```js
const sanitizedPath = sanitizePath(audioPath);     // computed...
const resolvedPath = path.resolve(audioPath);       // ...but original used instead
```

The sanitized path is calculated but discarded. The unsanitized `audioPath` goes directly to `path.resolve()`, defeating the purpose of sanitization.

**Fix:** Use `sanitizedPath` in subsequent operations, or validate `resolvedPath` against an allowlist.

---

### 3. Style Slider Default Mismatch
**Files:** [`index.html`](index.html:241), [`renderer.js`](renderer.js:94), [`renderer.js`](renderer.js:1351)

| Location | Default Style Value |
|---|---|
| HTML `value` attribute | `0.5` |
| `loadSettings()` default | `0` |
| `resetVoiceSettings()` | `0.0` |
| "Balanced" preset | `0` |
| `validateVoiceSettings()` fallback | `0.5` |

Fresh users see `0.5` in the slider but every preset and reset expects `0`. This causes unexpected voice output on first use.

**Fix:** Align all defaults to `0` (the ElevenLabs API default for style exaggeration).

---

### 4. Event Listeners Stack on Every Refresh
**File:** [`renderer.js`](renderer.js:834), [`renderer.js`](renderer.js:938)

Every call to `loadVoices()` appends a **new** `change` event listener to `voiceSelect` (line 834). Same for `loadModels()` and `modelSelect` (line 938). After 5 refreshes, there are 5 duplicate listeners saving settings on each change.

**Fix:** Add the event listeners once during initialization, outside the load functions.

---

### 5. `testVoiceSettings` Uses Wrong Audio Source Format
**File:** [`renderer.js`](renderer.js:1428)

```js
audioPlayer.src = result.audioPath;   // raw path, no file:// prefix
```

But [`playAudio()`](renderer.js:1177) uses `file://${path}`. The inconsistency means test playback may fail on some platforms.

**Fix:** Use `playAudio(result.audioPath)` consistently.

---

### 6. Missing `icon.png` Asset
**File:** [`main.js`](main.js:103)

```js
icon: path.join(__dirname, 'assets/icon.png')
```

The `assets/` directory contains `logo-11labsgui.png` and `screenshot.png` — no `icon.png`. The window icon will silently fail to load.

**Fix:** Add proper icon files (`.png`, `.ico`, `.icns`) or point to the existing logo.

---

### 7. `add-voice-from-library` Is a No-Op
**File:** [`main.js`](main.js:809-830)

The handler returns `{ success: true }` without doing anything. The "Add to My Voices" button misleads users.

**Fix:** Either implement the actual ElevenLabs shared voice add API, or remove the button / show an honest message.

---

### 8. `get-voice-library` Doesn't Fetch the Real Library
**File:** [`main.js`](main.js:781-806)

It calls `elevenLabsClient.voices.getAll()` (the user's own voices) and filters by category. It should use a different endpoint to browse the ElevenLabs shared voice library.

**Fix:** Use the correct ElevenLabs API method for browsing shared/public voices.

---

### 9. Data Directory in App Directory — Will Fail When Installed
**File:** [`main.js`](main.js:10)

```js
const dataDir = path.join(__dirname, 'data');
```

In a packaged Electron app, `__dirname` points to the app's read-only resources (ASAR archive). Writing to it will fail.

**Fix:** Use `app.getPath('userData')` instead of `__dirname`.

---

## 🟡 Security Issues

### 10. API Keys Returned Unencrypted to Renderer
**File:** [`main.js`](main.js:233-235)

```js
ipcMain.handle('get-api-keys', () => {
  return apiKeys;   // full array with raw API key strings
});
```

The renderer (less trusted context) receives the actual API key values. Any XSS or renderer compromise would expose all keys.

**Fix:** Return only key names/metadata to the renderer. Keep actual API key strings in the main process only.

---

### 11. Hardcoded `electron-store` Encryption Key
**File:** [`main.js`](main.js:20)

```js
encryptionKey: 'elevenlabs-gui-studio-2024'
```

This provides zero security — anyone reading the source knows the key.

**Fix:** Use OS keychain (via `keytar` or `safeStorage`) or derive from a user password.

---

### 12. Encryption Key Stored Next to Encrypted Data
**File:** [`utils/crypto.js`](utils/crypto.js:6)

The encryption key file (`data/.encryption_key`) sits right alongside `data/api_keys.json`. If an attacker accesses the data directory, they get both.

**Fix:** Store the key using Electron's `safeStorage` API or the OS keychain.

---

### 13. Arbitrary Path Checking via IPC
**File:** [`main.js`](main.js:658-665)

`check-file-exists` accepts any file path with no validation. An attacker with renderer access could enumerate files on the system.

**Fix:** Restrict to temp directory or known audio output paths.

---

### 14. No Content Security Policy
**File:** [`index.html`](index.html:1)

No CSP `<meta>` tag. This is a common Electron security gap that enables XSS attacks.

**Fix:** Add a strict CSP header:
```html
<meta http-equiv="Content-Security-Policy" 
      content="default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'">
```

---

## 🟠 Code Quality Issues

### 15. Unused Dependencies
**File:** [`package.json`](package.json:19-26)

| Package | Used? |
|---|---|
| `react` | ❌ Never imported |
| `react-dom` | ❌ Never imported |
| `express` | ❌ Never imported |
| `bcryptjs` | ❌ Never imported |
| `wavesurfer.js` | ❌ Files bundled in `js/` but never loaded |

These inflate `node_modules` and the built app size for no benefit.

**Fix:** Remove unused dependencies.

---

### 16. WaveSurfer Files Bundled but Unused
**Files:** [`js/wavesurfer.min.js`](js/wavesurfer.min.js), [`js/minimap.min.js`](js/minimap.min.js), [`js/regions.min.js`](js/regions.min.js), [`js/timeline.min.js`](js/timeline.min.js)

Four minified JS files in `js/` are never `<script>`-loaded or referenced anywhere.

**Fix:** Either integrate WaveSurfer for proper waveform visualization or remove the dead files.

---

### 17. Excessive `console.log` in Production
**File:** [`main.js`](main.js:348-349), [`main.js`](main.js:373), [`main.js`](main.js:473-475)

Full API responses are `JSON.stringify`'d and logged (including all voice/model data). This is a performance waste and potential information leak.

**Fix:** Add a logger with log levels; only verbose-log in dev mode.

---

### 18. Monolithic 1832-Line `renderer.js`
**File:** [`renderer.js`](renderer.js)

All UI logic — API key management, voice loading, speech generation, audio playback, history, voice cloning, presets, dock toggling — lives in one massive file with no modularity.

**Fix:** Split into modules (e.g., `api-keys.js`, `speech.js`, `voices.js`, `history.js`, `audio-player.js`, `presets.js`).

---

### 19. No Error Boundary / Global Error Handlers
**File:** [`main.js`](main.js)

No `process.on('uncaughtException')` or `process.on('unhandledRejection')` handlers. Unhandled errors could silently crash the app.

**Fix:** Add global error handlers with user-facing error dialogs.

---

### 20. CSS Variable Name Mismatch
**File:** [`renderer.js`](renderer.js:308)

```js
slider.style.background = `linear-gradient(to right, var(--primary-color) ... var(--button-color) ...)`;
```

But [`styles-optimized.css`](styles-optimized.css:9) defines `--accent`, not `--primary-color` or `--button-color`. The slider gradient will fall back to transparent, making it invisible.

**Fix:** Update to use `--accent` and `--bg-glass` (or whichever CSS vars actually exist).

---

### 21. Notification Duration Too Short
**File:** [`renderer.js`](renderer.js:292)

```js
setTimeout(() => { ... }, 1000);   // 1 second
```

Notifications auto-dismiss after only 1 second — too fast to read, especially for error messages.

**Fix:** Use longer durations (3-5s) and vary by notification type (errors longer than success messages).

---

## 🔵 Improvement Opportunities

### Architecture
- **Modularize renderer.js** into separate concern-based files
- **Add a build step** (Vite/Webpack) for proper module bundling, tree-shaking, and minification
- **Implement proper state management** instead of scattered `let` variables
- **Add TypeScript** for type safety across the codebase

### Features
- **Integrate WaveSurfer.js** for real waveform visualization (files already bundled)
- **Implement actual voice library browsing** via the ElevenLabs shared voices API
- **Add audio format conversion** (currently just copies MP3; the save dialog offers format options but doesn't convert)
- **Add character count / API usage tracking** to help users manage their quota
- **Add keyboard shortcuts** for common actions (generate, play/pause, new)
- **Add drag-and-drop text files** onto the text input area
- **Add dark/light theme toggle** (CSS var `theme` exists in settings but isn't wired up)

### UX
- **Loading states** — Many operations lack proper loading indicators
- **Batch generation** — Support generating multiple texts in sequence
- **Voice preview** — Play sample audio when selecting a voice
- **Better history** — Add search, pagination, and audio file size info
- **Responsive layout** — Handle window resize more gracefully

### DevOps
- **Add ESLint** for code quality enforcement
- **Add tests** (currently `npm test` just exits with an error)
- **Add CI/CD** pipeline for automated builds and releases
- **Add auto-update** via `electron-updater`
