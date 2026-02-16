# Changelog

All notable changes to ElevenLabs Studio will be documented in this file.

## [4.1.0] - 2026-02-16

### Added
- History download functionality - save audio files directly from history with the same interface as the playground

### Fixed
- TextEditor placeholder text overlap issue - placeholder now disappears when field is focused, preventing cursor overlap

## [4.0.0] - 2025-01-XX

### Changed
- **Complete native macOS rewrite** using Swift + SwiftUI (previously Electron-based)
- App size reduced from ~200MB to ~5MB
- Startup time now instant (previously 2-4 seconds)
- Memory usage reduced from ~300MB+ to ~30-50MB
- API key storage now uses macOS Keychain (previously custom encryption)
- Audio player now uses AVFoundation (previously HTML5 audio)
- History storage now uses SwiftData (previously localStorage)
- UI components now native macOS (previously custom CSS)

### Removed
- Workstation multi-track editor (simplified release)

## [3.0.0] - 2024-XX-XX

### Changed
- Optimized layouts and improved UX
- Electron-based implementation

### Added
- Professional installer configuration and build system

## [2.0.0] - 2024-XX-XX

### Changed
- Major UI update with improved layouts

## [1.0.0] - 2024-XX-XX

### Added
- Initial release with core text-to-speech functionality
- Voice management and cloning
- History tracking
- Settings management
