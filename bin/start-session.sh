#!/bin/sh
set -eu

if [ "$(id -u)" -eq 0 ]; then
	printf '%s\n' 'Do not start a graphical session as root.' >&2
	exit 1
fi
if [ -n "${WAYLAND_DISPLAY:-}" ]; then
	printf '%s\n' 'A Wayland session is already active.' >&2
	exit 1
fi

export XDG_CURRENT_DESKTOP=Hyprland
export XDG_SESSION_TYPE=wayland
export XDG_SESSION_DESKTOP=Hyprland

if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
	exec Hyprland
fi
exec dbus-run-session Hyprland