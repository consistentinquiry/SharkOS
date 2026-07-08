#!/usr/bin/env bash
# Boot a built SharkOS ISO in QEMU (UEFI) to test before writing to real hardware.
#
# Usage:
#   scripts/test-iso.sh [path/to.iso]   boot ISO + virtual disk (defaults to newest in dist/)
#   scripts/test-iso.sh --installed     boot the virtual disk only (post-install testing)
#
# A persistent qcow2 disk (dist/test-disk.qcow2, sparse) is attached so the
# installer has something to install onto and first-boot/desktop testing
# survives reboots. Delete the file to start from a clean machine.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"

DISK="${SHARKOS_TEST_DISK:-$REPO/dist/test-disk.qcow2}"
DISK_SIZE="${SHARKOS_TEST_DISK_SIZE:-40G}"

command -v qemu-system-x86_64 >/dev/null || { echo "Install QEMU: sudo pacman -S qemu-base"; exit 1; }

if [[ ! -f "$DISK" ]]; then
  echo "==> Creating virtual disk $DISK ($DISK_SIZE, sparse)"
  qemu-img create -f qcow2 "$DISK" "$DISK_SIZE" >/dev/null
fi

# q35: modern machine type, and no legacy floppy controller (a phantom
# /dev/fd0 otherwise shows up in the installer's disk list).
# virtio-vga gives the guest proper KMS for Plymouth/Hyprland but qemu-base
# doesn't ship it (package: qemu-hw-display-virtio-vga, or qemu-desktop);
# fall back to std VGA (bochs-drm in the guest) when it's missing. GL is
# software/llvmpipe either way — expect the desktop to render slowly.
if qemu-system-x86_64 -device help 2>/dev/null | grep -q virtio-vga; then
  VGA=virtio
else
  echo "==> virtio-vga not available (pacman -S qemu-hw-display-virtio-vga); using std VGA"
  VGA=std
fi
ARGS=(-enable-kvm -machine q35 -m 4096 -smp 2 -cpu host
      -vga "$VGA"
      -drive "file=$DISK,if=virtio,format=qcow2")

if [[ "${1:-}" == "--installed" ]]; then
  echo "==> Booting installed system from $DISK (no ISO)"
else
  ISO="${1:-$(ls -t "$REPO"/dist/*.iso 2>/dev/null | head -1 || true)}"
  [[ -n "$ISO" && -f "$ISO" ]] || { echo "No ISO found. Build one first: ./build-iso.sh"; exit 1; }
  echo "==> Booting $ISO"
  ARGS+=(-cdrom "$ISO" -boot d)
fi

# Find OVMF firmware for UEFI boot (package: edk2-ovmf). Falls back to BIOS if absent.
OVMF=""
for f in /usr/share/edk2/x64/OVMF_CODE.4m.fd \
         /usr/share/edk2-ovmf/x64/OVMF_CODE.fd \
         /usr/share/OVMF/OVMF_CODE.fd; do
  [[ -f "$f" ]] && { OVMF="$f"; break; }
done
if [[ -n "$OVMF" ]]; then
  echo "==> UEFI boot via $OVMF"
  ARGS+=(-drive "if=pflash,format=raw,readonly=on,file=$OVMF")
else
  echo "==> OVMF not found (sudo pacman -S edk2-ovmf for UEFI); booting BIOS mode"
fi

exec qemu-system-x86_64 "${ARGS[@]}"
