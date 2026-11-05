# HomeCrafter Plus for Mac

*The Sims 2 HomeCrafter Plus* (EA/Maxis's wall, floor and terrain-paint tool) as a
normal Mac app. It wraps **oduska's Portable TS2 HomeCrafter Plus**
([MTS 2322998](https://modthesims.info/d/2322998), used with oduska's permission) in a
bundled copy of Wine. No Sims 2 install inside Wine, no Wine setup by the user.

- Works with the Aspyr **Sims 2 Super Collection**. Other Sims 2 folders can be
  chosen on first launch if the Super Collection isn't found.
- Projects go in the game's own `Projects/HomeCrafter Plus/` (textures for GIMP
  go in `Working Directory`); **Import to Game** writes straight into the game's
  `Downloads`.
- Apple Silicon (through Rosetta) and Intel, macOS 10.15+. Signed and notarized.

## How it works

oduska's portable build was patched to read the game files it needs from
`HCBin/Game/TSData` and, when `portable.ini` exists, to keep all user data in
`HCBin/UserData/The Sims 2/` next to the exe. That makes every path something
the wrapper controls.

The signed app is never written to. On each launch `launcher/launch.sh` sets up
`~/Library/Application Support/HomeCrafter Plus/`:

| Path | What it is |
|---|---|
| `prefix/` | Wine's Windows folders. Disposable; recreated if deleted. |
| `HCBin/Portable_TS2HomeCrafterPlus.exe` | Copied from the app on each launch. |
| `HCBin/portable.ini` | Turns on portable mode. |
| `HCBin/Game`, `HCData` | Links to the read-only game files inside the app. |
| `HCBin/UserData/The Sims 2/` | HCP's own Config, Logs, Groups.cache, plus two links: `Projects` and `Downloads` → the game's folders. |
| `game-folder.txt` | Only if the user picked a Sims 2 folder by hand. |
| `launch.log` | Output of the last launch. |

**Only Projects and Downloads are linked, never the whole Sims 2 folder.** Given
the whole folder, HCP scans it at startup and rewrites every neighborhood and
character package (it trims the trailing zero padding the Mac game writes).

### Graphics and Wine settings

- **d9vk** (DXVK for D3D9, `Sikarugir-App/d9vk` macOS async build) + **MoltenVK**.
  Wine's own wined3d fails: HCP sets 1024 vertex-shader constants, wined3d allows 256.
- `dxvk.conf` reports an **NVIDIA GeForce 6800**. With the real vendor ("Apple")
  Graphics Rules falls back to software vertex processing, which DXVK can't do on
  Metal, and the window stays black.
- `d3d9.maxFrameLatency = 1` and `WINEMSYNC=1` make clicks respond faster.
- `ir50_32=d`: the Indeo codec probe aborts without winegstreamer (not shipped).
- No microphone entitlement: HCP's audio start-up opens input devices, and the
  hardened runtime then refuses the microphone without prompting.
- Startup is slow: after the window appears HCP keeps loading (it reads all of
  Downloads), and clicks lag until that finishes. It's HCP's own single-threaded
  code under Rosetta; not shader compiling.

## Building

Inputs not in git:

- `vendor/Portable_TS2HomeCrafterPlus/`: oduska's portable build, unpacked.
- `renderer/d9vk-macOS-async-v1.10.3-20250511/` and `renderer/libMoltenVK.dylib`
  (MoltenVK from Sikarugir Template-1.0.11), optionally
  `renderer/Portable_TS2HomeCrafterPlus.dxvk-cache` as a starter graphics cache.
- A Sikarugir wrapper with the **WS12WineSikarugir10.0_6** engine; by default
  `/Applications/SimPE.app` (set `WINE_APP` to use another). Its `SharedSupport/wine`
  and `Frameworks` are copied in.

```sh
build/build-app.sh                 # -> dist/HomeCrafter Plus.app (unsigned)
SIGN_ONLY=1 build/release.sh       # sign for local testing
build/release.sh                   # sign, notarize, staple, make the .dmg
```

`run-hcp-portable.sh` is a dev launcher that runs the same setup straight from
`vendor/` (with an FPS counter) without building the app.

## Credits

The Sims 2 HomeCrafter Plus © Electronic Arts / Maxis. Portable build by
**oduska** (<https://oduska.com>). Mac wrapper by **Rhiamom**.
