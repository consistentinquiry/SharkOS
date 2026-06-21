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

# Greeting banner shown when the updater window opens.
print_banner() {
    local ver; ver="$(tr -d '[:space:]' < "$SHARKOS_DIR/VERSION" 2>/dev/null)"
    printf '%b' "${GREEN}${BOLD}"
    cat <<'ART'

     ▟▙
    ▟██▙    ███████ ██   ██  █████  ██████  ██   ██  ██████  ███████
   ▟████▙   ██      ██   ██ ██   ██ ██   ██ ██  ██  ██    ██ ██
   ▜████▛   ███████ ███████ ███████ ██████  █████   ██    ██ ███████
    ▜██▛         ██ ██   ██ ██   ██ ██   ██ ██  ██  ██    ██      ██
     ▜▛     ███████ ██   ██ ██   ██ ██   ██ ██   ██  ██████  ███████
ART
    printf '%b' "${RESET}"
    printf '   %bSharkOS %s%b — keeping your shark up to date\n\n' \
        "${GREEN}" "${ver:-rolling}" "${RESET}"
}

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
# ── Remote URLs: pull keyless over HTTPS, push over SSH ─────────────────
# The repo is public, so updates can fetch anonymously over HTTPS — no SSH key
# or passphrase needed (the whole point of sharkos-update on other machines).
# Dev boxes set origin to SSH so they can push; preserve that by keeping the SSH
# push URL while switching the fetch URL to HTTPS. Idempotent: once origin's
# fetch URL is HTTPS this is a no-op. Reverse with `git remote set-url origin
# git@github.com:consistentinquiry/SharkOS.git`.
ensure_remote_urls() {
    local cur
    cur="$(git -C "$SHARKOS_DIR" remote get-url origin 2>/dev/null)" || return 0
    case "$cur" in
        git@github.com:*|ssh://git@github.com/*)
            git -C "$SHARKOS_DIR" remote set-url --push origin "$cur"
            git -C "$SHARKOS_DIR" remote set-url origin "$SHARKOS_REPO"
            info "origin: fetch via HTTPS (keyless updates), push via SSH."
            ;;
    esac
}

# Resolve the update channel for this machine. Explicit override wins; else
# infer: a dev box has a separate SSH *push* URL (set by ensure_remote_urls),
# consumers cloned over HTTPS and have none. Dev → edge (track main, where you
# commit); consumer → stable (released v* tags only). Override by writing
# "edge" or "stable" to $SHARKOS_STATE/channel.
SHARKOS_STATE="${SHARKOS_STATE:-$HOME/.local/state/sharkos}"
sharkos_channel() {
    local ch=""
    [[ -f "$SHARKOS_STATE/channel" ]] && ch="$(tr -d '[:space:]' < "$SHARKOS_STATE/channel")"
    case "$ch" in edge|stable) printf '%s' "$ch"; return ;; esac
    local fetch push
    fetch="$(git -C "$SHARKOS_DIR" remote get-url origin 2>/dev/null)"
    push="$(git -C "$SHARKOS_DIR" remote get-url --push origin 2>/dev/null)"
    if [[ -n "$push" && "$push" != "$fetch" ]]; then printf 'edge'; else printf 'stable'; fi
}

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
    local channel; channel="$(sharkos_channel)"
    info "Pulling latest sharkOS (channel: $channel)..."
    git fetch --tags origin || die "git fetch failed — check your network connection."
    if [[ "$channel" == "edge" ]]; then
        # Bleeding edge (dev boxes): fast-forward ONLY this branch's upstream.
        # Bare `git pull --ff-only` fetches every branch and can fail with
        # "cannot fast-forward to multiple branches"; merging @{u} is
        # deterministic. A box ahead of origin just reports up-to-date.
        git merge --ff-only '@{u}' \
            || die "Can't fast-forward to origin/main (history diverged?). Resolve manually."
    else
        # Stable: check out the newest release tag. Detached HEAD is expected
        # and harmless on a consumer — it never commits.
        local tag; tag="$(git tag --list 'v*' --sort=-v:refname | head -n1)"
        [[ -n "$tag" ]] || die "No release tags found. Push a 'v*' tag, or set channel to edge."
        git checkout --quiet --detach "tags/$tag" || die "Could not check out release $tag."
        info "Checked out release $tag."
    fi
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

# ── Pre-update btrfs snapshot (non-fatal) ───────────────────────────────
# Before mutating the system (pacman -Syu + the config/initramfs/bootloader
# convergence below), snapshot root so a broken upgrade is one rollback away.
# Only runs when root is btrfs; a snapshot failure must NEVER block the update,
# so (like detect_asus) it warns and continues. Prefers snapper when a root
# config exists — it pairs with grub-btrfs boot entries and does its own
# retention — else takes a plain read-only snapshot with bounded retention.
SHARKOS_SNAP_DIR="${SHARKOS_SNAP_DIR:-/.snapshots-sharkos}"
SHARKOS_SNAP_KEEP="${SHARKOS_SNAP_KEEP:-5}"
snapshot_pre_update() {
    local fstype; fstype="$(findmnt -no FSTYPE / 2>/dev/null || true)"
    if [[ "$fstype" != "btrfs" ]]; then
        info "Root is ${fstype:-unknown} (not btrfs) — skipping snapshot."
        return 0
    fi
    local ver; ver="$(tr -d '[:space:]' < "$SHARKOS_DIR/VERSION" 2>/dev/null || echo rolling)"

    if command -v snapper &>/dev/null && sudo snapper -c root list &>/dev/null; then
        info "Taking snapper pre-update snapshot..."
        sudo snapper -c root create -t single -c number -d "sharkos-update pre $ver" \
            || err "snapper snapshot failed — continuing without it."
        return 0
    fi

    info "Taking btrfs pre-update snapshot..."
    sudo mkdir -p "$SHARKOS_SNAP_DIR"
    local snap="$SHARKOS_SNAP_DIR/pre-$ver-$(date +%Y%m%d-%H%M%S)"
    if sudo btrfs subvolume snapshot -r / "$snap" >/dev/null 2>&1; then
        ok "Snapshot: $snap"
        # Prune all but the newest $SHARKOS_SNAP_KEEP.
        local old; mapfile -t old < <(
            sudo ls -1dt "$SHARKOS_SNAP_DIR"/pre-* 2>/dev/null | tail -n +$((SHARKOS_SNAP_KEEP + 1)))
        local s
        for s in "${old[@]}"; do
            sudo btrfs subvolume delete "$s" >/dev/null 2>&1 \
                && info "  pruned $(basename "$s")"
        done
    else
        err "btrfs snapshot failed — continuing without it."
    fi
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
# asusctl is a heavy from-source AUR build (the whole Slint/Rust GUI stack)
# and is the most likely step to fail — notably an OOM kill of rustc on
# low-RAM machines without swap. So its failure is non-fatal: we warn and
# continue rather than aborting the whole sync. This is also why the
# orchestrators run detect_asus LAST, after the Plymouth/greetd/theme
# convergence has already been applied.
detect_asus() {
    if [[ -d /sys/module/asus_wmi ]] || dmidecode -s system-manufacturer 2>/dev/null | grep -qi asus; then
        info "ASUS hardware detected, installing asusctl..."
        if yay -S "${YAY_FLAGS[@]}" asusctl; then
            ok "asusctl installed."
        else
            err "asusctl build failed (often an OOM kill of rustc on low-RAM/no-swap machines)."
            err "Everything else is applied; re-run later or build asusctl manually with limited jobs."
        fi
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

# ── Gaming features (opt-in) ────────────────────────────────────────────
# Windows-game support: Steam + Proton, performance tooling, and the 32-bit
# GPU drivers matching the detected hardware. The 64-bit drivers come from
# detect_gpu; this adds the lib32 counterparts so 32-bit games/Proton runtimes
# work. Idempotent (pacman --needed), so update.sh can re-run it safely.
install_gaming() {
    info "Installing gaming features (Steam + Proton)..."

    # 32-bit game libraries live in the [multilib] repo — enable it if needed.
    if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
        info "  Enabling [multilib] repository (required for Steam/Proton)..."
        sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
        sudo pacman -Sy --noconfirm
    fi

    # Common repo packages (Steam, perf tools, 32-bit Vulkan loader).
    local PKGS=()
    mapfile -t PKGS < <(grep -vE '^#|^$' "$SHARKOS_DIR/packages/gaming-pacman.txt")

    # GPU-specific 32-bit drivers — same PCI-vendor matching as detect_gpu.
    local GPUS; GPUS="$(lspci -nn 2>/dev/null | grep -Ei 'vga|3d|display' || true)"
    if grep -qiE '\[10de:' <<<"$GPUS"; then
        info "  NVIDIA GPU — adding lib32 driver + PRIME render offload"
        PKGS+=(lib32-nvidia-utils nvidia-prime)
    fi
    if grep -qiE '\[1002:' <<<"$GPUS"; then
        info "  AMD GPU — adding lib32 Vulkan/Mesa"
        PKGS+=(lib32-vulkan-radeon lib32-mesa)
    fi
    if grep -qiE '\[8086:' <<<"$GPUS"; then
        info "  Intel GPU — adding lib32 Vulkan/Mesa"
        PKGS+=(lib32-vulkan-intel lib32-mesa)
    fi

    sudo pacman -S --needed --noconfirm "${PKGS[@]}"

    # AUR: Proton-GE manager + Epic/GOG launcher.
    info "  Installing AUR gaming tools..."
    grep -vE '^#|^$' "$SHARKOS_DIR/packages/gaming-aur.txt" | \
        yay -S "${YAY_FLAGS[@]}" -

    ok "Gaming features installed."
}

# Install-time prompt. Records the choice in $SHARKOS_STATE/gaming so
# sharkos-update keeps it in sync without re-asking. Honors SHARKOS_GAMING for
# unattended installs and defaults to "no" when there's no terminal to prompt.
configure_gaming() {
    local choice flag="$SHARKOS_STATE/gaming"
    mkdir -p "$SHARKOS_STATE"

    if [[ -n "${SHARKOS_GAMING:-}" ]]; then
        case "${SHARKOS_GAMING,,}" in
            y|yes|on|1|true) choice=yes ;;
            *)               choice=no ;;
        esac
        info "Gaming features: '$choice' (from SHARKOS_GAMING)"
    elif [[ -r /dev/tty ]]; then
        local ans=""
        printf '\n  Install gaming features (Steam + Proton, Windows-game support)? [y/N] ' > /dev/tty
        read -r ans < /dev/tty || true
        [[ "${ans,,}" == y* ]] && choice=yes || choice=no
    else
        info "No terminal for the gaming prompt; skipping (set SHARKOS_GAMING=yes to force)."
        choice=no
    fi

    echo "$choice" > "$flag"
    if [[ "$choice" == yes ]]; then
        install_gaming
    else
        info "Skipping gaming features."
    fi
}

# Update-time sync: re-run install_gaming only on machines that opted in, so
# gaming packages stay current. Never prompts.
sync_gaming() {
    if [[ "$(cat "$SHARKOS_STATE/gaming" 2>/dev/null)" == yes ]]; then
        install_gaming
    else
        info "Gaming features not enabled on this machine; skipping."
    fi
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
    local CONFIG_DIRS=(hypr waybar walker swayosd swaync ghostty swappy elephant themes jolt btop nvim)
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

# ── OS branding: os-release as SharkOS (idempotent) ─────────────────────
# /etc/os-release is the canonical OS identity that fastfetch/neofetch, systemd,
# login, desktop "About" panels and jolt all read. On Arch it's a symlink to the
# filesystem-package-owned /usr/lib/os-release; the symlink itself is unowned by
# pacman, so we shadow it with a regular file carrying SharkOS branding. We keep
# ID=arch (and BUILD_ID, support URLs) so yay/AUR/pacman tooling that keys off
# the distro id keeps working — only the user-facing name/version are rebranded.
# Reversible: `sudo ln -sf ../usr/lib/os-release /etc/os-release`.
brand_os_release() {
    local ver; ver="$(tr -d '[:space:]' < "$SHARKOS_DIR/VERSION" 2>/dev/null)"
    [[ -n "$ver" ]] || ver="rolling"
    info "Branding os-release as SharkOS $ver..."

    # Idempotent: skip if already branded to this exact version.
    if [[ -f /etc/os-release && ! -L /etc/os-release ]] && \
       grep -q '^NAME="SharkOS"' /etc/os-release && \
       grep -q "^VERSION_ID=\"$ver\"\$" /etc/os-release; then
        ok "os-release already branded (SharkOS $ver)."
        return 0
    fi

    local tmp; tmp="$(mktemp)"
    # Inherit Arch's os-release, then override the branding-relevant fields.
    grep -vE '^(NAME|PRETTY_NAME|VERSION|VERSION_ID|ANSI_COLOR|HOME_URL)=' \
        /usr/lib/os-release > "$tmp"
    {
        echo 'NAME="SharkOS"'
        echo "PRETTY_NAME=\"SharkOS $ver\""
        echo "VERSION=\"$ver\""
        echo "VERSION_ID=\"$ver\""
        echo 'ANSI_COLOR="38;2;130;251;156"'   # SharkOS signature green
        echo 'HOME_URL="https://github.com/consistentinquiry/SharkOS"'
    } >> "$tmp"
    # --remove-destination replaces the symlink with a real file rather than
    # following it and clobbering the package-owned /usr/lib/os-release.
    sudo cp --remove-destination "$tmp" /etc/os-release
    sudo chmod 644 /etc/os-release
    rm -f "$tmp"
    ok "os-release branded — SharkOS $ver everywhere (fastfetch, login, jolt, …)."
}

# ── PipeWire user services ──────────────────────────────────────────────
enable_pipewire() {
    info "Enabling PipeWire user services..."
    systemctl --user enable --now pipewire.service 2>/dev/null || true
    systemctl --user enable --now pipewire-pulse.service 2>/dev/null || true
    systemctl --user enable --now wireplumber.service 2>/dev/null || true
    ok "PipeWire enabled."
}

# ── Bluetooth: BlueZ config (idempotent) ─────────────────────────────────
# Bluetooth is intentionally NOT enabled here — the BlueZ stack is installed so
# it's ready to go, but bluetooth.service is left for the user to opt into
# (`systemctl enable --now bluetooth` or the waybar icon). We do prepare its
# config though: flip BlueZ's Experimental flag under [General], which AirPods
# (and many modern devices) need for battery reporting and reliable handling.
# We only touch that one key, and only restart bluetooth.service if the user has
# already turned it on — we never start it here.
configure_bluetooth() {
    local conf="/etc/bluetooth/main.conf"
    if [[ ! -f "$conf" ]]; then
        info "No $conf yet (bluez not installed?) — skipping Bluetooth config."
        return 0
    fi

    if grep -qE '^[[:space:]]*Experimental[[:space:]]*=[[:space:]]*true' "$conf"; then
        ok "BlueZ Experimental already enabled."
    else
        info "Enabling BlueZ Experimental features (AirPods battery/handling)..."
        if grep -qE '^[[:space:]]*#?[[:space:]]*Experimental[[:space:]]*=' "$conf"; then
            # Replace the existing (commented or not) Experimental line in place.
            sudo sed -i -E 's/^[[:space:]]*#?[[:space:]]*Experimental[[:space:]]*=.*/Experimental = true/' "$conf"
        elif grep -qE '^\[General\]' "$conf"; then
            # Insert right after the [General] header.
            sudo sed -i -E '/^\[General\]/a Experimental = true' "$conf"
        else
            # No [General] section — append one.
            printf '\n[General]\nExperimental = true\n' | sudo tee -a "$conf" >/dev/null
        fi
        ok "BlueZ Experimental enabled."
    fi

    # Apply now only if the user has already opted Bluetooth on.
    if systemctl is-active --quiet bluetooth.service; then
        sudo systemctl restart bluetooth.service && info "  Restarted bluetooth.service."
    fi
}

# ── Record the applied version ──────────────────────────────────────────
# Stamp the version this machine is now at (the repo's VERSION, post-pull)
# into machine-local state. The waybar update indicator compares this against
# the latest available version; when they match, the icon hides. We also poke
# waybar (SIGRTMIN+9, the custom/update module's signal) for an instant refresh.
# (SHARKOS_STATE is defined above, near sharkos_channel.)
record_version() {
    local ver
    ver="$(tr -d '[:space:]' < "$SHARKOS_DIR/VERSION" 2>/dev/null)"
    [[ -n "$ver" ]] || { err "No VERSION file in repo — skipping version stamp."; return; }
    mkdir -p "$SHARKOS_STATE"
    printf '%s\n' "$ver" > "$SHARKOS_STATE/version"
    ok "Recorded sharkOS version $ver."
    pkill -RTMIN+9 waybar 2>/dev/null || true
}

# ── Expose `sharkos-update` on PATH (symlink → repo update.sh) ──────────
# A symlink (not a copy) so it auto-tracks the repo on every machine.
link_self() {
    if [[ "$(readlink -f /usr/local/bin/sharkos-update 2>/dev/null)" != "$SHARKOS_DIR/update.sh" ]]; then
        sudo ln -sf "$SHARKOS_DIR/update.sh" /usr/local/bin/sharkos-update
        ok "sharkos-update linked into /usr/local/bin."
    fi
}
