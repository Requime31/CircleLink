#!/bin/bash
# Runs SwiftLint during an Xcode build (warnings only — never fails the build).
set -euo pipefail

ROOT="${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
CONFIG="$ROOT/.swiftlint.yml"

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

if ! command -v swiftlint >/dev/null 2>&1; then
  echo "warning: SwiftLint is not installed. Install with: brew install swiftlint"
  exit 0
fi

if [[ ! -f "$CONFIG" ]]; then
  echo "warning: SwiftLint config not found at $CONFIG"
  exit 0
fi

CACHE_PATH="${SRCROOT:-$ROOT}/.swiftlint-cache"
mkdir -p "$CACHE_PATH"

# Soft mode: surface violations in the Issue Navigator, keep ⌘B green.
set +e
swiftlint lint --config "$CONFIG" --reporter xcode --cache-path "$CACHE_PATH"
status=$?
set -e

if [[ $status -ne 0 ]]; then
  echo "note: SwiftLint finished with exit code $status (non-blocking)"
fi

exit 0
