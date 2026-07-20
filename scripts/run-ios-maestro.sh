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
debug_output="${MAESTRO_DEBUG_OUTPUT:-$PWD/.build/maestro/debug}"
boot_timeout="${IOS_SIMULATOR_BOOT_TIMEOUT_SECONDS:-180}"
install_timeout="${IOS_SIMULATOR_INSTALL_TIMEOUT_SECONDS:-120}"
maestro_timeout="${MAESTRO_TEST_TIMEOUT_SECONDS:-240}"

run_with_timeout() {
  local timeout_seconds="$1"
  shift

  "$@" &
  local command_pid="$!"
  local started_at="$SECONDS"

  while kill -0 "$command_pid" >/dev/null 2>&1; do
    if (( SECONDS - started_at >= timeout_seconds )); then
      echo "Timed out after ${timeout_seconds}s: $*" >&2
      kill "$command_pid" >/dev/null 2>&1 || true
      sleep 2
      kill -9 "$command_pid" >/dev/null 2>&1 || true
      wait "$command_pid" 2>/dev/null || true
      return 124
    fi

    sleep 2
  done

  wait "$command_pid"
}

select_simulator_udid() {
  local preferred_name="$1"
  local escaped_preferred
  escaped_preferred="$(printf '%s' "$preferred_name" | sed 's/[][\\.^$*+?{}|()]/\\&/g')"

  xcrun simctl list devices available |
    sed -nE "/^[[:space:]]*${escaped_preferred} \\([A-F0-9-]{36}\\) \\((Shutdown|Booted)\\)[[:space:]]*$/ {
      s/.*\\(([A-F0-9-]{36})\\).*/\\1/p
      q
    }"
}

select_first_iphone_udid() {
  xcrun simctl list devices available |
    sed -nE '/^[[:space:]]*iPhone .* \([A-F0-9-]{36}\) \((Shutdown|Booted)\)[[:space:]]*$/ {
      s/.*\(([A-F0-9-]{36})\).*/\1/p
      q
    }'
}

if ! command -v maestro >/dev/null 2>&1; then
  echo "Maestro is not installed. Run scripts/install-maestro.sh first." >&2
  exit 127
fi

if [[ ! -d "$app_path" ]]; then
  echo "iOS simulator app was not found at: $app_path" >&2
  exit 66
fi

if [[ "${CI:-false}" == "true" ]]; then
  echo "Resetting previously booted simulators for CI."
  xcrun simctl shutdown all >/dev/null 2>&1 || true
fi

simulator_udid="${IOS_SIMULATOR_UDID:-}"

if [[ -z "$simulator_udid" ]]; then
  simulator_udid="$(select_simulator_udid "$preferred_simulator")"
fi

if [[ -z "$simulator_udid" ]]; then
  echo "Preferred simulator '$preferred_simulator' was not found. Falling back to the first available iPhone simulator."
  simulator_udid="$(select_first_iphone_udid)"
fi

if [[ -z "$simulator_udid" ]]; then
  echo "No available iPhone simulator was found." >&2
  xcrun simctl list devices available >&2
  exit 69
fi

echo "Using iOS simulator: $simulator_udid"

if [[ "${CI:-false}" == "true" ]]; then
  echo "Erasing simulator for a clean CI run."
  xcrun simctl erase "$simulator_udid" >/dev/null 2>&1 || true
fi

if ! xcrun simctl list devices booted | grep -q "$simulator_udid"; then
  echo "Booting iOS simulator."
  run_with_timeout "$boot_timeout" xcrun simctl boot "$simulator_udid"
fi

echo "Waiting for iOS simulator to finish booting."
run_with_timeout "$boot_timeout" xcrun simctl bootstatus "$simulator_udid" -b

echo "Installing iOS simulator app."
run_with_timeout "$install_timeout" xcrun simctl install "$simulator_udid" "$app_path"

mkdir -p "$(dirname "$report_path")" "$debug_output"
echo "Running Maestro iOS smoke flow."
run_with_timeout "$maestro_timeout" maestro --device "$simulator_udid" --platform=ios test \
  --env APP_ID="$app_id" \
  --config .maestro/config.yaml \
  --debug-output "$debug_output" \
  --output "$report_path" \
  .maestro/ios-smoke.yaml
