#!/usr/bin/env bash
set -euo pipefail

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

.github/scripts/update-homebrew-cask.sh \
  "$tmp_dir" \
  "0.0.0" \
  "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" \
  "https://github.com/lcsvcn/heic-to-png/releases/download/v0.0.0/HEICToPNG-0.0.0.zip" \
  "https://github.com/lcsvcn/heic-to-png"

cask_path="$tmp_dir/Casks/heic-to-png.rb"
ruby -c "$cask_path"
grep -q 'app "HEICToPNG.app"' "$cask_path"
grep -q 'Convert HEIC to PNG' "$cask_path"
