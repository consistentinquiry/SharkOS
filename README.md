# sharkOS

A minimal, opinionated Arch Linux desktop built on Hyprland.

## What you get

- **Hyprland** window manager
- **Waybar** status bar
- **Walker + Elephant** application launcher
- **SwayOSD** volume/brightness overlay
- **Mako** notifications
- **Ghostty** terminal
- **System-wide theming** — a `noir` default plus 21 Omarchy-derived themes, switchable from one menu (palette, wallpaper, and corner style apply across waybar, walker, terminal, mako, swayosd, hyprlock & hyprland borders)
- **Plymouth** themed boot splash (supports LUKS encryption)
- **greetd + tuigreet** login manager
- **PipeWire** audio stack

## Install

**From the SharkOS ISO** (recommended): boot the ISO and run `sharkos-install`. It
installs a base Arch system (mark your user as a **superuser** when prompted). After you
reboot, the full SharkOS desktop installs itself automatically on first boot, then reboots
into SharkOS — no manual second step.

**On an existing Arch install:**

```bash
curl -fsSL https://raw.githubusercontent.com/consistentinquiry/SharkOS/main/install.sh | bash
```

Reboot when done.

## Building the ISO

The ISO layers SharkOS onto Arch's official `releng` archiso profile (no fork).

```bash
sudo pacman -S --needed archiso qemu-base edk2-ovmf   # build + test deps
./build-iso.sh                  # -> dist/sharkos-*.iso  (runs sudo mkarchiso)
./scripts/test-iso.sh           # boot the newest ISO in QEMU (UEFI) to test
```

Install flow is two-stage, both automatic: the ISO's `sharkos-install` lays down base
Arch via `archinstall` (disk/user interactive, SharkOS defaults from
`iso/archinstall/sharkos.json`). That enables a one-shot `sharkos-firstboot.service`
(installed from `iso/target/`) which, on the new system's first boot, runs `install.sh`
as the user to install the desktop and then reboots into SharkOS.

## How it works

The install script:
1. Clones this repo to `~/Git/sharkOS`
2. Installs all packages (official + AUR via yay)
3. Symlinks configs from the repo to `~/.config/`
4. Selects the right wallpaper resolution for your display
5. Generates the themes (clones the upstream omarchy palettes) and applies the `noir` default
6. Sets up Plymouth boot splash (auto-detects LUKS vs unencrypted)
7. Configures greetd login manager

## Theming

Themes live in `config/themes/`. Each theme is a `theme.conf` of variables; an engine
expands `templates/*.tpl` into the real app configs and reloads everything.

- **Switch themes:** open the hub menu → **Themes** (or run `~/.config/themes/apply-theme.sh <name>`).
- **`noir`** is the hand-made default (rounded corners, shark wallpaper).
- **`omarchy-*`** themes are generated from the upstream [omarchy](https://github.com/basecamp/omarchy)
  palettes by `config/themes/generate-omarchy-themes.sh` (squared corners, per-theme wallpaper).
  They are **not committed** (`.gitignore`d) — they're rebuilt at install time, or any time via:

  ```bash
  ~/.config/themes/generate-omarchy-themes.sh
  ```

> Note: switching themes rewrites the rendered app configs (waybar `style.css`, ghostty
> `config`, etc.), so those files will show as changes in `git status`. Commit them only
> if you want to change the tracked default.

## Editing configs

Since configs are symlinked, editing `~/.config/hypr/hyprland.conf` on your live system is editing the repo file directly. When you're happy with changes:

```bash
cd ~/Git/sharkOS
git add -A && git commit -m "update hyprland config"
git push
```

## Versioning & updates

The repo carries a `VERSION` file (SemVer). **Bump it on every change** —
`scripts/bump-version.sh [major|minor|patch]` (default `patch`) — then commit
and push.

Each machine records the version it last applied (`~/.local/state/sharkos/version`,
written when `install.sh`/`sharkos-update` finishes). A waybar indicator
(`󰚰`, left of the clock) appears whenever the recorded version differs from the
latest on `origin/main`; **click it to run `sharkos-update`**. It hides again
once the machine is current. Update from any machine with `git push` here →
`sharkos-update` (or the icon) on the others.

## Structure

```
config/       Mirrors ~/.config/ (symlinked at install)
config/themes/  Theming engine, templates, and the noir theme
packages/     Package lists (pacman.txt, aur.txt)
plymouth/     Boot splash theme
wallpaper/    Desktop wallpapers at multiple resolutions
scripts/      Helper scripts (package audit, ISO test)
greetd/       Login manager config
iso/          ISO overlay (live installer, archinstall config) layered on releng
iso/target/   Files installed into the target system (first-boot desktop install)
install.sh    Desktop setup (run automatically on first boot, or manually)
build-iso.sh  Builds the live/installer ISO
```

## Requirements

- Arch Linux (base install)
- Internet connection
- Non-root user with sudo access
