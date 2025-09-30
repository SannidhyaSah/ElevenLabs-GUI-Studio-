# Building ElevenLabs GUI Studio

This guide explains how to build installers for ElevenLabs GUI Studio on different platforms.

## Prerequisites

Before building, ensure you have:
### Windows-Specific Requirements

On Windows, electron-builder may encounter permission errors when extracting code signing tools. You have three options:

#### Option 1: Enable Developer Mode (Recommended)
1. Open Windows Settings
2. Go to "Privacy & Security" > "For developers"
3. Enable "Developer Mode"
4. Restart your computer if prompted
5. Run `npm run build`

#### Option 2: Run as Administrator
1. Open PowerShell as Administrator
2. Navigate to the project directory
3. Run `npm run build`

#### Option 3: Use GitHub Actions (For Distribution)
- Push your code to GitHub
- GitHub Actions will build for all platforms automatically
- See the "Automated Builds (CI/CD)" section below

1. **Node.js** (v16 or higher) and **npm** installed
2. **Git** installed
3. All project dependencies installed: `npm install`

## Platform-Specific Requirements

### Windows
- No additional requirements
- Builds: NSIS installer (.exe) and Portable version

### macOS
- macOS 10.13 or higher
- Xcode Command Line Tools: `xcode-select --install`
- Builds: DMG installer and ZIP archive
- For code signing, you'll need an Apple Developer account

### Linux
- Standard build tools
- Builds: AppImage, DEB package, and RPM package

## Building the Application

### Build for Current Platform

To build for your current operating system:

```bash
npm run build
```

This will create installers in the `dist` directory.

### Build for Specific Platforms

#### Windows (from any platform)
```bash
npm run build -- --win
```

Outputs:
- `dist/ElevenLabs GUI Studio-3.0.0-x64-Setup.exe` (64-bit installer)
- `dist/ElevenLabs GUI Studio-3.0.0-ia32-Setup.exe` (32-bit installer)
- `dist/ElevenLabs GUI Studio-3.0.0-Portable.exe` (Portable version)

#### macOS (from macOS or Linux)
```bash
npm run build -- --mac
```

Outputs:
- `dist/ElevenLabs GUI Studio-3.0.0-x64.dmg` (Intel Mac)
- `dist/ElevenLabs GUI Studio-3.0.0-arm64.dmg` (Apple Silicon)
- `dist/ElevenLabs GUI Studio-3.0.0-x64.zip`
- `dist/ElevenLabs GUI Studio-3.0.0-arm64.zip`

#### Linux (from any platform)
```bash
npm run build -- --linux
```

Outputs:
- `dist/ElevenLabs GUI Studio-3.0.0-x64.AppImage`
- `dist/ElevenLabs GUI Studio-3.0.0-x64.deb` (Debian/Ubuntu)
- `dist/ElevenLabs GUI Studio-3.0.0-x64.rpm` (Fedora/RedHat)

### Build for All Platforms

```bash
npm run build -- --win --mac --linux
```

**Note:** Building for macOS requires a macOS machine or CI/CD service.

## Build Configuration

The build configuration is defined in [`package.json`](package.json:32) under the `build` section.

### Key Configuration Options

- **appId**: `com.elevenlabs.gui.studio`
- **productName**: ElevenLabs GUI Studio
- **Icon**: `assets/logo-11labsgui.png`
- **Output Directory**: `dist/`

### Windows Installer Options (NSIS)

- Two-step installation (not one-click)
- User can choose installation directory
- Creates desktop and start menu shortcuts
- Option to run after installation
- Supports both per-user and per-machine installation

### macOS Options

- Universal builds for Intel and Apple Silicon
- DMG with drag-to-Applications interface
- Hardened runtime enabled
- Requires entitlements for network access and file operations

### Linux Options

- AppImage (universal, no installation required)
- DEB package (Debian/Ubuntu)
- RPM package (Fedora/RedHat/CentOS)

## Icon Requirements

The application uses `assets/logo-11labsgui.png` as the icon source. Electron-builder automatically converts this to the required formats:

- **Windows**: .ico (256x256, 128x128, 64x64, 48x48, 32x32, 16x16)
- **macOS**: .icns (1024x1024, 512x512, 256x256, 128x128, 64x64, 32x32, 16x16)
- **Linux**: .png (512x512, 256x256, 128x128, 64x64, 48x48, 32x32, 16x16)

## Code Signing

### Windows
To sign Windows executables, set these environment variables:
```bash
$env:CSC_LINK = "path/to/certificate.pfx"
$env:CSC_KEY_PASSWORD = "certificate-password"
```

### macOS
To sign macOS applications, set these environment variables:
```bash
export CSC_LINK="path/to/certificate.p12"
export CSC_KEY_PASSWORD="certificate-password"
export APPLE_ID="your-apple-id@email.com"
export APPLE_ID_PASSWORD="app-specific-password"
```

**Note:** Code signing is optional for development builds but required for distribution.

## Troubleshooting

### Build Fails with "Cannot find module"
```bash
# Clean install dependencies
Remove-Item -Recurse -Force node_modules
npm install
```

### Icon Not Showing
- Ensure `assets/logo-11labsgui.png` exists
- Icon should be at least 512x512 pixels
- PNG format with transparency

### macOS Build Fails on Windows/Linux
- macOS builds require a macOS machine or CI/CD service like GitHub Actions
- Consider using GitHub Actions for cross-platform builds

### Large Installer Size
- The installer includes Electron runtime (~150MB)
- This is normal for Electron applications
- Consider using portable/AppImage versions for smaller downloads

## Distribution

After building:

1. **Test the installer** on a clean system
2. **Create release notes** describing changes
3. **Upload to GitHub Releases** or your distribution platform
4. **Update download links** in README.md

## Automated Builds (CI/CD)

For automated builds, consider using GitHub Actions. Create `.github/workflows/build.yml`:

```yaml
name: Build

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [windows-latest, macos-latest, ubuntu-latest]
    
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: 18
      
      - run: npm install
      - run: npm run build
      
      - uses: actions/upload-artifact@v3
        with:
          name: installers-${{ matrix.os }}
          path: dist/*
```

## Additional Resources

- [electron-builder Documentation](https://www.electron.build/)
- [Electron Documentation](https://www.electronjs.org/docs)
- [Code Signing Guide](https://www.electron.build/code-signing)

## Support

For build issues, please open an issue on the [GitHub repository](https://github.com/SannidhyaSah/ElevenLabs-GUI-Studio-/issues).