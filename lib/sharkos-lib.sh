#!/bin/bash
# ┌──────────────────────────────────────────────────────────────────┐
# │  sharkOS shared library                                          │
# │  Idempotent system-materialization steps sourced by both         │
# │  install.sh (first-time setup) and update.sh (sharkos-update).    │
# │  Sourcing this file only defines functions + globals; it runs     │
# │  nothing. The orchestrators set `set -euo pipefail` and call the  │
# │  functions in order.                                              │
# └──────────────────────────────────────────────────────────────────┘

# ── Globals ───────────────────────────────────────────────────────────
SHARKOS_REPO="${SHARKOS_REPO:-https://github.com/consistentinquiry/SharkOS.git}"
SHARKOS_DIR="${SHARKOS_DIR:-$HOME/Git/sharkOS}"

BOLD='\033[1m'
BLUE='\033[1;34m'
GREEN='\033[1;32m'
RED='\033[1;31m'
RESET='\033[0m'

# Non-interactive yay flags so AUR builds never try to open /dev/tty for a
# diff/edit/clean/provider menu (which fails outside a real terminal).
YAY_FLAGS=(--needed --noconfirm --answerdiff=None --answeredit=None --answerclean=None --removemake)

info()  { echo -e "${BLUE}[sharkOS]${RESET} $*"; }
ok()    { echo -e "${GREEN}[sharkOS]${RESET} $*"; }
err()   { echo -e "${RED}[sharkOS]${RESET} $*" >&2; }
die()   { err "$*"; exit 1; }

# ── Preflight ──────────────────────────────────────────────────────────
preflight() {
    [[ -f /etc/arch-release ]] || die "This script only runs on Arch Linux."
    [[ "$EUID" -ne 0 ]] || die "Do not run as root. The script will use sudo when needed."
}

# ── Repo sync (used by update.sh; install.sh clones inline first) ──────
# Pull the latest repo with a fast-forward. A dirty working tree is the
# expected friction point of multi-machine dev: rendered theme outputs are
# gitignored so they never block a pull — only real tracked edits do. We
# refuse to pull over them (rather than silently auto-committing) unless the
# caller passed "stash".
sync_repo() {
    local allow_stash="${1:-}" stashed=0
    cd "$SHARKOS_DIR"
    if [[ -n "$(git status --porcelain)" ]]; then
        if [[ "$allow_stash" == "stash" ]]; then
            info "Stashing local changes..."
            git stash push -u -m "sharkos-update autostash"
            stashed=1
        else
            err "Working tree has uncommitted changes:"
            git status --short >&2
            die "Commit & push them on this machine first, or re-run with --stash."
        fi
    fi
    info "Pulling latest sharkOS..."
    git pull --ff-only || die "git pull --ff-only failed (history diverged?). Resolve manually."
    if [[ "$stashed" == "1" ]]; then
        info "Restoring stashed changes..."
        git stash pop || err "git stash pop hit conflicts — resolve them manually."
    fi
}

# ── System update ──────────────────────────────────────────────────────
system_upgrade() {
    info "Updating system packages..."
    sudo pacman -Syu --noconfirm
}

# ── yay (AUR helper) ────────────────────────────────────────────────────
ensure_yay() {
    if command -v yay &>/dev/null; then
        ok "yay already installed."
        return
    fi
    info "Installing yay..."
    sudo pacman -S --needed --noconfirm base-devel git
    local tmpdir; tmpdir=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
    (cd "$tmpdir/yay" && makepkg -si --noconfirm)
    rm -rf "$tmpdir"
    ok "yay installed."
}

# ── Packages (official + AUR) ───────────────────────────────────────────
install_packages() {
    info "Installing official packages..."
    grep -v '^#' "$SHARKOS_DIR/packages/pacman.txt" | grep -v '^$' | \
        sudo pacman -S --needed --noconfirm -

    info "Installing AUR packages..."
    grep -vE '^#|^$' "$SHARKOS_DIR/packages/aur.txt" | \
        yay -S "${YAY_FLAGS[@]}" -
}

# ── Hardware: ASUS ─────────────────────────────────────────────────────
detect_asus() {
    if [[ -d /sys/module/asus_wmi ]] || dmidecode -s system-manufacturer 2>/dev/null | grep -qi asus; then
        info "ASUS hardware detected, installing asusctl..."
        yay -S "${YAY_FLAGS[@]}" asusctl
        ok "asusctl installed."
    else
        info "Non-ASUS hardware detected, skipping asusctl."
    fi
}

# ── Helpers for GPU env / kernel cmdline (idempotent) ───────────────────
# Append KEY=VALUE to /etc/environment if that key isn't already set there.
# Machine-specific, so it lives here rather than in the symlinked repo config.
add_env() {
    local kv="$1" key="${1%%=*}"
    if ! sudo grep -q "^${key}=" /etc/environment 2>/dev/null; then
        echo "$kv" | sudo tee -a /etc/environment >/dev/null
        info "  /etc/environment += $kv"
    fi
}

# Add a kernel command-line parameter (handles GRUB and systemd-boot).
add_cmdline_param() {
    local param="$1"
    if [[ -f /etc/default/grub ]]; then
        if ! grep -q -- "$param" /etc/default/grub; then
            sudo sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1 $param\"/" /etc/default/grub
            sudo grub-mkconfig -o /boot/grub/grub.cfg
            info "  GRUB cmdline += $param"
        fi
    elif [[ -d /boot/loader/entries ]]; then
        for entry in /boot/loader/entries/*.conf; do
            grep -q -- "$param" "$entry" || sudo sed -i "/^options/ s/\$/ $param/" "$entry"
        done
        info "  systemd-boot cmdline += $param"
    else
        err "  Could not patch kernel cmdline for '$param' (unknown bootloader). Add it manually."
    fi
}

# ── GPU detection & drivers ─────────────────────────────────────────────
# Detect the graphics stack and install the matching drivers. NVIDIA also gets
# the kernel-cmdline + env tweaks Hyprland needs; AMD/Intel ride on Mesa. In a
# VM we install guest tooling and (for VirtualBox) force Mesa's software path,
# since VMSVGA 3D is unreliable under Wayland. All steps are guarded so
# re-running adds nothing duplicate.
detect_gpu() {
    info "Detecting graphics hardware..."

    local VIRT; VIRT="$(systemd-detect-virt 2>/dev/null || true)"
    [[ -n "$VIRT" ]] || VIRT="none"

    if [[ "$VIRT" != "none" ]]; then
        info "Virtualized environment detected: $VIRT"
        sudo pacman -S --needed --noconfirm mesa
        case "$VIRT" in
            oracle)   # VirtualBox
                info "  Installing VirtualBox guest utilities..."
                sudo pacman -S --needed --noconfirm virtualbox-guest-utils
                sudo systemctl enable vboxservice.service 2>/dev/null || true
                # VirtualBox's VMSVGA 3D path is unreliable under Wayland, so force
                # Mesa's software renderer (llvmpipe) to guarantee Hyprland a working
                # GL/EGL context. Remove these two if you enable working 3D accel.
                add_env "LIBGL_ALWAYS_SOFTWARE=1"
                add_env "GALLIUM_DRIVER=llvmpipe"
                ;;
            vmware)
                sudo pacman -S --needed --noconfirm open-vm-tools
                sudo systemctl enable vmtoolsd.service 2>/dev/null || true
                ;;
            kvm|qemu)
                sudo pacman -S --needed --noconfirm qemu-guest-agent spice-vdagent
                sudo systemctl enable qemu-guest-agent.service 2>/dev/null || true
                ;;
            *)
                info "  No specific guest tooling for '$VIRT'; Mesa installed for software rendering."
                ;;
        esac
        ok "VM graphics configured."
        return
    fi

    # ---- Bare metal: detect by PCI vendor ----
    command -v lspci &>/dev/null || sudo pacman -S --needed --noconfirm pciutils
    local GPUS; GPUS="$(lspci -nn | grep -Ei 'vga|3d|display' || true)"
    echo "$GPUS" | sed 's/^/  /'

    # Match on PCI vendor IDs (NVIDIA 10de, AMD 1002, Intel 8086) rather than
    # names — substrings like "ati" would otherwise match "CorporATIon".
    local has_nvidia=false has_amd=false has_intel=false
    grep -qiE '\[10de:' <<<"$GPUS" && has_nvidia=true
    grep -qiE '\[1002:' <<<"$GPUS" && has_amd=true
    grep -qiE '\[8086:' <<<"$GPUS" && has_intel=true

    # Mesa is the GL/EGL stack for AMD + Intel (and software fallback everywhere).
    local PKGS=(mesa)
    $has_amd   && { info "  AMD GPU detected";   PKGS+=(vulkan-radeon libva-mesa-driver); }
    $has_intel && { info "  Intel GPU detected"; PKGS+=(vulkan-intel intel-media-driver); }
    sudo pacman -S --needed --noconfirm "${PKGS[@]}"

    if $has_nvidia; then
        info "  NVIDIA GPU detected — installing nvidia-open-dkms stack..."
        # DKMS needs headers for every installed kernel so the module rebuilds on upgrade.
        local HEADERS=() k
        for k in linux linux-lts linux-zen linux-hardened; do
            pacman -Qq "$k" &>/dev/null && HEADERS+=("${k}-headers")
        done
        sudo pacman -S --needed --noconfirm \
            nvidia-open-dkms nvidia-utils egl-wayland libva-nvidia-driver dkms "${HEADERS[@]}"

        # Early KMS: load the nvidia modules from the initramfs.
        if ! grep -q 'nvidia_drm' /etc/mkinitcpio.conf; then
            sudo sed -i 's/^MODULES=(\(.*\))/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
            info "  Added nvidia modules to mkinitcpio MODULES"
            sudo mkinitcpio -P
        fi

        # DRM modesetting (required for Wayland) + framebuffer (clean console/splash).
        add_cmdline_param "nvidia_drm.modeset=1"
        add_cmdline_param "nvidia_drm.fbdev=1"

        # Session env so Hyprland / XWayland / VA-API use the NVIDIA stack.
        add_env "LIBVA_DRIVER_NAME=nvidia"
        add_env "__GLX_VENDOR_LIBRARY_NAME=nvidia"
        add_env "NVD_BACKEND=direct"
        ok "  NVIDIA configured (driver + modeset + env)."
    fi

    $has_amd || $has_intel || $has_nvidia || \
        err "  No known GPU vendor matched; installed Mesa only. Check 'lspci | grep -Ei vga'."
    ok "Bare-metal graphics configured."
}

# ── Directories ─────────────────────────────────────────────────────────
ensure_dirs() {
    info "Creating directories..."
    mkdir -p "$HOME/Pictures/Screenshots"
    mkdir -p "$HOME/.config"
}

# ── Symlink config directories (idempotent) ─────────────────────────────
symlink_configs() {
    info "Symlinking config files..."
    local CONFIG_DIRS=(hypr waybar walker swayosd mako ghostty swappy elephant themes)
    local dir src dest
    for dir in "${CONFIG_DIRS[@]}"; do
        src="$SHARKOS_DIR/config/$dir"
        dest="$HOME/.config/$dir"
        if [[ -L "$dest" ]]; then
            rm "$dest"
        elif [[ -d "$dest" ]]; then
            info "  Backing up existing $dest -> ${dest}.bak"
            mv "$dest" "${dest}.bak"
        fi
        ln -s "$src" "$dest"
        ok "  $dest -> $src"
    done
}

# ── Wallpaper ───────────────────────────────────────────────────────────
setup_wallpaper() {
    info "Setting up wallpaper..."
    export SHARKOS_DIR
    bash "$SHARKOS_DIR/scripts/select_wallpaper.sh"
}

# ── Themes: generate Omarchy-derived themes (does not apply a theme) ─────
generate_themes() {
    info "Generating themes..."
    local OMARCHY_DIR="$HOME/Git/omarchy"
    if [[ ! -d "$OMARCHY_DIR/.git" ]]; then
        # We only use omarchy as a palette/wallpaper source, so fetch just
        # themes/<name>/colors.toml + backgrounds/ — not the whole project.
        # Shallow + blobless + sparse (non-cone patterns) keeps it minimal.
        info "  Fetching upstream omarchy theme palettes + wallpapers (sparse)..."
        git clone --depth 1 --filter=blob:none --no-checkout \
            https://github.com/basecamp/omarchy.git "$OMARCHY_DIR"
        git -C "$OMARCHY_DIR" sparse-checkout set --no-cone \
            '/themes/*/colors.toml' '/themes/*/backgrounds/'
        git -C "$OMARCHY_DIR" checkout
    else
        git -C "$OMARCHY_DIR" pull --ff-only || true
    fi
    bash "$HOME/.config/themes/generate-omarchy-themes.sh" "$OMARCHY_DIR"
    ok "Themes generated."
}

# ── Apply a theme ────────────────────────────────────────────────────────
# Modes:
#   apply_active_theme noir       -> force the named theme (first-time install)
#   apply_active_theme preserve   -> re-apply the machine's active theme from
#                                    config/themes/.current (fallback noir),
#                                    so an update re-renders templates without
#                                    resetting the user's chosen theme.
apply_active_theme() {
    local mode="${1:-noir}" theme
    if [[ "$mode" == "preserve" ]]; then
        theme="$(cat "$HOME/.config/themes/.current" 2>/dev/null || echo noir)"
        info "Re-applying active theme ($theme)..."
    else
        theme="$mode"
        info "Applying theme ($theme)..."
    fi
    bash "$HOME/.config/themes/apply-theme.sh" "$theme" || true
    ok "Theme '$theme' applied."
}

# ── Plymouth boot splash (change-detected) ──────────────────────────────
# Copies the sharkos theme, ensures the kms + plymouth initcpio hooks, and
# sets sharkos as the default — but only rebuilds the (slow) initramfs when
# something actually changed. On a fresh machine everything is "changed", so
# it behaves like the original unconditional install.
#
# NOTE: current plymouth ships only the `plymouth` hook — `plymouth-encrypt`
# and `sd-plymouth` were removed upstream, so we must not reference them. We
# only *add* hooks, never reorder existing ones, so we never disturb a
# working LUKS setup (busybox `encrypt` is left exactly as-is).
install_plymouth() {
    info "Installing/updating Plymouth theme..."
    local src="$SHARKOS_DIR/plymouth/sharkos"
    local dest="/usr/share/plymouth/themes/sharkos"
    local MK="/etc/mkinitcpio.conf"
    local changed=0 cur

    # 1. Theme files
    if ! sudo diff -rq "$src" "$dest" >/dev/null 2>&1; then
        sudo mkdir -p "$dest"
        sudo cp -r "$src/." "$dest/"
        info "  Plymouth theme files updated"
        changed=1
    else
        ok "  Plymouth theme files already current"
    fi

    # 2. kms hook (required for Plymouth) — add after autodetect if missing.
    cur=$(grep '^HOOKS=' "$MK")
    if ! grep -qw 'kms' <<<"$cur"; then
        sudo sed -i 's/\bautodetect\b/autodetect kms/' "$MK"
        info "  Added kms hook"
        changed=1
    fi

    # 3. plymouth hook — after `systemd` on a systemd initramfs (themed
    #    systemd-ask-password prompt), otherwise after `kms`.
    cur=$(grep '^HOOKS=' "$MK")
    if ! grep -qw 'plymouth' <<<"$cur"; then
        if grep -qw 'systemd' <<<"$cur"; then
            info "  systemd initramfs detected — adding plymouth after systemd"
            sudo sed -i 's/\bsystemd\b/systemd plymouth/' "$MK"
        else
            info "  busybox initramfs detected — adding plymouth after kms"
            sudo sed -i 's/\bkms\b/kms plymouth/' "$MK"
        fi
        changed=1
    else
        ok "  plymouth hook already present"
    fi

    # 4. Default theme
    if [[ "$(plymouth-set-default-theme 2>/dev/null || true)" != "sharkos" ]]; then
        sudo plymouth-set-default-theme sharkos
        info "  Default Plymouth theme set to sharkos"
        changed=1
    fi

    # 5. Rebuild initramfs only when something changed.
    if [[ "$changed" == "1" ]]; then
        info "  Rebuilding initramfs..."
        sudo mkinitcpio -P
        ok "Plymouth updated and initramfs rebuilt."
    else
        ok "Plymouth already current — skipping initramfs rebuild."
    fi
}

# ── Bootloader: quiet splash (idempotent) ───────────────────────────────
configure_bootloader_splash() {
    if [[ -f /etc/default/grub ]]; then
        info "Configuring GRUB for Plymouth..."
        if ! grep -q 'splash' /etc/default/grub; then
            sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 quiet splash"/' /etc/default/grub
            sudo grub-mkconfig -o /boot/grub/grub.cfg
            ok "GRUB updated with quiet splash."
        else
            ok "GRUB already has splash parameter."
        fi
    elif [[ -d /boot/loader/entries ]]; then
        info "Configuring systemd-boot for Plymouth..."
        local entry
        for entry in /boot/loader/entries/*.conf; do
            if ! grep -q 'splash' "$entry"; then
                sudo sed -i '/^options/ s/$/ quiet splash/' "$entry"
                ok "  Updated $entry"
            fi
        done
    else
        err "Could not detect bootloader (GRUB or systemd-boot). Add 'quiet splash' to kernel cmdline manually."
    fi
}

# ── greetd login manager (idempotent) ───────────────────────────────────
configure_greetd() {
    info "Configuring greetd..."
    sudo mkdir -p /etc/greetd
    sudo cp "$SHARKOS_DIR/greetd/config.toml" /etc/greetd/config.toml

    # Create greeter user if it doesn't exist
    if ! id -u greeter &>/dev/null; then
        sudo useradd -r -s /bin/bash greeter
    fi

    # Ensure greeter can access the tty
    sudo chmod 755 /etc/greetd

    # Enable greetd (disable any other display manager first)
    local dm
    for dm in gdm sddm lightdm lxdm; do
        if systemctl is-enabled "$dm.service" &>/dev/null; then
            info "  Disabling $dm..."
            sudo systemctl disable "$dm.service"
        fi
    done
    sudo systemctl enable greetd.service
    ok "greetd enabled."

    # Create systemd drop-in for Plymouth handoff
    sudo mkdir -p /etc/systemd/system/greetd.service.d
    printf '[Unit]\nAfter=plymouth-quit-wait.service\n' | \
        sudo tee /etc/systemd/system/greetd.service.d/plymouth.conf >/dev/null
    ok "greetd configured for Plymouth handoff."
}

# ── PipeWire user services ──────────────────────────────────────────────
enable_pipewire() {
    info "Enabling PipeWire user services..."
    systemctl --user enable --now pipewire.service 2>/dev/null || true
    systemctl --user enable --now pipewire-pulse.service 2>/dev/null || true
    systemctl --user enable --now wireplumber.service 2>/dev/null || true
    ok "PipeWire enabled."
}

# ── Expose `sharkos-update` on PATH (symlink → repo update.sh) ──────────
# A symlink (not a copy) so it auto-tracks the repo on every machine.
link_self() {
    if [[ "$(readlink -f /usr/local/bin/sharkos-update 2>/dev/null)" != "$SHARKOS_DIR/update.sh" ]]; then
        sudo ln -sf "$SHARKOS_DIR/update.sh" /usr/local/bin/sharkos-update
        ok "sharkos-update linked into /usr/local/bin."
    fi
}
