#!/usr/bin/env bash
# Push keymap → wait for CI → grab dongle UF2 → flash.
# Usage (from anywhere):
#   ~/Projects/Kiwiboard/zmk-config/ship-dongle.sh
#
# Edit first, commit if you want history, then run this.
# While it builds (~2 min), stay near the dongle; flash step
# gives you GRACE_SECS to hit Tab+Bspc / double-RST.
#
# Faster CI: temporarily leave only corne_dongle in build.yaml.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
REPO="${REPO:-HttpKiwi/zmk-config}"
UF2_NAME="corne_dongle-nice_nano_v2-zmk.uf2"
OUT="$ROOT/firmware/$UF2_NAME"
FLASH=("$ROOT/flash-dongle.sh")

cd "$ROOT"

if [[ -n "$(git status --porcelain -- config boards build.yaml)" ]]; then
  echo "Uncommitted keymap/config changes. Commit (or stash) before shipping." >&2
  git status -sb -- config boards build.yaml >&2
  exit 1
fi

branch="$(git rev-parse --abbrev-ref HEAD)"
sha="$(git rev-parse HEAD)"
echo "Shipping $branch @ ${sha:0:7} → $REPO"

# Prefer HTTPS + gh token (works when origin is https without a stored password).
git -c credential.helper='!f() { echo "username=x-access-token"; echo "password=$(gh auth token)"; }; f' \
  push -u origin "HEAD:refs/heads/$branch"

echo "Waiting for Actions run…"
# Give GitHub a moment to create the run for this SHA.
run_id=""
for _ in $(seq 1 30); do
  run_id="$(gh run list --repo "$REPO" --branch "$branch" --limit 10 \
    --json databaseId,headSha,status,event \
    -q ".[] | select(.headSha==\"$sha\") | .databaseId" | head -n1 || true)"
  if [[ -n "$run_id" ]]; then
    break
  fi
  sleep 2
done

if [[ -z "$run_id" ]]; then
  echo "No Actions run found for $sha" >&2
  exit 1
fi

echo "Run $run_id"
gh run watch "$run_id" --repo "$REPO" --exit-status

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

gh run download "$run_id" --repo "$REPO" -D "$tmpdir"
found="$(find "$tmpdir" -name "$UF2_NAME" -print -quit)"
if [[ -z "$found" ]]; then
  echo "Artifact missing $UF2_NAME" >&2
  find "$tmpdir" -name '*.uf2' >&2 || true
  exit 1
fi

mkdir -p "$ROOT/firmware"
cp -v "$found" "$OUT"
echo "Saved $OUT"

# Hand off to the no-keyboard flash helper.
UF2="$OUT" exec "${FLASH[@]}"
