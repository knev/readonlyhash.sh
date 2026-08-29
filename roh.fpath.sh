#!/bin/bash

VERSION="2.2.26"

shopt -s nullglob

#set -x

usage() {
	echo "Usage:" 
	echo "        $(basename "$0") <COMMAND|[<write|show|hide> --force]> [--roh-dir PATH] <ROOT> -- <PATHSPEC/GLOBSPEC>"
	echo "        $(basename "$0") <write|verify> -- <PATH/GLOBSPEC>"
	echo "        $(basename "$0") <query [--db PATH] [ROOT] -- <HASH>"
	echo
	echo "Commands:"
	echo "        v|verify         Verify computed hashes against stored hashes; check for orphaned hashes"
	echo "        verify hide      Verify, ERROR for any hash NOT exclusively hidden (default)"
	echo "        verify show      Verify, ERROR for any hash NOT exclusively shown"
	echo "        w|write          Write SHA256 hashes (hidden by default) for existing files"
	echo "        i|index          Index hash files in a DB (sqlite3 required), including orphaned hashes"
	echo "        verify index     Verify by processing files and create index by maintaining hashes"
	echo "        write index      Write hashes by processing files and create index by maintaining hashes"
	echo "        d|delete         Delete all hashes with a corresponding file"
	echo "        h|hide           Move hash files from the files location to ROH_DIR"
	echo "        s|show           Move hash files from ROH_DIR to next to the file's location"
	echo "        hide sweep       Hide hashes by processing files, and sweep orphaned/mismatched hashes afterwards"
	echo "        show sweep       Show hashes by processing files, and sweep for empty directories afterwards"
	echo "        write hide       Write and hide hashes by processing files"
	echo "        write show       Write and show hashes by processing files"
	echo "        write show sweep Write, show hashes by processing files, and sweep for empty directories afterwards"
	echo "        q|query          Query an existing index for the existence of a hash"
	echo "        index query      Create an index and then query that index"
	echo "        r|recover        Write/index files with hashes found in the DB; remove orphaned duplicates"
	echo "        index recover    Create an index, recover by processing files and recover orphaned hashes in maintenance"
	echo "        e|sweep          Remove all orphaned and mismatched hashes"
	echo "        write sweep      Write hashes by processing files and sweep by maintaining hashes"
	echo "        delete sweep     Delete hash by processing files and sweep remain hashes during maintanence"
	echo
	echo "Options:"
	echo "        --verbose        Verbose operational output"
	echo "  -f,   --force          Force operation even if hash files do not match"
	echo "        --roh-dir        Specify the readonly hash path"
	echo "        --db             Explicity specify the location of the database file"
	echo "        --only-files     Only process files, do not run hash maintanence"
	echo "        --only-hashes    Do not process files, only run hash maintanence"
	echo "  -mfn, --match-filenames When recovering also search for matching filenames"
	echo "        --dedup          With write index: first-seen hash is accepted; subsequent duplicates are logged as NEW"
    echo "        --version        Display the version and exit"
	echo "  -h,   --help           Display this help and exit"
	echo
}

#BUGS
# kiim@Fractal:~/Fractal$ roh.fpath r --db ../fotos.db --roh-dir _Fotos/.roh.git _tmp
# ROH_DIR: using [_Fotos/.roh.git]
# Using DB_SQL [../fotos.db]
# # Processing files ... [_tmp]
# # Hash maintanence ... [_Fotos/.roh.git]
# ROH_DIR: [_Fotos/.roh.git] -- DELETED
# Done.

# readonlyhash
#TODO: readonlyhash commit

# roh.copy
#TODO: on rebase, use the rebase string to rename output .roh.txt file; create a roh.copy command that accepts a rebase string; accepts export output too

#TODO: git init .roh.git256 --object-format=sha256 
#TODO: .roh if git is not applied and .roh.git if git has been applied!?
#TODO: multiple "copies" using readonlyhash write the loop file to the same ~ro.loop.txt
#TODO: permissions: git created as user account, access as different user or root
#TODO: prune all index hashes that point to files that no longer exist
#TODO: ? write parts in C++ or rust to improve performance
#TODO: when using --roh-dir, perhaps the output paths should show that the roh-dir is different than the file location.

KEEP_PROGRESS_BAR="false"

# List of file extensions to avoid, comma separated
EXTENSIONS_TO_AVOID="rslsi,rslsv,rslsz,rsls"

# Loaded from $ROOT/.rohignore at startup; one shell-glob pattern per line.
# Patterns containing '/' are anchored relative to $ROOT (leading '/' optional).
# Patterns without '/' match against the basename of any entry at any depth.
# Dotfile skipping is structural (via shell glob defaults) and not configurable here.
ROHIGNORE_PATTERNS=()

ROOT="_INVALID_"
PATHSPEC="_INVALID_"
ROH_DIR="_INVALID_"
DB_SQL="_INVALID_"

HASH="sha256"

ERROR_COUNT=0
WARN_COUNT=0

EXPORT_MODE="false"
VERBOSE_MODE="false"

load_rohignore() {
    local file="$ROOT/.rohignore"
    [ -r "$file" ] || return 0
    local line
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%%#*}"
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [ -z "$line" ] && continue
        ROHIGNORE_PATTERNS+=("$line")
    done < "$file"
}

should_ignore() {
    local entry="$1"
    [ ${#ROHIGNORE_PATTERNS[@]} -eq 0 ] && return 1
    local base rel pat clean
    base="${entry##*/}"
    rel="$(remove_top_dir "$ROOT" "$entry")"
    for pat in "${ROHIGNORE_PATTERNS[@]}"; do
        if [[ "$pat" == */* ]]; then
            clean="${pat#/}"
            # shellcheck disable=SC2053
            [[ "$rel" == $clean ]] && return 0
        else
            # shellcheck disable=SC2053
            [[ "$base" == $pat ]] && return 0
        fi
    done
    return 1
}

# Build a find prune-args array from ROHIGNORE_PATTERNS, scoped to the search root.
# Usage: _rohignore_find_prune_args <search_root>; result lands in global _ROH_PRUNE_ARGS.
_rohignore_find_prune_args() {
    _ROH_PRUNE_ARGS=()
    [ ${#ROHIGNORE_PATTERNS[@]} -eq 0 ] && return 0
    local root="$1"
    _ROH_PRUNE_ARGS=( '(' )
    local first=1 pat clean
    for pat in "${ROHIGNORE_PATTERNS[@]}"; do
        [ $first -eq 1 ] || _ROH_PRUNE_ARGS+=( -o )
        if [[ "$pat" == */* ]]; then
            clean="${pat#/}"
            _ROH_PRUNE_ARGS+=( -path "$ROOT/$clean" )
        else
            _ROH_PRUNE_ARGS+=( -name "$pat" )
        fi
        first=0
    done
    _ROH_PRUNE_ARGS+=( ')' -prune -o )
}

# Function to check if a file's extension is in the list to avoid
check_extension() {
    local file="$1"

    # Get only the extension part of the filename, supporting double extensions
    local file_extension="${file##*.}"
    # Split the comma-separated list with IFS (local, so no global side-effect)
    # instead of echo|tr — that pipeline cost two process spawns per file.
    local IFS=','
    local ext
    for ext in $EXTENSIONS_TO_AVOID; do
        if [[ "$file_extension" == "$ext" ]]; then
            return 0  # Extension found, exit with success (0) for the function
        fi
    done
    return 1  # Extension not found
}

#------------------------------------------------------------------------------------------------------------------------------------------

generate_hash() {
    local file="$1"
	if [ ! -r "$file" ]; then
        echo >&2
        echo "ERROR: [$file] file -- not readable or permission denied" >&2
		echo "0000000000000000000000000000000000000000000000000000000000000000"
		return
    fi
    # echo $($SHA256_BIN "$file" | awk '{print $1}')
	# echo $(stdbuf -i0 shasum -a 256 "$file" | cut -c1-64) # brew install coreutils || gstdbuf Instead
	# echo $(stdbuf -i0 openssl sha256 "$file" | tail -c 65) # brew install coreutils || gstdbuf Instead
	# Feed the file via stdin (bash opens it) rather than as an openssl argument:
	# the native Windows openssl can't fopen an absolute MSYS path that contains a
	# single quote (and other chars MSYS arg path-conversion mangles). stdin
	# sidesteps that entirely. Output is "(stdin)= <hash>"; the hash is parsed
	# out with bash expansions (CR-stripped, first 64 chars) instead of
	# awk|head — two fewer process spawns per file, which dominates on Windows.
	local out
	out=$(openssl sha256 < "$file")
	out="${out##* }"
	out="${out%$'\r'}"
	echo "${out:0:64}"
}

stored_hash() {
    # First 64 chars of the first line, read with the bash builtin instead of
    # `head -c 64` (a process spawn per call). Same fallbacks as head: zeros
    # when the path is missing/unreadable/a directory, empty for an empty file.
    local hash_file="$1" line=""
    if [ -f "$hash_file" ] && [ -r "$hash_file" ]; then
        IFS= read -r line < "$hash_file"
        line="${line%$'\r'}"
        printf '%s\n' "${line:0:64}"
    else
        echo "0000000000000000000000000000000000000000000000000000000000000000"
    fi
}

#------------------------------------------------------------------------------------------------------------------------------------------

remove_top_dir() {
  local base_dir="$1"
  local full_path="$2"

  # If the base_dir and full_path are identical, return an empty string
  if [[ "$base_dir" == "$full_path" ]]; then
    echo ""
    return
  fi

  # Normalize base_dir: remove trailing slashes and replace multiple slashes
  # with a single slash. Pure bash expansions — the previous sed pipelines
  # cost three process spawns per call in the per-file hot path.
  while [[ "$base_dir" == *//* ]]; do base_dir="${base_dir//\/\//\/}"; done
  while [[ "$base_dir" == */ ]]; do base_dir="${base_dir%/}"; done
  while [[ "$full_path" == *//* ]]; do full_path="${full_path//\/\//\/}"; done

  # Append a trailing slash to base_dir for matching
  base_dir="${base_dir}/"

  # Check if full_path starts with base_dir
  if [[ "$full_path" == "$base_dir"* ]]; then
    echo "${full_path#"$base_dir"}"
  else
    echo "$full_path"
  fi
}

# echo $(remove_top_dir "test" "test")"]" # output: ]
# echo $(remove_top_dir "2002 X.ro" "2002 X.ro/2002_FIRE!") # output: 2002_FIRE!
# echo $(remove_top_dir "2002.ro/." "2002.ro/./2002_FIRE!") # output: 2002_FIRE!
# echo $(remove_top_dir "2002.ro/" "2002.ro//2002_FIRE!") # output: 2002_FIRE!
# echo $(remove_top_dir "Fotos [space]/" "Fotos [space]//1999.ro/1999-07 Cool Runnings Memories") # output: 1999.ro/1999-07 Cool Runnings Memories
# echo $(remove_top_dir "Fotos [space/" "Fotos [space//1999.ro/1999-07 Cool Runnings Memories") # output: 1999.ro/1999-07 Cool Runnings Memories
# echo $(remove_top_dir "$PWD" "$PWD/Fotos") #output: Fotos
# echo $(remove_top_dir "$PWD/Fotos [space]/1999.ro" "$PWD/Fotos [space]/1999.ro/1999-07 Cool Runnings Memories") # output: 1999-07 Cool Runnings Memories
# exit


# given the path of the file, return the path of the hash (hidden in $ROH_DIR)
fpath_to_hash_fpath() {
    local dir="$1"
	local sub_dir="$(remove_top_dir "$ROOT" "$dir")"
    local fpath="$2"

    local hash_fname="${fpath##*/}.$HASH"
    local roh_hash_path="$ROH_DIR${sub_dir:+/}$sub_dir/$hash_fname"
    echo "$roh_hash_path"
}

# given the path of the file, return the path of the hash (placed/shown next to the file)
fpath_to_dir_hash_fpath() {
    local dir="$1"
    local fpath="$2"

    local hash_fname="${fpath##*/}.$HASH"
    echo "$dir/$hash_fname"
}

# given the path to the hidden hash, return the path to the corresponding file
hash_fpath_to_fpath() {
    local roh_hash_fpath="$1"

	local sub_filepath="$(remove_top_dir "$ROH_DIR" "$roh_hash_fpath")"
	local fpath="$ROOT/${sub_filepath%.$HASH}"
	echo "$fpath"
}

#------------------------------------------------------------------------------------------------------------------------------------------

# ── Internal helpers ─────────────────────────────────────────────

# The progress helpers below are pure bash (integer math, no awk/tput/date
# per redraw): each external process in this per-file hot path costs tens of
# milliseconds on Windows (MSYS fork emulation). Results are passed back in
# _PROG_* globals instead of command substitution to avoid subshells too.

# _prog_fmt <numerator> <denominator> <unit> <sep>
#   %.0f/%.1f/%.2f-style rendering chosen by magnitude (like the old awk),
#   integer-only with half-up rounding. Result in _PROG_FMT.
_prog_fmt() {
  local num=$1 denom=$2 unit=$3 sep=$4 r
  if [ "$num" -ge $(( 100 * denom )) ]; then
    printf -v _PROG_FMT '%d%s%s' "$(( (num + denom / 2) / denom ))" "$sep" "$unit"
  elif [ "$num" -ge $(( 10 * denom )) ]; then
    r=$(( (num * 10 + denom / 2) / denom ))
    printf -v _PROG_FMT '%d.%d%s%s' "$(( r / 10 ))" "$(( r % 10 ))" "$sep" "$unit"
  else
    r=$(( (num * 100 + denom / 2) / denom ))
    printf -v _PROG_FMT '%d.%02d%s%s' "$(( r / 100 ))" "$(( r % 100 ))" "$sep" "$unit"
  fi
}

_prog_human_size() {  # result in _PROG_FMT
  local bytes=$1
  if   [ "$bytes" -ge 1099511627776 ]; then _prog_fmt "$bytes" 1099511627776 "TB" " "
  elif [ "$bytes" -ge 1073741824 ];    then _prog_fmt "$bytes" 1073741824 "GB" " "
  else                                      _prog_fmt "$bytes" 1048576 "MB" " "
  fi
}

_prog_human_count() {  # result in _PROG_FMT
  local n=$1
  if   [ "$n" -ge 1000000000 ]; then _prog_fmt "$n" 1000000000 "B" ""
  elif [ "$n" -ge 1000000 ];    then _prog_fmt "$n" 1000000 "M" ""
  elif [ "$n" -ge 1000 ];       then _prog_fmt "$n" 1000 "K" ""
  else _PROG_FMT=$n
  fi
}

# _prog_pct_eta <cur_bytes> <elapsed>
#   Combined byte/file percentage and ETA. Results in _PROG_PCT / _PROG_ETA.
_prog_pct_eta() {
  local cur_bytes=$1 elapsed=$2
  local byte_pct=0 file_pct=0 p
  [ "$_PROG_TOTAL" -gt 0 ] && byte_pct=$(( cur_bytes * 100 / _PROG_TOTAL ))
  [ "$_PROG_TOTAL_FILES" -gt 0 ] && file_pct=$(( _PROG_CURRENT_FILES * 100 / _PROG_TOTAL_FILES ))
  if [ "$_PROG_TOTAL" -eq 0 ] && [ "$_PROG_TOTAL_FILES" -eq 0 ]; then p=100
  elif [ "$_PROG_TOTAL" -eq 0 ]; then p=$file_pct
  elif [ "$_PROG_TOTAL_FILES" -eq 0 ]; then p=$byte_pct
  else p=$(( (byte_pct + file_pct) / 2 ))
  fi
  [ "$p" -gt 100 ] && p=100
  _PROG_PCT=$p

  local byte_eta=0 file_eta=0 n=0 rem
  if [ "$cur_bytes" -gt 0 ]; then
    byte_eta=$(( (_PROG_TOTAL - cur_bytes) * elapsed / cur_bytes )); n=$(( n + 1 ))
  fi
  if [ "$_PROG_CURRENT_FILES" -gt 0 ] && [ "$_PROG_TOTAL_FILES" -gt 0 ]; then
    file_eta=$(( (_PROG_TOTAL_FILES - _PROG_CURRENT_FILES) * elapsed / _PROG_CURRENT_FILES )); n=$(( n + 1 ))
  fi
  if [ "$n" -eq 0 ]; then
    _PROG_ETA="--:--"
  else
    rem=$(( (byte_eta + file_eta) / n ))
    [ "$rem" -lt 0 ] && rem=0
    printf -v _PROG_ETA '%02dm%02ds' "$(( rem / 60 ))" "$(( rem % 60 ))"
  fi
}

# _prog_render_suffix <cur_bytes>
#   The "NN%  files/files  size/size  ETA" tail. Result in _PROG_SUFFIX.
_prog_render_suffix() {
  local cur_bytes=$1
  local down_h total_h cur_files_h total_files_h
  _prog_human_size "$cur_bytes";            down_h=$_PROG_FMT
  _prog_human_size "$_PROG_TOTAL";          total_h=$_PROG_FMT
  _prog_human_count "$_PROG_CURRENT_FILES"; cur_files_h=$_PROG_FMT
  _prog_human_count "$_PROG_TOTAL_FILES";   total_files_h=$_PROG_FMT
  printf -v _PROG_SUFFIX "%3d%%  %s/%s  %s/%s  %s" \
    "$_PROG_PCT" "$cur_files_h" "$total_files_h" "$down_h" "$total_h" "$_PROG_ETA"
}

# _prog_draw_bar <pct> <suffix_len>
#   Builds the bar with per-glyph appends (locale-safe for the multi-byte
#   █/░ — substring slicing would cut them apart under a non-UTF-8 locale);
#   the terminal width is probed once in progress_init, not per redraw.
#   Result in _PROG_BAR.
_prog_draw_bar() {
  local pct=$1 suffix_len=$2
  local bar_width=$(( ${_PROG_COLS:-80} - suffix_len - 3 ))  # 3 = "[" + "] "
  (( bar_width < 10 )) && bar_width=10
  local filled=$(( pct * bar_width / 100 ))
  local empty=$(( bar_width - filled ))
  local i
  _PROG_BAR=""
  for ((i=0; i<filled; i++)); do _PROG_BAR+="█"; done
  for ((i=0; i<empty; i++)); do _PROG_BAR+="░"; done
}

# ── Public API ───────────────────────────────────────────────────

# progress_init <total_bytes> <total_files> [label]
#   Call once before updates. Hides cursor, prints label. The bar only
#   animates on a terminal (_PROG_ACTIVE); when output is piped or captured
#   the redraws (and the per-file stat calls that feed them) are pure
#   overhead, so everything except the label is skipped.
progress_init() {
  _PROG_TOTAL="${1:?usage: progress_init <total_bytes> <total_files> [label]}"
  _PROG_TOTAL_FILES="${2:-0}"
  _PROG_LABEL="${3:-Processing...}"
  _PROG_PREV_BYTES=0
  _PROG_CURRENT_FILES=0
  _PROG_START_SEC=$SECONDS
  _PROG_LAST_PCT=-1
  _PROG_LAST_SEC=-1

  if [ -t 1 ]; then
    _PROG_ACTIVE="true"
    _PROG_COLS=$(tput cols 2>/dev/null)
    [ -z "$_PROG_COLS" ] && _PROG_COLS=80
    printf "\033[?25l"  # hide cursor
  else
    _PROG_ACTIVE="false"
  fi
  printf "%s\n" "$_PROG_LABEL"
}

# progress_update <current_bytes>
#   Call repeatedly with the current processed byte count. Redraws are
#   throttled to percentage changes and clock ticks; intermediate calls only
#   record the byte count.
progress_update() {
  local cur_bytes="${1:?usage: progress_update <current_bytes>}"

  _PROG_PREV_BYTES="$cur_bytes"
  [ "$_PROG_ACTIVE" = "true" ] || return 0

  local elapsed=$(( SECONDS - _PROG_START_SEC ))
  (( elapsed < 1 )) && elapsed=1
  _prog_pct_eta "$cur_bytes" "$elapsed"

  if [ "$_PROG_PCT" = "$_PROG_LAST_PCT" ] && [ "$SECONDS" = "$_PROG_LAST_SEC" ]; then
    return 0
  fi
  _PROG_LAST_PCT=$_PROG_PCT
  _PROG_LAST_SEC=$SECONDS

  _prog_render_suffix "$cur_bytes"
  _prog_draw_bar "$_PROG_PCT" "${#_PROG_SUFFIX}"
  printf "\r[%s] %s" "$_PROG_BAR" "$_PROG_SUFFIX"
}

# progress_log <message>
#   Print a message above the progress bar without disturbing it.
progress_log() {
  # If progress bar isn't active, just echo
  if [ -z "$_PROG_TOTAL" ] || [ "$_PROG_ACTIVE" != "true" ]; then
    printf "%s\n" "$*"
    return
  fi
  # Clear bar, print message, redraw bar — all in one write to minimize flicker
  local cur_bytes="${_PROG_PREV_BYTES:-0}"
  local elapsed=$(( SECONDS - _PROG_START_SEC ))
  (( elapsed < 1 )) && elapsed=1

  _prog_pct_eta "$cur_bytes" "$elapsed"
  _prog_render_suffix "$cur_bytes"
  _prog_draw_bar "$_PROG_PCT" "${#_PROG_SUFFIX}"
  printf "\r\033[2K%s\n\r[%s] %s" "$*" "$_PROG_BAR" "$_PROG_SUFFIX"
}

# progress_done
#   Fills bar to 100%, prints newline, restores cursor. Clears _PROG_TOTAL so
#   any post-done progress_log/log calls print plainly (no stale bar redraw).
progress_done() {
  if [ "$_PROG_ACTIVE" = "true" ]; then
    if [ "$KEEP_PROGRESS_BAR" = "true" ]; then
      _PROG_LAST_PCT=-1  # force the final redraw past the throttle
      progress_update "$_PROG_TOTAL"
      printf "\n"
    else
      printf "\r\033[2K"
    fi
    printf "\033[?25h"  # show cursor
  fi
  _PROG_TOTAL=""
  _PROG_ACTIVE="false"
}

# Internal: resolve LEVEL -> printable prefix, bumping counters where needed.
# Echoes the prefix; sets _LOG_PREFIX as a fast path too.
_log_prefix() {
    # Note: post-increment via `((X++))` returns the OLD value as the exit
    # code; if X was 0 (the very first call), the expression is "false" and
    # callers using `_log_prefix … || return` would silently bail before
    # the message prints. Use `: $((…))` so the exit code is always 0.
    case "$1" in
        OK)      _LOG_PREFIX="  OK" ;;
        INFO)    _LOG_PREFIX="INFO" ;;
        WARN)    _LOG_PREFIX="WARN"  ; : $(( WARN_COUNT++ )) ;;
        ERROR)   _LOG_PREFIX="ERROR" ; : $(( ERROR_COUNT++ )) ;;
        ERR)     _LOG_PREFIX="    ERR" ; : $(( ERROR_COUNT++ )) ;;  # 7-col verbose-short ERROR (colon aligned under RECOVER)
        IDX)     _LOG_PREFIX=" IDX" ;;
        RECOVER) _LOG_PREFIX="RECOVER" ;;
        ROH_DIR) _LOG_PREFIX="ROH_DIR" ;;
        BULLET_6) _LOG_PREFIX="      ■" ;;  # 7-col, aligns under RECOVER
        BULLET_4) _LOG_PREFIX="   ■" ;;     # 4-col, aligns under WARN
        *)       progress_log "BUG: log() called with unknown level [$1]" ; return 1 ;;
    esac
}

# Token helpers: render one logical entity. tok_file = "user file with its
# computed hash"; tok_hash = "hash content with its sidecar filename". Today
# both render [a]: [b]; function identity carries the file/hash distinction so
# tok_hash can later diverge (e.g. drop the ": ", different brackets) without
# touching call sites. The _new variants emit >hash<: [name] for rows that were
# just inserted into IDX (vs [hash]: [name] for already-known rows).
tok_file()     { printf '[%s]: [%s]' "$1" "$2"; }   # (hashcontent, user_file_path)
tok_hash()     { printf '[%s]: [%s]' "$1" "$2"; }   # (hashcontent, sidecar_path)
tok_file_new() { printf '>%s<: [%s]' "$1" "$2"; }   # newly-indexed user file
tok_hash_new() { printf '>%s<: [%s]' "$1" "$2"; }   # newly-indexed sidecar

# log <LEVEL> <message-pieces...>
#   LEVEL ∈ { OK | INFO | WARN | ERROR | IDX | RECOVER | ROH_DIR }
#   Always prints. WARN bumps WARN_COUNT, ERROR bumps ERROR_COUNT (via
#   _log_prefix). Pieces are concatenated and prefixed with "LEVEL: ".
#   Compose entity tokens at the call site via $(tok_file ...), $(tok_hash ...).
log() {
    _log_prefix "$1" || return
    shift
    progress_log "$_LOG_PREFIX: $*"
}

# log_v: verbose-only sibling of log() — drops the call entirely outside --verbose.
log_v() {
    [ "$VERBOSE_MODE" = "true" ] && log "$@"
}

# abort: stop the program with the canonical "Abort.\n\n" + exit 1 sequence.
# Use after a logged failure or with `|| abort` after a function that already
# emitted its own ERROR message.
#
# Uses plain echo (not progress_log) so the output stream ends with newlines —
# progress_log redraws the bar without a trailing newline, which would leave
# the bar's escape sequences in the stream tail and confuse output capture.
# Leading echo breaks off any active progress-bar line.
abort() {
    echo
    echo "Abort."
    echo
    exit 1
}

# log_abort <message-pieces...>
#   Combined ERROR + abort. LEVEL is hard-coded to ERROR — every abort is.
log_abort() {
    log ERROR "$@"
    abort
}

# ellipsis_block <depth> <header> [<desc> <token>]...
#   Render a continuation block at the given depth.
#     depth = 1 → pad = LEVEL+2  (just past "<LEVEL>: ", under [hash] col)
#     depth = 2 → pad = LEVEL+6  (one indent step deeper)
#     depth = N → pad = LEVEL+2 + (N-1)*4
#   Header is rendered as "<pad>... <header>". If trailing (desc, token)
#   pairs follow, they render at depth+1 with right-aligned descriptors so
#   the tokens' "[" line up across rows.
ellipsis_block() {
    local depth=$1; shift
    local pad
    printf -v pad "%*s" "$(( ${#_LOG_PREFIX} + 2 + (depth-1)*4 ))" ""
    progress_log "${pad}... $1"
    shift
    if [ $# -gt 0 ]; then
        local i max=0
        local descs=() tokens=()
        while [ $# -ge 2 ]; do
            descs+=("$1"); tokens+=("$2")
            (( ${#1} > max )) && max=${#1}
            shift 2
        done
        printf -v pad "%*s" "$(( ${#_LOG_PREFIX} + 2 + depth*4 ))" ""
        local desc_pad
        for (( i=0; i<${#descs[@]}; i++ )); do
            printf -v desc_pad "%*s" "$(( max - ${#descs[i]} ))" ""
            progress_log "${pad}... ${desc_pad}${descs[i]} ${tokens[i]}"
        done
    fi
}
ellipsis_block_v() { [ "$VERBOSE_MODE" = "true" ] && ellipsis_block "$@"; }

# phantom <string>
#   LaTeX-style \phantom: emits whitespace whose width matches the input
#   string's character count. Useful for aligning continuation content under
#   a column rendered on the parent line — e.g. pass the parent's hash to
#   skip past its position:
#       ellipsis_block 1 "$(phantom "$some_hash")[$fpath] -- ..."
phantom() { printf '%*s' "${#1}" ""; }

# log_block <LEVEL> <header> [<desc> <token>]...
#   Multi-line: header followed by N (desc, token) pairs. Continuations are
#   indented so that the longest descriptor's "..." aligns just under the
#   "<LEVEL>: " column, and shorter descriptors get extra leading pad so that
#   the token's leading "[" lines up vertically across all continuations.
#   Tokens are typically built with tok_file/tok_hash; literal "[$var]" is
#   fine when only a single bracketed value is wanted.
#   Same counter rules as log().
log_block() {
    _log_prefix "$1" || return
    local prefix="$_LOG_PREFIX"
    progress_log "$prefix: $2"
    shift 2
    local i max=0
    local descs=() tokens=()
    while [ $# -ge 2 ]; do
        descs+=("$1"); tokens+=("$2")
        (( ${#1} > max )) && max=${#1}
        shift 2
    done
    local base_lead=$(( ${#prefix} + 2 ))
    local lead pad
    for (( i=0; i<${#descs[@]}; i++ )); do
        lead=$(( base_lead + max - ${#descs[i]} ))
        printf -v pad "%*s" "$lead" ""
        progress_log "${pad}... ${descs[i]} ${tokens[i]}"
    done
}

# Count total bytes of non-hash files in a directory (skip hidden dirs and .rohignore matches)
_prog_entry_bytes() {
  _rohignore_find_prune_args "$1"
  if [ "$_STAT_FMT" = "bsd" ]; then
    find "$1" "${_ROH_PRUNE_ARGS[@]}" -name '.*' -prune -o -type f ! -name "*.${HASH}" -exec stat -f%z {} + 2>/dev/null | awk '{s+=$1}END{print s+0}'
  else
    find "$1" "${_ROH_PRUNE_ARGS[@]}" -name '.*' -prune -o -type f ! -name "*.${HASH}" -exec stat -c%s {} + 2>/dev/null | awk '{s+=$1}END{print s+0}'
  fi
}

# Count total non-hash files in a directory (skip all hidden and .rohignore matches)
_prog_entry_count() {
  _rohignore_find_prune_args "$1"
  find "$1" "${_ROH_PRUNE_ARGS[@]}" -name '.*' -prune -o -type f ! -name "*.${HASH}" -print 2>/dev/null | wc -l | tr -d ' '
}

# Count total bytes of hash files in a directory (prune .git)
_prog_hash_bytes() {
  if [ "$_STAT_FMT" = "bsd" ]; then
    find "$1" -name ".git" -prune -o -type f -name "*.${HASH}" -exec stat -f%z {} + 2>/dev/null | awk '{s+=$1}END{print s+0}'
  else
    find "$1" -name ".git" -prune -o -type f -name "*.${HASH}" -exec stat -c%s {} + 2>/dev/null | awk '{s+=$1}END{print s+0}'
  fi
}

# Count total hash files in a directory (prune .git)
_prog_hash_count() {
  find "$1" -name ".git" -prune -o -type f -name "*.${HASH}" -print 2>/dev/null | wc -l | tr -d ' '
}

#------------------------------------------------------------------------------------------------------------------------------------------

hex_encode() {
	printf '%s' "$1" | xxd -p | tr -d '\n'
}

hex_decode() {
	printf '%s' "$1" | xxd -r -p
}

# native_path <path>
#   Return a path that native Windows tools (sqlite3) can open. MSYS mangles a
#   POSIX absolute path containing '[' or ']' when handing it as an argument to
#   a native exe, so convert to a Windows path via cygpath there. On macOS/Linux
#   cygpath is absent and the path is returned unchanged.
native_path() {
    if command -v cygpath >/dev/null 2>&1; then
        cygpath -w "$1"
    else
        printf '%s' "$1"
    fi
}

# roh_sqlite3_query <db> <sql>
#   sqlite3 wrapper for value-returning queries. The native Windows sqlite3
#   emits CRLF line endings, so a trailing \r contaminates the last parsed
#   field (numbers fail -eq, hashes/paths miscompare). Strip CR with a bash
#   builtin (no tr) while preserving sqlite3's exit status. No-op on LF
#   platforms (macOS/Linux). Use for SELECTs; INSERT/schema calls don't need it.
roh_sqlite3_query() {
    local db="$1"; shift
    local out
    out=$(sqlite3 "$(native_path "$db")" "$@") || return $?
    printf '%s\n' "${out//$'\r'/}"
}

roh_sqlite3_db_init() {
    local db="$1"

    # Remove existing database file if it exists (no point if using mktemp)
	if [ -f "$db" ]; then
		# rm "$db"; echo "db: [$db] -- deleted"
		return 0
	fi

    # Create or open the SQLite database with a new schema
    sqlite3 "$(native_path "$db")" <<EOF
CREATE TABLE IF NOT EXISTS hashes (
    id INTEGER PRIMARY KEY,
    hash TEXT NOT NULL,
    filename TEXT NOT NULL,
    fpath TEXT UNIQUE,
    roh_hash_fpath TEXT NOT NULL UNIQUE
);

-- Index for faster hash lookups
CREATE INDEX IF NOT EXISTS idx_hash ON hashes(hash);

-- Index for faster filename lookups
CREATE INDEX IF NOT EXISTS idx_filename ON hashes(filename);

-- Remove all existing entries before inserting new ones (if needed)
-- DELETE FROM hashes;

EOF

    echo "DB_SQL: [$db] -- initialized"
	return 0
}

# sqlite3 "$DB_SQL" ".dump hashes" >&2

roh_sqlite3_db_insert() {
    local db="$1"
    local fpath="$2"
    local roh_hash_fpath="$3"
    local stored="$4"
	
    if [ ! -f "$db" ]; then
		log_abort "[$db] -- can not access database file"
	fi

    # Escape single quotes for SQLite
    local fn=$(basename "$fpath")
    local enc_fn=$(hex_encode "$fn")

    local abs_roh_hash_fpath=$(readlink -f "$roh_hash_fpath")
    local enc_abs_roh_hash_fpath=$(hex_encode "$abs_roh_hash_fpath")

	# readlink of missing file on linux returns a path, on macOS returns empty string
	if ! stat "$fpath" >/dev/null 2>&1; then
		# echo "roh_sqlite3_db_insert: abs_fpath NULL" >&2
		sqlite3 "$(native_path "$db")" "INSERT INTO hashes (hash, filename, fpath, roh_hash_fpath) VALUES ('$stored', '$enc_fn', NULL, '$enc_abs_roh_hash_fpath');"
	else
		# echo "roh_sqlite3_db_insert: abs_fpath $abs_fpath" >&2
    	local abs_fpath=$(readlink -f "$fpath")
		local enc_abs_fpath=$(hex_encode "$abs_fpath")
		sqlite3 "$(native_path "$db")" "INSERT INTO hashes (hash, filename, fpath, roh_hash_fpath) VALUES ('$stored', '$enc_fn', '$enc_abs_fpath', '$enc_abs_roh_hash_fpath');"
	fi
}

roh_sqlite3_db_find_hash() {
    local db="$1"
    local stored="$2"

    if [ ! -f "$db" ]; then
		log_abort "[$db] -- can not access database file"
	fi

	# Fields joined with '|' (not char(13)/CR): newer sqlite3 CLIs escape CR in
	# output to "^M", which breaks an IFS=$'\r' split. '|' passes through raw and
	# never appears in the values (hex-encoded paths, the '<NULL>' sentinel, hex
	# hash). Parsed with IFS='|' by the callers.
	roh_sqlite3_query "$db" "SELECT IFNULL(fpath, '<NULL>') || '|' || roh_hash_fpath FROM hashes WHERE hash = '$stored';"
	# '$enc_abs_fpath' | '$enc_abs_roh_hash_fpath'
}

roh_sqlite3_db_find_fn() {
    local db="$1"
    local fn="$2"

    if [ ! -f "$db" ]; then
		log_abort "[$db] -- can not access database file"
	fi

    local enc_fn=$(hex_encode "$fn")
	roh_sqlite3_query "$db" "SELECT IFNULL(fpath, '<NULL>') || '|' || roh_hash_fpath || '|' || hash FROM hashes WHERE filename = '$enc_fn';"
	# '$enc_abs_fpath' | '$enc_abs_roh_hash_fpath' | '$stored'  (see find_hash note re '|')
}

roh_sqlite3_db_fpath_exists() {
    local db="$1"
	local fpath="$2"
	local stored="$3"

    if [ ! -f "$db" ]; then
		log_abort "[$db] -- can not access database file"
	fi

	# readlink of missing file on linux returns a path, on macOS returns empty string
	if ! stat "$fpath" >/dev/null 2>&1; then
		roh_sqlite3_query "$db" "SELECT COUNT(*) FROM hashes WHERE hash = '$stored' AND fpath IS NULL;"
	else
		local abs_fpath=$(readlink -f "$fpath")
		local enc_abs_fpath=$(hex_encode "$abs_fpath")
		roh_sqlite3_query "$db" "SELECT COUNT(*) FROM hashes WHERE fpath = '$enc_abs_fpath';"	
	fi
}

roh_sqlite3_db_get_1fpath_hash() {
    local db="$1"
	local fpath="$2"
	
    if [ ! -f "$db" ]; then
		log_abort "[$db] -- can not access database file"
	fi

	# readlink of missing file on linux returns a path, on macOS returns empty string
	if ! stat "$fpath" >/dev/null 2>&1; then
		return "0000000000000000000000000000000000000000000000000000000000000000";
	else
		local abs_fpath=$(readlink -f "$fpath")
		local enc_abs_fpath=$(hex_encode "$abs_fpath")
		roh_sqlite3_query "$db" "SELECT hash FROM hashes WHERE fpath = '$enc_abs_fpath';"
		# '$stored'
	fi
}

roh_sqlite3_db_roh_hash_fpath_exists() {
    local db="$1"
	local roh_hash_fpath="$2"
	
    if [ ! -f "$db" ]; then
		log_abort "[$db] -- can not access database file"
	fi

    local abs_roh_hash_fpath=$(readlink -f "$roh_hash_fpath")
    local enc_abs_roh_hash_fpath=$(hex_encode "$abs_roh_hash_fpath")

	roh_sqlite3_query "$db" "SELECT COUNT(*) FROM hashes WHERE roh_hash_fpath = '$enc_abs_roh_hash_fpath';"
}

#------------------------------------------------------------------------------------------------------------------------------------------

find_matching_fn() 
{
    local db="$1"
    local fpath="$2"
    local roh_hash_fpath="$3"
    local computed_hash="$4"

    local fn=$(basename "$fpath")
#    local enc_fn=$(hex_encode "$fn")

    local abs_fpath=$(readlink -f "$fpath")
#    local enc_abs_fpath=$(hex_encode "$abs_fpath")

	list_roh_hash_fpaths=$(roh_sqlite3_db_find_fn "$db" "$fn") || return 1
	if [ -n "$list_roh_hash_fpaths" ]; then

		# echo "* Found in file(s): [ ..."
		# echo "$list_roh_hash_fpaths"
		# echo "...]"

		local original_found=0
		local files_displayed=0
		local orphans_displayed=0
		local missing_displayed=0
		local total_found=0

	    # Only print non-empty paths
	    while IFS= read -r found; do
			if [ -n "$found" ]; then
				IFS='|' read -r found_enc_abs_fpath found_enc_abs_roh_hash_fpath found_hash <<< "$found"

				local found_abs_fpath=$(hex_decode "$found_enc_abs_fpath")
				local found_abs_roh_hash_fpath=$(hex_decode "$found_enc_abs_roh_hash_fpath")
				# echo "[$found_hash] [$found_abs_fpath] [$found_enc_abs_roh_hash_fpath]==$enc_abs_roh_hash_fpath"
				
                if [ "$found_enc_abs_roh_hash_fpath" = "$enc_abs_roh_hash_fpath" ]; then
                	# we found the original file
                	if (( original_found > 0 )); then
						echo
						log_abort "this should not happen, should only be one original"
                	fi
                	((original_found++))
                	continue
                fi

				(( total_found == 0 )) && ellipsis_block 1 "FILENAME matches ..."
				((total_found++))

				# file is missing, indexed as file not found, so fpath == NULL
				if [ "$found_enc_abs_fpath" = "<NULL>" ]; then
					if [ "$VERBOSE_MODE" = "true" ] || [ "$orphans_displayed" -lt 2 ]; then
						((orphans_displayed++))
						ellipsis_block 2 "$(tok_hash "$found_hash" "$found_abs_roh_hash_fpath") orphaned hash"
					fi
					continue # found_enc_abs_fpath == NULL, so found_abs_fpath is INVALID
				fi

				# file is found, but at a different path
				if [ -f "$found_abs_fpath" ]; then
					# verify IDX
					local found_stored=$(stored_hash "$found_abs_roh_hash_fpath")
					if [ "$found_hash" != "$found_stored" ]; then
						echo
						log_block ERROR "[$found_abs_roh_hash_fpath] -- IDX inconsistency" \
						    indexed "[$found_hash]" \
						    stored  "[$found_stored]"
						abort
					fi

					if [ "$VERBOSE_MODE" = "true" ] || [ "$files_displayed" -lt 2 ]; then
						((files_displayed++))
						ellipsis_block 2 "$(tok_file "$found_hash" "$found_abs_fpath")"
					fi

				# file is missing, but it was indexed as having a valid fpath
				else
					if [ "$VERBOSE_MODE" = "true" ]; then
						((missing_displayed++))
						ellipsis_block 2 "[$found_abs_fpath] -- indexed, but missing"
					fi
				fi

			fi
	    done <<< "$list_roh_hash_fpaths"

		local displayed=$((files_displayed + orphans_displayed + missing_displayed))
		if [ ! "$VERBOSE_MODE" = "true" ] && [ "$total_found" -gt 3 ]; then
			ellipsis_block 3 "$((total_found - displayed)) more ..."
		fi

		log_v BULLET_4 "NOOP!"
	fi

	return 0
}

#------------------------------------------------------------------------------------------------------------------------------------------

recover_file() {
    local db="$1"
    local fpath="$2"
    local roh_hash_fpath="$3"
    local computed_hash="$4"

	list_roh_hash_fpaths=$(roh_sqlite3_db_find_hash "$db" "$computed_hash") || return 1

	# while IFS=$'\r' read -r found_fpath found_roh_hash_fpath; do
	#	echo "[$found_fpath:$found_roh_hash_fpath]"
	# done <<< "$list_roh_hash_fpaths"
	if [ -n "$list_roh_hash_fpaths" ]; then
		write_hash "$dir" "$fpath" "hide" "false"

		# ----
		# index file

		local stored=$(stored_hash "$roh_hash_fpath")

		local fpath_exists=$(roh_sqlite3_db_fpath_exists "$db" "$fpath" "$stored") || return 1
		if [ "$fpath_exists" -eq 0 ]; then
			roh_sqlite3_db_insert "$db" "$fpath" "$roh_hash_fpath" "$stored"
			log IDX "$(tok_file_new "$stored" "$fpath") -- written INDEXED"
		else
			log_v IDX "$(tok_file "$stored" "$fpath") -- already indexed, skipping"
		fi

		# ----

		return 0
	fi

	# progress_log "  OK: [$computed_hash]: [$fpath] -- NEW!?"
	# [ "$VERBOSE_MODE" = "true" ] && progress_log "  OK: [$computed_hash]: [$fpath] -- NEW!?"

	# else
	# no matching hash found, file identical file names

	log WARN "$(tok_file "$computed_hash" "$fpath") -- NEW!?"
	export_log "$fpath" "$EXPORT_FILE_NEW"

	[ "$match_filenames" = "true" ] &&find_matching_fn "$db" "$fpath" "$roh_hash_fpath" "$computed_hash"
	return 0
}

verify_hash() {
    local dir="$1"
    local fpath="$2"

	# local hash_fname="$(basename "$fpath").$HASH"
	# local roh_hash_path="$ROH_DIR${sub_dir:+/}$sub_dir" # ${sub_dir:+/} expands to a slash / if sub_dir is not empty, otherwise, it expands to nothing.
	# local roh_hash_fpath=$roh_hash_path/$hash_fname

	local verify_mode="hide"
	contains "show" && verify_mode="show"

	local sub_dir="$(remove_top_dir "$ROOT" "$dir")"
	local roh_hash_fpath=$(fpath_to_hash_fpath "$dir" "$fpath")
	local dir_hash_fpath=$(fpath_to_dir_hash_fpath "$dir" "$fpath")

	local computed_hash=$(generate_hash "$fpath")

    if [ -f "$roh_hash_fpath" ] && [ -f "$dir_hash_fpath" ]; then
		local stored_roh=$(stored_hash "$roh_hash_fpath")
		local stored_dir=$(stored_hash "$dir_hash_fpath")

		if [ "$stored_roh" = "$stored_dir" ] && [ "$stored_roh" = "$computed_hash" ]; then
			# all three agree: the duplication is redundant, not inconsistent
			log_block WARN "two hash files exist but EQUAL" \
			    hidden "$(tok_hash "$stored_roh" "$roh_hash_fpath")" \
			    shown  "$(tok_hash "$stored_dir" "$dir_hash_fpath")"
		else
			log_block ERROR "two hash files exist" \
			    hidden   "$(tok_hash "$stored_roh"    "$roh_hash_fpath")" \
			    shown    "$(tok_hash "$stored_dir"    "$dir_hash_fpath")" \
			    computed "$(tok_file "$computed_hash" "$fpath")"
		fi
        return 0
	fi

    if [ -f "$roh_hash_fpath" ]; then
		local stored=$(stored_hash "$roh_hash_fpath")

		if [ "$verify_mode" = "show" ]; then
			if [ "$computed_hash" = "$stored" ]; then
				log ERROR "$(tok_hash "$stored" "$roh_hash_fpath") hash NOT shown"
			else
				log_block ERROR "hash NOT shown" \
				    hidden   "$(tok_hash "$stored"        "$roh_hash_fpath")" \
				    computed "$(tok_file "$computed_hash" "$fpath")"
			fi
			return 0
		fi

		if [ "$computed_hash" = "$stored" ]; then
			log_v OK "$(tok_file "$computed_hash" "$fpath")"
			return 0
		else
			log_block ERROR "hash mismatch" \
			    stored   "$(tok_hash "$stored"        "$roh_hash_fpath")" \
			    computed "$(tok_file "$computed_hash" "$fpath")"
			return 0
		fi

    elif [ -f "$dir_hash_fpath" ]; then
		local stored=$(stored_hash "$dir_hash_fpath")

		if [ "$verify_mode" = "hide" ]; then
			if [ "$computed_hash" = "$stored" ]; then
				log ERROR "$(tok_hash "$stored" "$dir_hash_fpath") hash NOT hidden"
			else
				log_block ERROR "hash NOT hidden" \
				    shown    "$(tok_hash "$stored"        "$dir_hash_fpath")" \
				    computed "$(tok_file "$computed_hash" "$fpath")"
			fi
			return 0
		fi

		if [ "$computed_hash" = "$stored" ]; then
			log_v OK "$(tok_file "$computed_hash" "$fpath")"
			return 0
		else
			log_block ERROR "hash mismatch" \
			    stored   "$(tok_hash "$stored"        "$dir_hash_fpath")" \
			    computed "$(tok_file "$computed_hash" "$fpath")"
			return 0
		fi
	fi

	if contains "recover"; then
		recover_file "$DB_SQL" "$fpath" "$roh_hash_fpath" "$computed_hash"
		return $?
	else
		log WARN "$(tok_file "$computed_hash" "$fpath") -- NEW!?"
		export_log "$fpath" "$EXPORT_FILE_NEW"
	fi
	return 0
}

# New function for hashing
write_hash() {
    local dir="$1"
    local fpath="$2"
	local visibility_mode="$3"
    local force_mode="$4"

	local sub_dir="$(remove_top_dir "$ROOT" "$dir")"
	local roh_hash_fpath=$(fpath_to_hash_fpath "$dir" "$fpath")
	local dir_hash_fpath=$(fpath_to_dir_hash_fpath "$dir" "$fpath")
	local computed_hash="0000000000000000000000000000000000000000000000000000000000000000"

	# optimization for if we run "write index" more than once; also the --dedup hash check
	if contains "index"; then
		# fpath must exist for roh_sqlite3_db_fpath_exists() to succeed here
		if [ ! -f "$fpath" ]; then
			echo
			log_abort "[$fpath] -- file unexpectedly missing during write index"
		fi
		local fpath_exists=$(roh_sqlite3_db_fpath_exists "$DB_SQL" "$fpath" "0000000000000000000000000000000000000000000000000000000000000000") || return 1
		if [ "$fpath_exists" -eq 0 ]; then
			:
		elif [ "$fpath_exists" -eq 1 ]; then
			local stored=$(roh_sqlite3_db_get_1fpath_hash "$DB_SQL" "$fpath") || return 1
			log IDX "$(tok_file "$stored" "$fpath") -- already exists, skipping"
			return
		else
			echo
			log_abort "[$fpath] -- unexpected fpath_exists count [$fpath_exists]"
		fi

		# --dedup: if this content-hash is already indexed (by an earlier file in this walk,
		# or a prior run), skip the write AND the DB insert; log the source to NEW as a
		# "duplicate left untracked".
		if [ "$dedup_mode" = "true" ]; then
			computed_hash=$(generate_hash "$fpath")
			if [ -n "$(roh_sqlite3_db_find_hash "$DB_SQL" "$computed_hash")" ]; then
				log IDX "$(tok_file "$computed_hash" "$fpath") -- duplicate, skipped (--dedup)"
				export_log "$fpath" "$EXPORT_FILE_NEW"
				return 0
			fi
		fi
	fi

	# echo "* [$dir]-[$ROOT]= [$sub_dir]; $roh_hash_fpath"
	# echo "* dir_hash_fpath: $dir_hash_fpath"

	# exist-R=F         , exist-D=T (eq-D=F)
	# exist-R=F         , exist-D=T (eq-D=T)
	# exist-R=F         , exist-D=F
	#---
	# exist-R=T (eq-R=F), exist-D=T (eq-D=F)
	# exist-R=T (eq-R=F), exist-D=T (eq-D=T)
	# exist-R=T (eq-R=F), exist-D=F
	#---
	# exist-R=T (eq-R=T), exist-D=T (eq-D=F)
	# exist-R=T (eq-R=T), exist-D=T (eq-D=T)
	# exist-R=T (eq-R=T), exist-D=F

	# compute if not already done by the --dedup branch above
	if [ "$computed_hash" = "0000000000000000000000000000000000000000000000000000000000000000" ]; then
		if [ "$force_mode" = "true" ] || ( ! [ -f "$dir_hash_fpath" ] && ! [ -f "$roh_hash_fpath" ] ); then
			computed_hash=$(generate_hash "$fpath")
		fi
	fi

	if [ -f "$dir_hash_fpath" ] || [ -f "$roh_hash_fpath" ]; then
		# exist-R=T
	    if [ -f "$roh_hash_fpath" ]; then
			local stored=$(stored_hash "$roh_hash_fpath")
			if [ "$force_mode" = "false" ]; then
				# Free piggy-back: if an upstream branch (e.g. --dedup) already
				# computed the hash, compare and warn on mismatch. Otherwise
				# stay fast: plain `write` over an existing tree must NOT rehash.
				if [ "$computed_hash" != "0000000000000000000000000000000000000000000000000000000000000000" ] \
				   && [ "$computed_hash" != "$stored" ]; then
					log_block WARN "hash mismatch" \
					    computed "$(tok_file "$computed_hash" "$fpath")" \
					    stored   "$(tok_hash "$stored"        "$roh_hash_fpath")"
				else
					log_v OK "$(tok_hash "$stored" "$roh_hash_fpath") -- hidden hash exists -- SKIPPING"
				fi
				return 0
			fi

			if [ "$computed_hash" != "$stored" ]; then
				# exist-R=T (eq-R=F)
				rm "$roh_hash_fpath"
				log_block OK "hash mismatch -- stored deleted (FORCED)!" \
				    computed "$(tok_file "$computed_hash" "$fpath")" \
				    stored   "$(tok_hash "$stored"        "$roh_hash_fpath")"
			fi
		fi

		# exist-D=T
		if [ -f "$dir_hash_fpath" ]; then
			local stored=$(stored_hash "$dir_hash_fpath")
			if [ "$force_mode" = "false" ]; then
				if [ "$computed_hash" != "0000000000000000000000000000000000000000000000000000000000000000" ] \
				   && [ "$computed_hash" != "$stored" ]; then
					log_block WARN "hash mismatch" \
					    computed "$(tok_file "$computed_hash" "$fpath")" \
					    stored   "$(tok_hash "$stored"        "$dir_hash_fpath")"
				else
					log_v OK "$(tok_hash "$stored" "$dir_hash_fpath") -- shown hash exists -- SKIPPING"
				fi
				return 0
			fi

			if [ "$computed_hash" != "$stored" ]; then
				# exist-D=T (eq-D=F)
				rm "$dir_hash_fpath"
				log_block OK "hash mismatch -- stored deleted (FORCED)!" \
				    computed "$(tok_file "$computed_hash" "$fpath")" \
				    stored   "$(tok_hash "$stored"        "$dir_hash_fpath")"
			fi
		fi
	fi

	# echo "* \"$(basename "$fpath")\" "

	# exist-R=F         , exist-D=T (eq-D=T) // sh= T, nop
	# exist-R=F         , exist-D=F			 // sh= T, write to R, move R->D
	#---
	# exist-R=T (eq-R=T), exist-D=T (eq-D=T) // sh= T, (write to R), move R->D
	# exist-R=T (eq-R=T), exist-D=F          // sh= T, (write to R), move R->D

	# exist-R=F         , exist-D=T (eq-D=T) // sh= F, (write to R), move D->R
	# exist-R=F         , exist-D=F			 // sh= F, write to R
	#---
	# exist-R=T (eq-R=T), exist-D=T (eq-D=T) // sh= F, (write to R), move D->R
	# exist-R=T (eq-R=T), exist-D=F          // sh= F, (write to R)

	# exist-R=F         , exist-D=F
	if ! [ -f "$dir_hash_fpath" ] && ! [ -f "$roh_hash_fpath" ]; then
		# write to R
		if [ "$visibility_mode" = "show" ]; then
			# write to $dir_hash_fpath, because it exist, then let visibility handle the move
			echo "$computed_hash" > "$dir_hash_fpath"
			log_v OK "$(tok_file "$computed_hash" "$fpath") -- file hash written"
		else
			local roh_hash_just_path="$ROH_DIR${sub_dir:+/}$sub_dir"
			[ ! -d "$ROH_DIR" ] && log ROH_DIR "creating [$ROH_DIR]"
			if mkdir -p "$roh_hash_just_path" 2>/dev/null && { echo "$computed_hash" > "$roh_hash_fpath"; } 2>/dev/null; then
				log_v OK "$(tok_file "$computed_hash" "$fpath") -- file hash written"
			else
				log ERROR "[$fpath] -- failed to write hash to [$roh_hash_fpath]"
				return 0  # Signal that an error occurred
			fi
		fi
		# --dedup: insert into DB inline so subsequent same-hash files in this walk are skipped.
		if [ "$dedup_mode" = "true" ] && contains "index"; then
			roh_sqlite3_db_insert "$DB_SQL" "$fpath" "$roh_hash_fpath" "$computed_hash"
		fi
		return 0
	fi

	# exist-R=F         , exist-D=T (eq-D=T) // sh= T, nop
	#---
	# exist-R=T (eq-R=T), exist-D=T (eq-D=T) // sh= T, move R->D, clobber
	# exist-R=T (eq-R=T), exist-D=F          // sh= T, move R->D

	# exist-R=F         , exist-D=T (eq-D=T) // sh= F, move D->R
	# exist-R=T (eq-R=T), exist-D=T (eq-D=T) // sh= F, move D->R, clobber
	#---
	# exist-R=T (eq-R=T), exist-D=F          // sh= F, nop

	if [ "$visibility_mode" = "show" ] && [ -f "$roh_hash_fpath" ]; then
		# move R->D: show
		manage_hash_visibility "$dir" "$fpath" "show" "$force_mode"

	elif [ "$visibility_mode" != "show" ] && [ -f "$dir_hash_fpath" ]; then
		# move D->R: hide
		manage_hash_visibility "$dir" "$fpath" "hide" "$force_mode"
	
	# else
	#	echo "  OK: [$computed_hash]: [$dir] \"$(basename "$fpath")\""
	fi

	return 0
}

# Function to delete hash files
delete_hash() {
    local dir="$1"
    local fpath="$2"

	local sub_dir="$(remove_top_dir "$ROOT" "$dir")"
	local roh_hash_fpath=$(fpath_to_hash_fpath "$dir" "$fpath")

	local dir_hash_fpath=$(fpath_to_dir_hash_fpath "$dir" "$fpath")
    if [ -f "$dir_hash_fpath" ]; then
		rm "$dir_hash_fpath"
		log_v OK "[$fpath] -- hash file [$dir_hash_fpath] -- deleted"
		export_log "$dir_hash_fpath" "$EXPORT_HASH_DELETED"
	fi

    if [ -f "$roh_hash_fpath" ]; then
		rm "$roh_hash_fpath"
		log_v OK "[$fpath] -- hash file [$roh_hash_fpath] -- deleted"
		export_log "$roh_hash_fpath" "$EXPORT_HASH_DELETED"
    fi

	return 0
}

manage_hash_visibility() {
    local dir="$1"
    local fpath="$2"
    local action="$3"
    local force_mode="$4"

	local sub_dir="$(remove_top_dir "$ROOT" "$dir")"
	local roh_hash_fpath=$(fpath_to_hash_fpath "$dir" "$fpath")

	local src_fpath
    local dest_fpath
    if [ "$action" = "show" ]; then
		src_fpath=$(fpath_to_hash_fpath "$dir" "$fpath")
		dest_fpath=$(fpath_to_dir_hash_fpath "$dir" "$fpath") 
    elif [ "$action" = "hide" ]; then
		src_fpath=$(fpath_to_dir_hash_fpath "$dir" "$fpath")
		dest_fpath=$(fpath_to_hash_fpath "$dir" "$fpath")
    else
        echo
        log_abort "invalid hash visibility action [$action]"
    fi

	# # src yes, dest yes -> err else mv (forced)
	# # src yes, dest no  -> mv
	# # src no,  dest yes -> check dest hash, if computed=dest; OK else err
	# # src no,  dest no  -> err
	
	local past_tense="hidden"
	[ "$action" = "show" ] && past_tense="shown"

	if [ -f "$src_fpath" ]; then
		if [ -f "$dest_fpath" ] && [ "$force_mode" = "false" ]; then
			if [ "$(stored_hash "$src_fpath")" != "$(stored_hash "$dest_fpath")" ]; then
				log ERROR "[$fpath] -- not moving/(not $past_tense) ..."
				ellipsis_block 1 "destination [$dest_fpath] -- exists"
				ellipsis_block 1 "for source [$src_fpath]"
				return 0
			fi
			# equal hashes: move is effectively a redundant-file cleanup, no --force needed.
		fi

		if [ "$action" = "hide" ]; then
			local roh_hash_just_path="$ROH_DIR${sub_dir:+/}$sub_dir"
			[ ! -d "$ROH_DIR" ] && log ROH_DIR "creating [$ROH_DIR]"
			if ! mkdir -p "$roh_hash_just_path" 2>/dev/null; then
				log ERROR "[$fpath] -- failed to make (hash) directory [$roh_hash_just_path]"
				return 0
			fi
		fi
		if ! mv -- "$src_fpath" "$dest_fpath" 2>/dev/null; then
			log ERROR "[$fpath]: [$src_fpath] to [$dest_fpath] -- failed to move hash file"
			return 0
		fi
        log_v OK "[$fpath]: [$dest_fpath] hash file -- moved($past_tense)"
        return 0
	else
		if [ -f "$dest_fpath" ]; then
		# 	local stored=$(stored_hash "$dest_fpath")
		# 	if [ "$computed_hash" = "$stored" ]; then
			log_v OK "[$fpath]: [$dest_fpath] hash file already exists($past_tense) -- nothing to move($action), NOOP"
			return 0  # No error
		# 	fi
		fi

        log ERROR "[$fpath]: [$src_fpath] hash file -- NOT found, not $past_tense"
        return 0
    fi

	return 0
}

#------------------------------------------------------------------------------------------------------------------------------------------

# Count total bytes for progress bar — mirrors process_entry skip logic
# count_entry_bytes() {
# 	local entry="$1"
# 
# 	if [ -L "$entry" ]; then
# 		return 0
# 	elif [ -d "$entry" ]; then
# 		if [ "$entry" != "$ROOT" ] && ([ -d "$entry/.roh.git" ] || [ -f "$entry/_.roh.git.zip" ]); then
# 			return 0
# 		fi
# 		for sub_entry in "$entry"/*; do
# 			count_entry_bytes "$sub_entry"
# 		done
# 	elif [ -f "$entry" ]; then
# 		if [[ $(basename "$entry") =~ \.${HASH}$ ]]; then
# 			return 0
# 		fi
# 		local entry_bytes
# 		if [ "$_STAT_FMT" = "bsd" ]; then
# 			entry_bytes=$(stat -f%z "$entry")
# 		else
# 			entry_bytes=$(stat -c%s "$entry")
# 		fi
# 		_COUNT_TOTAL_BYTES=$(( _COUNT_TOTAL_BYTES + entry_bytes ))
# 	fi
# }

# Function to process entries contents recursively
process_entry()
{
	local parent="$1"
    local entry="$2"
	# local sub_dir="$(remove_top_dir "$ROOT" "$dir")"
	local visibility_mode="$3"
    local force_mode="$4"

	if should_ignore "$entry"; then
		log_v INFO "Ignoring [$entry] (matches .rohignore)"
		export_log "$entry" "$EXPORT_FILE_IGNORED"
		return 0
	fi

	if [ -L "$entry" ]; then
		log_v INFO "Avoiding symlink [$entry] like the Plague"
		return 0

	# If the entry is a directory, process it recursively
    elif [ -d "$entry" ]; then

		# Flag this directory only if it holds a hidden entry that is neither one
		# of our own .roh* files nor covered by .rohignore. The exclusion is
		# dot-less (.roh* not .roh.*) on purpose so it also covers .rohignore
		# itself; every other hidden entry is run through should_ignore, so a
		# folder whose only hidden content is ignored (e.g. .DS_Store) is quiet.
		# Glob instead of find(1): `.[!.]*` + `..?*` together match every
		# dot-entry except `.`/`..` (nullglob is on), saving a process spawn
		# per directory. `-e || -L` keeps broken symlinks visible, as find did.
		local _h
		for _h in "$entry"/.[!.]* "$entry"/..?*; do
			[ -e "$_h" ] || [ -L "$_h" ] || continue
			case "${_h##*/}" in .roh*) continue ;; esac
			if ! should_ignore "$_h"; then
				export_log "$entry" "$EXPORT_FILE_IGNORED"
				break
			fi
		done
	
		if [ "$entry" != "$ROOT" ] && ([ -d "$entry/.roh.git" ] || [ -f "$entry/_.roh.git.zip" ]); then
			log WARN "[$entry] is a readonlyhash directory -- SKIPPING"
			if [ "$_PROG_ACTIVE" = "true" ]; then
				_PROG_CURRENT_BYTES=$(( _PROG_CURRENT_BYTES + $(_prog_entry_bytes "$entry") ))
				_PROG_CURRENT_FILES=$(( _PROG_CURRENT_FILES + $(_prog_entry_count "$entry") ))
				progress_update "$_PROG_CURRENT_BYTES"
			fi
			return 0
		fi

		if contains "verify" && [ "$VERBOSE_MODE" = "false" ]; then
			local sub_dir="$(remove_top_dir "$ROOT" "$entry")"
			local roh_hash_path="$ROH_DIR${sub_dir:+/}$sub_dir"
			# echo "ROH_HASH_PATH(entry) is [$roh_hash_path]"

			if [ ! -d "$roh_hash_path" ]; then
				# Stuff that is NOT REAL: symlinks (files or dirs), hidden files, empty subdirs (any depth)
				has_real_files=$(find "$entry" -mindepth 1 -not -name '.*' ! -type l ! -type d -print | head -n 1)
				has_hashes=$(find "$entry" -type f -name '*.sha256' -print | head -n 1)
				
				if [ -n "$has_real_files" ] && [ -z "$has_hashes" ]; then
				    log WARN "[$entry] -- NEW DIRECTORY!?"
					export_log "$entry" "$EXPORT_FILE_NEW"
					if [ "$_PROG_ACTIVE" = "true" ]; then
						_PROG_CURRENT_BYTES=$(( _PROG_CURRENT_BYTES + $(_prog_entry_bytes "$entry") ))
						_PROG_CURRENT_FILES=$(( _PROG_CURRENT_FILES + $(_prog_entry_count "$entry") ))
						progress_update "$_PROG_CURRENT_BYTES"
					fi
				    return 0
				fi
			fi

		fi

		#process_directory "$entry" "$visibility_mode" "$force_mode" || return 1
	    for sub_entry in "$entry"/*; do
			process_entry "$entry" "$sub_entry" "$visibility_mode" "$force_mode" || return 1
		done

	# else ...
    elif [ -f "$entry" ]; then
		case "$entry" in *.$HASH) # && [[ $(basename "$entry") != "_.roh.git.zip" ]]; then
			return 0 ;;
		esac

		# stat only feeds the progress bar's byte counter — skip its process
		# spawn per file when the bar is inactive.
		if [ "$_PROG_ACTIVE" = "true" ]; then
			local entry_bytes
			if [ "$_STAT_FMT" = "bsd" ]; then
				entry_bytes=$(stat -f%z "$entry")
			else
				entry_bytes=$(stat -c%s "$entry")
			fi
			_PROG_CURRENT_BYTES=$(( _PROG_CURRENT_BYTES + entry_bytes ))
		fi
		(( _PROG_CURRENT_FILES++ ))
		progress_update "$_PROG_CURRENT_BYTES"

		if ! contains "delete"; then
			if check_extension "$entry"; then
				log ERROR "[$parent] \"$(basename "$entry")\" -- file with restricted extension"
				return 0
			fi

			if contains "verify" || contains "recover"; then
				verify_hash "$parent" "$entry" || return 1
			elif contains "write"; then
				write_hash "$parent" "$entry" "$visibility_mode" "$force_mode" || return 1
			fi

			if ! contains "verify"; then
				if contains "hide"; then
					manage_hash_visibility "$parent" "$entry" "hide" "$force_mode" || return 1
				elif contains "show"; then
					manage_hash_visibility "$parent" "$entry" "show" "$force_mode" || return 1
				fi
			fi
		else
			delete_hash "$parent" "$entry" || return 1
        fi

    fi	
	
	return 0
}

#------------------------------------------------------------------------------------------------------------------------------------------

# check_pre_reqs <cmd>...
# Abort with a clear message listing every required external tool that is
# missing. command -v is a shell builtin, so this works even on environments
# where `which` itself isn't installed (e.g. some Git-Bash setups).
check_pre_reqs() {
    local req missing=()
    for req in "$@"; do
        command -v "$req" >/dev/null 2>&1 || missing+=("$req")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        echo "ERROR: $(basename "$0") requires missing tool(s): ${missing[*]}" >&2
        echo "Abort." >&2
        echo >&2
        exit 1
    fi
}

# Check if a command is provided
if [ $# -eq 0 ]; then
	usage
    exit 1
fi

QUERY_HASH="0000000000000000000000000000000000000000000000000000000000000000"

# ----

# Compatible with bash 3.2+ (macOS default) and bash 4+

# List of valid full commands
valid_long="verify write index delete hide show query recover sweep"

# Short to long mapping (using case statement instead of assoc array)
get_long() {
    case "$1" in
        v) echo "verify" ;;
        w) echo "write" ;;
        i) echo "index" ;;
        d) echo "delete" ;;
        h) echo "hide" ;;
        s) echo "show" ;;
        q) echo "query" ;;
        r) echo "recover" ;;
        e) echo "sweep" ;;
        *) echo "" ;;  # empty = invalid
    esac
}

commands=()  # normal array is fine even in 3.2

contains() {
    local needle="$1"
    local item
    for item in "${commands[@]}"; do
        [[ "$item" == "$needle" ]] && return 0
    done
    return 1
}

i=1
while [ $i -le $# ]; do
    arg="${!i}"

    # Stop on any switch-like argument
    case "$arg" in
        -*) break ;;
    esac

    # 1. Try full word match (word-boundary lookup without a grep spawn)
    if [[ " $valid_long " == *" $arg "* ]]; then
        commands+=("$arg")
        i=$((i+1))
        continue
    fi

    # 2. Try short letters (consecutive, no separators)
    if [[ "$arg" =~ ^[vwidhsqre]+$ ]]; then
        invalid=0
        for ((j=0; j<${#arg}; j++)); do
            c="${arg:$j:1}"
            long=$(get_long "$c")
            if [ -n "$long" ]; then
                commands+=("$long")
            else
                echo "ERROR: unknown short operation '$c' in '$arg'" >&2
                invalid=1
                break
            fi
        done
        if [ $invalid -eq 0 ]; then
            i=$((i+1))
            continue
        fi
    fi

	if [ ${#commands[@]} -eq 0 ]; then
		# If we get here → error
		echo "ERROR: invalid command [$arg]" >&2
		# echo "Allowed full: verify write index delete hide show query recover sweep" >&2
		# echo "     short:  v      w     i      d      h    s    q     r      e" >&2
		# echo "Shorts can be concatenated like: vwidhsqre" >&2
		usage
		exit 1
	fi
	break
done
# echo "Parsed commands (${#commands[@]}):"
# for cmd in "${commands[@]}"; do
#     echo "  - $cmd"
# done

# Reset positional parameters to remaining arguments only
shift $((i-1))   # now $1 is the first -something argument

# -----

# Parse command line options
roh_dir_mode="false"
roh_dir="_INVALID_"
db=""
force_mode="false"
only_files="false"
only_hashes="false"
match_filenames="false"
dedup_mode="false"

# Translate short alias -mfn to --match-filenames before getopts (getopts
# does not support multi-character short options).
_mfn_args=()
for _mfn_a in "$@"; do
	case "$_mfn_a" in
		-mfn) _mfn_args+=("--match-filenames") ;;
		*)    _mfn_args+=("$_mfn_a") ;;
	esac
done
set -- "${_mfn_args[@]}"
unset _mfn_args _mfn_a

while getopts "vfh-:" opt; do
  # echo "Option: $opt, Arg: $OPTARG, OPTIND: $OPTIND"
  case $opt in
	v)
	  echo "$(basename "$0") version: v$VERSION"
	  echo
	  exit 0
	  ;;
	f)
	  force_mode="true"
	  ;;
    h)
      usage
      exit 0
      ;;	  
    -)
      case "${OPTARG}" in
        roh-dir)
		  roh_dir_mode="true"
          roh_dir="${!OPTIND}"
          OPTIND=$((OPTIND + 1))
          ;;		  
        db)
          db="${!OPTIND}"
          OPTIND=$((OPTIND + 1))
          ;;		  
        force)
          force_mode="true"
          ;;
		only-files)
		  only_files="true"
		  ;;
		only-hashes)
		  only_hashes="true"
		  ;;
		match-filenames)
		  match_filenames="true"
		  ;;
		dedup)
		  dedup_mode="true"
		  ;;
		verbose)
		  VERBOSE_MODE="true"
		  ;;
	    version)
	      echo "$(basename "$0") version: v$VERSION"
		  echo
	      exit 0
	      ;;
        help)
          usage
          exit 0
          ;;
        *)
          echo "ERROR: invalid option: [--${OPTARG}]" >&2
          usage
          exit 1
          ;;
      esac
      ;;
    \?)
      echo "ERROR: invalid option: [-${OPTARG}]" >&2
      usage
      exit 1
      ;;
    :)
      echo "ERROR: option [-$OPTARG] requires an argument." >&2
      usage
      exit 1
      ;;
  esac
done

# echo "[$@]"

globspec_mode="false"
PATHSPEC=""

# is "--" the very first parameter after all the switches (no ROOT)
prev=$((OPTIND-1))
if [[ $OPTIND -ge 2 && ${!prev} == "--" ]]; then
	# capture all remaining arguments after the options have been processed
	shift $((OPTIND-1))

	if [ $# -eq 0 ]; then 
		echo "ERROR: expected argument after \"--\"" >&2
		usage
		exit 1	
	fi

	globspec_mode="true"
else
	# capture all remaining arguments after the options have been processed
	shift $((OPTIND-1))

	# Bash's parameter expansion feature, specifically the ${parameter:-default_value} syntax
	# ROOT="${1:-.}"
	ROOT=$1
	if [ -z "$ROOT" ]; then 
		echo "ERROR: NO valid ROOT specified [$ROOT]" >&2
		usage
		exit 1	
	fi
	# echo "* ROOT [$ROOT]"
	if ! contains "query" && [ ! -d "$ROOT" ]; then
		log_abort "[$ROOT] -- directory does not exist"
	fi
	shift

	if [ "$1" = "--" ]; then
		shift
		PATHSPEC="$1"
		if [ -z "$PATHSPEC" ]; then
			echo "ERROR: expected argument after \"--\"" >&2
			usage
			exit 1	
		fi
		shift # this will fail if there are not enough args
		if [ $# -ne 0 ]; then 
			echo "ERROR: too many arguments after \"--\"" >&2
			usage
			exit 1	
		fi
		# echo "* PATHSPEC (ROOT) set to [$PATHSPEC]"
	fi
fi

# echo "[$@]"

visibility_mode="none"

if [ ${#commands[@]} -eq 3 ]; then
	if contains "write" && contains "show" && contains "sweep"; then
		visibility_mode="show"
	else
		echo "ERROR: invalid triple command combination [${commands[@]}]" >&2
		usage
		exit 1	
	fi
elif [ ${#commands[@]} -eq 2 ]; then
	# In globspec mode, hashes are always written next to files, so `ws` is
	# just a redundant restating of `w` and should be accepted as equivalent.
	if [ "$globspec_mode" = "true" ] \
	   && ! contains "query" \
	   && ! ( contains "write" && contains "show" ); then
		echo "ERROR: invalid globspec command combination [${commands[@]}]" >&2
		usage
		exit 1
	fi

	if contains "verify" && ( contains "show" || contains "hide" ); then
		:
	elif contains "index" && ( contains "query" || contains "recover" || contains "verify" || contains "write"); then
		:
	elif contains "sweep" && ( contains "write" || contains "delete" || contains "show" || contains "hide" ); then
		:
	elif contains "write" && contains "show"; then
		visibility_mode="show"
	elif contains "write" && contains "hide"; then
		visibility_mode="hide"
	else
		echo "ERROR: invalid double command combination [${commands[@]}]" >&2
		usage
		exit 1	
	fi
elif [ ${#commands[@]} -eq 1 ]; then
	:
else
	echo "ERROR: invalid command combination [${commands[@]}]" >&2
	usage
	exit 1
fi

# Required external tools: openssl is always needed (generate_hash). The
# DB-backed commands (index/query/recover) additionally need sqlite3 and xxd
# (hex-encode of paths). Checked only after the command combination is known to
# be valid, so bad combinations report their own error first. Fail fast before
# processing any files.
reqs=(openssl)
if contains "index" || contains "query" || contains "recover"; then
	reqs+=(sqlite3 xxd)
fi
check_pre_reqs "${reqs[@]}"

# Check for force_mode usage
if [ "$force_mode" = "true" ] && ! contains "write" && ! contains "show" && ! contains "hide"; then
    echo "ERROR: [--force] can only be used with: write|show|hide" >&2
    usage
    exit 1
fi

# Check for dedup_mode usage
if [ "$dedup_mode" = "true" ] && ! contains "index"; then
    echo "ERROR: [--dedup] can only be used with: index" >&2
    usage
    exit 1
fi

# ----

if [ "$roh_dir_mode" = "true" ]; then
	ROH_DIR="$roh_dir"
	log ROH_DIR "using [$ROH_DIR]"
	if [ ! -d "$ROH_DIR" ] || [ ! -x "$ROH_DIR" ]; then
		echo "ERROR: --roh-dir [$ROH_DIR] does not exist or is not accessible" >&2
		exit 1
	fi
else
	ROH_DIR="$ROOT/.roh.git"
fi
# echo "* ROH_DIR [$ROH_DIR]"

# NOTE: use the parent path, NOT "$ROH_DIR/../.roh.logs". The latter embeds
# ".roh.git/.." literally, so `mkdir -p "$ROH_LOGS"` materialises an empty
# .roh.git before resolving the "..", creating the hash store as a side-effect
# on read-only runs. dirname semantics via bash expansion (no process spawn):
# strip a trailing slash, then everything after the last slash; "." when the
# path has no directory part.
_roh_logs_parent="${ROH_DIR%/}"
case "$_roh_logs_parent" in
    */*) _roh_logs_parent="${_roh_logs_parent%/*}" ;;
    *)   _roh_logs_parent="." ;;
esac
ROH_LOGS="$_roh_logs_parent/.roh.logs"
if [ -d "$ROH_LOGS" ]; then
	rm -rf "$ROH_LOGS"
fi
EXPORT_FILE_NEW="$ROH_LOGS/files-new.exported.txt"
EXPORT_FILE_MISSING="$ROH_LOGS/files-missing.exported.txt"
EXPORT_FILE_IGNORED="$ROH_LOGS/files-ignored.exported.txt"
EXPORT_HASH_DELETED="$ROH_LOGS/hashes-deleted.exported.txt"

# Append <line> to export log <file>, creating $ROH_LOGS lazily so read-only or
# no-op runs (verify/show with nothing to report) don't leave an empty .roh.logs
# behind. No-op unless EXPORT_MODE is enabled.
export_log() {
	[ "$EXPORT_MODE" = "true" ] || return 0
	mkdir -p "$ROH_LOGS"
	printf '%s\n' "$1" >> "$2"
}

load_rohignore

if [ -z "$db" ]; then
    DB_SQL=("$ROOT/.roh.sqlite3")  # Single path as an array
else	
	#IFS=':' read -r -a DB_SQL <<< "$db"  # Assign colon-separated paths to DB_SQL array
	DB_SQL="$db"
fi
# echo "* DB_SQL [${DB_SQL[*]}]"

if contains "index"; then
	if ! roh_sqlite3_db_init "$DB_SQL"; then
		log_abort "[$DB_SQL] -- database file? this should not happen"
	fi
elif contains "verify"; then
	if  [ -f "$DB_SQL" ]; then
		log WARN "database file [$DB_SQL] exists; has not been deleted"
	fi
fi

if contains "index" || contains "recover" ; then
	if  [ -f "$DB_SQL" ]; then
		echo "Using DB_SQL [$DB_SQL]"
	else
		log_abort "[$DB_SQL] -- database file not found"
	fi
fi

#------------------------------------------------------------------------------------------------------------------------------------------

recover_hash() {
    local db="$1"
    local fpath="$2"
    local roh_hash_fpath="$3"
    local stored="$4"

	log_v RECOVER "$(tok_hash "$stored" "$roh_hash_fpath") orphaned hash ..."
	
    local fn=$(basename "$fpath")
    local enc_fn=$(hex_encode "$fn")

    local abs_fpath=$(readlink -f "$fpath")
    local enc_abs_fpath=$(hex_encode "$abs_fpath")

    local abs_roh_hash_fpath=$(readlink -f "$roh_hash_fpath")
    local enc_abs_roh_hash_fpath=$(hex_encode "$abs_roh_hash_fpath")

	list_roh_hash_fpaths=$(roh_sqlite3_db_find_hash "$db" "$stored") || return 1
	if [ -n "$list_roh_hash_fpaths" ]; then

		# echo "* Found in file(s): [ ..."
		# echo "$list_roh_hash_fpaths"
		# echo "...]"

		local original_found=0
		local duplicates_found=0
		local total_found=0
	
	    # Only print non-empty paths
	    while IFS= read -r found; do
	        if [ -n "$found" ]; then
				IFS='|' read -r found_enc_abs_fpath found_enc_abs_roh_hash_fpath <<< "$found"

				local found_abs_fpath=$(hex_decode "$found_enc_abs_fpath")
				local found_abs_roh_hash_fpath=$(hex_decode "$found_enc_abs_roh_hash_fpath")
				# echo "[$found_abs_fpath] [$found_abs_roh_hash_fpath]"

				if [ "$found_enc_abs_fpath" = "<NULL>" ]; then
					# consider this as if the hash is different, so should be found as a filename match instead
					# [ "$VERBOSE_MODE" = "true" ] && echo "         ... [<NULL>] -- indexed, but [$found_abs_roh_hash_fpath] orphaned hash"
					continue
				fi

				# same hash fpath
				if [ "$found_enc_abs_roh_hash_fpath" = "$enc_abs_roh_hash_fpath" ]; then
					if [ -f "$found_abs_roh_hash_fpath" ]; then
						# we found the original file
						if (( original_found > 0 )); then
							echo
							log_abort "this should not happen, should only be one original"
						fi
						((original_found++))
						continue
					else
						echo
						log_abort "this should not happen, because we are processing orphans that exist"
					fi
				fi

				((total_found++))

				# same index hash, diff fpath, different location
				if [ -f "$found_abs_fpath" ]; then

					# $stored == found_hash(indexed), because we queried on $stored
					# found_roh_hash_fpath(found_stored) == stored(indexed)? verify IDX
					# found_file_fpath hash matches found_roh_hash_fpath? 

					# verify IDX
					local found_stored=$(stored_hash "$found_abs_roh_hash_fpath")
					if [ "$stored" != "$found_stored" ]; then
						echo
						log_block ERROR "[$found_abs_roh_hash_fpath] -- IDX inconsistency" \
						    indexed "[$stored]" \
						    stored  "[$found_stored]"
						abort
					fi

					local found_computed=$(generate_hash "$found_abs_fpath")
					if [ "$found_computed" = "$stored" ]; then
						((duplicates_found++))
						# duplicate FOUND
						ellipsis_block_v 1 "[$found_abs_fpath] -- duplicate FOUND"
					else
						ellipsis_block_v 1 "[$found_abs_fpath] -- hash mismatch: ..." \
						    computed "[$found_computed]" \
						    stored   "[$stored]"
					fi
				else
					# we found another orphaned hash, assume the rest of the loop will take care of it
					# consider this as if the hash is different, so should be found as a filename match instead
					: # [ "$VERBOSE_MODE" = "true" ] && echo "         ... [$found_abs_fpath] -- X indexed, but missing"
				fi

			fi
	    done <<< "$list_roh_hash_fpaths"

		if [ "$duplicates_found" -ne 0 ]; then
 			if rm "$roh_hash_fpath"; then
 				if [ "$VERBOSE_MODE" = "true" ]; then
 					#echo "      ■: -- orphaned hash [$stored]: [$roh_hash_fpath] -- deleted"
 					log BULLET_6 "DELETED!"
 				else
 					log RECOVER "$(tok_hash "$stored" "$roh_hash_fpath") orphaned hash -- DELETED!"
 				fi
				export_log "$roh_hash_fpath" "$EXPORT_HASH_DELETED"
 			else
 				log ERROR "Failed to remove hash [$roh_hash_fpath]"
 			fi
			return 0
		fi

	fi

	# else
	# no matching hash found, file identical file names

	if [ "$VERBOSE_MODE" = "true" ]; then
		log ERR "orphaned hash not in IDX [$fpath] -- file MISSING !?"
	else
		log ERROR "[$stored] -- orphaned hash not in IDX [$fpath] -- file MISSING !?"
	fi
	export_log "$fpath" "$EXPORT_FILE_MISSING"

#	list_roh_hash_fpaths=$(roh_sqlite3_db_find_fn "$db" "$fn") || return 1
#	if [ -n "$list_roh_hash_fpaths" ]; then
#
#		# echo "* Found in file(s): [ ..."
#		# echo "$list_roh_hash_fpaths"
#		# echo "...]"
#
#		#TODO: indexed, but missing 4 times
#		local files_found=0
#
#	    # Only print non-empty paths
#	    while IFS= read -r found; do
#			if [ -n "$found" ]; then
#				IFS=$'\r' read -r found_enc_abs_fpath found_enc_abs_roh_hash_fpath found_hash <<< "$found"
#				# echo "[$found_enc_abs_fpath] [$found_enc_abs_roh_hash_fpath]==$enc_abs_roh_hash_fpath"
#
#				# same fpath
#				if [ "$found_enc_abs_roh_hash_fpath" = "$enc_abs_roh_hash_fpath" ]; then
#					# echo "found_hash: $found_hash:$stored"
#					local found_abs_roh_hash_fpath=$(hex_decode "$found_enc_abs_roh_hash_fpath")
#					if [ -f "$found_abs_roh_hash_fpath" ]; then
#						if [ "$found_hash" != "$stored" ]; then
#							echo "  ERROR:    ... hash mismatch: ..."
#							echo "                ... indexed [$found_hash]: [$found_abs_roh_hash_fpath]"
#							echo "                ...  stored [$stored]: [$abs_roh_hash_fpath]"
#							((ERROR_COUNT++))
#						fi								
#						continue
#					else
#						echo "this should not happen, because we are processing orphans that exist"
#						((ERROR_COUNT++))
#						continue
#					fi
#				fi
#
#				local found_abs_fpath=$(hex_decode "$found_enc_abs_fpath")
#
#				# diff fpath
#				if [ -f "$found_abs_fpath" ]; then
# 					found_computed_hash=$(generate_hash "$found_abs_fpath")
#					local found_abs_roh_hash_fpath=$(hex_decode "$found_enc_abs_roh_hash_fpath")
#					if [ -f "$found_abs_roh_hash_fpath" ]; then
#						found_stored=$(stored_hash "$found_abs_roh_hash_fpath")
#						if [ "$found_computed_hash" != "$found_stored" ]; then
#							echo "  ERROR:    ... hash mismatch -- matching FILENAME found ..."
#							echo "                ...   stored [$found_stored]: [$found_abs_roh_hash_fpath]"
#							echo "                ... computed [$found_computed_hash]: [$found_abs_fpath]"
#							((ERROR_COUNT++))
#							continue
#						fi
#					fi
#					# echo "computed_hash: $found_computed_hash:$stored"
# 					if [ "$found_computed_hash" = "$stored" ]; then
#						# the indexed and found file at a different location was indexed with a wrong/outdated hash
# 						echo "         ... duplicate FOUND [$found_abs_fpath]"
# 					else
# 						echo "            ... hash mismatch -- matching FILENAME found ..."
#						echo "                ...   stored [$stored]: [$abs_roh_hash_fpath]"
#						echo "                ... computed [$found_computed_hash]: [$found_abs_fpath]"
# 					fi
#				else
#					echo "            ... [$found_abs_fpath] -- indexed, but missing"
#				fi
#			fi
#	    done <<< "$list_roh_hash_fpaths"
#	fi

	[ "$match_filenames" = "true" ] && find_matching_fn "$db" "$fpath" "$roh_hash_fpath" "$stored"
	return 0
}

run_directory_process() {
	local parent="$1"
    local entry="$2"
	#local sub_dir="$(remove_top_dir "$ROOT" "$dir")"
	local visibility_mode="$3"
    local force_mode="$4"

	# Bail before any side-effects (mkdir of ROH_DIR/ROH_LOGS) if the target
	# entry doesn't exist; otherwise globspec/path errors leave stray
	# .roh.git/ and .roh.logs/ directories behind in $ROOT.
	if ! [ -e "$entry" ]; then
		log ERROR "can't find [$entry] for processing"
		return 0
	fi

	if ( contains "hide" && ! contains "verify" ) || ( contains "write" && [ "$visibility_mode" != "show" ] ); then
		if [ ! -d "$ROH_DIR" ]; then
			log ROH_DIR "creating [$ROH_DIR]"
			mkdir "$ROH_DIR"
		fi
 	elif contains "verify" || contains "recover" || ( contains "show" && ! contains "write" ); then
		# An archive at ROOT means "forgot to extract" -- but only when the
		# ROH_DIR in use is the one that archive would produce. With --roh-dir
		# pointing elsewhere (e.g. readonlyhash staging the archive in a temp
		# dir) the archive is expected and irrelevant.
		if [ "${ROH_DIR%/}" = "${entry%/}/.roh.git" ] && [ -f "$entry/_.roh.git.zip" ]; then
			log ERROR "found archived ROH_DIR [$entry/_.roh.git.zip] at [$entry]"
			return 0
		fi

		if [ ! -d "$ROH_DIR" ] || ! [ -x "$ROH_DIR" ]; then
			if contains "verify" && contains "show"; then
				log WARN "[$ROH_DIR] missing or inaccessible"
			else
				log_abort "[$ROH_DIR] -- missing or inaccessible"
			fi
		fi
	fi

	if [ -e "$entry" ]; then
		: # echo "Processing directory: [$dir]"
	else
		log ERROR "can't find [$entry] for processing"
		return 0
	fi

	#----

	_PROG_CURRENT_BYTES=0
	case "$OSTYPE" in darwin*) _STAT_FMT="bsd" ;; *) _STAT_FMT="gnu" ;; esac

	# The totals only feed the progress bar; when stdout is not a terminal the
	# bar never draws, so skip the two find sweeps that compute them.
	if [ -t 1 ]; then
		total_bytes=$(_prog_entry_bytes "$entry")
		total_files=$(_prog_entry_count "$entry")
	else
		total_bytes=0
		total_files=0
	fi

	trap 'printf "\033[?25h"; exit' INT TERM
	progress_init "$total_bytes" "$total_files" "# Processing files ... [$entry]"

	#process_directory "$@" || return 1
	process_entry "$ROOT" "$entry" "$visibility_mode" "$force_mode" || return 1

	progress_done

	#----

	return 0
}

# Count total bytes for progress bar — mirrors process_hash_entry skip logic
# count_hash_entry_bytes() {
# 	local roh_hash_fpath="$1"
# 
# 	if [ -L "$roh_hash_fpath" ]; then
# 		return 0
# 	elif [ -d "$roh_hash_fpath" ]; then
# 		local recursive_dir="$roh_hash_fpath"
# 		if [ -n "$(find "$recursive_dir" -mindepth 1 -print -quit)" ]; then
# 			for sub_roh_hash_fpath in "$recursive_dir"/*; do
# 				count_hash_entry_bytes "$sub_roh_hash_fpath"
# 			done
# 		fi
# 	elif [ -f "$roh_hash_fpath" ]; then
# 		local entry_bytes
# 		if [ "$_STAT_FMT" = "bsd" ]; then
# 			entry_bytes=$(stat -f%z "$roh_hash_fpath")
# 		else
# 			entry_bytes=$(stat -c%s "$roh_hash_fpath")
# 		fi
# 		_COUNT_TOTAL_BYTES=$(( _COUNT_TOTAL_BYTES + entry_bytes ))
# 	fi
# }

process_hash_entry()
{
	local roh_hash_fpath="$1"
	# echo "* roh_hash_fpath: [$roh_hash_fpath]"

	if [ -L "$roh_hash_fpath" ]; then
		log_v INFO "Avoiding symlink [$roh_hash_fpath] like the Plague"
		return 0

	# if the fpath is a directory AND empty, remove it on delete|sweep
    elif [ -d "$roh_hash_fpath" ]; then

		if contains "verify"; then
			if find "$roh_hash_fpath" -mindepth 1 -maxdepth 1 -name '.*' ! -name '.git*' -print -quit | grep -q .; then
				log ERROR "directory [$roh_hash_fpath] contains hidden entries"
			fi
		fi
		
		# save to local variable, because $roh_hash_fpath gets trash during recursion
		local recursive_dir="$roh_hash_fpath"

		# echo "Directory '$recursive_dir' is NOT empty (including hidden files)"
		if [ -n "$(find "$recursive_dir" -mindepth 1 -print -quit)" ]; then

			local hashes_found=$(find "$recursive_dir" -mindepth 1 -name "*.$HASH" -print -quit)
 			if [ -n "$hashes_found" ] && contains "verify" && [ "$VERBOSE_MODE" = "false" ]; then
				local dir_fpath="$(hash_fpath_to_fpath "$recursive_dir")"
				# echo "   * fpath DIRECTORY: [$dir_fpath]"
 
 				if [ ! -d "$dir_fpath" ]; then
					log ERROR "[$recursive_dir] -- orphaned hash DIRECTORY!"
					export_log "$recursive_dir" "$EXPORT_HASH_DELETED"
					if [ "$_PROG_ACTIVE" = "true" ]; then
						_PROG_CURRENT_BYTES=$(( _PROG_CURRENT_BYTES + $(_prog_hash_bytes "$recursive_dir") ))
						_PROG_CURRENT_FILES=$(( _PROG_CURRENT_FILES + $(_prog_hash_count "$recursive_dir") ))
						progress_update "$_PROG_CURRENT_BYTES"
					fi
					return 0
 				fi
 
 			fi

			for sub_roh_hash_fpath in "$recursive_dir"/*; do
				process_hash_entry "$sub_roh_hash_fpath" || return 1
			done
		fi

		if [ -z "$(find "$recursive_dir" -mindepth 1 -print -quit)" ]; then
			if contains "delete" || contains "sweep" || contains "recover"; then
				if ! rmdir "$recursive_dir"; then
					log ERROR "Failed to remove directory [$recursive_dir]"
				else
					if [ "$recursive_dir" = "$ROH_DIR" ]; then
						log ROH_DIR "[$ROH_DIR] -- DELETED"
					else
						log_v OK "orphaned hash directory [$recursive_dir] -- DELETED"
						export_log "$recursive_dir" "$EXPORT_HASH_DELETED"
					fi
				fi
			fi
		fi

    elif [ -f "$roh_hash_fpath" ]; then

		# stat only feeds the progress bar's byte counter (see process_entry).
		if [ "$_PROG_ACTIVE" = "true" ]; then
			local entry_bytes
			if [ "$_STAT_FMT" = "bsd" ]; then
				entry_bytes=$(stat -f%z "$roh_hash_fpath")
			else
				entry_bytes=$(stat -c%s "$roh_hash_fpath")
			fi
			_PROG_CURRENT_BYTES=$(( _PROG_CURRENT_BYTES + entry_bytes ))
		fi
		(( _PROG_CURRENT_FILES++ ))
		progress_update "$_PROG_CURRENT_BYTES"

		local stored=$(stored_hash "$roh_hash_fpath")
		local fpath="$(hash_fpath_to_fpath "$roh_hash_fpath")"
		# echo "   * fpath: [$fpath]"

		# Hash points to a path covered by .rohignore — active reconcile:
		# sweep deletes (cruft), verify WARNs, recover/index skip with INFO.
		if should_ignore "$fpath"; then
			if contains "sweep"; then
				if rm "$roh_hash_fpath"; then
					log_v OK "$(tok_hash "$stored" "$roh_hash_fpath") hash for ignored file -- DELETED"
					export_log "$roh_hash_fpath" "$EXPORT_HASH_DELETED"
				else
					log ERROR "Failed to remove hash [$roh_hash_fpath]"
				fi
			elif contains "verify"; then
				log WARN "$(tok_hash "$stored" "$roh_hash_fpath") hash for ignored file [$fpath] -- run sweep to clean"
				export_log "$roh_hash_fpath" "$EXPORT_FILE_IGNORED"
			elif contains "recover" || contains "index"; then
				log_v INFO "[$fpath] is ignored -- not processing hash [$roh_hash_fpath]"
			fi
			return 0
		fi

 		# if the file corresponding to the hash doesn't exist (orphaned), remove it on sweep
 		if ! stat "$fpath" >/dev/null 2>&1; then
 			if contains "sweep"; then
 				if rm "$roh_hash_fpath"; then
 					log_v OK "$(tok_hash "$stored" "$roh_hash_fpath") orphaned hash -- DELETED"
					export_log "$roh_hash_fpath" "$EXPORT_HASH_DELETED"
					return 0
				else
 					log ERROR "Failed to remove hash [$roh_hash_fpath]"
 				fi
			fi
			if contains "verify"; then
				if contains "index"; then
					log ERROR "$(tok_hash "$stored" "$roh_hash_fpath") orphaned hash -- indexing"
				else
					log ERROR "$(tok_hash "$stored" "$roh_hash_fpath") orphaned hash"
				fi
 				#                                    "       [dfc5388fd5213984e345a62ff6fac21e0f0ec71df44f05340b0209e9cac489db]: [$roh_hash_fpath] -- orphaned hash"
 				ellipsis_block_v 1 "$(phantom "$stored")[$fpath] -- NO corresponding file"
				export_log "$fpath" "$EXPORT_FILE_MISSING"
 			fi

 			if contains "index"; then
				local roh_hash_fpath_exists=$(roh_sqlite3_db_roh_hash_fpath_exists "$DB_SQL" "$roh_hash_fpath")

				# IDX consistency. Skip only when write_hash's inline insert under `write index --dedup`
				# legitimately populated this row — otherwise uniqueness still applies.
		        if [ "$roh_hash_fpath_exists" -eq 1 ] && \
				   ! ( [ "$dedup_mode" = "true" ] && contains "write" ); then
					log ERROR "[$roh_hash_fpath] hash NOT UNIQUE -- IDX inconsistency"
					return 0
				fi

		        local fpath_exists=$(roh_sqlite3_db_fpath_exists "$DB_SQL" "$fpath" "$stored") || return 1
		        if [ "$fpath_exists" -eq 0 ]; then
					if [ "$dedup_mode" = "true" ] && [ -n "$(roh_sqlite3_db_find_hash "$DB_SQL" "$stored")" ]; then
						log_v IDX "$(tok_hash "$stored" "$roh_hash_fpath") orphaned hash -- duplicate, skipped (--dedup)"
					else
						roh_sqlite3_db_insert "$DB_SQL" "$fpath" "$roh_hash_fpath" "$stored"
						log_v IDX "$(tok_hash_new "$stored" "$roh_hash_fpath") orphaned hash -- INDEXED"
						ellipsis_block_v 1 "$(phantom "$stored")[$fpath] -- NO corresponding file"
						export_log "$fpath" "$EXPORT_FILE_MISSING"
					fi
		        else
					log_v IDX "$(tok_hash "$stored" "$roh_hash_fpath") orphaned hash -- already indexed, skipping"
		        fi
			fi
 			if contains "recover"; then
 				recover_hash "$DB_SQL" "$fpath" "$roh_hash_fpath" "$stored" || return 1
			fi

		else
	 		if contains "index"; then
				# IDX consistency. Skip only when write_hash's inline insert under `write index --dedup`
				# legitimately populated this row — otherwise uniqueness still applies.
				local roh_hash_fpath_exists=$(roh_sqlite3_db_roh_hash_fpath_exists "$DB_SQL" "$roh_hash_fpath")
		        if [ "$roh_hash_fpath_exists" -eq 1 ] && \
				   ! ( [ "$dedup_mode" = "true" ] && contains "write" ); then
					log ERROR "[$roh_hash_fpath] hash NOT UNIQUE -- IDX inconsistency"
					return 0
				fi

				local fpath_exists=$(roh_sqlite3_db_fpath_exists "$DB_SQL" "$fpath" "$stored") || return 1
	 			if [ "$fpath_exists" -eq 0 ]; then
					if [ "$dedup_mode" = "true" ] && [ -n "$(roh_sqlite3_db_find_hash "$DB_SQL" "$stored")" ]; then
						log_v IDX "$(tok_hash "$stored" "$roh_hash_fpath") -- duplicate, skipped (--dedup)"
					else
						roh_sqlite3_db_insert "$DB_SQL" "$fpath" "$roh_hash_fpath" "$stored"
						log_v IDX "$(tok_hash_new "$stored" "$roh_hash_fpath") -- INDEXED"
					fi
	 			else
	 				log_v IDX "$(tok_hash "$stored" "$roh_hash_fpath") -- already indexed, skipping"
	 			fi
	 		fi
		fi

    fi

	return 0
}


hash_maintanence() {
    local dir="$1"
	#local sub_dir="$(remove_top_dir "$ROOT" "$dir")"
#	local visibility_mode="$3"
#   local force_mode="$4"

	# searching for hashes, because .git exists
	if contains "index"; then
		if [ -z "$(find "$ROH_DIR" -mindepth 1 -name "*.sha256" -print -quit)" ]; then
			log ERROR "nothing to index [$ROH_DIR]"
			echo
			return 1
		fi
	fi

	# ROH_DIR must exist and be accessible for the while loop to execute
	[ ! -d "$ROH_DIR" ] || ! [ -x "$ROH_DIR" ] && return 0;

	#----

	_PROG_CURRENT_BYTES=0
	case "$OSTYPE" in darwin*) _STAT_FMT="bsd" ;; *) _STAT_FMT="gnu" ;; esac

	# See run_directory_process: totals are progress-bar-only.
	if [ -t 1 ]; then
		total_bytes=$(_prog_hash_bytes "$dir")
		total_files=$(_prog_hash_count "$dir")
	else
		total_bytes=0
		total_files=0
	fi

	trap 'printf "\033[?25h"; exit' INT TERM
	progress_init "$total_bytes" "$total_files" "# Hash maintanence ... [$dir]"

	process_hash_entry "$dir"

	progress_done

	#----

	# This will fail if git is being used

	if contains "delete" && contains "sweep"; then
		if [ -f "$DB_SQL" ]; then
			if rm "$DB_SQL"; then
				echo "Removing DB_SQL [$DB_SQL]"
			else
				log ERROR "Failed to delete [$DB_SQL]"
			fi
		fi
	fi

	return 0
}

#------------------------------------------------------------------------------------------------------------------------------------------

process_query() {
    local db="$1"
	local query_hash="$2"

    echo "query hash: [$query_hash]"
	list_roh_hash_fpaths=$(roh_sqlite3_db_find_hash "$db" "$query_hash")
	if [ $? -ne 0 ]; then
		log ERROR "failed to query db [$db]"
		return 1
	fi

	[ -z "$list_roh_hash_fpaths" ] && echo "  --"
	while IFS='|' read -r found_enc_abs_fpath found_enc_abs_roh_hash_fpath; do
		#[ -n "$found_enc_abs_fpath" ] && echo "[$fpath:$roh_hash_fpath]"
		if [ -n "$found_enc_abs_roh_hash_fpath" ]; then
			found_abs_roh_hash_fpath=$(hex_decode "$found_enc_abs_roh_hash_fpath")
			found_abs_fpath=$(hex_decode "$found_enc_abs_fpath")
			log OK "found -- hash path [$found_abs_roh_hash_fpath]"
			ellipsis_block 1 "absolute fpath [$found_abs_fpath]"
		fi
	done <<< "$list_roh_hash_fpaths"
#    # Loop through DB_SQL array
#    for db_path in "${DB_SQL[@]}"; do
#		echo "db: [$db_path]"
#        list_roh_hash_fpaths=$(roh_sqlite3_db_search "$db_path" "$QUERY_HASH")
#        # Only print non-empty paths
#        while IFS= read -r fpath; do
#            [ -n "$fpath" ] && echo "[$fpath]"
#        done <<< "$list_roh_hash_fpaths"
#    done
}

if [ "$globspec_mode" = "true" ]; then
	# echo "* $@"
	for fpath in "$@"; do
		if contains "query"; then
			QUERY_HASH="$fpath"
			process_query "$DB_SQL" "$QUERY_HASH"
			continue
		fi

		[[ "${fpath}" = *.sha256 ]] && continue
	
		if ! [ -f "$fpath" ]; then
			log WARN "[$fpath] not a file -- SKIPPING"
			continue
		fi
		
		dir=$(dirname -- "$fpath")
		entry="$fpath"

		VERBOSE_MODE="true" 

		if contains "write"; then
			write_hash "$dir" "$entry" "show" "$force_mode"
		fi
		if contains "verify"; then
			verify_hash "$dir" "$entry" 
		fi
		if contains "delete"; then
			delete_hash "$dir" "$entry" 
		fi
	done

	if [ $ERROR_COUNT -gt 0 ] || [ $WARN_COUNT -gt 0 ]; then
		echo "Number of ERRORs encountered: [$ERROR_COUNT]"
		echo "Number of ...       WARNings: [$WARN_COUNT]"
		echo
		if [ $ERROR_COUNT -gt 0 ]; then
			exit 1
		fi
		exit 0 # WARNings
	fi

	echo "Done."
	exit 0
fi

EXPORT_MODE="true"

if contains "index" && ( contains "recover" || contains "query" ); then
	cmds_copy=("${commands[@]}")
	commands=("index")

	echo "# Indexing ... [${ROH_DIR%/}]"
	hash_maintanence "${ROH_DIR%/}" || abort

	commands=("${cmds_copy[@]/index}")
fi

if contains "query"; then
    QUERY_HASH="$PATHSPEC"
	process_query "$DB_SQL" "$QUERY_HASH" || abort

    echo "Done."
    exit 0
fi

if [ "$only_hashes" = "true" ]; then
	:
elif contains "write" || contains "delete" || contains "show" || contains "hide" || contains "verify" || contains "recover"; then
	# append a folder to ROOT without having a double /; and if the folder is "", no trailing slash on ROOT
	if [ -z "$PATHSPEC" ]; then
		run_directory_process "$ROOT" "$ROOT" "$visibility_mode" "$force_mode" || abort
	else
		run_directory_process "$ROOT" "${ROOT%/}${PATHSPEC:+/$PATHSPEC}" "$visibility_mode" "$force_mode" || abort
	fi
fi

if [ "$only_files" = "true" ]; then
	:
elif contains "verify" || contains "recover" || contains "sweep" || contains "index"; then
	hash_maintanence "${ROH_DIR%/}${PATHSPEC:+/$PATHSPEC}" || abort
fi

if [ "$EXPORT_MODE" = "true" ] && [ -f "$EXPORT_FILE_IGNORED" ]; then
	log WARN "ignored entries (hidden and/or .rohignore matches) were detected and exported"
	echo "LOG: >> [$EXPORT_FILE_IGNORED]"
fi

[ "$EXPORT_MODE" = "true" ] && [ -f "$EXPORT_FILE_NEW" ] && echo "LOG: >> [$EXPORT_FILE_NEW]"
[ "$EXPORT_MODE" = "true" ] && [ -f "$EXPORT_FILE_MISSING" ] && echo "LOG: >> [$EXPORT_FILE_MISSING]"
[ "$EXPORT_MODE" = "true" ] && [ -f "$EXPORT_HASH_DELETED" ] && echo "LOG: >> [$EXPORT_HASH_DELETED]"

if [ $ERROR_COUNT -gt 0 ] || [ $WARN_COUNT -gt 0 ]; then
	echo "Number of ERRORs encountered: [$ERROR_COUNT]"
	echo "Number of ...       WARNings: [$WARN_COUNT]"
	echo
	if [ $ERROR_COUNT -gt 0 ]; then
		exit 1
	fi
	exit 0 # WARNings
fi

echo "Done."
