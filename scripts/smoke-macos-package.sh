#!/usr/bin/env bash
set -euo pipefail

version="${VERSION:-ci-smoke}"
artifact=".build/release/HEICToPNG-${version}.zip"
checksum="${artifact}.sha256"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

make package-macos VERSION="$version"

test -f "$artifact"
test -f "$checksum"
shasum -a 256 -c "$checksum"

ditto -x -k "$artifact" "$tmp_dir"

app="$tmp_dir/HEICToPNG.app"
quick_action="$app/Contents/PlugIns/FinderQuickAction.appex"
workflow="$tmp_dir/Convert HEIC to PNG.workflow"

test -d "$app"
test -d "$quick_action"
test -d "$workflow"

mac_bundle_id="$(plutil -extract CFBundleIdentifier raw -o - "$app/Contents/Info.plist")"
action_bundle_id="$(plutil -extract CFBundleIdentifier raw -o - "$quick_action/Contents/Info.plist")"
action_name="$(plutil -extract CFBundleDisplayName raw -o - "$quick_action/Contents/Info.plist")"
workflow_bundle_id="$(plutil -extract CFBundleIdentifier raw -o - "$workflow/Contents/Info.plist")"
workflow_name="$(plutil -extract CFBundleName raw -o - "$workflow/Contents/Info.plist")"

test "$mac_bundle_id" = "com.lcsvcn.HEICToPNG.mac"
test "$action_bundle_id" = "com.lcsvcn.HEICToPNG.mac.FinderQuickAction"
test "$action_name" = "Convert HEIC to PNG"
test "$workflow_bundle_id" = "com.lcsvcn.HEICToPNG.quickaction.workflow"
test "$workflow_name" = "Convert HEIC to PNG"
