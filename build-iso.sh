#!/usr/bin/env bash
# ┌──────────────────────────────────────────────────────────────────┐
# │  Build the SharkOS live/installer ISO                            │
# │  Layers the SharkOS overlay on Arch's official `releng` profile  │
# │  so we track upstream archiso instead of forking it.             │
# └──────────────────────────────────────────────────────────────────┘
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
RELENG="/usr/share/archiso/configs/releng"
WORK="${SHARKOS_ISO_WORK:-$HOME/.cache/sharkos-iso}"
PROFILE="$WORK/profile"
OUT="${SHARKOS_ISO_OUT:-$REPO/dist}"

command -v mkarchiso >/dev/null || { echo "archiso not installed. Run: sudo pacman -S archiso"; exit 1; }
[[ -d "$RELENG" ]] || { echo "releng profile not found at $RELENG (reinstall archiso)"; exit 1; }

echo "==> Preparing profile from releng"
rm -rf "$PROFILE"; mkdir -p "$PROFILE" "$OUT"
cp -a "$RELENG/." "$PROFILE/"

echo "==> Applying SharkOS overlay"
# Files baked into the live environment (installer, motd, ...)
cp -a "$REPO/iso/airootfs/." "$PROFILE/airootfs/"
# Ship the archinstall config template into the live env
install -Dm644 "$REPO/iso/archinstall/sharkos.json" \
  "$PROFILE/airootfs/root/sharkos/archinstall/sharkos.json"
# Extra packages for the live environment
cat "$REPO/iso/packages.x86_64.extra" >> "$PROFILE/packages.x86_64"

echo "==> Branding profiledef.sh"
sed -i \
  -e 's/^iso_name=.*/iso_name="sharkos"/' \
  -e 's/^iso_label=.*/iso_label="SHARKOS"/' \
  -e 's#^iso_publisher=.*#iso_publisher="SharkOS <https://github.com/consistentinquiry/SharkOS>"#' \
  -e 's/^iso_application=.*/iso_application="SharkOS Live\/Installer"/' \
  "$PROFILE/profiledef.sh"
# Ensure the installer is executable inside the squashfs (archiso reads file_permissions)
echo 'file_permissions+=(["/usr/local/bin/sharkos-install"]="0:0:755")' >> "$PROFILE/profiledef.sh"

echo "==> Building ISO (requires root)"
sudo mkarchiso -v -w "$WORK/work" -o "$OUT" "$PROFILE"

echo "==> Done. ISO(s) in: $OUT"
ls -lh "$OUT"/*.iso 2>/dev/null || true
