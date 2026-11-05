#!/bin/zsh
# Portable-mode test launcher: mimics what the .app launcher will do.
# vendor/ stands in for the read-only app bundle; nothing in it is modified.
HERE="${0:A:h}"
SIMPE=/Applications/SimPE.app/Contents
WINE="$SIMPE/SharedSupport/wine/bin/wine"
BUNDLE="$HERE/vendor/Portable_TS2HomeCrafterPlus"         # read-only payload
STAGE="$HOME/Library/Application Support/HomeCrafter Plus" # writable working copy
# HCP shares the game's own user folder, as it does with EA Games/The Sims 2 on Windows
USERDIR="$HOME/Library/Containers/com.aspyr.sims2.appstore/Data/Library/Application Support/Aspyr/The Sims 2"
[[ -d "$USERDIR" ]] || { echo "Sims 2 user folder not found: $USERDIR"; exit 1; }

# --- stage the writable program folder ---
mkdir -p "$STAGE/HCBin/UserData"
cp -p "$BUNDLE/HCBin/Portable_TS2HomeCrafterPlus.exe" "$STAGE/HCBin/"
cp -p "$BUNDLE/HCBin/portable_disabled.ini" "$STAGE/HCBin/portable.ini"   # presence = portable mode
ln -sfn "$BUNDLE/HCBin/Game" "$STAGE/HCBin/Game"
ln -sfn "$BUNDLE/HCData" "$STAGE/HCData"
# HCP's "The Sims 2" is a real folder holding only links to the game's Projects and Downloads.
# Linking the whole game folder let HCP scan & rewrite Neighborhoods packages (trimmed padding).
# Its own Config/Logs/Groups.cache stay here so it can't overwrite the game's.
HCUSER="$STAGE/HCBin/UserData/The Sims 2"
[[ -L "$HCUSER" ]] && rm "$HCUSER"
mkdir -p "$HCUSER" "$USERDIR/Projects"
ln -sfn "$USERDIR/Projects"  "$HCUSER/Projects"
ln -sfn "$USERDIR/Downloads" "$HCUSER/Downloads"

# --- Wine environment (same as run-hcp.sh) ---
export WINEPREFIX="$HERE/prefix"
export DYLD_FALLBACK_LIBRARY_PATH="$SIMPE/Frameworks:$HERE/renderer"
export WINEDLLOVERRIDES="mscoree,mshtml=;ir50_32=d;d3d9=n"
export WINEDEBUG=-all
# Lag test: msync = fast in-process sync instead of wineserver round-trips
export WINEMSYNC=${WINEMSYNC:-1}
# Lag test: frame-rate counter in the corner (DXVK_HUD=0 to hide)
export DXVK_HUD=${DXVK_HUD:-fps}
export DXVK_CONFIG_FILE="$HERE/renderer/dxvk.conf"
export DXVK_LOG_LEVEL=none
cp -p "$HERE/renderer/d9vk-macOS-async-v1.10.3-20250511/x32/d3d9.dll" "$WINEPREFIX/drive_c/windows/syswow64/d3d9.dll"

cd "$STAGE/HCBin" || exit 1
exec "$WINE" Portable_TS2HomeCrafterPlus.exe -w -r1280x800
