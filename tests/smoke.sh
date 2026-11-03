#!/bin/sh
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
INSTALLER="$PROJECT_DIR/install.sh"

output=$(sh "$INSTALLER" --user smoke --browser both --dry-run)
printf '%s\n' "$output" | grep -Fq 'Browser selection: both'
printf '%s\n' "$output" | grep -Fq '  firefox'
printf '%s\n' "$output" | grep -Fq '  chromium'
printf '%s\n' "$output" | grep -Fq '  quickshell'
printf '%s\n' "$output" | grep -Fq '  libreoffice'
printf '%s\n' "$output" | grep -Fq ' + pkg install -y'

if sh "$INSTALLER" --user smoke --browser firefox --widevine --dry-run >/dev/null 2>&1; then
	printf '%s\n' 'Expected incompatible browser/Widevine options to fail.' >&2
	exit 1
fi

if sh "$INSTALLER" --user smoke --browser invalid --dry-run >/dev/null 2>&1; then
	printf '%s\n' 'Expected an invalid browser option to fail.' >&2
	exit 1
fi

printf '%s\n' 'Installer smoke tests passed.'