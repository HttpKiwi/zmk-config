#!/usr/bin/env bash
# Flash the Kiwiboard dongle UF2.
# Usage: ./flash-dongle.sh
# Then Tab+Bspc (or double-RST) while it waits.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
UF2="${UF2:-$ROOT/firmware/kiwiboard_dongle-nice_nano_v2-zmk.uf2}"
GRACE_SECS="${GRACE_SECS:-8}"
TIMEOUT_SECS="${TIMEOUT_SECS:-60}"

if [[ ! -f "$UF2" ]]; then
  echo "Missing UF2: $UF2" >&2
  exit 1
fi

find_mount() {
  local d
  for d in \
    "/run/media/${USER}/NICENANO" \
    "/media/${USER}/NICENANO" \
    "/run/media/${USER}/RPI-RP2" \
    "/media/${USER}/RPI-RP2"
  do
    if [[ -d "$d" && -w "$d" ]]; then
      printf '%s\n' "$d"
      return 0
    fi
  done
  return 1
}

echo "Dongle UF2: $UF2"
echo "Enter bootloader now (Tab+Bspc, or double-RST on the dongle)."
echo "Waiting ${GRACE_SECS}s…"

for ((i = GRACE_SECS; i > 0; i--)); do
  printf '\r  %2ds ' "$i"
  sleep 1
done
printf '\rLooking for NICENANO…\n'

deadline=$((SECONDS + TIMEOUT_SECS))
mount=""
while (( SECONDS < deadline )); do
  if mount="$(find_mount)"; then
    break
  fi
  sleep 0.25
done

if [[ -z "$mount" ]]; then
  echo "Timed out after ${TIMEOUT_SECS}s — NICENANO never appeared." >&2
  exit 1
fi

echo "Found: $mount"
cp -v "$UF2" "$mount/"
sync

for _ in $(seq 1 40); do
  if [[ ! -d "$mount" ]]; then
    echo "Done — dongle left bootloader."
    exit 0
  fi
  sleep 0.25
done

echo "Copied. If it is still mounted, unplug/replug the dongle."
