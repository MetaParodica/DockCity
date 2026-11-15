#!/usr/bin/env bash
# Run the native automated checks. Real Dock/TCC/input checks remain manual.
set -euo pipefail
if [[ "$(uname -s)" != Darwin ]]; then
  echo "Native verification requires a Mac GUI session with Xcode/Command Line Tools." >&2
  exit 1
fi
cd "$(dirname "$0")/.."
swift --version
swift build --jobs 4
swift test --jobs 4
swift test -c release --jobs 4
bash scripts/make-app.sh app release
codesign --verify --strict --verbose=2 'build/Dock City.app'
echo "Native automated checks passed. Follow docs/snow-validation.md for real window and permission checks."
