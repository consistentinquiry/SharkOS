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
# No `-e` here: the progress runner inspects each step's exit code itself (each
# step runs in its own `set -e` subshell), so a failure is reported with a log
# path instead of aborting the script silently mid-bar.
set -uo pipefail

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

# ── Pretty UI: credential prompts + progress bar ────────────────────────
# Front-load the two interactive prompts (SSH key passphrase for the pull, sudo
# password for pacman), then run every step non-interactively behind a progress
# bar with all command output captured to a log. On failure we surface the log
# location rather than a wall of red text.
LOG="$HOME/.local/state/sharkos/update.log"
SPIN=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
BAR_WIDTH=28
STEP=0
TOTAL=0
SUDO_KEEPALIVE=""
SHARKOS_SSH_AGENT=""

# Read a secret from the terminal with a styled one-line prompt. The secret is
# printed on stdout; all chrome goes to stderr so $(ask_secret …) captures only
# the secret.
ask_secret() {
    local prompt="$1" secret=""
    printf '\n  %b▸%b %s ' "${GREEN}${BOLD}" "${RESET}" "$prompt" >&2
    read -rs secret < /dev/tty
    printf '\n' >&2
    printf '%s' "$secret"
}

# Authenticate sudo once up front, then keep the timestamp warm so a long run
# never re-prompts mid-progress.
request_sudo() {
    if sudo -n true 2>/dev/null; then return 0; fi
    local pw tries=0
    while (( tries < 3 )); do
        pw="$(ask_secret 'Enter your sudo password:')"
        if printf '%s\n' "$pw" | sudo -S -v 2>/dev/null; then
            unset pw
            ok "sudo authenticated."
            ( while sleep 30; do
                  kill -0 "$$" 2>/dev/null || exit
                  sudo -n -v 2>/dev/null || exit
              done ) &
            SUDO_KEEPALIVE=$!
            return 0
        fi
        tries=$((tries + 1))
        err "  Incorrect password (${tries}/3)."
    done
    die "Could not authenticate with sudo."
}

# If the repo uses an SSH remote and no key is loaded in an agent, unlock it now
# with a styled prompt (via an SSH_ASKPASS helper) so the pull doesn't stop to
# ask. Best-effort: if it doesn't load, the foreground pull falls back to ssh's
# own prompt, which is safe.
ensure_ssh_key() {
    case "$(git -C "$SHARKOS_DIR" remote get-url origin 2>/dev/null)" in
        git@*|ssh://*) ;;
        *) return 0 ;;
    esac
    ssh-add -l >/dev/null 2>&1 && return 0          # already unlocked
    if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then          # no agent — start one
        eval "$(ssh-agent -s)" >/dev/null 2>&1 || return 0
        SHARKOS_SSH_AGENT="${SSH_AGENT_PID:-}"
    fi
    local askpass; askpass="$(mktemp)"
    cat >"$askpass" <<'EOS'
#!/bin/bash
printf '\n  \033[1;32m▸\033[0m %s ' "$1" >/dev/tty
read -rs p </dev/tty; printf '\n' >/dev/tty
printf '%s' "$p"
EOS
    chmod +x "$askpass"
    SSH_ASKPASS="$askpass" SSH_ASKPASS_REQUIRE=force DISPLAY="${DISPLAY:-:0}" \
        ssh-add </dev/null >/dev/null 2>&1 || true
    rm -f "$askpass"
}

# Render the single-line progress bar. $1 = leading glyph, $2 = label.
draw_bar() {
    local glyph="$1" label="$2" filled k bar=""
    filled=$(( STEP * BAR_WIDTH / TOTAL ))
    for ((k = 0; k < filled; k++)); do bar+="█"; done
    for ((k = filled; k < BAR_WIDTH; k++)); do bar+="░"; done
    printf '\r  %b%s%b %b%3d%%%b %b(%d/%d)%b  %s %s\033[K' \
        "${GREEN}" "$bar" "${RESET}" \
        "${BOLD}" "$(( STEP * 100 / TOTAL ))" "${RESET}" \
        "${BLUE}" "$STEP" "$TOTAL" "${RESET}" \
        "$glyph" "$label" >&2
}

# Stop the keep-alive / ssh-agent we started.
_cleanup() {
    [[ -n "$SUDO_KEEPALIVE" ]] && kill "$SUDO_KEEPALIVE" 2>/dev/null
    [[ -n "$SHARKOS_SSH_AGENT" ]] && kill "$SHARKOS_SSH_AGENT" 2>/dev/null
    SUDO_KEEPALIVE=""; SHARKOS_SSH_AGENT=""
}

update_failed() {
    local label="$1"
    printf '\r\033[K' >&2
    _cleanup
    {
        echo
        printf '  %b✗ Error during update%b — failed while: %b%s%b\n' \
            "${RED}${BOLD}" "${RESET}" "${BOLD}" "$label" "${RESET}"
        printf '  A log file has been generated in %b%s%b\n\n' \
            "${BOLD}" "$LOG" "${RESET}"
        printf '  %blast lines of the log:%b\n' "${BLUE}" "${RESET}"
        tail -n 12 "$LOG" 2>/dev/null | sed 's/^/    /'
        echo
    } >&2
    exit 1
}

# Run one step in a clean (set -e) subshell, output → log, animating the bar.
run_step() {
    local label="$1"; shift
    draw_bar "${SPIN[0]}" "$label"
    ( set -euo pipefail; "$@" ) >>"$LOG" 2>&1 </dev/null &
    local pid=$! i=0
    while kill -0 "$pid" 2>/dev/null; do
        draw_bar "${SPIN[i % ${#SPIN[@]}]}" "$label"
        i=$((i + 1)); sleep 0.1
    done
    local rc=0; wait "$pid" || rc=$?
    (( rc != 0 )) && update_failed "$label"
    STEP=$((STEP + 1))
    draw_bar "✓" "$label"
}

# ── Run ─────────────────────────────────────────────────────────────────
print_banner
preflight
ensure_ssh_key
sync_repo "$STASH"          # foreground: dirty-tree guidance + pull stay visible
request_sudo

mkdir -p "$(dirname "$LOG")"
: > "$LOG"
TOTAL=$(( 16 + DO_UPGRADE ))

[[ "$DO_UPGRADE" == "1" ]] && run_step "Upgrading system packages" system_upgrade
run_step "Setting up yay"            ensure_yay
run_step "Installing packages"       install_packages
run_step "Configuring GPU drivers"   detect_gpu
run_step "Preparing directories"     ensure_dirs
run_step "Linking configs"           symlink_configs
run_step "Setting wallpaper"         setup_wallpaper
run_step "Generating themes"         generate_themes
run_step "Applying theme"            apply_active_theme preserve
run_step "Installing boot splash"    install_plymouth
run_step "Configuring bootloader"    configure_bootloader_splash
run_step "Configuring login manager" configure_greetd
run_step "Branding SharkOS"          brand_os_release
run_step "Enabling audio"            enable_pipewire
run_step "Linking updater"           link_self
run_step "Checking ASUS hardware"    detect_asus
run_step "Recording version"         record_version

_cleanup
printf '\r\033[K' >&2

# ── Done ──────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}════════════════════════════════════════${RESET}"
echo -e "${GREEN}${BOLD}  SharkOS is up to date!                ${RESET}"
echo -e "${GREEN}${BOLD}════════════════════════════════════════${RESET}"
echo ""
echo -e "  If the boot splash or login manager changed, reboot to apply."
echo ""
