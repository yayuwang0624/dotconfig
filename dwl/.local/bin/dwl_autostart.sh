#!/bin/sh
# dwl session startup.  Launch with:  dwl -s /path/to/startup.sh
# Starts the dwlb bar, its status feeder, and autostart programs.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
FONT="SauceCodePro Nerd Font:size=16"
LOGDIR="${XDG_RUNTIME_DIR:-/tmp}"

# Run "$2 ..." once, unless a process matching "$1" is already running.
run_once() {
	pgrep -f "$1" >/dev/null 2>&1 && return
	shift
	command -v "$1" >/dev/null 2>&1 || return
	"$@" >"$LOGDIR/$1.log" 2>&1 &
}

# XWayland DPI (X11 apps only).
if [ -f "$HOME/.Xresources" ] && command -v xrdb >/dev/null 2>&1; then
	sed -E -i 's/Xft\.dpi:[[:space:]]*[0-9]+/Xft.dpi: 144/g' "$HOME/.Xresources"
	xrdb -merge "$HOME/.Xresources"
fi

# IBus — dwl has no Wayland input-method protocol, so use the env-var path.
# Must be exported before GUI apps launch so they inherit the IM hints.
export XDG_CURRENT_DESKTOP=GNOME   # silences ibus panel "no desktop" warning
export GTK_IM_MODULE=ibus
export QT_IM_MODULE=ibus
export XMODIFIERS=@im=ibus

# Session programs.
run_once emacs             emacs
run_once zen-browser       zen-browser
run_once dunst             dunst
run_once ibus-daemon       ibus-daemon -drx
run_once Discord           discord
run_once monitor_indicator monitor_indicator
run_once volnoti           volnoti      # X11, via XWayland
run_once Snipaste          Snipaste     # X11, via XWayland
run_once kanshi            kanshi       # X11, via XWayland
# NOTE: dwlb has no system tray (StatusNotifier host), so pasystray has
# nowhere to render and is left disabled.
# run_once pasystray       pasystray -S
# Wacom: xsetwacom is X11-only — dwl has no tablet-to-output mapping.

run_once swaybg swaybg \
	-o eDP-1    -i "$HOME/Documents/Wallpapers/mao.jpg" -m fill \
	-o HDMI-A-1 -i "$HOME/Documents/Wallpapers/mao.jpg" -m fill

# Warp the cursor to the primary monitor (DP-1 centre); needs ydotoold.
if command -v ydotool >/dev/null 2>&1; then
	ydotool mousemove --absolute -x $((2160 + 3840 / 2)) -y $((2160 / 2))
fi

# Status feeder: status.sh prints one status line per second on stdout; push
# each line into the running dwlb as its status text. With -ipc, dwlb ignores
# stdin, so the status text must be sent over the `-status` command interface.
# (Runs in the background; it starts succeeding once the exec'd dwlb is up.)
( "$SCRIPT_DIR/status.sh" 2>/dev/null | while IFS= read -r line; do
	dwlb -status all "$line"
done ) &

# The bar — dwlb. -ipc makes it talk to dwl over dwl-ipc-unstable-v2 (tags,
# layout symbol, window title, and clickable tags). Occupied-but-unselected
# tags get a blue underline marker (patched in dwlb.c). exec keeps it as the
# session anchor.
exec dwlb								\
	-ipc								\
	-font "$FONT"							\
	-active-fg-color          "#eeeeeeff"	\
	-active-bg-color          "#6b88caff"	\
	-occupied-fg-color        "#bbbbbbff"	\
	-occupied-bg-color        "#222222ff"	\
	-inactive-fg-color        "#bbbbbbff"	\
	-inactive-bg-color        "#222222ff"	\
	-urgent-fg-color          "#eeeeeeff"	\
	-urgent-bg-color          "#ff0000ff"	\
	-middle-bg-color          "#222222ff"	\
	-middle-bg-color-selected "#6b88caff"   \
	-scale 2
