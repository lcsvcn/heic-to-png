#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 5 ]]; then
  echo "Usage: $0 <tap-dir> <version> <sha256> <download-url> <repository-url>" >&2
  exit 64
fi

tap_dir="$1"
version="$2"
sha256="$3"
download_url="$4"
repository_url="$5"
verified_url="${repository_url#https://}/"
cask_path="${tap_dir}/Casks/heic-to-png.rb"

mkdir -p "$(dirname "$cask_path")"

cat > "$cask_path" <<RUBY
cask "heic-to-png" do
  version "${version}"
  sha256 "${sha256}"

  url "${download_url}",
      verified: "${verified_url}"
  name "HEIC to PNG"
  desc "Native HEIC and HEIF to PNG converter for macOS"
  homepage "${repository_url}"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :ventura"

  app "HEICToPNG.app"
  artifact "Convert HEIC to PNG.workflow",
           target: "#{Dir.home}/Library/Services/Convert HEIC to PNG.workflow"

  postflight do
    system_command "/System/Library/CoreServices/pbs",
                   args: ["-flush"],
                   sudo: false
  end

  caveats do
    <<~EOS
      The Homebrew cask installs the no-cost Finder Quick Action:
      Finder > right-click a HEIC/HEIF file > Quick Actions > Convert HEIC to PNG

      If Finder was already open and the action is not visible yet, relaunch Finder.

      This no-cost build is not notarized. If macOS blocks first launch,
      Control-click the app in Finder and choose Open.
    EOS
  end

  zap trash: [
    "~/Library/Containers/com.lcsvcn.HEICToPNG.mac",
    "~/Library/Preferences/com.lcsvcn.HEICToPNG.mac.plist",
    "~/Library/Services/Convert HEIC to PNG.workflow",
  ]
end
RUBY
