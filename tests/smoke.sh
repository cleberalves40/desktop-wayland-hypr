#!/bin/sh
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
INSTALLER="$PROJECT_DIR/install.sh"
VERSION=$(cat "$PROJECT_DIR/VERSION")

[ "$(sh "$INSTALLER" --version)" = "desktop-wayland-hypr $VERSION" ]

output=$(sh "$INSTALLER" --user smoke --browser both --dry-run)
printf '%s\n' "$output" | grep -F 'Browser selection: both' >/dev/null
printf '%s\n' "$output" | grep -F 'GPU profile: intel' >/dev/null
printf '%s\n' "$output" | grep -F 'Wi-Fi profile: ax210' >/dev/null
printf '%s\n' "$output" | grep -F 'Wi-Fi driver: auto' >/dev/null
printf '%s\n' "$output" | grep -F '  firefox' >/dev/null
printf '%s\n' "$output" | grep -F '  chromium' >/dev/null
printf '%s\n' "$output" | grep -F '  drm-kmod' >/dev/null
printf '%s\n' "$output" | grep -F '  wifi-firmware-iwlwifi-kmod' >/dev/null
printf '%s\n' "$output" | grep -F '  quickshell' >/dev/null
printf '%s\n' "$output" | grep -F '  libreoffice' >/dev/null
printf '%s\n' "$output" | grep -F ' + pkg install -y' >/dev/null
if printf '%s\n' "$output" | grep -Fq 'devmatch_blocklist'; then
	printf '%s\n' 'Implicit auto selection should not modify devmatch_blocklist.' >&2
	exit 1
fi

output=$(sh "$INSTALLER" --user smoke --gpu amd --wifi none --dry-run)
printf '%s\n' "$output" | grep -F 'GPU profile: amd' >/dev/null
printf '%s\n' "$output" | grep -F 'Wi-Fi profile: none' >/dev/null
if printf '%s\n' "$output" | grep -Fq '  wifi-firmware-iwlwifi-kmod'; then
	printf '%s\n' 'The no-Wi-Fi profile should omit AX210 firmware.' >&2
	exit 1
fi

output=$(sh "$INSTALLER" --user smoke --gpu nvidia --wifi none --dry-run)
printf '%s\n' "$output" | grep -F 'GPU profile: nvidia' >/dev/null
printf '%s\n' "$output" | grep -F '  nvidia-driver' >/dev/null
printf '%s\n' "$output" | grep -F '  nvidia-drm-kmod' >/dev/null

output=$(sh "$INSTALLER" --user smoke --wifi ax210 --wifi-driver iwx --dry-run)
printf '%s\n' "$output" | grep -F 'Wi-Fi driver: iwx' >/dev/null
printf '%s\n' "$output" | grep -F ' + sysrc devmatch_blocklist-=if_iwx' >/dev/null
printf '%s\n' "$output" | grep -F ' + sysrc devmatch_blocklist+=if_iwlwifi' >/dev/null
printf '%s\n' "$output" | grep -F ' + sysrc devmatch_blocklist+=if_iwm' >/dev/null

output=$(sh "$INSTALLER" --user smoke --wifi ax210 --wifi-driver auto --dry-run)
printf '%s\n' "$output" | grep -F ' + sysrc devmatch_blocklist-=if_iwlwifi' >/dev/null
printf '%s\n' "$output" | grep -F ' + sysrc devmatch_blocklist-=if_iwx' >/dev/null
printf '%s\n' "$output" | grep -F ' + sysrc devmatch_blocklist-=if_iwm' >/dev/null

output=$(sh "$INSTALLER" --user smoke --wifi legacy --wifi-driver iwm --dry-run)
printf '%s\n' "$output" | grep -F 'Wi-Fi profile: legacy' >/dev/null
printf '%s\n' "$output" | grep -F 'Wi-Fi driver: iwm' >/dev/null
printf '%s\n' "$output" | grep -F ' + sysrc devmatch_blocklist+=if_iwx' >/dev/null
if printf '%s\n' "$output" | grep -Fq '  wifi-firmware-iwlwifi-kmod'; then
	printf '%s\n' 'The legacy iwm profile should not install AX210 firmware.' >&2
	exit 1
fi

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

if sh "$INSTALLER" --user smoke --wifi ax210 --wifi-driver iwm --dry-run >/dev/null 2>&1; then
	printf '%s\n' 'Expected iwm with AX210 to fail.' >&2
	exit 1
fi

if sh "$INSTALLER" --user smoke --wifi legacy --wifi-driver iwx --dry-run >/dev/null 2>&1; then
	printf '%s\n' 'Expected iwx with legacy Intel Wi-Fi to fail.' >&2
	exit 1
fi

if sh "$INSTALLER" --user smoke --wifi none --wifi-driver iwlwifi --dry-run >/dev/null 2>&1; then
	printf '%s\n' 'Expected a driver with no Wi-Fi profile to fail.' >&2
	exit 1
fi

if sh "$INSTALLER" --user smoke --wifi-driver invalid --dry-run >/dev/null 2>&1; then
	printf '%s\n' 'Expected an invalid Wi-Fi driver to fail.' >&2
	exit 1
fi

printf '%s\n' 'Installer smoke tests passed.'