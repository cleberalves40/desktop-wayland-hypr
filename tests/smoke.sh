#!/bin/sh
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
INSTALLER="$PROJECT_DIR/install.sh"
VERSION=$(cat "$PROJECT_DIR/VERSION")

[ "$(sh "$INSTALLER" --version)" = "desktop-wayland-hypr $VERSION" ]

output=$(sh "$INSTALLER" --user smoke --browser both --dry-run)
printf '%s\n' "$output" | grep -Fq 'Browser selection: both'
printf '%s\n' "$output" | grep -Fq 'GPU profile: intel'
printf '%s\n' "$output" | grep -Fq 'Wi-Fi profile: ax210'
printf '%s\n' "$output" | grep -Fq '  firefox'
printf '%s\n' "$output" | grep -Fq '  chromium'
printf '%s\n' "$output" | grep -Fq '  drm-kmod'
printf '%s\n' "$output" | grep -Fq '  wifi-firmware-iwlwifi-kmod'
printf '%s\n' "$output" | grep -Fq '  quickshell'
printf '%s\n' "$output" | grep -Fq '  libreoffice'
printf '%s\n' "$output" | grep -Fq ' + pkg install -y'

output=$(sh "$INSTALLER" --user smoke --gpu amd --wifi none --dry-run)
printf '%s\n' "$output" | grep -Fq 'GPU profile: amd'
printf '%s\n' "$output" | grep -Fq 'Wi-Fi profile: none'
if printf '%s\n' "$output" | grep -Fq '  wifi-firmware-iwlwifi-kmod'; then
	printf '%s\n' 'The no-Wi-Fi profile should omit AX210 firmware.' >&2
	exit 1
fi

output=$(sh "$INSTALLER" --user smoke --gpu nvidia --wifi none --dry-run)
printf '%s\n' "$output" | grep -Fq 'GPU profile: nvidia'
printf '%s\n' "$output" | grep -Fq '  nvidia-driver'
printf '%s\n' "$output" | grep -Fq '  nvidia-drm-kmod'

if sh "$INSTALLER" --user smoke --browser firefox --widevine --dry-run >/dev/null 2>&1; then
	printf '%s\n' 'Expected incompatible browser/Widevine options to fail.' >&2
	exit 1
fi

if sh "$INSTALLER" --user smoke --browser invalid --dry-run >/dev/null 2>&1; then
	printf '%s\n' 'Expected an invalid browser option to fail.' >&2
	exit 1
fi

if sh "$INSTALLER" --user smoke --gpu invalid --dry-run >/dev/null 2>&1; then
	printf '%s\n' 'Expected an invalid GPU profile to fail.' >&2
	exit 1
fi

printf '%s\n' 'Installer smoke tests passed.'