#!/usr/bin/env bash
set -euo pipefail

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export MAESTRO_CLI_NO_ANALYTICS="${MAESTRO_CLI_NO_ANALYTICS:-true}"
export MAESTRO_CLI_ANALYSIS_NOTIFICATION_DISABLED="${MAESTRO_CLI_ANALYSIS_NOTIFICATION_DISABLED:-true}"

if [[ -z "${JAVA_HOME:-}" && -d "/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home" ]]; then
  export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
  export PATH="$JAVA_HOME/bin:$PATH"
fi
export PATH="$HOME/.maestro/bin:$PATH"

app_id="${IOS_BUNDLE_ID:-com.lcsvcn.HEICToPNG.iOS}"
app_path="${IOS_APP_PATH:-$PWD/.build/DerivedData-iOS/Build/Products/Debug-iphonesimulator/HEICToPNGiOS.app}"
preferred_simulator="${IOS_SIMULATOR:-iPhone 16}"
report_path="${MAESTRO_REPORT_PATH:-$PWD/.build/maestro/report.xml}"

if ! command -v maestro >/dev/null 2>&1; then
  echo "Maestro is not installed. Run scripts/install-maestro.sh first." >&2
  exit 127
fi

if [[ ! -d "$app_path" ]]; then
  echo "iOS simulator app was not found at: $app_path" >&2
  exit 66
fi

if ! xcrun simctl list devices booted | grep -q "Booted"; then
  if ! xcrun simctl boot "$preferred_simulator" >/dev/null 2>&1; then
    fallback_udid="$(
      xcrun simctl list devices available |
        sed -nE '/iPhone .* \([A-F0-9-]{36}\) \((Shutdown|Booted)\)/ {
          s/.*\(([A-F0-9-]{36})\).*/\1/p
          q
        }'
    )"

    if [[ -z "$fallback_udid" ]]; then
      echo "No available iPhone simulator was found." >&2
      xcrun simctl list devices available >&2
      exit 69
    fi

    xcrun simctl boot "$fallback_udid"
  fi
fi

xcrun simctl bootstatus booted -b
xcrun simctl install booted "$app_path"

mkdir -p "$(dirname "$report_path")"
maestro --platform=ios test \
  --env APP_ID="$app_id" \
  --config .maestro/config.yaml \
  --output "$report_path" \
  .maestro/ios-smoke.yaml
