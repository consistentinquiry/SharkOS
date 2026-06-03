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

Start with a base Arch Linux installation, then:

```bash
curl -fsSL http://sharkos.io/install.sh | bash
```

Reboot when done.

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

## Structure

```
config/       Mirrors ~/.config/ (symlinked at install)
config/themes/  Theming engine, templates, and the noir theme
packages/     Package lists (pacman.txt, aur.txt)
plymouth/     Boot splash theme
wallpaper/    Desktop wallpapers at multiple resolutions
scripts/      Helper scripts
greetd/       Login manager config
install.sh    Main installer
```

## Requirements

- Arch Linux (base install)
- Internet connection
- Non-root user with sudo access
