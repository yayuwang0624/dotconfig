#!/bin/sh
# dwl session startup.  Launch with:  dwl -s /path/to/startup.sh
# Starts the dwlb bar, its status feeder, and autostart programs.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
FONT="SauceCodePro Nerd Font:size=24"
LOGDIR="${XDG_RUNTIME_DIR:-/tmp}"

# Run "$2 ..." once, unless a process matching "$1" is already running.
run_once() {
	pgrep -f "$1" >/dev/null 2>&1 && return
	shift
	command -v "$1" >/dev/null 2>&1 || return
	"$@" >"$LOGDIR/$1.log" 2>&1 &
}

# Status feeder — pipe status.sh into a client dwlb (sleep lets the bar
# create its socket first).
( sleep 1; "$SCRIPT_DIR/status.sh" | dwlb -status-stdin all ) </dev/null >/dev/null 2>&1 &

# XWayland DPI (X11 apps only).
if [ -f "$HOME/.Xresources" ] && command -v xrdb >/dev/null 2>&1; then
	sed -E -i 's/Xft\.dpi:[[:space:]]*[0-9]+/Xft.dpi: 144/g' "$HOME/.Xresources"
	xrdb -merge "$HOME/.Xresources"
fi

# Wallpaper — one image per output (swap -o blocks if they land swapped).
WALL="$HOME/Documents/Wallpapers"
run_once swaybg swaybg \
	-o DP-1     -i "$WALL/mao.jpg"   -m fill \
	-o HDMI-A-1 -i "$WALL/mao_v.png" -m fill

# Session programs.
run_once emacs             emacs
run_once zen-browser       zen-browser
run_once dunst             dunst
run_once ibus-daemon       ibus-daemon -x -d
run_once Discord           discord
run_once monitor_indicator monitor_indicator
run_once volnoti           volnoti      # X11, via XWayland
run_once Snipaste          Snipaste     # X11, via XWayland
# run_once pasystray       pasystray -S # needs a system tray (dwlb has none)
# Wacom: xsetwacom is X11-only — dwl has no tablet-to-output mapping.

# Warp the cursor to the primary monitor (DP-1 centre); needs ydotoold.
if command -v ydotool >/dev/null 2>&1; then
	ydotool mousemove --absolute -x $((2160 + 3840 / 2)) -y $((2160 / 2))
fi

# The bar — exec so dwlb inherits dwl's status stream on stdin.
exec dwlb \
	-font "$FONT" \
	-active-fg-color          "#eeeeeeff" \
	-active-bg-color          "#6b88caff" \
	-occupied-fg-color        "#bbbbbbff" \
	-occupied-bg-color        "#222222ff" \
	-inactive-fg-color        "#bbbbbbff" \
	-inactive-bg-color        "#222222ff" \
	-urgent-fg-color          "#eeeeeeff" \
	-urgent-bg-color          "#ff0000ff" \
	-middle-bg-color          "#222222ff" \
	-middle-bg-color-selected "#6b88caff"
