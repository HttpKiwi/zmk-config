#!/usr/bin/env bash
# Flash one half UF2. Usage: ./flash-half.sh left|right
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
SIDE="${1:-}"
case "$SIDE" in
  left)  UF2="$ROOT/firmware/kiwiboard_left-nice_nano_v2-zmk.uf2"
         # artifact-name override in build.yaml drops the board suffix sometimes
         [[ -f "$UF2" ]] || UF2="$ROOT/firmware/kiwiboard_left.uf2"
         ;;
  right) UF2="$ROOT/firmware/kiwiboard_right-nice_nano_v2-zmk.uf2"
         [[ -f "$UF2" ]] || UF2="$ROOT/firmware/kiwiboard_right.uf2"
         ;;
  *) echo "Usage: $0 left|right" >&2; exit 1 ;;
esac
GRACE_SECS="${GRACE_SECS:-10}"
TIMEOUT_SECS="${TIMEOUT_SECS:-60}"
[[ -f "$UF2" ]] || { echo "Missing $UF2" >&2; exit 1; }

find_mount() {
  for d in "/run/media/${USER}/NICENANO" "/media/${USER}/NICENANO" \
           "/run/media/${USER}/RPI-RP2" "/media/${USER}/RPI-RP2"; do
    [[ -d "$d" && -w "$d" ]] && { printf '%s\n' "$d"; return 0; }
  done
  return 1
}

echo "Half UF2 ($SIDE): $UF2"
echo "Double-RST that half into bootloader now. Waiting ${GRACE_SECS}s…"
for ((i = GRACE_SECS; i > 0; i--)); do printf '\r  %2ds ' "$i"; sleep 1; done
printf '\rLooking for NICENANO…\n'
deadline=$((SECONDS + TIMEOUT_SECS))
mount=""
while (( SECONDS < deadline )); do
  mount="$(find_mount)" && break
  sleep 0.25
done
[[ -n "$mount" ]] || { echo "Timed out — NICENANO never appeared." >&2; exit 1; }
echo "Found: $mount"
cp -v "$UF2" "$mount/"
sync
for _ in $(seq 1 40); do
  [[ ! -d "$mount" ]] && { echo "Done — half left bootloader."; exit 0; }
  sleep 0.25
done
echo "Copied. Unplug/replug if still mounted."
