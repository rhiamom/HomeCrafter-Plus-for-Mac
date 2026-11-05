#!/bin/zsh
# HomeCrafter Plus for Mac — runtime launcher (Contents/Resources/launch.sh).
#
# Runs oduska's Portable TS2 HomeCrafter Plus under the bundled Wine. The signed
# app is never written to: everything that changes lives in
#   ~/Library/Application Support/HomeCrafter Plus/
#     prefix/         Wine's Windows folders (disposable; rebuilt if deleted)
#     HCBin/          writable copy of the program folder:
#       Portable_TS2HomeCrafterPlus.exe   copied from the app
#       portable.ini                      presence = oduska's portable mode
#       Game -> app's read-only game files
#       UserData/The Sims 2/              HCP's own Config, Logs, Groups.cache
#         Projects  -> <Sims 2 folder>/Projects
#         Downloads -> <Sims 2 folder>/Downloads
#     HCData -> app's read-only HCData
#     game-folder.txt   the Sims 2 user folder, if the user picked one
#
# Only Projects and Downloads are linked: given the whole Sims 2 folder, HCP
# scans and rewrites neighborhood packages at startup.

C="${0:A:h:h}"                                  # .../Contents
RES="$C/Resources"
HCP="$RES/hcp"                                  # read-only payload
SUP="$HOME/Library/Application Support/HomeCrafter Plus"
EXE=Portable_TS2HomeCrafterPlus.exe
LOG="$SUP/launch.log"

mkdir -p "$SUP"
exec >"$LOG" 2>&1
echo "HomeCrafter Plus launch $(date)"

alert() {
  /usr/bin/osascript -e 'on run argv' \
    -e 'display alert "HomeCrafter Plus" message (item 1 of argv) as critical' \
    -e 'end run' "$1" >/dev/null 2>&1
}

# --- already running? --------------------------------------------------------
if /usr/bin/pgrep -f "$EXE" >/dev/null; then
  echo "already running"; exit 0
fi

# --- find the Sims 2 user folder --------------------------------------------
ASPYR="$HOME/Library/Containers/com.aspyr.sims2.appstore/Data/Library/Application Support/Aspyr/The Sims 2"
GAME=""
[[ -f "$SUP/game-folder.txt" ]] && GAME="$(<"$SUP/game-folder.txt")"
[[ -n "$GAME" && -d "$GAME/Downloads" ]] || GAME=""
[[ -z "$GAME" && -d "$ASPYR" ]] && GAME="$ASPYR"
if [[ -z "$GAME" ]]; then
  GAME="$(/usr/bin/osascript \
    -e 'set f to choose folder with prompt "HomeCrafter Plus could not find your Sims 2 folder. Please choose it (the folder that holds Downloads, Neighborhoods and Projects)."' \
    -e 'POSIX path of f' 2>/dev/null)"
  GAME="${GAME%/}"
  [[ -n "$GAME" ]] || { echo "no game folder chosen"; exit 0; }
  if [[ ! -d "$GAME/Downloads" ]]; then
    alert "That folder has no Downloads folder inside it, so it does not look like the Sims 2 folder. Please open HomeCrafter Plus again and choose the right folder."
    exit 1
  fi
  print -r -- "$GAME" >"$SUP/game-folder.txt"
fi
echo "Sims 2 folder: $GAME"

# --- stage the writable program folder ---------------------------------------
ST="$SUP/HCBin"
HCUSER="$ST/UserData/The Sims 2"
mkdir -p "$HCUSER" "$GAME/Projects"
cp -p "$HCP/HCBin/$EXE" "$ST/$EXE"
: >"$ST/portable.ini"
ln -sfn "$HCP/HCBin/Game" "$ST/Game"
ln -sfn "$HCP/HCData" "$SUP/HCData"
[[ -L "$HCUSER" ]] && rm "$HCUSER" && mkdir -p "$HCUSER"
ln -sfn "$GAME/Projects"  "$HCUSER/Projects"
ln -sfn "$GAME/Downloads" "$HCUSER/Downloads"
# seed the graphics cache once; DXVK keeps it up to date next to the exe after that
[[ -f "$ST/${EXE:r}.dxvk-cache" || ! -f "$RES/${EXE:r}.dxvk-cache" ]] || \
  cp -p "$RES/${EXE:r}.dxvk-cache" "$ST/"

# --- Wine environment ----------------------------------------------------------
WINE="$C/SharedSupport/wine/bin/wine"
export WINEPREFIX="$SUP/prefix"
export DYLD_FALLBACK_LIBRARY_PATH="$C/Frameworks:/usr/lib"
# mscoree/mshtml: no Wine Mono/Gecko (not shipped, not needed)
# ir50_32: Indeo codec probe aborts without winegstreamer
# d3d9=n: d9vk (DXVK) instead of wined3d, which can't give the 1024 VS constants HCP needs
export WINEDLLOVERRIDES="mscoree,mshtml=;ir50_32=d;d3d9=n"
export WINEDEBUG=-all
export WINEMSYNC=1
# dxvk.conf reports a GeForce 6800 so Graphics Rules picks hardware vertex processing
export DXVK_CONFIG_FILE="$RES/dxvk.conf"
export DXVK_LOG_LEVEL=none
export MVK_CONFIG_LOG_LEVEL=0

if [[ ! -f "$WINEPREFIX/system.reg" ]]; then
  echo "creating Wine prefix"
  "$WINE" wineboot --init
  "$C/SharedSupport/wine/bin/wineserver" -w
fi
cp -p "$RES/d3d9.dll" "$WINEPREFIX/drive_c/windows/syswow64/d3d9.dll"

cd "$ST" || { alert "Could not open $ST"; exit 1; }
echo "starting $EXE"
"$WINE" "$EXE" -w -r1280x800
echo "exited with $?"
