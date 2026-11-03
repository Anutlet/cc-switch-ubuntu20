# CC Switch 4.0.21 on Ubuntu 20.04

The upstream AppImage is built against glibc 2.35 and cannot run on Ubuntu 20.04's glibc 2.31. This build path compiles the current source in an Ubuntu 22.04 container, then packages the resulting `.deb` into a Flatpak. Flatpak supplies its own runtime; the host glibc is unchanged.

## Build

From this repository root:

```bash
scripts/build-flatpak-artifact.sh
```

The script always rebuilds the `.deb` from the checked-out source. It uses the versions pinned by this repository: Node 22.12.0, pnpm 10.12.3, and Rust 1.95.0. It disables Tauri updater artifact signing for a local build. The Flatpak runtime version comes from `flatpak/com.ccswitch.desktop.yml` (currently GNOME 46). The resulting bundle is `dist-flatpak/CC-Switch-v4.0.21-Ubuntu20.04.flatpak`.

The first build requires Docker daemon access and network access inside Docker to obtain the Ubuntu 22.04 base image, system packages, the Rust toolchain, npm and Cargo packages, and the Flatpak runtime. It uses a privileged container for the Flatpak packaging step, as in the reference Ubuntu 20.04 build workflow. It does not install or replace the host's glibc.

If Docker is unavailable in the current environment, run this script from a normal host terminal with Docker access. The script checks `docker info` before it changes build output.

## Install and run

Install Flatpak on the host if needed, then install the GNOME 46 runtime and the local bundle:

```bash
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install --user flathub org.gnome.Platform//46
flatpak install --user ./dist-flatpak/CC-Switch-v4.0.21-Ubuntu20.04.flatpak
flatpak run com.ccswitch.desktop
```

The manifest grants home-directory access so CC Switch can manage `~/.cc-switch`, Claude Code, Codex and other local tool settings. Before installation, back up `~/.cc-switch` if it contains providers or credentials.

## Verification

```bash
flatpak info com.ccswitch.desktop
flatpak run --command=sh com.ccswitch.desktop -c 'echo smoke-ok'
```

The build script runs the same Flatpak smoke command inside its packaging container. A new shell or desktop login may be needed before the app appears in the launch menu.
