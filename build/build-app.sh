#!/bin/zsh
# Assemble "dist/HomeCrafter Plus.app" (unsigned). Then run build/release.sh.
#
# Inputs (none of the big ones are in git):
#   vendor/Portable_TS2HomeCrafterPlus/   oduska's portable HCP (MTS 2322998), used with permission
#   renderer/d9vk-macOS-async-*/x32/d3d9.dll, renderer/libMoltenVK.dylib, renderer/dxvk.conf
#   $WINE_APP  a Sikarugir wrapper with WS12WineSikarugir10.0_6; default /Applications/SimPE.app
#              (its SharedSupport/wine + Frameworks are what HCP was tested on)
set -e
ROOT="${0:A:h:h}"
VERSION="${VERSION:-1.0.0}"
WINE_APP="${WINE_APP:-/Applications/SimPE.app}"
NAME="HomeCrafter Plus"
APP="$ROOT/dist/$NAME.app"
C="$APP/Contents"
VENDOR="$ROOT/vendor/Portable_TS2HomeCrafterPlus"
D9VK="$(print -r -- $ROOT/renderer/d9vk-macOS-async-*/x32/d3d9.dll(N[1]))"

for f in "$VENDOR/HCBin/Portable_TS2HomeCrafterPlus.exe" "$D9VK" "$ROOT/renderer/libMoltenVK.dylib" \
         "$ROOT/renderer/dxvk.conf" "$WINE_APP/Contents/SharedSupport/wine/bin/wine"; do
  [[ -e "$f" ]] || { echo "missing: $f" >&2; exit 1; }
done

echo "==> Fresh bundle at $APP"
rm -rf "$APP"
mkdir -p "$C/MacOS" "$C/Resources/hcp" "$C/SharedSupport" "$C/Frameworks"

echo "==> Launcher (universal)"
clang -O2 -arch arm64 -arch x86_64 -mmacosx-version-min=10.15 \
  -o "$C/MacOS/$NAME" "$ROOT/launcher/main.c"
cp "$ROOT/launcher/launch.sh" "$C/Resources/launch.sh"
chmod 755 "$C/Resources/launch.sh"

echo "==> Wine engine + libraries from $WINE_APP"
ditto "$WINE_APP/Contents/SharedSupport/wine" "$C/SharedSupport/wine"
ditto "$WINE_APP/Contents/Frameworks" "$C/Frameworks"
cp "$ROOT/renderer/libMoltenVK.dylib" "$C/Frameworks/"

echo "==> Renderer (d9vk) + config"
cp "$D9VK" "$C/Resources/d3d9.dll"
grep -v '^#' "$ROOT/renderer/dxvk.conf" | grep -v '^\s*$' > "$C/Resources/dxvk.conf"

echo "==> HomeCrafter Plus (oduska portable)"
ditto "$VENDOR/HCBin/Game" "$C/Resources/hcp/HCBin/Game"
cp -p "$VENDOR/HCBin/Portable_TS2HomeCrafterPlus.exe" "$C/Resources/hcp/HCBin/"
ditto "$VENDOR/HCData" "$C/Resources/hcp/HCData"
ditto "$VENDOR/Support" "$C/Resources/hcp/Support"
cp -p "$VENDOR/Readme.txt" "$C/Resources/hcp/Readme-oduska.txt"
[[ -f "$ROOT/renderer/Portable_TS2HomeCrafterPlus.dxvk-cache" ]] && \
  cp -p "$ROOT/renderer/Portable_TS2HomeCrafterPlus.dxvk-cache" "$C/Resources/"
find "$APP" -name .DS_Store -delete

echo "==> Icon"
ICONSET="$(mktemp -d)/HomeCrafter.iconset"; mkdir -p "$ICONSET"
ICO="$ICONSET/../hcp.ico"; PNG="$ICONSET/../hcp.png"
if [[ -f "$ROOT/build/HomeCrafter.png" ]]; then PNG="$ROOT/build/HomeCrafter.png"
else
  python3 -I "$ROOT/build/extract-icon.py" "$VENDOR/HCBin/Portable_TS2HomeCrafterPlus.exe" "$ICO" >/dev/null
  sips -s format png "$ICO" --out "$PNG" >/dev/null
fi
for s in 16 32 128 256 512; do
  sips -z $s $s "$PNG" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) "$PNG" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$C/Resources/HomeCrafter.icns"

echo "==> Info.plist"
cat > "$C/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$NAME</string>
  <key>CFBundleDisplayName</key><string>$NAME</string>
  <key>CFBundleExecutable</key><string>$NAME</string>
  <key>CFBundleIdentifier</key><string>com.gramzesweatshop.homecrafterplus</string>
  <key>CFBundleIconFile</key><string>HomeCrafter</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>10.15</string>
  <key>LSUIElement</key><true/>
  <key>NSHumanReadableCopyright</key><string>The Sims 2 HomeCrafter Plus © EA/Maxis. Portable build by oduska. Mac wrapper by Rhiamom.</string>
</dict>
</plist>
EOF

echo "==> Done: $(du -sh "$APP" | cut -f1)  $APP"
