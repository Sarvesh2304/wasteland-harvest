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
