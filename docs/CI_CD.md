# Build, Release, and Homebrew

## Local commands

Use `make` from the repository root:

```bash
make test
make coverage
make build-macos
make build-ios
make build
make test-e2e-ios
make install-finder-quick-action
make run-macos
make package-macos VERSION=1.0.0
make smoke-finder-quick-action-workflow
make smoke-homebrew-cask
make smoke-macos-package VERSION=ci-smoke
make ci
```

The build commands use `HEICToPNG.xcodeproj` directly and keep build output under `.build/`.

`make coverage` runs the shared converter package tests with SwiftPM coverage enabled and enforces `COVERAGE_MIN`, which defaults to 80 percent line coverage. `make smoke-finder-quick-action-workflow` validates the no-cost Automator Finder Quick Action package and its embedded shell script.

`make test-e2e-ios` builds the iOS Simulator app and runs the Maestro flow in `.maestro/ios-smoke.yaml`. The runner targets one exact simulator UDID, warms up simulator UI services, uses bounded waits for boot/install/test steps, increases Maestro's iOS driver startup timeout for slower CI runners, and writes reports under `.build/maestro/`. Maestro applies to the iOS app because it is a mobile UI automation tool. It is not used for the macOS menu-bar app or Finder Quick Action.

Install Maestro locally with:

```bash
scripts/install-maestro.sh
```

For a local smoke test of app-level conversion:

```bash
make run-macos
open -a "$(pwd)/.build/DerivedData/Build/Products/Debug/HEICToPNG.app" path/to/photo.heic
```

The PNG is written beside the HEIC file.

For a local smoke test of automatic AirDrop-style conversion:

```bash
make run-macos
cp path/to/photo.heic ~/Downloads/HEICToPNG-AutoWatch-Test.heic
```

When the app is running, the PNG should appear beside the HEIC file in Downloads.

## GitHub Actions

`CI` runs on pushes to `main`, pull requests, and manual dispatch. New pushes cancel older in-progress runs for the same branch so stuck simulator jobs do not pile up. It has two jobs:

- `Unit, Coverage, Build, Package`: enforces converter coverage, builds the macOS app plus Finder Quick Action, builds the iOS simulator app plus Share Extension, validates the Automator Finder Quick Action workflow, smoke-tests Homebrew cask generation, and smoke-tests the macOS zip artifact.
- `iOS Maestro E2E`: installs the free local Maestro CLI, builds the iOS Simulator app, installs it on a simulator, and runs the `.maestro/ios-smoke.yaml` flow.

`CD` runs when you push a tag like `v1.0.0`, or manually from GitHub Actions. It runs the coverage and deployment smoke gates, builds a macOS release zip, creates or updates a GitHub Release, uploads the zip and checksum, and updates the configured Homebrew tap. Tag-triggered runs require Homebrew tap credentials so a tagged release cannot silently skip Homebrew publishing.

## No-cost deployment model

This project does not require the Mac App Store or a paid Apple Developer Program account for basic distribution.

The free path is:

1. GitHub Actions builds `HEICToPNG.app`.
2. GitHub Releases hosts `HEICToPNG-<version>.zip` and its SHA-256 checksum. The zip contains `HEICToPNG.app` and the no-cost Automator Finder Quick Action workflow.
3. The Homebrew tap job updates a cask that installs the app into `/Applications` and the workflow into `~/Library/Services`.

Tradeoff: without Developer ID signing and notarization, macOS may show Gatekeeper warnings on first launch. A smoother “identified developer” install requires Developer ID signing and notarization, which requires Apple Developer Program membership.

The iOS app and Share Extension are buildable from source, but broad iOS distribution still requires Apple-managed distribution channels. The no-cost release pipeline therefore focuses on macOS GitHub Release/Homebrew delivery.

## Homebrew tap deployment

The CD workflow updates Homebrew for every pushed `v*` tag when these repository secrets are configured:

- `HOMEBREW_TAP_REPO`: the tap repository, for example `lcsvcn/homebrew-tap`.
- `HOMEBREW_TAP_DEPLOY_KEY`: a private SSH deploy key with write access to the tap repository. This is preferred because the key is scoped to the tap repo.

Alternatively, use `HOMEBREW_TAP_TOKEN` with write access to the tap repository.

The workflow writes this cask file in the tap:

```text
Casks/heic-to-png.rb
```

Users can then install with:

```bash
brew tap lcsvcn/tap
brew install --cask heic-to-png
```

If the tap secrets are missing, tag-triggered CD fails after publishing the GitHub Release. Manual CD runs only update Homebrew when `publish_homebrew` is selected.

Because this app repository is private, Homebrew installs will need authenticated access to the GitHub release asset. For a public one-command install, publish release artifacts from a public repository or another public download location.

For signed macOS builds, enable the App Group `group.com.lcsvcn.HEICToPNG` on both macOS targets so the app settings and Finder Quick Action settings stay in sync.

For the macOS app target, keep these sandbox capabilities enabled:

- Downloads Folder: Read/Write, for AirDrop and Downloads auto-conversion.
- User Selected File: Read/Write, for manually selected files and folders.
- App-Scoped Bookmarks, for persisted custom watched folders.

## Release steps

1. Make sure CI is passing on `main`.
2. Create and push a version tag:

   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

3. The CD workflow publishes `HEICToPNG-1.0.0.zip`.
4. The CD workflow updates the tap cask with the new URL and SHA-256.
