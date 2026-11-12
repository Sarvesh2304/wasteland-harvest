#!/usr/bin/env bash
# Exports release builds for every preset in export_presets.cfg into build/ (git-ignored), then
# smoke-runs the Linux build headlessly. Needs Godot 4.7 on PATH as `godot` and the 4.7 export
# templates installed (~/.local/share/godot/export_templates/4.7.stable/; download
# Godot_v4.7-stable_export_templates.tpz from the Godot releases page and unzip its templates/
# folder there).
# Usage: tools/export_all.sh [linux|windows|macos ...]   (default: all three)
set -euo pipefail
cd "$(dirname "$0")/.."

declare -A PRESET=([linux]="Linux" [windows]="Windows Desktop" [macos]="macOS")
declare -A OUT=([linux]="build/linux/WastelandHarvest.x86_64" [windows]="build/windows/WastelandHarvest.exe"
	[macos]="build/macos/WastelandHarvest.zip")
targets=("$@")
[ ${#targets[@]} -eq 0 ] && targets=(linux windows macos)

godot --headless --path . --import >/dev/null 2>&1 || true
for t in "${targets[@]}"; do
	mkdir -p "$(dirname "${OUT[$t]}")"
	echo "[export] ${PRESET[$t]} -> ${OUT[$t]}"
	godot --headless --path . --export-release "${PRESET[$t]}" "${OUT[$t]}" 2>&1 | grep -E "ERROR" && exit 1 || true
	[ -s "${OUT[$t]}" ] || { echo "[export] ${OUT[$t]} missing"; exit 1; }
done
if [[ " ${targets[*]} " == *" linux "* ]]; then
	echo "[export] smoke-running the Linux build"
	log=$(timeout 60 ./build/linux/WastelandHarvest.x86_64 --headless --audio-driver Dummy --quit-after 600 2>&1)
	if echo "$log" | grep -q "ERROR"; then echo "$log"; exit 1; fi
fi
echo "[export] done"
ls -la build/*/
