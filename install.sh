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
WIFI_DRIVER=auto
WIFI_DRIVER_EXPLICIT=0
LOCALE=
CONSOLE_KEYMAP=
KB_LAYOUT=
KB_MODEL=
KB_VARIANT=
KB_OPTIONS=
THEME=default
THEME_EXPLICIT=0
THEME=default
THEME_EXPLICIT=0

usage()
{
	cat <<'EOF'
Usage: install.sh --user USER [options]

Options:
  --user USER          Desktop account to configure
  --browser CHOICE     none, firefox, chromium, or both (default: none)
	--gpu PROFILE        intel, amd, or nvidia (default: intel)
	--wifi PROFILE       ax210, legacy, or none (default: ax210)
	--wifi-driver DRIVER auto, iwlwifi, iwx, or iwm (default: auto)
	--locale LOCALE      Default login locale for the desktop account
	--keymap KEYMAP      FreeBSD virtual-console keymap
	--kb-layout LAYOUT   Hyprland XKB layout, e.g. us,br
	--kb-model MODEL     Hyprland XKB model, e.g. pc105
	--kb-variant VARIANT Hyprland XKB variant
	--kb-options OPTIONS Hyprland XKB options, e.g. grp:alt_shift_toggle
	--theme THEME        default, nord, catppuccin-mocha/frappe/macchiato/latte,
	                     dracula, gruvbox-dark, or tokyo-night
	--theme THEME        default, nord, catppuccin-mocha, catppuccin-latte,
	                     dracula, gruvbox-dark, or tokyo-night
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

configure_wifi_driver()
{
	[ "$WIFI_DRIVER_EXPLICIT" -eq 1 ] || return 0

	case $WIFI_DRIVER in
	auto)
		for module in if_iwlwifi if_iwx if_iwm; do
			run sysrc "devmatch_blocklist-=$module"
		done
		;;
	*)
		run sysrc "devmatch_blocklist-=if_$WIFI_DRIVER"
		for module in if_iwlwifi if_iwx if_iwm; do
			[ "$module" = "if_$WIFI_DRIVER" ] && continue
			run sysrc "devmatch_blocklist+=$module"
		done
		;;
	esac
}

configure_locale()
{
	[ -n "$LOCALE" ] || return 0
	login_conf="$TARGET_HOME/.login_conf"
	printf ' + configure login locale %s for %s\n' "$LOCALE" "$TARGET_USER"
	if [ "$DRY_RUN" -eq 0 ]; then
		if [ -e "$login_conf" ]; then
			tmp_file=$(mktemp "$TARGET_HOME/.login_conf.XXXXXX")
			if ! awk -v locale="$LOCALE" '
				{ line = $0; sub(/\\$/, "", line); sub(/^[[:space:]]+/, "", line); record = record line }
				END {
					if (record !~ /^me:/) exit 1
					if (record ~ /:lang=[^:]*:/)
						sub(/:lang=[^:]*:/, ":lang=" locale ":", record)
					else {
						sub(/:$/, "", record)
						record = record ":lang=" locale ":"
					}
					print record
				}' "$login_conf" > "$tmp_file"; then
				rm -f "$tmp_file"
				fail "could not update existing login configuration: $login_conf"
			fi
			chown "$TARGET_USER:$TARGET_GROUP" "$tmp_file"
			chmod 0644 "$tmp_file"
			mv "$tmp_file" "$login_conf"
		else
			printf 'me:lang=%s:\n' "$LOCALE" > "$login_conf"
			chown "$TARGET_USER:$TARGET_GROUP" "$login_conf"
			chmod 0644 "$login_conf"
		fi
	fi
	run cap_mkdb -f "$login_conf.db" "$login_conf"
}

configure_hyprland_keyboard()
{
	[ -n "$KB_LAYOUT$KB_MODEL$KB_VARIANT$KB_OPTIONS" ] || return 0
	keyboard_file="$HYPR_CONFIG/desktop-wayland-hypr-keyboard.conf"
	source_line='source = ~/.config/hypr/desktop-wayland-hypr-keyboard.conf'
	printf ' + write Hyprland keyboard settings to %s\n' "$keyboard_file"
	if [ "$DRY_RUN" -eq 0 ]; then
		{
			printf 'input {\n'
			[ -z "$KB_LAYOUT" ] || printf '    kb_layout = %s\n' "$KB_LAYOUT"
			[ -z "$KB_MODEL" ] || printf '    kb_model = %s\n' "$KB_MODEL"
			[ -z "$KB_VARIANT" ] || printf '    kb_variant = %s\n' "$KB_VARIANT"
			[ -z "$KB_OPTIONS" ] || printf '    kb_options = %s\n' "$KB_OPTIONS"
			printf '}\n'
		} > "$keyboard_file"
		chown "$TARGET_USER:$TARGET_GROUP" "$keyboard_file"
		chmod 0644 "$keyboard_file"
	fi
	if ! grep -Fqx "$source_line" "$HYPR_CONFIG/hyprland.conf" 2>/dev/null; then
		printf ' + include managed keyboard settings in %s/hyprland.conf\n' "$HYPR_CONFIG"
		if [ "$DRY_RUN" -eq 0 ]; then
			printf '\n%s\n' "$source_line" >> "$HYPR_CONFIG/hyprland.conf"
		fi
	fi
}

set_theme_palette()
{
	case $THEME in
	default)
		THEME_BACKGROUND='#1c2528'
		THEME_FOREGROUND='#e8efed'
		THEME_MUTED='#454d52'
		THEME_ACCENT='#65c6b8'
		;;
	nord)
		THEME_BACKGROUND='#2e3440'
		THEME_FOREGROUND='#eceff4'
		THEME_MUTED='#4c566a'
		THEME_ACCENT='#88c0d0'
		;;
	catppuccin-mocha)
		THEME_BACKGROUND='#1e1e2e'
		THEME_FOREGROUND='#cdd6f4'
		THEME_MUTED='#45475a'
		THEME_ACCENT='#cba6f7'
		;;
	catppuccin-frappe)
		THEME_BACKGROUND='#303446'
		THEME_FOREGROUND='#c6d0f5'
		THEME_MUTED='#626880'
		THEME_ACCENT='#ca9ee6'
		;;
	catppuccin-macchiato)
		THEME_BACKGROUND='#24273a'
		THEME_FOREGROUND='#cad3f5'
		THEME_MUTED='#5b6078'
		THEME_ACCENT='#c6a0f6'
		;;
	catppuccin-latte)
		THEME_BACKGROUND='#eff1f5'
		THEME_FOREGROUND='#4c4f69'
		THEME_MUTED='#9ca0b0'
		THEME_ACCENT='#8839ef'
		;;
	dracula)
		THEME_BACKGROUND='#282a36'
		THEME_FOREGROUND='#f8f8f2'
		THEME_MUTED='#6272a4'
		THEME_ACCENT='#bd93f9'
		;;
	gruvbox-dark)
		THEME_BACKGROUND='#282828'
		THEME_FOREGROUND='#ebdbb2'
		THEME_MUTED='#665c54'
		THEME_ACCENT='#fabd2f'
		;;
	tokyo-night)
		THEME_BACKGROUND='#1a1b26'
		THEME_FOREGROUND='#c0caf5'
		THEME_MUTED='#414868'
		THEME_ACCENT='#7aa2f7'
		;;
	esac
}

configure_desktop_theme()
{
	[ "$THEME_EXPLICIT" -eq 1 ] || return 0
	set_theme_palette
	theme_js="$QS_CONFIG/theme.js"
	theme_conf="$HYPR_CONFIG/desktop-wayland-hypr-theme.conf"
	source_line='source = ~/.config/hypr/desktop-wayland-hypr-theme.conf'
	printf ' + write %s desktop theme palette to %s and %s\n' \
		"$THEME" "$theme_js" "$theme_conf"
	if [ "$DRY_RUN" -eq 0 ]; then
		{
			printf '.pragma library\n'
			printf 'var background = "%s"\n' "$THEME_BACKGROUND"
			printf 'var foreground = "%s"\n' "$THEME_FOREGROUND"
			printf 'var muted = "%s"\n' "$THEME_MUTED"
			printf 'var accent = "%s"\n' "$THEME_ACCENT"
		} > "$theme_js"
		chown "$TARGET_USER:$TARGET_GROUP" "$theme_js"
		chmod 0644 "$theme_js"
		{
			printf 'general {\n'
			printf '    col.active_border = rgba(%sff)\n' "${THEME_ACCENT#\#}"
			printf '    col.inactive_border = rgba(%saa)\n' "${THEME_MUTED#\#}"
			printf '}\n'
		} > "$theme_conf"
		chown "$TARGET_USER:$TARGET_GROUP" "$theme_conf"
		chmod 0644 "$theme_conf"
	fi
	if ! grep -Fqx "$source_line" "$HYPR_CONFIG/hyprland.conf" 2>/dev/null; then
		printf ' + include desktop theme in %s/hyprland.conf\n' "$HYPR_CONFIG"
		if [ "$DRY_RUN" -eq 0 ]; then
			printf '\n%s\n' "$source_line" >> "$HYPR_CONFIG/hyprland.conf"
		fi
	fi
	if [ "$DRY_RUN" -eq 1 ] || grep -Fq 'import "theme.js" as Theme' "$QS_CONFIG/shell.qml"; then
		return 0
	fi
	if grep -Fq 'color: "#1c2528"' "$QS_CONFIG/shell.qml" &&
		grep -Fq 'color: "#e8efed"' "$QS_CONFIG/shell.qml"; then
		tmp_file=$(mktemp "$QS_CONFIG/shell.qml.XXXXXX")
		sed \
			-e 's/color: "#1c2528"/color: Theme.background/' \
			-e 's/color: "#e8efed"/color: Theme.foreground/' \
			"$QS_CONFIG/shell.qml" > "$tmp_file"
		{
			printf 'import "theme.js" as Theme\n'
			cat "$tmp_file"
		} > "$QS_CONFIG/shell.qml.new"
		rm -f "$tmp_file"
		chown "$TARGET_USER:$TARGET_GROUP" "$QS_CONFIG/shell.qml.new"
		chmod 0644 "$QS_CONFIG/shell.qml.new"
		mv "$QS_CONFIG/shell.qml.new" "$QS_CONFIG/shell.qml"
	else
		printf '%s\n' 'Preserving custom Quickshell configuration; theme palette is available in theme.js.'
	fi
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
	--wifi-driver)
		[ "$#" -ge 2 ] || fail '--wifi-driver requires a value'
		WIFI_DRIVER=$2
		WIFI_DRIVER_EXPLICIT=1
		shift 2
		;;
	--locale)
		[ "$#" -ge 2 ] || fail '--locale requires a value'
		LOCALE=$2
		shift 2
		;;
	--keymap)
		[ "$#" -ge 2 ] || fail '--keymap requires a value'
		CONSOLE_KEYMAP=$2
		shift 2
		;;
	--kb-layout)
		[ "$#" -ge 2 ] || fail '--kb-layout requires a value'
		KB_LAYOUT=$2
		shift 2
		;;
	--kb-model)
		[ "$#" -ge 2 ] || fail '--kb-model requires a value'
		KB_MODEL=$2
		shift 2
		;;
	--kb-variant)
		[ "$#" -ge 2 ] || fail '--kb-variant requires a value'
		KB_VARIANT=$2
		shift 2
		;;
	--kb-options)
		[ "$#" -ge 2 ] || fail '--kb-options requires a value'
		KB_OPTIONS=$2
		shift 2
		;;
	--theme)
		[ "$#" -ge 2 ] || fail '--theme requires a value'
		THEME=$2
		THEME_EXPLICIT=1
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
ax210|legacy|none) ;;
*) fail "unsupported Wi-Fi profile: $WIFI" ;;
esac
case $WIFI_DRIVER in
auto|iwlwifi|iwx|iwm) ;;
*) fail "unsupported Wi-Fi driver: $WIFI_DRIVER" ;;
esac
case $LOCALE in
'') ;;
*[!A-Za-z0-9_.@-]*) fail "invalid locale: $LOCALE" ;;
esac
case $CONSOLE_KEYMAP in
'') ;;
*[!A-Za-z0-9_.-]*) fail "invalid console keymap: $CONSOLE_KEYMAP" ;;
esac
for value in "$KB_LAYOUT" "$KB_MODEL" "$KB_VARIANT" "$KB_OPTIONS"; do
	[ -n "$value" ] || continue
	case $value in
	*[!A-Za-z0-9_,:+-]*) fail "invalid Hyprland keyboard value: $value" ;;
	esac
done
case $THEME in
default|nord|catppuccin-mocha|catppuccin-frappe|catppuccin-macchiato|catppuccin-latte|dracula|gruvbox-dark|tokyo-night) ;;
*) fail "unsupported desktop theme: $THEME" ;;
esac
case $WIFI:$WIFI_DRIVER in
ax210:iwm|legacy:iwlwifi|legacy:iwx|none:iwlwifi|none:iwx|none:iwm)
	fail "Wi-Fi driver $WIFI_DRIVER is incompatible with the $WIFI profile"
	;;
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
	if [ -n "$LOCALE" ]; then
		command -v cap_mkdb >/dev/null 2>&1 || fail 'cap_mkdb(1) was not found'
		locale -a | grep -Fx "$LOCALE" >/dev/null || fail "locale is not available: $LOCALE"
	fi
	if [ -n "$CONSOLE_KEYMAP" ]; then
		[ -f "/usr/share/vt/keymaps/$CONSOLE_KEYMAP.kbd" ] ||
			[ -f "/usr/share/syscons/keymaps/$CONSOLE_KEYMAP.kbd" ] ||
			fail "console keymap was not found: $CONSOLE_KEYMAP"
	fi
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
printf 'Wi-Fi driver: %s\n' "$WIFI_DRIVER"
printf 'Login locale: %s\n' "${LOCALE:-not specified}"
printf 'Console keymap: %s\n' "${CONSOLE_KEYMAP:-not specified}"
printf 'Hyprland XKB layout: %s\n' "${KB_LAYOUT:-not specified}"
printf 'Desktop theme: %s\n' "$THEME"
printf 'Install packages:\n'
set -f
set -- $PACKAGES
for package do
	printf '  %s\n' "$package"
done
run pkg install -y "$@"
configure_wifi_driver
configure_locale
if [ -n "$CONSOLE_KEYMAP" ]; then
	run sysrc "keymap=$CONSOLE_KEYMAP"
fi

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
install_if_missing "$SCRIPT_DIR/config/quickshell/theme.js" \
	"$QS_CONFIG/theme.js" 0644
install_if_missing "$SCRIPT_DIR/bin/start-session.sh" \
	"$BIN_DIR/desktop-wayland-hypr" 0755
configure_hyprland_keyboard
configure_desktop_theme

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

Existing configuration files were preserved; explicitly selected themes and
keyboard settings were added through separate configuration files.
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