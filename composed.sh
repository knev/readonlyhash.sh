#!/usr/bin/env bash
#
# normalize-filenames.sh
#
# Recursively rename files & directories between NFC ↔ NFD Unicode normalization
# Best used when moving files between macOS and Linux/other systems.
#
# Requirements:
#   Preferred:  icu4c / uconv     (brew install icu4c | apt install icu-devtools | dnf install icu | ...)
#   Fallback:   perl (Unicode::Normalize)
#
# Usage:
#   normalize-filenames.sh [options] [directory]
#
# Options:
#   --to-nfc      Convert to NFC (precomposed)      [default on Linux-like systems]
#   --to-nfd      Convert to NFD (decomposed)       [default behavior on macOS]
#   --dry-run     Show what would be renamed, don't rename
#   --verbose     Show every rename operation
#   --help        Show this help
#

set -u
set -e

# ──────────────────────────────────────────────────────────────────────────────
#  Configuration & helpers
# ──────────────────────────────────────────────────────────────────────────────

DRY_RUN=false
VERBOSE=false
TARGET_FORM=""

show_help() {
    sed -n '/^# Usage:/,/^$/p' "$0" | sed 's/^# //'
    echo
    echo "Default direction depends on OS:"
    echo "  macOS     → converts TO NFC (most common cross-platform choice)"
    echo "  Linux etc → converts TO NFC"
    echo
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --to-nfc)   TARGET_FORM="NFC"; shift ;;
        --to-nfd)   TARGET_FORM="NFD"; shift ;;
        --dry-run)  DRY_RUN=true;     shift ;;
        --verbose)  VERBOSE=true;     shift ;;
        --help|-h)  show_help ;;
        -*)         echo "Unknown option: $1"; exit 1 ;;
        *)          break ;;
    esac
done

START_DIR="${1:-.}"

if [[ ! -d "$START_DIR" ]]; then
    echo "Error: Not a directory: $START_DIR" >&2
    exit 1
fi

# ──────────────────────────────────────────────────────────────────────────────
#  Choose normalization engine
# ──────────────────────────────────────────────────────────────────────────────

if command -v uconv >/dev/null 2>&1; then
    NORMALIZER="uconv"
elif perl -MUnicode::Normalize -e 'exit 0' 2>/dev/null; then
    NORMALIZER="perl"
else
    cat >&2 <<'EOF'
Error: No suitable Unicode normalizer found.

Please install one of:
  • ICU tools (provides uconv)
      macOS:  brew install icu4c
      Ubuntu: sudo apt install icu-devtools
      Fedora: sudo dnf install icu
      Arch:   sudo pacman -S icu
  • perl                (usually already installed)
EOF
    exit 1
fi

# Default direction if not specified
if [[ -z "$TARGET_FORM" ]]; then
    if [[ "$(uname -s)" = Darwin ]]; then
        TARGET_FORM="NFC"   # macOS → most people want NFC when sharing
    else
        TARGET_FORM="NFC"
    fi
fi

echo "Target normalization: $TARGET_FORM"
echo "Engine:               $NORMALIZER"
echo "Start directory:      $(realpath "$START_DIR")"
echo "Dry run:              $DRY_RUN"
echo

# ──────────────────────────────────────────────────────────────────────────────
#  Normalize function
# ──────────────────────────────────────────────────────────────────────────────

normalize_string() {
    local str="$1"
    local form="$2"

    if [[ $NORMALIZER = uconv ]]; then
        local id="any-$(echo "$form" | tr '[:upper:]' '[:lower:]')"
        printf '%s' "$str" | uconv -x "$id" 2>/dev/null || echo "$str"
    else
        # perl fallback
        perl -MUnicode::Normalize -le '
            use strict; use warnings;
            my $s = shift;
            my $form = shift;
            print $form eq "NFC" ? NFC($s) : NFD($s);
        ' -- "$str" "$form" 2>/dev/null || echo "$str"
    fi
}

# ──────────────────────────────────────────────────────────────────────────────
#  Main logic – depth-first (important for renames involving dirs)
# ──────────────────────────────────────────────────────────────────────────────

find "$START_DIR" -depth -name '*' -print0 | while IFS= read -r -d '' path; do
    [[ -e "$path" ]] || continue   # might have been renamed already

    dir=$(dirname "$path")
    oldname=$(basename "$path")

    newname=$(normalize_string "$oldname" "$TARGET_FORM")

    if [[ "$oldname" = "$newname" ]]; then
        continue
    fi

    oldfull="$dir/$oldname"
    newfull="$dir/$newname"

    # Avoid overwriting existing file/dir (safety)
    if [[ -e "$newfull" ]]; then
        echo "SKIP (would overwrite): $oldfull → $newfull" >&2
        continue
    fi

    if $VERBOSE || $DRY_RUN; then
        echo "$oldfull → $newfull"
    fi

    if ! $DRY_RUN; then
        if ! mv -i -- "$oldfull" "$newfull"; then
            echo "Failed to rename: $oldfull" >&2
        fi
    fi
done

echo
echo "Done."
