#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 4 ]]; then
  echo 'Usage: update-watch.sh APP_PID RUNTIME_LOADER INSTALLER LAUNCHER [APP_ARGS...]' >&2
  exit 2
fi

app_pid=$1
runtime_loader=$2
installer=$3
launcher=$4
shift 4

log_dir=$(dirname "$runtime_loader")
mkdir -p "$log_dir"
exec >>"$log_dir/cc-switch-launch.log" 2>&1

while kill -0 "$app_pid" 2>/dev/null; do
  sleep 1
done

[[ -f $runtime_loader ]] || exit 0
if [[ $(stat -c %s "$runtime_loader") -lt 1000000 ]]; then
  rm -f "$runtime_loader"
  exit 0
fi

update_file="$log_dir/cc-switch-updater-$(date +%Y%m%d-%H%M%S)-$$.AppImage"
mv "$runtime_loader" "$update_file"
printf '[%s] Found downloaded CC Switch update: %s\n' "$(date '+%F %T %z')" "$update_file"

if ! "$update_file" --appimage-offset >/dev/null; then
  printf 'Downloaded file is not a valid AppImage; keeping it at %s\n' "$update_file" >&2
  exit 1
fi

if "$installer" "$update_file"; then
  printf '[%s] Update installed; relaunching CC Switch\n' "$(date '+%F %T %z')"
  nohup "$launcher" "$@" >/dev/null 2>&1 </dev/null &
else
  printf 'Update installation failed; keeping the package at %s\n' "$update_file" >&2
  exit 1
fi
