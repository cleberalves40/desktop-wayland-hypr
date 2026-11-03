# desktop-wayland-hypr

[Português](README.md) | **English**

A FreeBSD Wayland desktop bootstrap using Hyprland as the compositor and Quickshell as the QML shell. The project installs a configurable base; it does not change the existing display manager or replace an existing user configuration.

Current version: `0.3.0` (SemVer; the source of the version is `VERSION`).

## Installation

Use an existing FreeBSD account and run the installer from the checkout:

```sh
sudo sh ./install.sh --user cleber --browser firefox --dry-run
sudo sh ./install.sh --user cleber --browser firefox
```

Show the version with `sh ./install.sh --version`.

`--browser` accepts `none`, `firefox`, `chromium`, or `both`; no browser is selected by default. `--widevine` selects Chromium and installs `foreign-cdm`:

```sh
sudo sh ./install.sh --user cleber --widevine --dry-run
```

`--theme` applies a color palette to Hyprland and the Quickshell bar. Available themes are `default`, `nord`, `catppuccin-mocha`, `catppuccin-frappe`, `catppuccin-macchiato`, `catppuccin-latte`, `dracula`, `gruvbox-dark`, and `tokyo-night`. For example:

```sh
sudo sh ./install.sh --user cleber --theme nord --dry-run
sudo sh ./install.sh --user cleber --theme catppuccin-mocha
```

The Hyprland palette is stored in a separate file. Existing custom Quickshell configuration is preserved; if it does not use the project's default colors, applying a theme will not change its appearance. GTK/Qt application themes are not modified. Without `--theme`, the current appearance is left unchanged.

## Language and keyboard

`--locale` sets the login language only for the account specified with `--user`, using `~/.login_conf`; the capability database is rebuilt with `cap_mkdb`. The locale must be available on FreeBSD (`locale -a`). The change applies to new logins and does not change the default for other accounts.

`--keymap` selects the FreeBSD virtual-console keymap and sets the `keymap` option in `rc.conf`. For the graphical session, configure Hyprland's XKB settings with `--kb-layout`, `--kb-model`, `--kb-variant`, and `--kb-options`. Multiple layouts and comma-separated options are accepted. For example:

```sh
sudo sh ./install.sh --user cleber --locale pt_BR.UTF-8 --keymap br \
  --kb-layout br --kb-model pc105 --kb-variant abnt2 \
  --kb-options caps:escape,grp:alt_shift_toggle --dry-run
```

The console keymap and XKB layout are independent settings. Hyprland options are written to a dedicated file and included from the user's configuration, preserving other existing settings. If these options are omitted, the installer leaves the current defaults unchanged.

The installer requires FreeBSD, root for real changes, and an existing account. It enables and starts D-Bus and seatd, adds the account to the `video` and `seatd` groups if those groups exist and the account is not already a member, and installs initial files under `~/.config`. Existing configuration files are preserved. After a group membership change, log out and back in. To start the environment manually from a TTY:

```sh
~/.local/bin/desktop-wayland-hypr
```

`install.sh` does not enable Ly or create a login entry automatically; validate the graphics driver and session manually first. Package names follow the FreeBSD ports tree, but availability can vary by FreeBSD version, architecture, and configured package repository.

## Hardware

The default profiles are `--gpu intel` and `--wifi ax210`. `--gpu` accepts `intel`, `amd`, or `nvidia`; Intel/AMD profiles install `drm-kmod`, while the NVIDIA profile also installs `nvidia-driver` and `nvidia-drm-kmod`. The DRM metapackage selects modules and firmware according to the FreeBSD version and architecture available in the repositories. Review package messages and reboot before validating Hyprland. `--wifi` accepts `ax210`, `legacy`, or `none`; `legacy` represents Intel adapters listed by `iwm(4)` and does not install AX210 firmware.

On NVIDIA cards, `nvidia-drm-kmod` requires `hw.nvidiadrm.modeset=1` in `/boot/loader.conf` before `nvidia-drm` is loaded. The installer does not change boot configuration; follow package messages and confirm your hardware before editing that file.

The AX210 profile installs `wifi-firmware-iwlwifi-kmod`. The driver is part of the base system and depends on the FreeBSD version; installing firmware alone does not enable Wi-Fi. `--wifi-driver` accepts `auto`, `iwlwifi`, `iwx`, or `iwm` and, when specified, adjusts `devmatch_blocklist` to prefer the selected driver while preserving other blocked modules. Explicitly selecting `auto` removes these three drivers from the blocklist. If the option is omitted, driver selection is left unchanged.

For AX210, use `auto`, `iwx`, or `iwlwifi`; `iwm` does not support this adapter. For Intel adapters listed by `iwm(4)`, use `--wifi legacy` with `auto` or `iwm`. `iwm(4)` has limited Wi-Fi mode support and does not guarantee association with networks configured for 802.11n/ac only. `iwx(4)` lists AX210 but currently does not claim 802.11ax support; verify features and stability on the installed FreeBSD version. Intel 1GbE Ethernet interfaces usually use base-system drivers (for example, `em(4)` or `igc(4)`) and need no extra package. Identify the model with `pciconf -lv` and the interface with `ifconfig`.

## Applications and limitations

The base installation includes Neovim-Qt, Code - OSS (`vscode` in ports, not the official Microsoft binary), Inkscape, GIMP, Thunar, LibreOffice, and Zathura with the Poppler backend. Firefox and Chromium are optional. Browser selection does not imply compatibility with any particular streaming service.

Widevine on FreeBSD is best-effort, not a DRM guarantee. The `foreign-cdm` package alone does not ensure that Chromium detects the CDM or that a service allows playback, codecs, or a particular resolution. Test each service, GPU, and monitor on the target machine. If `auto-chromium+widevine-install` is installed, `--widevine` runs that helper after installing the packages.

The OctoPkg graphical application is not available as an official package in the ports tree reviewed for this project. `octopkg-tui` is a terminal application, not a GUI, and is not installed by this project. Integration with a graphical port or package can be added once its source and distribution method are established.

## Tests

On the development host:

```sh
sh -n install.sh bin/start-session.sh
sh tests/smoke.sh
```

The dry run and smoke tests do not install packages. The installation and graphical session still need to be tested on real FreeBSD hardware with the intended drivers and services; this repository does not certify every such combination.
