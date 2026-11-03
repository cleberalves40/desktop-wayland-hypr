#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
VERSION=$(cat "$SCRIPT_DIR/VERSION")
DRY_RUN=0
TARGET_USER=${SUDO_USER:-}
BROWSER=none
WIDEVINE=0
GPU=intel
WIFI=ax210

usage()
{
	cat <<'EOF'
Usage: install.sh --user USER [options]

Options:
  --user USER          Desktop account to configure
  --browser CHOICE     none, firefox, chromium, or both (default: none)
	--gpu PROFILE        intel, amd, or nvidia (default: intel)
	--wifi PROFILE       ax210 or none (default: ax210)
  --widevine           Install Chromium and the FreeBSD foreign-cdm package
  --dry-run            Print planned changes without applying them
	--version            Show the semantic version
  -h, --help           Show this help
EOF
}

fail()
{
	printf 'Error: %s\n' "$*" >&2
	exit 1
}

if ! awk -v version="$VERSION" 'BEGIN { exit !(version ~ /^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$/) }'; then
	fail "VERSION must contain a semantic version, got: $VERSION"
fi

run()
{
	printf ' +'
	printf ' %s' "$@"
	printf '\n'
	if [ "$DRY_RUN" -eq 0 ]; then
		"$@"
	fi
}

install_if_missing()
{
	source_file=$1
	target_file=$2
	mode=$3

	if [ -e "$target_file" ]; then
		printf 'Preserving existing file: %s\n' "$target_file"
		return
	fi
	run install -o "$TARGET_USER" -g "$TARGET_GROUP" -m "$mode" \
		"$source_file" "$target_file"
}

ensure_group_membership()
{
	group_name=$1
	if ! pw groupshow "$group_name" >/dev/null 2>&1; then
		return
	fi
	if id -Gn "$TARGET_USER" | tr ' ' '\n' | grep -Fxq "$group_name"; then
		return
	fi
	run pw groupmod "$group_name" -m "$TARGET_USER"
}

while [ "$#" -gt 0 ]; do
	case $1 in
	--user)
		[ "$#" -ge 2 ] || fail '--user requires a value'
		TARGET_USER=$2
		shift 2
		;;
	--browser)
		[ "$#" -ge 2 ] || fail '--browser requires a value'
		BROWSER=$2
		shift 2
		;;
	--gpu)
		[ "$#" -ge 2 ] || fail '--gpu requires a value'
		GPU=$2
		shift 2
		;;
	--wifi)
		[ "$#" -ge 2 ] || fail '--wifi requires a value'
		WIFI=$2
		shift 2
		;;
	--widevine)
		WIDEVINE=1
		shift
		;;
	--dry-run)
		DRY_RUN=1
		shift
		;;
	--version)
		printf 'desktop-wayland-hypr %s\n' "$VERSION"
		exit 0
		;;
	-h|--help)
		usage
		exit 0
		;;
	*)
		usage >&2
		fail "unknown option: $1"
		;;
	esac
done

[ -n "$TARGET_USER" ] || fail 'specify the desktop account with --user'
case $BROWSER in
none|firefox|chromium|both) ;;
*) fail "unsupported browser choice: $BROWSER" ;;
esac
case $GPU in
intel|amd|nvidia) ;;
*) fail "unsupported GPU profile: $GPU" ;;
esac
case $WIFI in
ax210|none) ;;
*) fail "unsupported Wi-Fi profile: $WIFI" ;;
esac
if [ "$WIDEVINE" -eq 1 ] && [ "$BROWSER" != none ] && [ "$BROWSER" != chromium ]; then
	fail '--widevine requires --browser chromium or no --browser option'
fi
if [ "$WIDEVINE" -eq 1 ]; then
	BROWSER=chromium
fi

if [ "$DRY_RUN" -eq 0 ]; then
	[ "$(id -u)" -eq 0 ] || fail 'run the installer as root'
	[ "$(uname -s)" = FreeBSD ] || fail 'this installer currently targets FreeBSD'
	command -v pkg >/dev/null 2>&1 || fail 'pkg(8) was not found'
	command -v sysrc >/dev/null 2>&1 || fail 'sysrc(8) was not found'
	command -v pw >/dev/null 2>&1 || fail 'pw(8) was not found'
	pw usershow "$TARGET_USER" >/dev/null 2>&1 || fail "unknown user: $TARGET_USER"
fi

if [ "$DRY_RUN" -eq 1 ]; then
	TARGET_HOME="/home/$TARGET_USER"
	TARGET_GROUP=$TARGET_USER
else
	TARGET_HOME=$(getent passwd "$TARGET_USER" | awk -F: 'NR == 1 { print $6 }')
	[ -n "$TARGET_HOME" ] || fail "could not determine home directory for $TARGET_USER"
	TARGET_GROUP=$(id -gn "$TARGET_USER")
fi

CORE_PACKAGES='hyprland quickshell seatd dbus hyprlock hypridle hyprpolkitagent xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk pipewire wireplumber alacritty fuzzel mako grim slurp wl-clipboard xdg-utils noto-basic'
APP_PACKAGES='neovim-qt vscode inkscape gimp thunar libreoffice zathura zathura-pdf-poppler'
GPU_PACKAGES='drm-kmod'
if [ "$GPU" = nvidia ]; then
	GPU_PACKAGES="$GPU_PACKAGES nvidia-driver nvidia-drm-kmod"
fi
WIFI_PACKAGES=
if [ "$WIFI" = ax210 ]; then
	WIFI_PACKAGES=wifi-firmware-iwlwifi-kmod
fi
PACKAGES="$CORE_PACKAGES $APP_PACKAGES $GPU_PACKAGES $WIFI_PACKAGES"

case $BROWSER in
firefox) PACKAGES="$PACKAGES firefox" ;;
chromium) PACKAGES="$PACKAGES chromium" ;;
both) PACKAGES="$PACKAGES firefox chromium" ;;
esac
if [ "$WIDEVINE" -eq 1 ]; then
	PACKAGES="$PACKAGES foreign-cdm"
fi

printf 'Target user: %s\n' "$TARGET_USER"
printf 'Browser selection: %s\n' "$BROWSER"
printf 'GPU profile: %s\n' "$GPU"
printf 'Wi-Fi profile: %s\n' "$WIFI"
printf 'Install packages:\n'
set -f
set -- $PACKAGES
for package do
	printf '  %s\n' "$package"
done
run pkg install -y "$@"

run sysrc dbus_enable=YES
run sysrc seatd_enable=YES
if [ "$DRY_RUN" -eq 0 ]; then
	service dbus onestatus >/dev/null 2>&1 || run service dbus start
	service seatd onestatus >/dev/null 2>&1 || run service seatd start
	ensure_group_membership video
	ensure_group_membership seatd
fi

HYPR_CONFIG="$TARGET_HOME/.config/hypr"
QS_CONFIG="$TARGET_HOME/.config/quickshell"
BIN_DIR="$TARGET_HOME/.local/bin"
run install -d -o "$TARGET_USER" -g "$TARGET_GROUP" -m 0755 \
	"$HYPR_CONFIG" "$QS_CONFIG" "$BIN_DIR"
install_if_missing "$SCRIPT_DIR/config/hypr/hyprland.conf" \
	"$HYPR_CONFIG/hyprland.conf" 0644
install_if_missing "$SCRIPT_DIR/config/hypr/hypridle.conf" \
	"$HYPR_CONFIG/hypridle.conf" 0644
install_if_missing "$SCRIPT_DIR/config/quickshell/shell.qml" \
	"$QS_CONFIG/shell.qml" 0644
install_if_missing "$SCRIPT_DIR/bin/start-session.sh" \
	"$BIN_DIR/desktop-wayland-hypr" 0755

if [ "$DRY_RUN" -eq 0 ]; then
	if [ "$WIDEVINE" -eq 1 ]; then
		if command -v auto-chromium+widevine-install >/dev/null 2>&1; then
			auto-chromium+widevine-install
		else
			printf '%s\n' 'Widevine packages installed. Browser/DRM integration still needs validation.'
		fi
	fi
	if [ ! -d /dev/dri ]; then
		printf '%s\n' 'Warning: /dev/dri is absent; configure and test a supported GPU/DRM driver before starting Hyprland.' >&2
	fi
fi

cat <<EOF

Installation stage complete.
Log out and back in if group membership changed, then start the session with:
  $BIN_DIR/desktop-wayland-hypr

Existing Hyprland and Quickshell configuration files were left untouched.
EOF

if [ "$WIDEVINE" -eq 1 ]; then
	cat <<'EOF'
Widevine is best-effort on FreeBSD. Confirm Chromium detects the CDM and test
playback with each intended streaming service; package installation alone does
not guarantee codec, resolution, HDCP, or service-policy compatibility.
EOF
fi

if [ "$GPU" = nvidia ]; then
	cat <<'EOF'
NVIDIA DRM requires hw.nvidiadrm.modeset=1 in /boot/loader.conf before the
nvidia-drm module loads. Review the package messages and configure this manually.
EOF
fi

if [ "$WIFI" = ax210 ]; then
	cat <<'EOF'
AX210 firmware is installed. Driver availability and Wi-Fi feature support
depend on the FreeBSD release; current iwx(4) documentation lists AX210 but
does not claim 802.11ax operation. Verify the adapter with pciconf and ifconfig.
EOF
fi