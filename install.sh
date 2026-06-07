#!/bin/bash
# ┌──────────────────────────────────────────────────────────────────┐
# │  sharkOS Installer                                               │
# │  Installs the full sharkOS desktop on a base Arch Linux system   │
# │  Usage: curl -fsSL http://sharkos.io/install.sh | bash           │
# │                                                                    │
# │  The actual work lives in lib/sharkos-lib.sh, shared with         │
# │  update.sh (sharkos-update). This script only bootstraps the      │
# │  repo, then sources the library and runs the steps in order.      │
# └──────────────────────────────────────────────────────────────────┘
set -euo pipefail

SHARKOS_REPO="https://github.com/consistentinquiry/SharkOS.git"
SHARKOS_DIR="$HOME/Git/sharkOS"

# ── Minimal bootstrap ─────────────────────────────────────────────────
# We can't source the library until the repo is on disk (this script may run
# straight from `curl | bash`), so do the preflight + clone inline first.
[[ -f /etc/arch-release ]] || { echo "This script only runs on Arch Linux." >&2; exit 1; }
[[ "$EUID" -ne 0 ]] || { echo "Do not run as root. The script will use sudo when needed." >&2; exit 1; }

echo "[sharkOS] Starting sharkOS installation..."
if [[ -d "$SHARKOS_DIR/.git" ]]; then
    echo "[sharkOS] Updating existing sharkOS repo..."
    git -C "$SHARKOS_DIR" pull --ff-only || true
else
    echo "[sharkOS] Cloning sharkOS repo..."
    mkdir -p "$(dirname "$SHARKOS_DIR")"
    git clone "$SHARKOS_REPO" "$SHARKOS_DIR"
fi
cd "$SHARKOS_DIR"

# ── Run the shared steps ───────────────────────────────────────────────
source "$SHARKOS_DIR/lib/sharkos-lib.sh"

system_upgrade
ensure_yay
install_packages
detect_asus
detect_gpu
ensure_dirs
symlink_configs
setup_wallpaper
generate_themes
apply_active_theme noir          # first-time install: force the noir default
install_plymouth
configure_bootloader_splash
configure_greetd
enable_pipewire
link_self

# ── Done ──────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}════════════════════════════════════════${RESET}"
echo -e "${GREEN}${BOLD}  sharkOS installation complete!        ${RESET}"
echo -e "${GREEN}${BOLD}════════════════════════════════════════${RESET}"
echo ""
echo -e "  Reboot to enter sharkOS."
echo -e "  Your configs are symlinked from ${BLUE}$SHARKOS_DIR/config/${RESET}"
echo -e "  Edit them live, then ${BOLD}git commit${RESET} to save changes."
echo -e "  On your other machines, run ${BOLD}sharkos-update${RESET} to sync."
echo ""
