#!/bin/bash
# Compile the Quickshell liquid-glass shaders (.frag -> .frag.qsb).
# The .qsb files are committed, so this only needs re-running after editing a
# shader source. Requires qt6-shadertools (provides qsb).
set -euo pipefail

SHARKOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHADER_DIR="$SHARKOS_DIR/config/quickshell/sharkos/shaders"

QSB="$(command -v qsb || true)"
[[ -n "$QSB" ]] || QSB=/usr/lib/qt6/bin/qsb
[[ -x "$QSB" ]] || { echo "qsb not found — install qt6-shadertools" >&2; exit 1; }

for src in "$SHADER_DIR"/*.frag; do
    "$QSB" --glsl "100 es,120,150" --hlsl 50 --msl 12 -o "$src.qsb" "$src"
    echo "built ${src##*/}.qsb"
done
