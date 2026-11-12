# Building a Release (Milestone E)

## One command

```sh
tools/export_all.sh            # Linux, Windows and macOS into build/ (git-ignored)
tools/export_all.sh linux      # just one
```

The script reimports, exports each preset in `export_presets.cfg`, fails on any export error,
and then runs the Linux build headlessly for ten seconds, failing if it logs an error.

## What's needed

- Godot **4.7** on `PATH` as `godot`.
- The 4.7 export templates, unpacked to `~/.local/share/godot/export_templates/4.7.stable/`.
  Download `Godot_v4.7-stable_export_templates.tpz` from the 4.7-stable release on GitHub; it's
  a zip, and its `templates/` folder is what goes there.

## The presets

| Preset | Output | Notes |
|---|---|---|
| Linux | `build/linux/WastelandHarvest.x86_64` + `.pck` | x86_64 |
| Windows Desktop | `build/windows/WastelandHarvest.exe` + `.pck` | x86_64, icon `art/ui/app_icon/icon.ico`, version 0.9.0.0 |
| macOS | `build/macos/WastelandHarvest.zip` | Universal (Intel + Apple Silicon). **Unsigned and un-notarised**, so Gatekeeper will warn until it's signed with an Apple Developer ID. |

All three leave out `tools/`, `tests/`, `graphify-out/` and the art preview sheets; the game
never loads anything from them. Apple Silicon builds need ETC2/ASTC texture import, which is
switched on in `project.godot` (`rendering/textures/vram_compression/import_etc2_astc`).

The app icon is drawn by `tools/art/app_icon/build.py`: a seedling in front of a ruined
skyline at dusk. It writes 32/256/512 px PNGs, a multi-size `.ico` and the project's
`icon.png`.

## Before a store upload (Steam / itch.io)

- Sign and notarise the macOS build; sign the Windows exe if a certificate is available.
- Bump `application/file_version` / `product_version` (Windows) and `application/version`
  (macOS) in `export_presets.cfg`.
- itch.io: upload each `build/<platform>/` folder (or the macOS zip) with butler, one channel
  per platform. Steam: one depot per platform, with the launch executable set to the binary
  above.
