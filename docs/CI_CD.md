# Build, Release, and Homebrew

## Local commands

Use `make` from the repository root:

```bash
make test
make build-macos
make build-ios
make build
make run-macos
make package-macos VERSION=1.0.0
make ci
```

The build commands use `HEICToPNG.xcodeproj` directly and keep build output under `.build/`.

## GitHub Actions

`CI` runs on pushes to `main`, pull requests, and manual dispatch. It runs the unit tests, builds the macOS app plus Finder Quick Action, and builds the iOS simulator app plus Share Extension.

`Release` runs when you push a tag like `v1.0.0`, or manually from GitHub Actions. It builds a macOS release zip, creates or updates a GitHub Release, uploads the zip and checksum, and can update a Homebrew tap.

## Homebrew tap deployment

The release workflow updates Homebrew only when these repository secrets are configured:

- `HOMEBREW_TAP_REPO`: the tap repository, for example `lcsvcn/homebrew-tap`.
- `HOMEBREW_TAP_TOKEN`: a GitHub token with write access to that tap repository.

The workflow writes this cask file in the tap:

```text
Casks/heic-to-png.rb
```

Users can then install with:

```bash
brew tap lcsvcn/tap
brew install --cask heic-to-png
```

If the tap secrets are missing, release still succeeds and the Homebrew update step is skipped.

Because this app repository is private, Homebrew installs will need authenticated access to the GitHub release asset. For a public one-command install, publish release artifacts from a public repository or another public download location.

## Release steps

1. Make sure CI is passing on `main`.
2. Create and push a version tag:

   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

3. The release workflow publishes `HEICToPNG-1.0.0.zip`.
4. If Homebrew tap secrets are configured, the workflow updates the tap cask with the new URL and SHA-256.
