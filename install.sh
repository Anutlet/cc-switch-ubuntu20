#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo 'Usage: install.sh APPIMAGE' >&2
  exit 2
fi

for command_name in unsquashfs dpkg-deb patchelf strings sha256sum; do
  command -v "$command_name" >/dev/null || { echo "Missing: $command_name" >&2; exit 1; }
done

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
appimage=$(realpath "$1")
libc_deb="$repo_dir/libs/libc6_2.35-0ubuntu3.15_amd64.deb"
freetype_deb="$repo_dir/libs/libfreetype6_2.11.1+dfsg-1ubuntu0.4_amd64.deb"
gbm_deb="$repo_dir/libs/libgbm1_23.2.1-1ubuntu3.1~22.04.4_amd64.deb"
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

check_hash() {
  local path=$1 expected=$2 actual
  actual=$(sha256sum "$path")
  [[ ${actual%% *} == "$expected" ]] || {
    echo "SHA-256 mismatch: $path" >&2
    exit 1
  }
}
check_hash "$libc_deb" 79e35256227e16a607c154cdeb8d76ff12d20e31de286ea7fd9ad3b96fe0452d
check_hash "$freetype_deb" 3728210ef44a7a51b3824d5c499f6fbd428584a42a65aee15794a4264c8c173a
check_hash "$gbm_deb" 10d37ffd63f8f98fc9a1ad5b32abc7a9da760f4ed85c806d98f10a61c17f8ef5

offset=$("$appimage" --appimage-offset)
[[ "$offset" =~ ^[0-9]+$ ]] || { echo 'Cannot read AppImage offset' >&2; exit 1; }
version_probe=$(mktemp -d)
trap 'rm -rf "$version_probe"' EXIT
unsquashfs -q -no-progress -o "$offset" -d "$version_probe/app" "$appimage" usr/bin/cc-switch
version=$(strings -a "$version_probe/app/usr/bin/cc-switch" | grep -Eo '=== CC Switch v[0-9]+\.[0-9]+\.[0-9]+ started ===' | sed -n '1s/=== CC Switch v\(.*\) started ===/\1/p')
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Cannot detect CC Switch version from AppImage' >&2; exit 1; }
appimage_name=$(basename "$appimage")
if [[ $appimage_name =~ ^CC-Switch-v([0-9]+\.[0-9]+\.[0-9]+)-Linux-x86_64\.AppImage$ ]]; then
  if [[ ${BASH_REMATCH[1]} != "$version" ]]; then
    echo "AppImage filename version does not match embedded version: $appimage_name != $version" >&2
    exit 1
  fi
fi
base="$HOME/.local/share/cc-switch-$version-local"
appdir="$base/squashfs-root"
mkdir -p "$base" "$HOME/.local/bin" "$HOME/.local/share/applications"
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

# Keep the previous desktop launcher if the new binary cannot load with these libraries.
if ! "$loader" --library-path "$libs" --list "$appdir/usr/bin/cc-switch" >"$base/link-check.log" 2>&1; then
  cat "$base/link-check.log" >&2
  echo 'New CC Switch binary is incompatible with the bundled libraries' >&2
  exit 1
fi

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
# Tauri's updater replaces /proc/self/exe; a watcher installs that AppImage
# after this process exits, then relaunches through this compatibility launcher.
runtime_loader=\$(mktemp "\$log_dir/cc-switch-ld-linux-runtime-XXXXXX")
cp "$loader" "\$runtime_loader"
chmod 755 "\$runtime_loader"
nohup "$repo_dir/update-watch.sh" "\$\$" "\$runtime_loader" "$repo_dir/install.sh" "$launcher" "\$@" >/dev/null 2>&1 </dev/null &
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
