#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

if [[ -z "${DEVELOPER_DIR:-}" ]]; then
  SELECTED="$(xcode-select -p 2>/dev/null || true)"
  if [[ "$SELECTED" == *"/Xcode"* ]]; then
    export DEVELOPER_DIR="$SELECTED"
  else
    for CANDIDATE in /Applications/Xcode*.app; do
      [[ -d "$CANDIDATE/Contents/Developer" ]] || continue
      export DEVELOPER_DIR="$CANDIDATE/Contents/Developer"
    done
  fi
fi

if [[ -z "${DEVELOPER_DIR:-}" || ! -d "$DEVELOPER_DIR" ]]; then
  printf 'Xcode introuvable. Installe Xcode 26 ou plus récent, puis relance.\n' >&2
  exit 1
fi

SCHEME="${SCHEME:-MineMaster}"
DESTINATION="${DESTINATION:-generic/platform=iOS Simulator}"
DERIVED_DATA="${DERIVED_DATA:-/tmp/minemaster-agent-derived}"

printf 'Racine      : %s\n' "$ROOT"
printf 'Xcode       : %s\n' "$DEVELOPER_DIR"
printf 'Destination : %s\n' "$DESTINATION"
printf 'DerivedData : %s\n' "$DERIVED_DATA"

xcodebuild -version
xcodebuild -resolvePackageDependencies \
  -project MineMaster.xcodeproj \
  -scheme "$SCHEME" \
  -derivedDataPath "$DERIVED_DATA"

xcodebuild \
  -project MineMaster.xcodeproj \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA" \
  build

printf 'Build terminé : %s/Build/Products/Debug-iphonesimulator/%s.app\n' \
  "$DERIVED_DATA" "$SCHEME"
