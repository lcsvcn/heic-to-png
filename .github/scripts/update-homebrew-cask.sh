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

  depends_on macos: ">= :ventura"

  app "HEICToPNG.app"

  caveats do
    <<~EOS
      Launch HEIC to PNG once, then enable the Finder Quick Action:
      System Settings > Privacy & Security > Extensions > Finder > Convert HEIC to PNG
    EOS
  end

  zap trash: [
    "~/Library/Containers/com.lcsvcn.HEICToPNG.mac",
    "~/Library/Preferences/com.lcsvcn.HEICToPNG.mac.plist",
  ]
end
RUBY

