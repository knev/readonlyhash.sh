#!/usr/bin/env bash
# Fake snap-style download progress bar

pkg_name="core22"
pkg_rev="1564"
total_mb="67.25"
speed_base=2

printf "\033[?25l" # hide cursor
trap 'printf "\033[?25l\n"; exit' INT TERM
trap 'printf "\033[?25h"' EXIT

# Simulated tasks with sizes in MB
tasks=(
  "Ensure prerequisites for \"${pkg_name}\" are available"
  "Download snap \"${pkg_name}\" (${pkg_rev}) from channel \"latest/stable\""
  "Fetch and check assertions for snap \"${pkg_name}\" (${pkg_rev})"
  "Mount snap \"${pkg_name}\" (${pkg_rev})"
  "Run install hook of \"${pkg_name}\" snap if present"
  "Start snap \"${pkg_name}\" (${pkg_rev}) services"
)

human_size() {
  awk -v bytes="$1" 'BEGIN {
    if (bytes >= 1048576)      printf "%.2f TB", bytes / 1048576
    else if (bytes >= 1024)    printf "%.2f GB", bytes / 1024
    else                       printf "%.2f MB", bytes
  }'
}

draw_bar() {
  local pct=$1 suffix_len=$2
  local cols=$(tput cols)
  # " [" (2) + "] " (2) + suffix
  local bar_width=$(( cols - suffix_len - 4 ))
  (( bar_width < 10 )) && bar_width=10
  local filled=$(( pct * bar_width / 100 ))
  local empty=$(( bar_width - filled ))
  local bar=""
  for ((i=0; i<filled; i++)); do bar+="█"; done
  for ((i=0; i<empty; i++)); do bar+="░"; done
  printf "%s" "$bar"
}

# Phase 1: download with progress bar
task="${tasks[1]}"
printf "%s\n" "$task"
pct=0
downloaded=0
total_val=67.25

while (( pct < 100 )); do
  # Variable speed
  increment=$(( RANDOM % 4 + 1 ))
  pct=$(( pct + increment ))
  (( pct > 100 )) && pct=100

  down_mb=$(awk "BEGIN { printf \"%.2f\", ${total_val} * ${pct} / 100 }")
  speed_mb=$(awk "BEGIN { printf \"%.1f\", ${speed_base} + (${RANDOM} % 30) / 10.0 }")

  down_h=$(human_size "$down_mb")
  total_h=$(human_size "$total_val")
  speed_h=$(human_size "$speed_mb")

  suffix=$(printf "%3d%%  %s/%s  %s/s" "$pct" "$down_h" "$total_h" "$speed_h")

  printf "\r [%s] %s" \
    "$(draw_bar "$pct" "${#suffix}")" "$suffix"

  sleep 0.$(( RANDOM % 8 + 2 ))
done
printf "\n\n"

# Phase 2: run remaining tasks quickly (snap "done" style)
cols=$(tput cols)
for i in 0 2 3 4 5; do
  task_text="${tasks[$i]}"
  pad=$(( cols - ${#task_text} - 6 ))
  (( pad < 1 )) && pad=1
  printf " %s%*s" "$task_text" "$pad" ""
  sleep 0.$(( RANDOM % 5 + 3 ))
  printf "Done\n"
done

printf "\n${pkg_name} (${pkg_rev}) installed\n"
