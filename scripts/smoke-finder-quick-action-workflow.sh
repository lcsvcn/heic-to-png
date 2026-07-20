#!/usr/bin/env bash
set -euo pipefail

workflow="QuickActions/Convert HEIC to PNG.workflow"
info_plist="$workflow/Contents/Info.plist"
document="$workflow/Contents/Resources/document.wflow"
version_plist="$workflow/Contents/version.plist"

plutil -lint "$info_plist" "$document" "$version_plist" >/dev/null

bundle_id="$(plutil -extract CFBundleIdentifier raw -o - "$info_plist")"
menu_title="$(plutil -extract NSServices.0.NSMenuItem.default raw -o - "$info_plist")"
message="$(plutil -extract NSServices.0.NSMessage raw -o - "$info_plist")"
workflow_type="$(plutil -extract workflowMetaData.workflowTypeIdentifier raw -o - "$document")"
input_method="$(plutil -extract actions.0.action.ActionParameters.inputMethod raw -o - "$document")"
shell="$(plutil -extract actions.0.action.ActionParameters.shell raw -o - "$document")"

test "$bundle_id" = "com.lcsvcn.HEICToPNG.quickaction.workflow"
test "$menu_title" = "Convert HEIC to PNG"
test "$message" = "runWorkflowAsService"
test "$workflow_type" = "com.apple.Automator.servicesMenu"
test "$input_method" = "1"
test "$shell" = "/bin/zsh"

script_file="$(mktemp "${TMPDIR:-/tmp}/heic-to-png-workflow.XXXXXX.zsh")"
trap 'rm -f "$script_file"' EXIT
plutil -extract actions.0.action.ActionParameters.COMMAND_STRING raw -o "$script_file" "$document"
/bin/zsh -n "$script_file"

echo "Finder Quick Action workflow smoke check passed"
