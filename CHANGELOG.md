# Changelog

All notable changes to ElevenLabs GUI Studio will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.0.0] - 2025-09-30

### Added
- Professional installer configuration for Windows, macOS, and Linux
- NSIS installer with customizable installation directory
- Portable Windows version (no installation required)
- Comprehensive build documentation (BUILD.md)
- MIT License file
- macOS DMG installer with drag-to-Applications interface
- Linux packages (AppImage, DEB, RPM)
- Multi-architecture support (x64, ia32, ARM64)

### Changed
- **Optimized Page Layouts**: Eliminated useless empty space across all pages
  - Reduced padding and margins for better space utilization
  - Improved responsive grid layouts for voice lists and library
  - Better alignment and spacing consistency
  - Optimized form layouts in Voice Management
  - Streamlined Settings and About pages
- **Enhanced UI/UX**: Multiple refinements for better user experience
  - Improved visual hierarchy
  - Better content density without feeling cramped
  - More efficient use of screen real estate

## [2.0.0] - 2025

### Added
- **Voice Cloning Feature**: Complete voice cloning functionality
  - Upload multiple audio samples
  - Create custom voice clones
  - Manage voice labels and descriptions
- **Preset Management System**: Save and load voice parameter combinations
  - Default presets included (Balanced, Expressive, Stable, Fast Speech, Slow & Clear)
  - Create custom presets
  - Delete unwanted presets
- **Voice Library Integration**: Browse and search available voices

### Changed
- **Major UI Overhaul**: Complete redesign with modern dark theme
- **Performance Optimization**: Removed heavy effects for smoother operation
- **Improved Visibility**: Enhanced slider tracks and controls
- **Better Spacing**: Fixed button overlaps and improved layout
- **Color Scheme Update**: Changed from purple to professional gray (#23272e)
- **Notification System**: Reduced duration to 1 second for better UX
- **Preset Management**: Improved preset selector to prevent overflow
- **Responsive Design**: Better adaptation to different screen sizes

## [1.0.0] - Initial Release

### Added
- Basic text-to-speech functionality
- Voice and model selection
- Parameter controls (Stability, Similarity Boost, Style, Speed)
- History tracking with replay capability
- API key management with secure storage
- SSML support with break tags
- Audio export functionality
- Real-time audio waveform visualization
- Dark theme interface
- Context menu with spell check
- Tips and tricks guide