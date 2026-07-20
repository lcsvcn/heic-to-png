# HEIC to PNG

A native Swift workspace for converting HEIC/HEIF images to PNG on macOS and iOS.

## What is included

- macOS menu-bar app with drag-and-drop conversion.
- Finder Quick Action named **Convert HEIC to PNG**.
- iOS SwiftUI app with file import, copy, and share actions.
- iOS Share Extension for Photos and Files.
- Shared `HEICPNGCore` Swift package using ImageIO, Core Graphics, and UniformTypeIdentifiers.
- Multi-file conversion, original-file preservation, orientation rendering, and safe numbered output filenames.
- Unit tests for type detection, filename collision handling, unsupported inputs, and PNG conversion where system HEIC encoding is available.

## Requirements

- Xcode 16 or newer.
- macOS 13 or newer for the macOS app.
- iOS 17 or newer for the iOS app and Share Extension.
- An Apple Developer Team for signing apps and extensions on devices.

## Build

1. Open `HEICToPNG.xcworkspace` in Xcode.
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

### Finder Quick Action

1. Build and run or archive the macOS app once so the embedded extension is registered.
2. Open **System Settings → Privacy & Security → Extensions → Finder**.
3. Enable **Convert HEIC to PNG**.
4. In Finder, select one or more HEIC/HEIF files.
5. Right-click and choose **Quick Actions → Convert HEIC to PNG**.

The Quick Action preserves the original images, writes PNG files beside them, avoids overwrites with numbered filenames, and reveals successful conversions in Finder.

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

## Notes

- iPhone screenshots are usually PNG already; camera photos are commonly HEIC unless **Settings → Camera → Formats → Most Compatible** is enabled.
- Browsers do not allow a general-purpose app to silently replace every selected upload file. The Finder Quick Action, menu-bar app, iOS app, and Share Extension cover the reliable native workflows.

