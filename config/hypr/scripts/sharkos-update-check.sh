#!/bin/bash
# Waybar custom/update module source.
#
# Emits JSON describing whether a sharkOS update is available. The module is
# hidden whenever the running version matches the latest, because waybar hides
# a custom module whose "text" is empty.
#
#   running  = the version this machine last applied (state file written by
#              record_version() at the end of install.sh / update.sh)
#   latest   = the version origin/main advertises (best-effort fetch), falling
#              back to the local working-tree VERSION when offline, and finally
#              to `running` so we never raise a false alarm.

REPO="${SHARKOS_DIR:-$HOME/Git/sharkOS}"
STATE="${SHARKOS_STATE:-$HOME/.local/state/sharkos}/version"
# Remembers the version we last sent a desktop notification for, so the check
# (run every interval and on every manual poll) notifies once per new release
# instead of re-spamming. Cleared again once the machine is up to date.
NOTIFIED="${SHARKOS_STATE:-$HOME/.local/state/sharkos}/notified"

running=""
[ -f "$STATE" ] && running="$(tr -d '[:space:]' < "$STATE")"
[ -n "$running" ] || running="0.0.0"

latest=""
if [ -d "$REPO/.git" ]; then
    # Update remote-tracking refs + tags without touching the working tree.
    # Time-boxed so a slow/offline network can't stall the bar.
    timeout 8 git -C "$REPO" fetch --quiet --tags origin main 2>/dev/null
    # Same channel inference as sharkos_channel() in the lib (kept inline so
    # this hot-path exec has no sourcing dependency): explicit override wins,
    # else a dev box (separate SSH push URL) is edge, a consumer is stable.
    channel=""
    [ -f "${SHARKOS_STATE:-$HOME/.local/state/sharkos}/channel" ] && \
        channel="$(tr -d '[:space:]' < "${SHARKOS_STATE:-$HOME/.local/state/sharkos}/channel")"
    case "$channel" in
        edge|stable) ;;
        *)  f="$(git -C "$REPO" remote get-url origin 2>/dev/null)"
            p="$(git -C "$REPO" remote get-url --push origin 2>/dev/null)"
            if [ -n "$p" ] && [ "$p" != "$f" ]; then channel=edge; else channel=stable; fi ;;
    esac
    if [ "$channel" = "edge" ]; then
        latest="$(git -C "$REPO" show origin/main:VERSION 2>/dev/null | tr -d '[:space:]')"
    else
        latest="$(git -C "$REPO" tag --list 'v*' --sort=-v:refname | head -n1 | sed 's/^v//')"
    fi
fi
# Offline fallback: whatever the local checkout knows (catches a local bump too).
[ -n "$latest" ] || { [ -f "$REPO/VERSION" ] && latest="$(tr -d '[:space:]' < "$REPO/VERSION")"; }
[ -n "$latest" ] || latest="$running"

# An update is available only when `latest` is strictly NEWER than `running`
# (SemVer order). A plain `!=` would also fire on a dev box whose local working
# tree is ahead of origin (running > latest), showing a bogus downgrade arrow
# that never clears.
newest="$(printf '%s\n%s\n' "$running" "$latest" | sort -V | tail -n1)"
if [ "$running" != "$latest" ] && [ "$newest" = "$latest" ]; then
    # Fire a one-shot desktop notification for this new version. Only when we
    # haven't already notified for this exact "latest", so neither the 30-minute
    # interval nor a manual poll re-spams it. Best-effort: needs a notif daemon.
    seen=""
    [ -f "$NOTIFIED" ] && seen="$(tr -d '[:space:]' < "$NOTIFIED")"
    if [ "$seen" != "$latest" ] && command -v notify-send >/dev/null 2>&1; then
        notify-send -a sharkOS -i system-software-update -u normal \
            "sharkOS update available" \
            "$(printf '%s → %s\nOpen the menu or run sharkos-update.' "$running" "$latest")" \
            2>/dev/null
        mkdir -p "$(dirname "$NOTIFIED")" 2>/dev/null
        printf '%s\n' "$latest" > "$NOTIFIED"
    fi

    printf '{"text":"󰚰","tooltip":"sharkOS update available\\n%s → %s\\nClick to update","class":"update-available"}\n' \
        "$running" "$latest"
else
    # Up to date: drop the marker so the next new version notifies afresh.
    rm -f "$NOTIFIED" 2>/dev/null
    printf '{"text":"","tooltip":"","class":"up-to-date"}\n'
fi
