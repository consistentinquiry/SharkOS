# Auto-launch the SharkOS installer on the live console.
# Only on the interactive main console (tty1), and only once per session.
# (Switch to tty2 with Ctrl-Alt-F2 for a plain root shell.)
case "$-" in
  *i*)
    if [ "$(tty)" = "/dev/tty1" ] && [ -z "${SHARKOS_INSTALLER_STARTED:-}" ]; then
      SHARKOS_INSTALLER_STARTED=1
      export SHARKOS_INSTALLER_STARTED
      sharkos-install
    fi
    ;;
esac
