# Building a Release (Milestone E)

## One command

```sh
tools/export_all.sh            # Linux, Windows and macOS into build/ (git-ignored)
tools/export_all.sh linux      # just one
```

The script reimports, exports each preset in `export_presets.cfg`, fails on any export error,
and on Linux then runs the Linux build headlessly for ten seconds, failing if it logs an error.

## What's needed

- Godot **4.7**: `godot` on `PATH`, or point the script at it with `GODOT=`. On a Mac that's the
  binary inside the app: `GODOT=~/Downloads/Godot.app/Contents/MacOS/Godot tools/export_all.sh macos`.
- The 4.7 export templates. Easiest: in the Godot editor, Editor > Manage Export Templates >
  Download and Install. By hand: download `Godot_v4.7-stable_export_templates.tpz` from the
  4.7-stable release on GitHub (it's a zip) and put its `templates/` folder at
  `~/.local/share/godot/export_templates/4.7.stable/` (Linux) or
  `~/Library/Application Support/Godot/export_templates/4.7.stable/` (macOS).

The script runs on macOS's own bash 3.2 as well as Linux. It only smoke-runs the Linux build
when it's on Linux.

## The presets

| Preset | Output | Notes |
|---|---|---|
| Linux | `build/linux/WastelandHarvest.x86_64` + `.pck` | x86_64 |
| Windows Desktop | `build/windows/WastelandHarvest.exe` + `.pck` | x86_64, icon `art/ui/app_icon/icon.ico`, version 0.9.0.0 |
| macOS | `build/macos/WastelandHarvest.zip` | Universal (Intel + Apple Silicon). **Ad-hoc signed** by `tools/export_all.sh` after export (Apple's `codesign` on a Mac, `rcodesign` elsewhere), not notarised. See "Mac signing" below. |

All three leave out `tools/`, `tests/`, `graphify-out/` and the art preview sheets; the game
never loads anything from them. Apple Silicon builds need ETC2/ASTC texture import, which is
switched on in `project.godot` (`rendering/textures/vram_compression/import_etc2_astc`).

The app icon is drawn by `tools/art/app_icon/build.py`: a seedling in front of a ruined
skyline at dusk. It writes 32/256/512 px PNGs, a multi-size `.ico` and the project's
`icon.png`.

## Playtesting on a Mac

- **From source (no export needed):** `GODOT_BIN=~/Downloads/Godot.app/Contents/MacOS/Godot`,
  then `"$GODOT_BIN" --path .` from the repo root runs the game. Without `-e` it opens the game,
  not the editor. The first run imports the assets for about a minute.
- **As an app:** `GODOT=... tools/export_all.sh macos`, unzip `build/macos/WastelandHarvest.zip`,
  and move `Wasteland Harvest.app` to Applications. It isn't notarised, so a copy that was
  downloaded is stopped once ("Apple could not verify…", with only Done or Move to Trash). Clear
  the download flag and re-sign it locally with Apple's own tool, both built into macOS:
  `xattr -dr com.apple.quarantine "/Applications/Wasteland Harvest.app"` then
  `codesign --force --deep --sign - "/Applications/Wasteland Harvest.app"`. (Or System Settings >
  Privacy & Security > Open Anyway after the first attempt. Right-click > Open no longer
  bypasses this on macOS 15.)
- **Saves, settings and logs** live in `~/Library/Application Support/Godot/app_userdata/Wasteland Harvest/`
  (`slot_*.json`, `settings.cfg`, `logs/godot.log`), shared by both ways of running. Older
  saves load into newer builds.

## Mac signing

The macOS preset exports **unsigned** (`codesign/codesign=0`), and `tools/export_all.sh` signs
the app afterwards. Godot 4.7's built-in ad-hoc signer (`codesign/codesign=1`) writes a DER
entitlements blob that doesn't parse (`rcodesign print-signature-info` fails on it), and macOS
checks that blob at launch, so its builds wouldn't open. The script signs with Apple's
`codesign --force --deep --sign -` on a Mac, or with `rcodesign sign` (ad-hoc when given no
certificate) on Linux. Install rcodesign with `cargo install apple-codesign` and point
`RCODESIGN=` at it. Without either, the macOS export stops with an error. A store release still
needs a real Developer ID signature and notarisation (below).

## Before a store upload (Steam / itch.io)

- Sign and notarise the macOS build; sign the Windows exe if a certificate is available.
- Bump `application/file_version` / `product_version` (Windows) and `application/version`
  (macOS) in `export_presets.cfg`.
- itch.io: upload each `build/<platform>/` folder (or the macOS zip) with butler, one channel
  per platform. Steam: one depot per platform, with the launch executable set to the binary
  above.
