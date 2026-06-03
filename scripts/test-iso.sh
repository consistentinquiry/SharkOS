#!/usr/bin/env bash
# Boot a built SharkOS ISO in QEMU (UEFI) to test before writing to real hardware.
# Usage: scripts/test-iso.sh [path/to.iso]   (defaults to newest in dist/)
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
ISO="${1:-$(ls -t "$REPO"/dist/*.iso 2>/dev/null | head -1 || true)}"

[[ -n "$ISO" && -f "$ISO" ]] || { echo "No ISO found. Build one first: ./build-iso.sh"; exit 1; }
command -v qemu-system-x86_64 >/dev/null || { echo "Install QEMU: sudo pacman -S qemu-base"; exit 1; }

# Find OVMF firmware for UEFI boot (package: edk2-ovmf). Falls back to BIOS if absent.
OVMF=""
for f in /usr/share/edk2/x64/OVMF_CODE.4m.fd \
         /usr/share/edk2-ovmf/x64/OVMF_CODE.fd \
         /usr/share/OVMF/OVMF_CODE.fd; do
  [[ -f "$f" ]] && { OVMF="$f"; break; }
done

ARGS=(-enable-kvm -m 4096 -smp 2 -cpu host -cdrom "$ISO" -boot d)
if [[ -n "$OVMF" ]]; then
  echo "==> UEFI boot via $OVMF"
  ARGS+=(-drive "if=pflash,format=raw,readonly=on,file=$OVMF")
else
  echo "==> OVMF not found (sudo pacman -S edk2-ovmf for UEFI); booting BIOS mode"
fi

echo "==> Booting $ISO"
exec qemu-system-x86_64 "${ARGS[@]}"
