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
    info "  Cloning upstream omarchy (theme source)..."
    git clone --depth 1 https://github.com/basecamp/omarchy.git "$OMARCHY_DIR"
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

if echo "$CURRENT_HOOKS" | grep -q 'sd-encrypt'; then
    # systemd-based LUKS
    info "  Detected systemd-based LUKS encryption"
    if ! echo "$CURRENT_HOOKS" | grep -q 'sd-plymouth'; then
        NEW_HOOKS=$(echo "$CURRENT_HOOKS" | sed 's/kms/kms sd-plymouth/')
        patch_hooks "$NEW_HOOKS"
    else
        ok "  sd-plymouth already in HOOKS"
    fi
elif echo "$CURRENT_HOOKS" | grep -q 'encrypt'; then
    # Traditional LUKS
    info "  Detected traditional LUKS encryption"
    if ! echo "$CURRENT_HOOKS" | grep -q 'plymouth-encrypt'; then
        # Add plymouth after kms, replace encrypt with plymouth-encrypt
        NEW_HOOKS=$(echo "$CURRENT_HOOKS" | sed 's/kms/kms plymouth/' | sed 's/ encrypt/ plymouth-encrypt/')
        patch_hooks "$NEW_HOOKS"
    else
        ok "  plymouth-encrypt already in HOOKS"
    fi
else
    # No encryption
    info "  No LUKS encryption detected"
    if ! echo "$CURRENT_HOOKS" | grep -q 'plymouth'; then
        NEW_HOOKS=$(echo "$CURRENT_HOOKS" | sed 's/kms/kms plymouth/')
        patch_hooks "$NEW_HOOKS"
    else
        ok "  plymouth already in HOOKS"
    fi
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
