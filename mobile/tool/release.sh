#!/usr/bin/env bash
# Publishes a new Android version that installed apps will offer to update to.
#
#   ./tool/release.sh 1.2.0 "Easier skills entry, new update button"
#
# 1. Sets the version in pubspec.yaml (1.2.0, build number +1).
# 2. Builds the signed release APK against the live server.
# 3. Creates GitHub release v1.2.0 with CrewMatch.apk attached. Apps compare
#    their own version with this release and show "New version available".
# 4. Also replaces the APK on the v1.0 release, so the poster's QR code and
#    old links always download the newest app.
set -euo pipefail

VERSION="${1:?Usage: tool/release.sh 1.2.0 \"notes\"}"
NOTES="${2:-Bug fixes and improvements}"
API_URL="${API_URL:-https://crewmatch.onrender.com/api}"
cd "$(dirname "$0")/.."

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Version must look like 1.2.0" >&2; exit 1
fi
if gh release view "v$VERSION" >/dev/null 2>&1; then
  echo "Release v$VERSION already exists. Pick a higher version." >&2; exit 1
fi

BUILD=$(( $(sed -nE 's/^version: [0-9.]+\+([0-9]+)$/\1/p' pubspec.yaml) + 1 ))
sed -i '' -E "s/^version: .*/version: $VERSION+$BUILD/" pubspec.yaml
echo "Version $VERSION (build $BUILD)"

flutter build apk --release --dart-define=API_URL="$API_URL"
OUT="$(mktemp -d)/CrewMatch.apk"
cp build/app/outputs/flutter-apk/app-release.apk "$OUT"

gh release create "v$VERSION" "$OUT" --title "CrewMatch $VERSION" --notes "$NOTES" --latest
cp "$OUT" "$(dirname "$OUT")/CrewMatch-v1.0.apk"
gh release upload v1.0 "$(dirname "$OUT")/CrewMatch-v1.0.apk" --clobber

echo "Released v$VERSION. Commit pubspec.yaml so the next release counts up from here."
