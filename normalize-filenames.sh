#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage:
  $(basename "$0") (--to-NFC | --to-NFD) [--dry-run] DIRECTORY
  --to-NFC Convert to NFC (precomposed)      [default on Linux-like systems]
  --to-NFD Convert to NFD (decomposed)       [default behavior on macOS]
EOF
  exit 1
}

MODE=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --to-NFC) MODE="NFC"; shift ;;
    --to-NFD) MODE="NFD"; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) break ;;
  esac
done

[[ -z "$MODE" || $# -ne 1 ]] && usage

ROOT="$1"
[[ -d "$ROOT" ]] || { echo "Not a directory: $ROOT" >&2; exit 1; }

# Normalize a filename using Python (argument-based, safe)
normalize() {
  python3 - "$MODE" "$1" <<'PY'
import sys, unicodedata
mode = sys.argv[1]
name = sys.argv[2]
print(unicodedata.normalize(mode, name), end="")
PY
}

export MODE DRY_RUN
export -f normalize

find "$ROOT" -depth -print0 |
while IFS= read -r -d '' path; do
  dir=$(dirname "$path")
  base=$(basename "$path")

  normalized=$(normalize "$base")

  raw_bytes=$(printf '%s' "$base" | od -An -tx1)
norm_bytes=$(printf '%s' "$normalized" | od -An -tx1)

if [[ "$raw_bytes" != "$norm_bytes" ]]; then
    src="$dir/$base"
    dst="$dir/$normalized"

    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "Would rename:"
      echo "  $src"
      echo "  -> $dst"
    else
      mv "$src" "$dst"
      echo "Renamed:"
      echo "  $src"
      echo "  -> $dst"
    fi
  fi
done

