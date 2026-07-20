#!/usr/bin/env bash
set -euo pipefail

minimum="${1:-80}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$PWD/.build/module-cache}"

swift test --enable-code-coverage

coverage_json="$(swift test --show-codecov-path)"
build_dir="$(dirname "$(dirname "$coverage_json")")"
profile="$build_dir/codecov/default.profdata"
test_binary="$build_dir/HEICToPNGWorkspacePackageTests.xctest/Contents/MacOS/HEICToPNGWorkspacePackageTests"
report_dir="$PWD/.build/coverage"
report_path="$report_dir/coverage.txt"

mkdir -p "$report_dir"
cp "$coverage_json" "$report_dir/codecov.json"

xcrun llvm-cov report "$test_binary" \
  -instr-profile "$profile" \
  -ignore-filename-regex='Tests|runner.swift' | tee "$report_path"

line_coverage="$(
  awk '/^TOTAL/ {
    gsub("%", "", $10)
    print $10
  }' "$report_path"
)"

awk -v coverage="$line_coverage" -v minimum="$minimum" 'BEGIN {
  if (coverage + 0 < minimum + 0) {
    printf "Line coverage %.2f%% is below required %.2f%%\n", coverage, minimum
    exit 1
  }
  printf "Line coverage %.2f%% meets required %.2f%%\n", coverage, minimum
}'
