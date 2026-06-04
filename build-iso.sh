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

# mkarchiso records per-stage "run_once" sentinels in the work dir and skips any
# stage whose sentinel exists. A leftover work dir therefore makes a rebuild a
# silent no-op (it never re-creates the ISO). Always start from a clean one.
# (Owned by root from the previous sudo mkarchiso run, so remove with sudo.)
echo "==> Clearing previous work dir"
sudo rm -rf "$WORK/work"

echo "==> Applying SharkOS overlay"
# Files baked into the live environment (installer, motd, ...)
cp -a "$REPO/iso/airootfs/." "$PROFILE/airootfs/"
# Bake the first-boot desktop stage (iso/target/) into the live env so the
# installer can lay it into the new system offline. Staged under a neutral
# path (not its real home) so the unit isn't active in the live env itself;
# sharkos-install copies it into place during install.
mkdir -p "$PROFILE/airootfs/usr/local/share/sharkos/target"
cp -a "$REPO/iso/target/." "$PROFILE/airootfs/usr/local/share/sharkos/target/"
# Extra packages for the live environment
cat "$REPO/iso/packages.x86_64.extra" >> "$PROFILE/packages.x86_64"

echo "==> Adding live-ISO boot splash (Plymouth)"
# Ship the SharkOS Plymouth theme into the live env (plymouthd.conf in our
# airootfs already points the daemon at it).
mkdir -p "$PROFILE/airootfs/usr/share/plymouth/themes/sharkos"
cp -a "$REPO/plymouth/sharkos/." "$PROFILE/airootfs/usr/share/plymouth/themes/sharkos/"
# Add the `plymouth` hook to the live initramfs, right after `kms` (needs the
# DRM driver loaded first). String-based so it tolerates HOOKS list changes.
ARCHISO_HOOKS="$PROFILE/airootfs/etc/mkinitcpio.conf.d/archiso.conf"
if [[ -f "$ARCHISO_HOOKS" ]] && ! grep -q 'plymouth' "$ARCHISO_HOOKS"; then
  sed -i 's/ kms / kms plymouth /' "$ARCHISO_HOOKS"
fi

echo "==> Branding profiledef.sh"
sed -i \
  -e 's/^iso_name=.*/iso_name="sharkos"/' \
  -e 's/^iso_label=.*/iso_label="SHARKOS"/' \
  -e 's#^iso_publisher=.*#iso_publisher="SharkOS <https://github.com/consistentinquiry/SharkOS>"#' \
  -e 's/^iso_application=.*/iso_application="SharkOS Live\/Installer"/' \
  "$PROFILE/profiledef.sh"
# Ensure the installer is executable inside the squashfs (archiso reads file_permissions)
echo 'file_permissions+=(["/usr/local/bin/sharkos-install"]="0:0:755")' >> "$PROFILE/profiledef.sh"

echo "==> Rebranding boot menus"
# Rewrite the boot-loader menu labels across whichever bootloaders releng ships
# (systemd-boot: efiboot/, GRUB: grub/, BIOS: syslinux/). String-based so it
# survives archiso layout changes between versions.
# The cmdline edit appends `quiet splash` to every kernel line (matched by the
# archisobasedir= param common to all bootloaders) so Plymouth shows on boot.
# Drop `quiet` if you'd rather keep boot diagnostics visible on install media.
for d in efiboot grub syslinux; do
  [[ -d "$PROFILE/$d" ]] && find "$PROFILE/$d" -type f -exec sed -i \
    -e 's/Arch Linux install medium/SharkOS Installer/g' \
    -e 's/^\(\s*MENU TITLE\) .*/\1 SharkOS/' \
    -e 's/Arch Linux (\(.*\))/SharkOS (\1)/g' \
    -e '/archisobasedir=%INSTALL_DIR%/ s/$/ quiet splash/' \
    {} +
done

echo "==> Building ISO (requires root)"
sudo mkarchiso -v -w "$WORK/work" -o "$OUT" "$PROFILE"

echo "==> Done. ISO(s) in: $OUT"
ls -lh "$OUT"/*.iso 2>/dev/null || true
