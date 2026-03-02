#!/usr/bin/env bash
set -euo pipefail

# 1. c3a4 (Precomposed / NFC)
# 
#     Representation: Two bytes (C3 A4).
#     Definition: Represents the single, precomposed Unicode character U+00E4 (LATIN SMALL LETTER A WITH DIAERESIS).
#     Common Use: Standard on Windows, web content, and modern Linux systems (Normalization Form C - NFC). 
# 
# 2. 61cc88 (Decomposed / NFD)
# 
#     Representation: Three bytes (61 CC 88).
#     Definition: Represents two Unicode characters: a normal letter 'a' (U+0061) followed by a combining diaeresis ¨ (U+0308).
#     Common Use: Default for file names on macOS (Normalization Form D - NFD)
# 
# Comparison Table
# Feature 	c3a4 (ä)			61cc88 (a + ̈)
# Bytes		2 (C3 A4)			3 (61 CC 88)
# Type		Precomposed (NFC)	Decomposed (NFD)
# Visual		ä					ä
# Platform	Windows/Web			macOS
# 
# Why This Matters (The "Bug")
# If you compare these two strings on a byte-by-byte level (e.g., in a database query or file handler), they will not match. This can lead to: 
# 
#     Files not being found, even though they appear to have the same name.
#     Incorrect string length calculations (e.g., ä = 1 char, but a+¨ = 2 chars in some contexts).
#     Database WHERE clauses failing. 
# 
# Solution: In programming (PHP, Python, etc.), you should use a normalization library to convert all strings to NFC (c3a4) before comparing or storing them
#

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

