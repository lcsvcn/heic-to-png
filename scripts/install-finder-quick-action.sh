#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_workflow="$repo_root/QuickActions/Convert HEIC to PNG.workflow"
services_dir="$HOME/Library/Services"
target_workflow="$services_dir/Convert HEIC to PNG.workflow"
lsregister="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

if [[ ! -d "$source_workflow" ]]; then
  echo "Missing workflow package: $source_workflow" >&2
  exit 66
fi

mkdir -p "$services_dir"
rm -rf "$target_workflow"
ditto "$source_workflow" "$target_workflow"

"$lsregister" -f "$target_workflow" >/dev/null 2>&1 || true
/System/Library/CoreServices/pbs -flush >/dev/null 2>&1 || true

echo "Installed Finder Quick Action: $target_workflow"
