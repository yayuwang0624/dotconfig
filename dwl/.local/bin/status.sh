#!/bin/sh
# dwmblocks-style status feeder for dwlb.
#
# Pipe this into a *client* dwlb instance:
#     status.sh | dwlb -status-stdin all
# Each line printed becomes the bar's status text. This mirrors the blocks
# from dwm-flexipatch/dwmblocks/blocks.def.h: volume, battery, monitor, clock.
#
# Each block prefers your existing dwmblocks script (dwm_volume, dwm_battery,
# dwm_monitor, dwm_clock) if it is found on PATH, and otherwise falls back to
# a built-in implementation. Empty blocks are dropped from the line.

INTERVAL=1   # seconds between refreshes (dwmblocks' shortest interval)

vol() {
	if command -v dwm_volume >/dev/null 2>&1; then dwm_volume; return; fi
	command -v pactl >/dev/null 2>&1 || return
	if [ "$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null)" = "Mute: yes" ]; then
		printf 'VOL mute'
	else
		printf 'VOL %s' "$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null \
			| awk -F'/' '{gsub(/ /,"",$2); print $2; exit}')"
	fi
}

bat() {
	if command -v dwm_battery >/dev/null 2>&1; then dwm_battery; return; fi
	for b in /sys/class/power_supply/BAT*; do
		[ -r "$b/capacity" ] || continue
		case "$(cat "$b/status" 2>/dev/null)" in
			Charging) icon='CHR';;
			Full)     icon='FULL';;
			*)        icon='BAT';;
		esac
		printf '%s %s%%' "$icon" "$(cat "$b/capacity")"
		return
	done
}

mon() {
	if command -v dwm_monitor >/dev/null 2>&1; then dwm_monitor; return; fi
	# Built-in fallback: memory in use. Replace with whatever your original
	# dwm_monitor block showed (cpu load, temperature, network, ...).
	awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2}
	     END{if(t)printf "MEM %d%%", (t-a)*100/t}' /proc/meminfo
}

clk() {
	if command -v dwm_clock >/dev/null 2>&1; then dwm_clock; return; fi
	date '+%a %d %b %H:%M'
}

while :; do
	line=''
	for part in "$(vol)" "$(bat)" "$(mon)" "$(clk)"; do
		[ -n "$part" ] || continue
		if [ -z "$line" ]; then line="$part"; else line="$line | $part"; fi
	done
	printf '%s\n' "$line"
	sleep "$INTERVAL"
done
