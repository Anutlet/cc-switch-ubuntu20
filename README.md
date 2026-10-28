# CC Switch 4.0.21 on Ubuntu 20.04

Run the official Linux AppImage with private Ubuntu 22.04 libraries. This project does not install or replace the system glibc and does not redistribute CC Switch or Ubuntu packages.

## Requirements

- Ubuntu 20.04 x86_64
- `unsquashfs`, `dpkg-deb`, `patchelf`, Bash
- Official `CC-Switch-v4.0.21-Linux-x86_64.AppImage`
- Ubuntu 22.04 amd64 packages: `libc6` 2.35-0ubuntu3.15, `libfreetype6` 2.11.1+dfsg-1ubuntu0.4, `libgbm1` 23.2.1-1ubuntu3.1~22.04.4

Download the four files yourself from their official sources. Keep the `.deb` files as files; do **not** install them with `dpkg -i`.

## Install

```bash
./install.sh \
  /path/to/CC-Switch-v4.0.21-Linux-x86_64.AppImage \
  /path/to/libc6_2.35-0ubuntu3.15_amd64.deb \
  /path/to/libfreetype6_2.11.1+dfsg-1ubuntu0.4_amd64.deb \
  /path/to/libgbm1_23.2.1-1ubuntu3.1~22.04.4_amd64.deb
```

Launch **CC Switch** from the application menu or run `~/.local/bin/cc-switch-appimage-local`. Startup output is written to `~/.cache/cc-switch-launch.log`.

The installer extracts the AppImage under `~/.local/share/cc-switch-4.0.21-local`, launches the original `cc-switch` binary through a private glibc loader, and wraps WebKit's two child processes with the same loader. It sets the working directory to the extracted `usr` directory because this WebKit build resolves those processes relative to that directory.

The approach was tested on one Ubuntu 20.04 workstation. It is specific to these package versions and may need changes for other AppImage releases.
