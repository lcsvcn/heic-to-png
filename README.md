# HEIC to PNG

A native Swift workspace for converting HEIC/HEIF images to PNG on macOS and iOS.

## What is included

- macOS menu-bar app with drag-and-drop and automatic watched-folder conversion.
- Finder Quick Action named **Convert HEIC to PNG**.
- iOS SwiftUI app with file import, copy, and share actions.
- iOS Share Extension for Photos and Files.
- Shared `HEICPNGCore` Swift package using ImageIO, Core Graphics, and UniformTypeIdentifiers.
- Multi-file conversion, original-file preservation, orientation rendering, and safe numbered output filenames.
- Unit tests for type detection, filename collision handling, unsupported inputs, alpha preservation, orientation handling, corrupt inputs, and PNG conversion where system HEIC encoding is available.

## Requirements

- Xcode 16 or newer.
- macOS 13 or newer for the macOS app.
- iOS 17 or newer for the iOS app and Share Extension.
- An Apple Developer Team for signing apps and extensions on devices.

## Build

1. Open `HEICToPNG.xcodeproj` in Xcode.
2. Select the `HEICToPNGMac` scheme to build the macOS menu-bar app and Finder Quick Action.
3. Select the `HEICToPNGiOS` scheme to build the iOS app and Share Extension.
4. In **Signing & Capabilities**, set your Apple Developer Team for every target:
   - `HEICToPNGMac`
   - `FinderQuickAction`
   - `HEICToPNGiOS`
   - `HEICShareExtension`
5. If Xcode reports bundle identifier conflicts, replace `com.lcsvcn.HEICToPNG` with your own reverse-DNS prefix.

## macOS Usage

### Menu-Bar App

1. Build and run `HEICToPNGMac`.
2. Click the menu-bar icon.
3. Drop one or more `.heic` or `.heif` files, or choose files manually.
4. Converted PNG files are saved beside the originals.
5. Use **Copy** to copy converted PNG files to the clipboard.
6. Use **Reveal** to show the converted files in Finder.
7. Use the toggles to customize Finder Quick Action conversion, automatic reveal, automatic copy, and watched-folder conversion behavior.

### Automatic AirDrop and Screenshot Conversion

When the macOS app is running, **Auto-convert new HEIC files** is enabled by default.

Default watched folders:

- **AirDrop / Downloads**: new `.heic` or `.heif` files in Downloads are converted to PNG beside the original.
- **Desktop / Screenshots**: new `.heic` or `.heif` files on the Desktop are converted to PNG beside the original.

Use **Add Folder** to watch another screenshot/export folder. This is useful if macOS screenshots or image exports are saved somewhere other than Desktop.

The watcher preserves the original HEIC/HEIF file. It skips files that already have a same-name `.png` beside them, so repeated folder scans do not create endless numbered duplicates.

The app cannot intercept AirDrop before macOS writes the received file. It watches the destination folder and creates the PNG immediately after the file appears and is readable.

### Finder Quick Action

For the no-cost local Finder menu, install the bundled Automator Quick Action:

```bash
make install-finder-quick-action
```

Then select one or more HEIC/HEIF files in Finder and choose **Quick Actions → Convert HEIC to PNG**.

The app also contains a native Action Extension for signed app builds:

1. Build and run or archive the macOS app once so the embedded extension is registered.
2. Open **System Settings → Privacy & Security → Extensions → Finder**.
3. Enable **Convert HEIC to PNG**.

Both Quick Action paths preserve the original images, write PNG files beside them, avoid overwrites with numbered filenames, and reveal successful conversions in Finder.

The in-app **Finder Quick Action** toggle is enabled by default. Turning it off keeps the extension installed but makes the action skip conversion until it is turned back on.

To share settings between the macOS app and Finder Quick Action, configure the App Group `group.com.lcsvcn.HEICToPNG` for both macOS targets when signing:

- `HEICToPNGMac`
- `FinderQuickAction`

Ad-hoc Debug builds can run the menu-bar app and convert files locally. Native Action Extension discovery is most reliable from a signed app install, so the Automator Quick Action is included for no-cost local Finder integration.

For signed sandboxed builds, keep Downloads Folder set to Read/Write and App-Scoped Bookmarks enabled on the macOS app target. Downloads access supports AirDrop conversion; bookmarks support user-added watched folders.

## iOS Usage

### App

1. Build and run `HEICToPNGiOS`.
2. Tap **Choose Files** and select HEIC/HEIF images from Files.
3. Converted PNG files are saved in the app's Documents folder under `Converted`.
4. Use **Copy** or **Share** for upload workflows.

### Share Extension

1. Build and install the iOS app on a device or simulator.
2. In Photos or Files, select one or more HEIC/HEIF images.
3. Tap **Share → Convert HEIC to PNG**.
4. Use **Save**, **Copy**, or **Share** for the converted PNG files.

## Running Tests

From the repository root:

```bash
swift test
```

The generated-HEIC conversion test automatically skips on systems where HEIC encoding is unavailable.

## Local Build Commands

From the repository root:

```bash
make test
make coverage
make build-macos
make build-ios
make test-e2e-ios
make run-macos
make ci
```

`make package-macos VERSION=1.0.0` creates a Homebrew-ready macOS zip under `.build/release/`.

`make test-e2e-ios` uses Maestro against the iOS Simulator app. Install Maestro first with `scripts/install-maestro.sh`.

## CI/CD and Homebrew

GitHub Actions are included:

- `CI`: runs coverage, builds macOS plus iOS simulator targets, smoke-tests the macOS zip, validates Homebrew cask generation, and runs a Maestro iOS E2E smoke flow.
- `Release`: runs the coverage/package smoke gates, builds a macOS release zip, publishes a GitHub Release, and optionally updates a Homebrew Cask tap.

For Homebrew deployment, configure repository secrets:

- `HOMEBREW_TAP_REPO`, for example `lcsvcn/homebrew-tap`
- `HOMEBREW_TAP_TOKEN`, with write access to the tap

See `docs/CI_CD.md` for release and tap setup details.

## Notes

- iPhone screenshots are usually PNG already; camera photos are commonly HEIC unless **Settings → Camera → Formats → Most Compatible** is enabled.
- Browsers do not allow a general-purpose app to silently replace every selected upload file. The Finder Quick Action, menu-bar app, iOS app, and Share Extension cover the reliable native workflows.
- The no-cost macOS deployment path is GitHub Releases plus Homebrew Cask. Notarization and Developer ID distribution require Apple Developer Program membership.
