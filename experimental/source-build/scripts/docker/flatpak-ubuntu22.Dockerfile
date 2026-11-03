FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    binutils \
    ca-certificates \
    dbus \
    elfutils \
    flatpak \
    flatpak-builder \
    libayatana-appindicator3-1 \
    libayatana-ido3-0.4-0 \
    libayatana-indicator3-7 \
    libdbusmenu-glib4 \
    libdbusmenu-gtk3-4 \
    xdg-dbus-proxy \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
CMD ["bash"]
