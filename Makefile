XCODEBUILD ?= /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild
PROJECT := HEICToPNG.xcodeproj
MAC_SCHEME := HEICToPNGMac
IOS_SCHEME := HEICToPNGiOS
CONFIGURATION ?= Debug
MAC_DERIVED_DATA ?= .build/DerivedData
IOS_DERIVED_DATA ?= .build/DerivedData-iOS
SOURCE_PACKAGES ?= .build/SourcePackages
RELEASE_DIR ?= .build/release
VERSION ?= dev
COVERAGE_MIN ?= 80
IOS_BUNDLE_ID ?= com.lcsvcn.HEICToPNG.iOS
IOS_APP_PATH ?= $(IOS_DERIVED_DATA)/Build/Products/Debug-iphonesimulator/HEICToPNGiOS.app

.PHONY: help test coverage build build-macos build-ios run-e2e-ios test-e2e-ios run-macos package-macos smoke-homebrew-cask smoke-macos-package ci clean

help:
	@printf "Available commands:\n"
	@printf "  make test             Run HEICPNGCore unit tests\n"
	@printf "  make coverage         Run unit tests with an enforced coverage threshold\n"
	@printf "  make build            Build macOS and iOS simulator targets\n"
	@printf "  make build-macos      Build the macOS menu-bar app and Quick Action\n"
	@printf "  make build-ios        Build the iOS app and Share Extension for simulator\n"
	@printf "  make run-e2e-ios      Run Maestro against an existing iOS simulator app build\n"
	@printf "  make test-e2e-ios     Build iOS simulator app and run Maestro E2E smoke flow\n"
	@printf "  make run-macos        Build and launch the macOS menu-bar app\n"
	@printf "  make package-macos    Build Release and create a Homebrew-ready zip\n"
	@printf "  make ci               Run coverage, builds, and deployment smoke checks\n"

test:
	DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
	CLANG_MODULE_CACHE_PATH="$(PWD)/.build/module-cache" \
	swift test

coverage:
	scripts/check-coverage.sh "$(COVERAGE_MIN)"

build: build-macos build-ios

build-macos:
	$(XCODEBUILD) -quiet \
		-project $(PROJECT) \
		-scheme $(MAC_SCHEME) \
		-configuration $(CONFIGURATION) \
		-destination 'platform=macOS' \
		-derivedDataPath $(MAC_DERIVED_DATA) \
		-clonedSourcePackagesDirPath $(SOURCE_PACKAGES) \
		CODE_SIGNING_ALLOWED=NO \
		build

build-ios:
	$(XCODEBUILD) -quiet \
		-project $(PROJECT) \
		-scheme $(IOS_SCHEME) \
		-configuration $(CONFIGURATION) \
		-destination 'generic/platform=iOS Simulator' \
		-derivedDataPath $(IOS_DERIVED_DATA) \
		-clonedSourcePackagesDirPath $(SOURCE_PACKAGES) \
		CODE_SIGNING_ALLOWED=NO \
		build

run-e2e-ios:
	IOS_BUNDLE_ID="$(IOS_BUNDLE_ID)" IOS_APP_PATH="$(IOS_APP_PATH)" scripts/run-ios-maestro.sh

test-e2e-ios: build-ios run-e2e-ios

run-macos: build-macos
	open "$(MAC_DERIVED_DATA)/Build/Products/$(CONFIGURATION)/HEICToPNG.app"

package-macos:
	$(MAKE) build-macos CONFIGURATION=Release
	mkdir -p "$(RELEASE_DIR)"
	ditto -c -k --keepParent \
		"$(MAC_DERIVED_DATA)/Build/Products/Release/HEICToPNG.app" \
		"$(RELEASE_DIR)/HEICToPNG-$(VERSION).zip"
	shasum -a 256 "$(RELEASE_DIR)/HEICToPNG-$(VERSION).zip" > "$(RELEASE_DIR)/HEICToPNG-$(VERSION).zip.sha256"

smoke-homebrew-cask:
	scripts/smoke-homebrew-cask.sh

smoke-macos-package:
	VERSION="$(VERSION)" scripts/smoke-macos-package.sh

ci: coverage build smoke-homebrew-cask smoke-macos-package

clean:
	$(XCODEBUILD) -quiet -project $(PROJECT) -scheme $(MAC_SCHEME) -derivedDataPath $(MAC_DERIVED_DATA) clean
	$(XCODEBUILD) -quiet -project $(PROJECT) -scheme $(IOS_SCHEME) -derivedDataPath $(IOS_DERIVED_DATA) clean
