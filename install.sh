#!/bin/bash
# ┌──────────────────────────────────────────────────────────────────┐
# │  sharkOS Installer                                               │
# │  Installs the full sharkOS desktop on a base Arch Linux system   │
# │  Usage: curl -fsSL http://sharkos.io/install.sh | bash           │
# └──────────────────────────────────────────────────────────────────┘
set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────
SHARKOS_REPO="https://github.com/consistentinquiry/SharkOS.git"
SHARKOS_DIR="$HOME/Git/sharkOS"
BOLD='\033[1m'
BLUE='\033[1;34m'
GREEN='\033[1;32m'
RED='\033[1;31m'
RESET='\033[0m'

info()  { echo -e "${BLUE}[sharkOS]${RESET} $*"; }
ok()    { echo -e "${GREEN}[sharkOS]${RESET} $*"; }
err()   { echo -e "${RED}[sharkOS]${RESET} $*" >&2; }
die()   { err "$*"; exit 1; }

# ── Preflight checks ─────────────────────────────────────────────────
[[ -f /etc/arch-release ]] || die "This script only runs on Arch Linux."
[[ "$EUID" -ne 0 ]] || die "Do not run as root. The script will use sudo when needed."

info "Starting sharkOS installation..."

# ── Clone or update repo ─────────────────────────────────────────────
if [[ -d "$SHARKOS_DIR/.git" ]]; then
    info "Updating existing sharkOS repo..."
    git -C "$SHARKOS_DIR" pull --ff-only || true
else
    info "Cloning sharkOS repo..."
    mkdir -p "$(dirname "$SHARKOS_DIR")"
    git clone "$SHARKOS_REPO" "$SHARKOS_DIR"
fi

cd "$SHARKOS_DIR"

# ── System update ────────────────────────────────────────────────────
info "Updating system packages..."
sudo pacman -Syu --noconfirm

# ── Install yay (AUR helper) ─────────────────────────────────────────
if ! command -v yay &>/dev/null; then
    info "Installing yay..."
    sudo pacman -S --needed --noconfirm base-devel git
    tmpdir=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
    (cd "$tmpdir/yay" && makepkg -si --noconfirm)
    rm -rf "$tmpdir"
    ok "yay installed."
else
    ok "yay already installed."
fi

# ── Install official packages ─────────────────────────────────────────
info "Installing official packages..."
grep -v '^#' packages/pacman.txt | grep -v '^$' | \
    sudo pacman -S --needed --noconfirm -

# ── Install AUR packages ─────────────────────────────────────────────
info "Installing AUR packages..."
# Non-interactive flags so the AUR build never tries to open /dev/tty for a
# diff/edit/clean/provider menu (which fails outside a real terminal).
YAY_FLAGS=(--needed --noconfirm --answerdiff=None --answeredit=None --answerclean=None --removemake)
grep -vE '^#|^$' packages/aur.txt | \
    yay -S "${YAY_FLAGS[@]}" -

# ── Hardware detection ────────────────────────────────────────────────
if [[ -d /sys/module/asus_wmi ]] || dmidecode -s system-manufacturer 2>/dev/null | grep -qi asus; then
    info "ASUS hardware detected, installing asusctl..."
    yay -S "${YAY_FLAGS[@]}" asusctl
    ok "asusctl installed."
else
    info "Non-ASUS hardware detected, skipping asusctl."
    # Remove ASUS-specific keybinds from hyprland config if not already removed
    # These binds will just be no-ops on non-ASUS hardware (XF86Launch keys won't exist)
fi

# ── GPU detection & drivers ───────────────────────────────────────────
# Detect the graphics stack and install the matching drivers. NVIDIA also gets
# the kernel-cmdline + env tweaks Hyprland needs; AMD/Intel ride on Mesa. In a
# VM we install guest tooling and (for VirtualBox) force Mesa's software path,
# since VMSVGA 3D is unreliable under Wayland.
info "Detecting graphics hardware..."

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

VIRT="$(systemd-detect-virt 2>/dev/null || true)"
[[ -n "$VIRT" ]] || VIRT="none"

if [[ "$VIRT" != "none" ]]; then
    # ---- Virtual machine ----
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
else
    # ---- Bare metal: detect by PCI vendor ----
    command -v lspci &>/dev/null || sudo pacman -S --needed --noconfirm pciutils
    GPUS="$(lspci -nn | grep -Ei 'vga|3d|display' || true)"
    echo "$GPUS" | sed 's/^/  /'

    # Match on PCI vendor IDs (NVIDIA 10de, AMD 1002, Intel 8086) rather than
    # names — substrings like "ati" would otherwise match "CorporATIon".
    has_nvidia=false; has_amd=false; has_intel=false
    grep -qiE '\[10de:' <<<"$GPUS" && has_nvidia=true
    grep -qiE '\[1002:' <<<"$GPUS" && has_amd=true
    grep -qiE '\[8086:' <<<"$GPUS" && has_intel=true

    # Mesa is the GL/EGL stack for AMD + Intel (and software fallback everywhere).
    PKGS=(mesa)
    $has_amd   && { info "  AMD GPU detected";   PKGS+=(vulkan-radeon libva-mesa-driver); }
    $has_intel && { info "  Intel GPU detected"; PKGS+=(vulkan-intel intel-media-driver); }
    sudo pacman -S --needed --noconfirm "${PKGS[@]}"

    if $has_nvidia; then
        info "  NVIDIA GPU detected — installing nvidia-open-dkms stack..."
        # DKMS needs headers for every installed kernel so the module rebuilds on upgrade.
        HEADERS=()
        for k in linux linux-lts linux-zen linux-hardened; do
            pacman -Qq "$k" &>/dev/null && HEADERS+=("${k}-headers")
        done
        sudo pacman -S --needed --noconfirm \
            nvidia-open-dkms nvidia-utils egl-wayland libva-nvidia-driver dkms "${HEADERS[@]}"

        # Early KMS: load the nvidia modules from the initramfs (rebuilt below; the
        # Plymouth step rebuilds again, which is harmless).
        if ! grep -q 'nvidia_drm' /etc/mkinitcpio.conf; then
            sudo sed -i 's/^MODULES=(\(.*\))/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
            info "  Added nvidia modules to mkinitcpio MODULES"
        fi
        sudo mkinitcpio -P

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
fi

# ── Create directories ────────────────────────────────────────────────
info "Creating directories..."
mkdir -p "$HOME/Pictures/Screenshots"
mkdir -p "$HOME/.config"

# ── Symlink config directories ────────────────────────────────────────
info "Symlinking config files..."

CONFIG_DIRS=(
    hypr
    waybar
    walker
    swayosd
    mako
    ghostty
    swappy
    elephant
    themes
)

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

# ── Wallpaper ─────────────────────────────────────────────────────────
info "Setting up wallpaper..."
export SHARKOS_DIR
bash "$SHARKOS_DIR/scripts/select_wallpaper.sh"

# ── Themes (generate Omarchy-derived themes + apply default) ──────────
# The omarchy-* themes are not committed (regenerable); build them from the
# upstream omarchy palettes, then apply the default 'noir' theme.
info "Generating themes..."
OMARCHY_DIR="$HOME/Git/omarchy"
if [[ ! -d "$OMARCHY_DIR/.git" ]]; then
    # We only use omarchy as a palette/wallpaper source, so fetch just
    # themes/<name>/colors.toml + backgrounds/ — not the whole project, and
    # not the per-theme preview/unlock images or app theme files. Shallow +
    # blobless + sparse (non-cone patterns) keeps the download minimal.
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
info "Applying default theme (noir)..."
bash "$HOME/.config/themes/apply-theme.sh" noir || true
ok "Themes generated and noir applied."

# ── Plymouth boot splash ─────────────────────────────────────────────
info "Installing Plymouth theme..."

# Copy theme files
sudo mkdir -p /usr/share/plymouth/themes/sharkos
sudo cp -r "$SHARKOS_DIR/plymouth/sharkos/"* /usr/share/plymouth/themes/sharkos/

# Detect encryption setup and patch mkinitcpio.conf
MKINITCPIO="/etc/mkinitcpio.conf"
CURRENT_HOOKS=$(grep '^HOOKS=' "$MKINITCPIO")

patch_hooks() {
    local new_hooks="$1"
    sudo sed -i "s/^HOOKS=.*/$new_hooks/" "$MKINITCPIO"
    info "  Updated mkinitcpio HOOKS"
}

# Add the `plymouth` initcpio hook. NOTE: current plymouth ships only the
# `plymouth` hook — `plymouth-encrypt` and `sd-plymouth` were removed upstream,
# so we must not reference them. Place plymouth early so the splash is up
# before the LUKS prompt: after `systemd` on a systemd initramfs (where
# systemd-ask-password renders the *themed* prompt via Plymouth), otherwise
# after `kms`. (A busybox `encrypt` setup gets the splash but an unthemed
# prompt, since that hook has no Plymouth integration — SharkOS installs use
# sd-encrypt for the themed prompt.)
if echo "$CURRENT_HOOKS" | grep -qw 'plymouth'; then
    ok "  plymouth hook already present"
elif echo "$CURRENT_HOOKS" | grep -qw 'systemd'; then
    info "  systemd initramfs detected — adding plymouth after systemd"
    patch_hooks "$(echo "$CURRENT_HOOKS" | sed 's/\bsystemd\b/systemd plymouth/')"
else
    info "  busybox initramfs detected — adding plymouth after kms"
    patch_hooks "$(echo "$CURRENT_HOOKS" | sed 's/\bkms\b/kms plymouth/')"
fi

# Ensure kms hook is present (required for Plymouth)
if ! grep '^HOOKS=' "$MKINITCPIO" | grep -q 'kms'; then
    info "  Adding kms hook (required for Plymouth)..."
    CURRENT=$(grep '^HOOKS=' "$MKINITCPIO")
    NEW=$(echo "$CURRENT" | sed 's/autodetect/autodetect kms/')
    sudo sed -i "s/^HOOKS=.*/$NEW/" "$MKINITCPIO"
fi

# Set theme and rebuild initramfs
sudo plymouth-set-default-theme -R sharkos
ok "Plymouth theme installed and initramfs rebuilt."

# Patch bootloader for quiet splash
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
    for entry in /boot/loader/entries/*.conf; do
        if ! grep -q 'splash' "$entry"; then
            sudo sed -i '/^options/ s/$/ quiet splash/' "$entry"
            ok "  Updated $entry"
        fi
    done
else
    err "Could not detect bootloader (GRUB or systemd-boot). Add 'quiet splash' to kernel cmdline manually."
fi

# ── greetd ────────────────────────────────────────────────────────────
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
cat <<'DROPIN' | sudo tee /etc/systemd/system/greetd.service.d/plymouth.conf >/dev/null
[Unit]
After=plymouth-quit-wait.service
DROPIN
ok "greetd configured for Plymouth handoff."

# ── PipeWire user services ───────────────────────────────────────────
info "Enabling PipeWire user services..."
systemctl --user enable --now pipewire.service 2>/dev/null || true
systemctl --user enable --now pipewire-pulse.service 2>/dev/null || true
systemctl --user enable --now wireplumber.service 2>/dev/null || true
ok "PipeWire enabled."

# ── Done ──────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}════════════════════════════════════════${RESET}"
echo -e "${GREEN}${BOLD}  sharkOS installation complete!        ${RESET}"
echo -e "${GREEN}${BOLD}════════════════════════════════════════${RESET}"
echo ""
echo -e "  Reboot to enter sharkOS."
echo -e "  Your configs are symlinked from ${BLUE}$SHARKOS_DIR/config/${RESET}"
echo -e "  Edit them live, then ${BOLD}git commit${RESET} to save changes."
echo ""
