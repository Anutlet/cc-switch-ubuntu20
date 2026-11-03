# CC Switch AppImage on Ubuntu 20.04

English | [简体中文](README_ZH.md)

Run the official Linux AppImage with private Ubuntu 22.04 libraries. This project does not install or replace the system glibc and does not redistribute CC Switch or Ubuntu packages.

## Requirements

- Ubuntu 20.04 x86_64
- `unsquashfs`, `dpkg-deb`, `patchelf`, Bash
- Official `CC-Switch-vVERSION-Linux-x86_64.AppImage` (tested with 4.0.21 and 4.0.25)
- Ubuntu 22.04 amd64 packages: `libc6` 2.35-0ubuntu3.15, `libfreetype6` 2.11.1+dfsg-1ubuntu0.4, `libgbm1` 23.2.1-1ubuntu3.1~22.04.4

Download the four files yourself from their official sources. Keep the `.deb` files as files; do **not** install them with `dpkg -i`.

## Install

```bash
./install.sh \
  /path/to/CC-Switch-v4.0.25-Linux-x86_64.AppImage \
  /path/to/libc6_2.35-0ubuntu3.15_amd64.deb \
  /path/to/libfreetype6_2.11.1+dfsg-1ubuntu0.4_amd64.deb \
  /path/to/libgbm1_23.2.1-1ubuntu3.1~22.04.4_amd64.deb
```

Launch **CC Switch** from the application menu or run `~/.local/bin/cc-switch-appimage-local`. Startup output is written to `~/.cache/cc-switch-launch.log`.

## How it works

Ubuntu 20.04 provides glibc 2.31, while the tested official AppImages require symbols from newer glibc releases. Launching the AppImage directly therefore fails before the application starts. This installer keeps the official application binary and supplies the needed runtime libraries in the user's home directory:

1. It reads the AppImage's SquashFS offset and extracts it to `~/.local/share/cc-switch-VERSION-local/squashfs-root`.
2. It extracts the specified Ubuntu 22.04 `.deb` packages into private `glibc`, `freetype`, and `gbm` directories. It also copies the host `libstdc++.so.6` into `compat` and removes that copy's RPATH. The script verifies package names, versions, and architecture, but does not verify download checksums.
3. The launcher invokes the private `ld-linux-x86-64.so.2` with an explicit library search path containing those directories and the AppImage libraries. The system glibc remains untouched. The application still uses host services and any libraries not supplied by this setup.
4. WebKit starts separate web and network processes. The installer replaces their entry points with small wrappers that invoke the same private loader; otherwise those processes would start with the host glibc. The launcher also loads the AppImage's GTK environment hook and starts from its `usr` directory because this WebKit build resolves child-process paths relative to that directory.
5. It creates `~/.local/bin/cc-switch-appimage-local` and `~/.local/share/applications/cc-switch.desktop` for application-menu launch. CC Switch's configuration and provider data are not copied into this repository.

### In-app updates

The in-app updater writes the downloaded AppImage over the running executable, which is the private loader in this setup. The launcher now uses a separate loader copy for each run so an update cannot damage the installed loader. After an in-app update, relaunch through the application menu; the downloaded AppImage will be saved as `~/.cache/cc-switch-updater-*.AppImage`. Rename it to the expected `CC-Switch-vVERSION-Linux-x86_64.AppImage` format and rerun `install.sh` to use the new version.

The updater's immediate restart may fail because it starts the new AppImage outside this compatibility launcher. The next application-menu launch still uses the previously installed version until you run `install.sh` for the update.

## Compared with the upstream Flatpak build

The [upstream Flatpak manifest](https://github.com/farion1231/cc-switch/blob/main/flatpak/com.ccswitch.desktop.yml) packages a CC Switch `.deb` with the GNOME 46 Flatpak runtime. It also avoids replacing the host glibc, but supplies its runtime through Flatpak instead of private Ubuntu `.deb` extractions.

| Aspect | This AppImage adapter | Upstream Flatpak build |
| --- | --- | --- |
| Application payload | Extracts the official AppImage; no CC Switch source compilation | Packages a built CC Switch `.deb` into Flatpak |
| Runtime | Private Ubuntu 22.04 glibc and selected libraries plus the AppImage libraries | `org.gnome.Platform//46` and libraries packaged with the Flatpak |
| Installation | User-local files and a desktop entry; no Flatpak service or runtime required | Flatpak installation and GNOME runtime required |
| File access | Runs as the user without a Flatpak sandbox | Runs in a Flatpak sandbox; the current upstream manifest grants access to the entire home directory |
| Updates | Extract and reinstall each new AppImage through this script; in-app updates need the manual step above | Managed by Flatpak when installed from an update-capable remote; a standalone `.flatpak` bundle must be installed again for a new release |

Neither approach changes the system glibc. Flatpak offers a defined runtime and permission model; this adapter stays closer to the official AppImage packaging and depends on the compatibility of the selected libraries with the host system. It was tested on one Ubuntu 20.04 workstation with CC Switch 4.0.21 and 4.0.25; other releases may need changes.
