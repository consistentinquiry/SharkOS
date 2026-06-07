#!/bin/bash
# ┌──────────────────────────────────────────────────────────────────┐
# │  sharkos-update                                                  │
# │  Sync an already-installed sharkOS machine to the latest repo.    │
# │                                                                    │
# │  Workflow: develop on any machine (edit live → git commit →       │
# │  git push), then run `sharkos-update` on the others. Symlinked    │
# │  configs ride along with the pull; this re-materialises the bits  │
# │  install.sh only *copies* (Plymouth, greetd, mkinitcpio hooks,    │
# │  bootloader cmdline, packages) while preserving machine-local     │
# │  state (active theme, GPU env).                                   │
# │                                                                    │
# │  Usage: sharkos-update [--stash] [--no-upgrade]                   │
# │    --stash       stash/pop local changes around the pull          │
# │    --no-upgrade  skip the full `pacman -Syu` system upgrade        │
# └──────────────────────────────────────────────────────────────────┘
set -euo pipefail

# Resolve the repo from this script's real path so it works whether invoked
# directly or via the /usr/local/bin/sharkos-update symlink.
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SHARKOS_DIR="${SHARKOS_DIR:-$(dirname "$SCRIPT_PATH")}"
source "$SHARKOS_DIR/lib/sharkos-lib.sh"

# ── Flags ──────────────────────────────────────────────────────────────
STASH=""
DO_UPGRADE=1
for arg in "$@"; do
    case "$arg" in
        --stash)      STASH="stash" ;;
        --no-upgrade) DO_UPGRADE=0 ;;
        -h|--help)
            # Print just the leading comment box (stop at the first non-# line).
            sed -n '2,${/^#/!q;s/^# \?//p}' "$SCRIPT_PATH"
            exit 0 ;;
        *) die "Unknown flag: $arg (try --stash, --no-upgrade)" ;;
    esac
done

# ── Run ─────────────────────────────────────────────────────────────────
preflight
sync_repo "$STASH"
[[ "$DO_UPGRADE" == "1" ]] && system_upgrade || info "Skipping system upgrade (--no-upgrade)."
ensure_yay
install_packages
detect_gpu
ensure_dirs
symlink_configs
setup_wallpaper
generate_themes
apply_active_theme preserve      # keep this machine's chosen theme
install_plymouth
configure_bootloader_splash
configure_greetd
enable_pipewire
link_self
detect_asus                      # heavy AUR build, non-fatal — runs last so a
                                 # failure can't block the convergence above

# ── Done ──────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}════════════════════════════════════════${RESET}"
echo -e "${GREEN}${BOLD}  sharkOS is up to date!                ${RESET}"
echo -e "${GREEN}${BOLD}════════════════════════════════════════${RESET}"
echo ""
echo -e "  If the boot splash or login manager changed, reboot to apply."
echo ""
