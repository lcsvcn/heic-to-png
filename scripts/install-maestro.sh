#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${JAVA_HOME:-}" && -d "/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home" ]]; then
  export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
  export PATH="$JAVA_HOME/bin:$PATH"
fi

export PATH="$HOME/.maestro/bin:$PATH"
export MAESTRO_CLI_NO_ANALYTICS="${MAESTRO_CLI_NO_ANALYTICS:-true}"
export MAESTRO_CLI_ANALYSIS_NOTIFICATION_DISABLED="${MAESTRO_CLI_ANALYSIS_NOTIFICATION_DISABLED:-true}"

if command -v maestro >/dev/null 2>&1; then
  maestro --version
  exit 0
fi

export MAESTRO_VERSION="${MAESTRO_VERSION:-2.4.0}"
curl -Ls "https://get.maestro.mobile.dev" | bash

maestro --version

if [[ -n "${GITHUB_PATH:-}" ]]; then
  echo "$HOME/.maestro/bin" >> "$GITHUB_PATH"
fi
