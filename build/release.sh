#!/bin/bash
# Sign "dist/HomeCrafter Plus.app" with Developer ID (hardened runtime), notarize,
# staple, and wrap it in a signed + notarized + stapled .dmg.
#
#   build/build-app.sh && build/release.sh        full release
#   SIGN_ONLY=1 build/release.sh                  sign only, for local testing
#
# Adapted from SimPE-Mac-Wine/sign-and-notarize.sh. Entitlements: Wine needs
# JIT/unsigned executable memory, its own unsigned-by-Apple libraries, and the
# DYLD_FALLBACK_LIBRARY_PATH the launcher sets. No audio-input entitlement on
# purpose: HCP's audio init opens capture devices, and without the entitlement
# macOS denies the microphone silently instead of prompting.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/HomeCrafter Plus.app"
SIGN_ID="${SIGN_ID:-Developer ID Application: Catherine Gramze (AJHGU52KS3)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-clean-installer}"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="$ROOT/dist/HomeCrafter-Plus-$VERSION.dmg"
ENT="$ROOT/build/entitlements.plist"

[ -d "$APP" ] || { echo "Build first: build/build-app.sh" >&2; exit 1; }

cat > "$ENT" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.cs.allow-jit</key><true/>
  <key>com.apple.security.cs.allow-unsigned-executable-memory</key><true/>
  <key>com.apple.security.cs.disable-executable-page-protection</key><true/>
  <key>com.apple.security.cs.disable-library-validation</key><true/>
  <key>com.apple.security.cs.allow-dyld-environment-variables</key><true/>
  <key>com.apple.security.automation.apple-events</key><true/>
</dict>
</plist>
EOF

FLAGS=(--force --timestamp --options runtime --sign "$SIGN_ID" --entitlements "$ENT")
sign() {
  local a
  for a in 1 2 3 4 5; do
    codesign "${FLAGS[@]}" "$1" 2>&1 && return 0
    echo "    codesign failed ($a/5), retrying in $((a * 5))s"; sleep $((a * 5))
  done
  return 1
}

echo "==> Stripping extended attributes"
xattr -cr "$APP"

echo "==> Signing Mach-O files, deepest first (takes a few minutes)"
LIST="$(mktemp)"; trap 'rm -f "$LIST"' EXIT
find "$APP/Contents" -type f ! -path "*/_CodeSignature/*" ! -path "*/Resources/hcp/*" -print0 |
while IFS= read -r -d '' f; do
  if file -h "$f" | grep -q "Mach-O"; then
    printf '%s\t%s\n' "$(awk -F/ '{print NF}' <<< "$f")" "$f"
  fi
done | sort -rn | cut -f2- > "$LIST"
echo "    $(wc -l < "$LIST" | tr -d ' ') files"
while IFS= read -r f; do sign "$f" >/dev/null; done < "$LIST"

echo "==> Signing nested frameworks"
find "$APP/Contents/Frameworks" -type d -name "*.framework" | while IFS= read -r b; do sign "$b"; done

echo "==> Signing the app"
sign "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

if [ "${SIGN_ONLY:-0}" = 1 ]; then echo "==> SIGN_ONLY: done"; exit 0; fi

echo "==> Notarizing the app"
ZIP="$ROOT/dist/notary-upload.zip"; rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
rm -f "$ZIP"
xcrun stapler staple "$APP"

echo "==> Building $DMG"
rm -f "$DMG"
STAGE="$(mktemp -d)"; trap 'rm -f "$LIST"; rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/HomeCrafter Plus.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "HomeCrafter Plus" -srcfolder "$STAGE" -fs HFS+ -format UDZO "$DMG"
codesign --force --timestamp --sign "$SIGN_ID" "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl --assess --type open --context context:primary-signature -v "$DMG"

echo "==> Done: $DMG"
