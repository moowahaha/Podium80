#!/usr/bin/env bash
# Build the distributable package for Podium '80.
#
# Produces:
#   build/game.pck            — the portable Godot 4 pack the console runs
#   build/podium-80.zip       — game.pck + manifest.json, ready to publish
#
# The .pck is engine-binary-free (GDScript + resources); the console runs it on its bundled Godot 4
# ARM64 runtime. Requires a `godot` 4.x on PATH.
set -euo pipefail
cd "$(dirname "$0")"

GODOT="${GODOT:-godot}"
OUT="build"
PCK="$OUT/game.pck"
ZIP="$OUT/podium-80.zip"

mkdir -p "$OUT"

echo "==> Importing resources"
"$GODOT" --headless --import

echo "==> Exporting pack -> $PCK"
"$GODOT" --headless --export-pack "Mebobox" "$PCK"

if [[ ! -f "$PCK" ]]; then
  echo "ERROR: export failed, $PCK not produced" >&2
  exit 1
fi

echo "==> Packaging -> $ZIP"
rm -f "$ZIP"
cp manifest.json "$OUT/manifest.json"
cp cover.png "$OUT/cover.png" 2>/dev/null || true
( cd "$OUT" && zip -q "$(basename "$ZIP")" game.pck manifest.json $( [[ -f cover.png ]] && echo cover.png ) )

echo "==> Done"
ls -la "$PCK" "$ZIP"
