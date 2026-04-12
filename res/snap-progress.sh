#!/usr/bin/env bash
# snap-progress.sh — snap-style terminal progress bar
# Source this file to use the functions, or run directly for a demo.

# ── Internal helpers ─────────────────────────────────────────────

_prog_human_size() {
  awk -v mb="$1" 'BEGIN {
    if (mb >= 1048576)      printf "%.2f TB", mb / 1048576
    else if (mb >= 1024)    printf "%.2f GB", mb / 1024
    else                    printf "%.2f MB", mb
  }'
}

_prog_draw_bar() {
  local pct=$1 suffix_len=$2
  local cols=$(tput cols)
  local bar_width=$(( cols - suffix_len - 4 ))  # 4 = " [" + "] "
  (( bar_width < 10 )) && bar_width=10
  local filled=$(( pct * bar_width / 100 ))
  local empty=$(( bar_width - filled ))
  local bar=""
  for ((i=0; i<filled; i++)); do bar+="█"; done
  for ((i=0; i<empty; i++)); do bar+="░"; done
  printf "%s" "$bar"
}

# ── Public API ───────────────────────────────────────────────────

# progress_init <total_mb> [label]
#   Call once before updates. Hides cursor, prints label.
progress_init() {
  _PROG_TOTAL="${1:?usage: progress_init <total_mb> [label]}"
  _PROG_LABEL="${2:-Downloading...}"
  _PROG_PREV_MB=0
  _PROG_PREV_SEC=$(date +%s)

  printf "\033[?25l"  # hide cursor
  printf "%s\n" "$_PROG_LABEL"
}

# progress_update <current_mb>
#   Call repeatedly with the current downloaded amount.
progress_update() {
  local cur_mb="${1:?usage: progress_update <current_mb>}"

  local pct=$(awk "BEGIN { p=int(${cur_mb}*100/${_PROG_TOTAL}); if(p>100)p=100; print p }")

  # Speed calc (MB since last call / seconds since last call)
  local now=$(date +%s)
  local elapsed=$(( now - _PROG_PREV_SEC ))
  (( elapsed < 1 )) && elapsed=1
  local speed_mb=$(awk "BEGIN { printf \"%.1f\", (${cur_mb} - ${_PROG_PREV_MB}) / ${elapsed} }")
  _PROG_PREV_MB="$cur_mb"
  _PROG_PREV_SEC="$now"

  local down_h=$(_prog_human_size "$cur_mb")
  local total_h=$(_prog_human_size "$_PROG_TOTAL")
  local speed_h=$(_prog_human_size "$speed_mb")

  local suffix=$(printf "%3d%%  %s/%s  %s/s" "$pct" "$down_h" "$total_h" "$speed_h")

  printf "\r [%s] %s" \
    "$(_prog_draw_bar "$pct" "${#suffix}")" "$suffix"
}

# progress_log <message>
#   Print a message above the progress bar without disturbing it.
progress_log() {
  # Clear the current bar line, print the message, then redraw the bar
  printf "\r\033[2K%s\n" "$*"
  # Redraw bar on the new current line
  progress_update "$_PROG_PREV_MB"
}

# progress_done
#   Fills bar to 100%, prints newline, restores cursor.
progress_done() {
  progress_update "$_PROG_TOTAL"
  printf "\n"
  printf "\033[?25h"  # show cursor
}

# ── Demo (only runs when executed directly) ──────────────────────

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  trap 'printf "\033[?25h"; exit' INT TERM

  total=500

  progress_init "$total" "Download snap \"core22\" (1564) from channel \"latest/stable\""

  # Simulate work in chunks
  current=0
  messages=(
    "file 1 done"
    "file 2 done"
    "file 3 failed — retrying..."
    "file 3 done"
    "file 4 done"
    "file 5 done"
  )
  steps=( 80 45 120 60 95 100 )

  for i in "${!steps[@]}"; do
    sleep 0.$(( RANDOM % 6 + 3 ))
    current=$(( current + steps[i] ))
    (( current > total )) && current=$total

    progress_log "${messages[$i]}"
    progress_update "$current"
  done

  progress_done

  # Phase 2: post-install tasks
  snap_tasks=(
    "Ensure prerequisites for \"core22\" are available"
    "Fetch and check assertions for snap \"core22\" (1564)"
    "Mount snap \"core22\" (1564)"
    "Run install hook of \"core22\" snap if present"
    "Start snap \"core22\" (1564) services"
  )
  cols=$(tput cols)
  for task in "${snap_tasks[@]}"; do
    pad=$(( cols - ${#task} - 6 ))
    (( pad < 1 )) && pad=1
    printf " %s%*s" "$task" "$pad" ""
    sleep 0.$(( RANDOM % 5 + 3 ))
    printf "Done\n"
  done

  printf "\ncore22 (1564) installed\n"
fi
