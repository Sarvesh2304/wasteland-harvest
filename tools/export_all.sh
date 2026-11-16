#!/usr/bin/env bash
# Exports release builds for every preset in export_presets.cfg into build/ (git-ignored). On
# Linux it then smoke-runs the Linux build headlessly.
#
# Needs Godot 4.7 and its 4.7 export templates:
#   - Godot: `godot` on PATH, or GODOT=/path/to/Godot. On macOS that's the binary inside the
#     app, e.g. GODOT=~/Downloads/Godot.app/Contents/MacOS/Godot.
#   - Templates: in the editor, Editor > Manage Export Templates > Download and Install; or
#     unzip Godot_v4.7-stable_export_templates.tpz (from the 4.7-stable GitHub release) and put
#     its templates/ folder at ~/.local/share/godot/export_templates/4.7.stable/ (Linux) or
#     ~/Library/Application Support/Godot/export_templates/4.7.stable/ (macOS).
#
# macOS signing: Godot's own ad-hoc signer writes a malformed entitlements blob (found
# 2026-11-16 with rcodesign), and macOS won't launch such an app. So the macOS preset exports
# UNSIGNED and this script signs the app afterwards, ad-hoc, with Apple's `codesign` when run on
# a Mac, or `rcodesign` (RCODESIGN=/path, or on PATH; `cargo install apple-codesign`) elsewhere.
# With neither, the macOS export stops with an error rather than ship an app that won't open.
#
# Usage: tools/export_all.sh [linux|windows|macos ...]   (default: all three)
# Portable to macOS's bash 3.2: no associative arrays, no GNU-only tools.
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
if ! command -v "$GODOT" >/dev/null 2>&1; then
	echo "[export] can't find Godot ('$GODOT'). Set GODOT=/path/to/Godot (see the header)." >&2
	exit 1
fi

preset_for() {
	case "$1" in
		linux) echo "Linux" ;;
		windows) echo "Windows Desktop" ;;
		macos) echo "macOS" ;;
		*) echo "" ;;
	esac
}

output_for() {
	case "$1" in
		linux) echo "build/linux/WastelandHarvest.x86_64" ;;
		windows) echo "build/windows/WastelandHarvest.exe" ;;
		macos) echo "build/macos/WastelandHarvest.zip" ;;
	esac
}

## Unzips the macOS export, signs the .app ad-hoc with a proper signer, and zips it back up.
sign_macos_zip() {
	zip_path="$1"
	work=$(mktemp -d)
	(cd "$work" && unzip -q "$OLDPWD/$zip_path")
	app=$(find "$work" -maxdepth 1 -name "*.app" | head -n 1)
	[ -n "$app" ] || { echo "[export] no .app inside $zip_path" >&2; rm -rf "$work"; exit 1; }
	rcodesign="${RCODESIGN:-$(command -v rcodesign || true)}"
	if [ "$(uname -s)" = "Darwin" ] && command -v codesign >/dev/null 2>&1; then
		echo "[export] signing $(basename "$app") ad-hoc with codesign"
		codesign --force --deep --sign - "$app"
		codesign --verify --deep --strict "$app"
	elif [ -n "$rcodesign" ] && [ -x "$rcodesign" ]; then
		echo "[export] signing $(basename "$app") ad-hoc with rcodesign"
		"$rcodesign" sign "$app" >/dev/null
	else
		echo "[export] can't sign the macOS app: run this on a Mac, or install rcodesign" \
			"(cargo install apple-codesign) and set RCODESIGN=/path/to/rcodesign." >&2
		rm -rf "$work"
		exit 1
	fi
	rm -f "$zip_path"
	if command -v ditto >/dev/null 2>&1; then
		ditto -c -k --keepParent "$app" "$zip_path"
	else
		(cd "$work" && zip -qry "$OLDPWD/$zip_path" "$(basename "$app")")
	fi
	rm -rf "$work"
}

targets="$*"
[ -z "$targets" ] && targets="linux windows macos"

"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
for t in $targets; do
	preset=$(preset_for "$t")
	if [ -z "$preset" ]; then
		echo "[export] unknown target '$t' (use linux, windows or macos)" >&2
		exit 1
	fi
	out=$(output_for "$t")
	mkdir -p "$(dirname "$out")"
	echo "[export] $preset -> $out"
	log=$("$GODOT" --headless --path . --export-release "$preset" "$out" 2>&1 || true)
	if echo "$log" | grep -q "ERROR"; then
		echo "$log" | grep -A3 "ERROR" >&2
		exit 1
	fi
	[ -s "$out" ] || { echo "[export] $out missing" >&2; exit 1; }
	if [ "$t" = "macos" ]; then
		sign_macos_zip "$out"
	fi
done

case " $targets " in
	*" linux "*)
		if [ "$(uname -s)" = "Linux" ]; then
			echo "[export] smoke-running the Linux build"
			log=$(./build/linux/WastelandHarvest.x86_64 --headless --audio-driver Dummy --quit-after 600 2>&1 || true)
			if echo "$log" | grep -q "ERROR"; then echo "$log"; exit 1; fi
		fi
		;;
esac
echo "[export] done"
ls -la build/*/
