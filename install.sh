#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo 'Usage: install.sh APPIMAGE LIBC6_DEB LIBFREETYPE6_DEB LIBGBM1_DEB' >&2
  exit 2
fi

for command_name in unsquashfs dpkg-deb patchelf; do
  command -v "$command_name" >/dev/null || { echo "Missing: $command_name" >&2; exit 1; }
done

appimage=$(realpath "$1")
libc_deb=$(realpath "$2")
freetype_deb=$(realpath "$3")
gbm_deb=$(realpath "$4")
for file_path in "$appimage" "$libc_deb" "$freetype_deb" "$gbm_deb"; do
  [[ -f "$file_path" ]] || { echo "Missing file: $file_path" >&2; exit 1; }
done

check_deb() {
  local path=$1 expected_package=$2 expected_version=$3
  [[ $(dpkg-deb -f "$path" Package) == "$expected_package" &&
     $(dpkg-deb -f "$path" Version) == "$expected_version" &&
     $(dpkg-deb -f "$path" Architecture) == amd64 ]] || {
    echo "Unexpected package, version, or architecture: $path" >&2
    exit 1
  }
}
check_deb "$libc_deb" libc6 2.35-0ubuntu3.15
check_deb "$freetype_deb" libfreetype6 '2.11.1+dfsg-1ubuntu0.4'
check_deb "$gbm_deb" libgbm1 '23.2.1-1ubuntu3.1~22.04.4'

appimage_name=$(basename "$appimage")
if [[ $appimage_name =~ ^CC-Switch-v([0-9]+\.[0-9]+\.[0-9]+)-Linux-x86_64\.AppImage$ ]]; then
  version=${BASH_REMATCH[1]}
else
  echo "Expected CC-Switch-vVERSION-Linux-x86_64.AppImage: $appimage_name" >&2
  exit 1
fi
base="$HOME/.local/share/cc-switch-$version-local"
appdir="$base/squashfs-root"
mkdir -p "$base" "$HOME/.local/bin" "$HOME/.local/share/applications"
offset=$("$appimage" --appimage-offset)
[[ "$offset" =~ ^[0-9]+$ ]] || { echo 'Cannot read AppImage offset' >&2; exit 1; }
unsquashfs -f -o "$offset" -d "$appdir" "$appimage" >/dev/null
dpkg-deb -x "$libc_deb" "$base/glibc"
dpkg-deb -x "$freetype_deb" "$base/freetype"
dpkg-deb -x "$gbm_deb" "$base/gbm"
mkdir -p "$base/compat"
cp -L /lib/x86_64-linux-gnu/libstdc++.so.6 "$base/compat/libstdc++.so.6"
patchelf --remove-rpath "$base/compat/libstdc++.so.6"

loader="$base/glibc/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2"
libs="$base/glibc/lib/x86_64-linux-gnu:$base/freetype/usr/lib/x86_64-linux-gnu:$base/gbm/usr/lib/x86_64-linux-gnu:$base/compat:$appdir/usr/lib:$appdir/usr/lib/x86_64-linux-gnu"
process_dir="$appdir/usr/lib/x86_64-linux-gnu/webkit2gtk-4.1"
for process_name in WebKitWebProcess WebKitNetworkProcess; do
  real="$process_dir/$process_name.real"
  mv "$process_dir/$process_name" "$real"
  printf '#!/bin/sh\nexec "%s" --library-path "%s" --argv0 "%s" "%s" "$@"\n' \
    "$loader" "$libs" "$process_name" "$real" >"$process_dir/$process_name"
  chmod 755 "$process_dir/$process_name"
done

launcher="$HOME/.local/bin/cc-switch-appimage-local"
cat >"$launcher" <<EOF
#!/usr/bin/env bash
set -e
log_dir="\${XDG_CACHE_HOME:-\$HOME/.cache}"
mkdir -p "\$log_dir"
exec >>"\$log_dir/cc-switch-launch.log" 2>&1
printf '\\n[%s] CC Switch launch; DISPLAY=%s; WAYLAND_DISPLAY=%s\\n' "\$(date '+%F %T %z')" "\${DISPLAY:-}" "\${WAYLAND_DISPLAY:-}"
APPDIR="$appdir"
export APPDIR
source "\$APPDIR/apprun-hooks/linuxdeploy-plugin-gtk.sh"
cd "\$APPDIR/usr"
# Tauri's updater replaces /proc/self/exe. Give it a disposable loader copy.
for update_candidate in "\$log_dir"/cc-switch-ld-linux-runtime-*; do
  if [[ -f "\$update_candidate" && \$(stat -c %s "\$update_candidate") -gt 1000000 ]]; then
    saved_update="\$log_dir/cc-switch-updater-\$(date +%Y%m%d-%H%M%S)-\${update_candidate##*-}.AppImage"
    mv "\$update_candidate" "\$saved_update"
    printf 'Saved updater AppImage: %s\\n' "\$saved_update"
  fi
done
runtime_loader=\$(mktemp "\$log_dir/cc-switch-ld-linux-runtime-XXXXXX")
cp "$loader" "\$runtime_loader"
chmod 755 "\$runtime_loader"
exec "\$runtime_loader" --library-path "$libs" "\$APPDIR/usr/bin/cc-switch" "\$@"
EOF
chmod 755 "$launcher"

cat >"$HOME/.local/share/applications/cc-switch.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=CC Switch
Comment=Claude Code, Codex and Gemini configuration manager
Exec=$launcher
Icon=$appdir/usr/share/icons/hicolor/256x256@2/apps/cc-switch.png
Terminal=false
Categories=Development;
StartupWMClass=cc-switch
MimeType=x-scheme-handler/ccswitch;
EOF
if command -v update-desktop-database >/dev/null; then
  update-desktop-database "$HOME/.local/share/applications"
fi
echo "Installed. Launch: $launcher"
