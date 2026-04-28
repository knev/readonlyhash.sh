#!/bin/bash

# This is a basic unit test script for the hash management script

usage() {
	echo
    echo "Usage: $(basename "$0") [-c|-v] [-u ID[,ID...]] [--step [ID,]LINENO] [-l]"
    echo "Options:"
    echo "    -c, --continue              Continue processing tests even in the event of failure."
	echo "    -v, --verbose               Display all output regardless if pass or fail."
    echo "    -h, --help                  Display this help and exit"
    echo "    -u, --units ID[,ID...]      Run only the listed test units (by number or name; comma-separated)."
    echo "    --step [ID,]LINENO          Pause before each run_test call in test unit ID once its caller line is >= LINENO."
	echo "                                ID is required when more than one test unit is present after filtering."
	echo "                                Prompts: [Enter]=run, c=continue without stepping, l=continue to [unit,]line, s=skip, q=quit."
	echo "    -l, --list-units            List discovered test units (id / name and file) and exit."
	echo
	echo "Note: options -c and -v are mutually exclusive."
	echo
}

# Parse command line options
continue_mode="false"
verbose_mode="false"
list_units_mode="false"
units_filter=""
step_line=""
step_unit=""

parse_step_value() {
    # Parse the value of --step=... into the globals step_unit/step_line.
    # Echoes errors and returns non-zero on bad input.
    local raw="$1"
    if [[ "$raw" == *,* ]]; then
        step_unit="${raw%%,*}"
        step_line="${raw#*,}"
        if [ -z "$step_unit" ] || [ -z "$step_line" ]; then
            echo "step: expected ID,LINE, got [$raw]" >&2
            return 1
        fi
    else
        step_unit=""
        step_line="$raw"
    fi
    if ! [[ "$step_line" =~ ^[0-9]+$ ]]; then
        echo "step: expected numeric line number, got [$step_line]" >&2
        return 1
    fi
    return 0
}

need_value() {
    # Helper for options that take a separate-argument value. Echoes the value,
    # or prints an error and returns non-zero when the next positional is
    # missing.
    local opt="$1" hint="$2" remaining="$3" next="$4"
    if [ "$remaining" -lt 2 ]; then
        echo "${opt#--}: missing value (use $hint)" >&2
        return 1
    fi
    printf '%s\n' "$next"
    return 0
}

while [ $# -gt 0 ]; do
    arg="$1"
    case "$arg" in
        -c|--continue)
            continue_mode="true"
            shift
            ;;
        -v|--verbose)
            verbose_mode="true"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -l|--list-units)
            list_units_mode="true"
            shift
            ;;
        -u|--units)
            if ! val=$(need_value "--units" "--units ID[,ID...]" "$#" "${2-}"); then
                usage; exit 1
            fi
            units_filter="$val"
            if [ -z "$units_filter" ]; then
                echo "units: missing value (use --units ID[,ID...])" >&2
                usage; exit 1
            fi
            shift 2
            ;;
        --step)
            if ! val=$(need_value "--step" "--step [ID,]LINENO" "$#" "${2-}"); then
                usage; exit 1
            fi
            if ! parse_step_value "$val"; then
                usage; exit 1
            fi
            shift 2
            ;;
        --)
            shift
            break
            ;;
        --*)
            echo "Invalid option: $arg" >&2
            usage; exit 1
            ;;
        -[a-zA-Z]*)
            # Any short-form starting with -X that didn't match an explicit
            # case above is an unknown short flag (or unsupported cluster).
            echo "${0##*/}: illegal option -- ${arg#-}" >&2
            usage; exit 1
            ;;
        *)
            echo "Unexpected argument: $arg" >&2
            usage; exit 1
            ;;
    esac
done

#	# Check for mutually exclusive flags
#	mutual_exclusive_count=0
#	for mode in "$continue_mode" "$verbose_mode"; do
#	    if [ "$mode" = "true" ]; then
#	        ((mutual_exclusive_count++))
#	    fi
#	done
#	
#	if [ $mutual_exclusive_count -gt 1 ]; then
#	    echo "Error: options -c and -v are mutually exclusive. Please use only one." >&2
#	    usage
#	    exit 1
#	fi

status_matches() {
    local s1="$1"
    local s2="$2"

    if [ "$s1" -eq 0 ] && [ "$s2" -eq 0 ]; then
        return 0
    elif [ "$s1" -ne 0 ] && [ "$s2" -ne 0 ]; then
        return 0
    else
        return 1
    fi
}

# !!!NOTE:  this means we can not use [] and () in the regex's passed to run_test()
#
escape_expected() {
    local raw_pattern="$1"
    echo "$raw_pattern" | sed 's/\[/\\[/g; s/\]/\\]/g; s/(/\\(/g; s/)/\\)/g; s/?/\\?/g; s/!/\\!/g; s/|/\\|/g'
}
	
# Helper function to run commands and check their output
run_test() {
    local cmd="$1"
    local expected_status="$2"
    local expected_regex="$3"
    local not_flag="${4:-false}"  # Default not_flag to false if not provided

    # --step: pause before running once the caller's line number in the
    # currently-sourced test unit is >= $step_line and the unit matches
    # $step_unit (when set). Reads keystrokes from /dev/tty so tests that
    # pipe stdin into the command under test aren't affected.
    local caller_line=${BASH_LINENO[0]}
    if [ -n "$step_line" ] \
       && { [ -z "$step_unit" ] || [ "$step_unit" = "$CURRENT_UNIT_ID" ]; } \
       && [ "$caller_line" -ge "$step_line" ]; then
        local caller_file="${BASH_SOURCE[1]##*/}"
        printf '\n--- step [%s:%s:%d] ---\n' "$CURRENT_UNIT_ID" "$caller_file" "$caller_line" >&2
        printf '  $ %s\n' "$cmd" >&2
        local not_suffix=""
        [ "$not_flag" = "true" ] && not_suffix=" (NOT)"
        printf '  Expected EXIT status:[%s] regex:[%s]%s\n' \
            "$expected_status" "$expected_regex" "$not_suffix" >&2
        local key="" target="" tunit="" tline="" tresolved="" tidx=""
        local done_prompt="false"
        while [ "$done_prompt" = "false" ]; do
			printf '[ENTER]=run, [c]ontinue/to (unit,)[l]ine, [s]kip, [q]uit ? ' >&2
            read -rsn1 key < /dev/tty
            printf '\n' >&2
            case "$key" in
                q|Q) echo "step: quit at [$CURRENT_UNIT_ID:$caller_file:$caller_line]" >&2; exit 0 ;;
                c|C) step_line=""; step_unit=""; done_prompt="true" ;;
                l|L)
                    print_unit_list
                    target=""
                    printf 'Continue to (unit,)line: ' >&2
                    read -r target < /dev/tty
                    # Empty input: re-display the main prompt so the user can pick again.
                    if [ -z "$target" ]; then
                        continue
                    fi
                    if [[ "$target" == *,* ]]; then
                        tunit="${target%%,*}"
                        tline="${target#*,}"
                        # Trailing comma with no line: "unit," means "jump to unit, start from the beginning".
                        [ -z "$tline" ] && tline="0"
                        tresolved=""
                        tidx=""
                        if [ -z "$tunit" ] || ! [[ "$tline" =~ ^[0-9]+$ ]]; then
                            echo "step: expected [unit,]line, got [$target] — staying at [$caller_line]" >&2
                        elif ! tresolved=$(unit_resolve "$tunit"); then
                            echo "step: unknown test unit [$tunit] — staying at [$caller_line]" >&2
                        else
                            tidx=$(unit_index "$tresolved")
                            if [ "$tidx" -lt "${CURRENT_UNIT_INDEX:-0}" ]; then
                                echo "step: test unit [$tresolved] has already completed — staying at [$caller_line]" >&2
                            else
                                step_unit="$tresolved"
                                step_line="$tline"
                            fi
                        fi
                    elif [[ "$target" =~ ^[0-9]+$ ]]; then
                        step_unit="$CURRENT_UNIT_ID"
                        step_line="$target"
                    else
                        echo "step: expected [unit,]line, got [$target] — staying at [$caller_line]" >&2
                    fi
                    done_prompt="true"
                    ;;
                s|S) echo "step: skipped [$CURRENT_UNIT_ID:$caller_file:$caller_line]" >&2; return 0 ;;
                *) done_prompt="true" ;;
            esac
        done
    fi

    #	local output=$(eval "$cmd" 2>&1)
	#	if [ "$not_flag" = "true" ]; then
	#	    # Check if expected is NOT in output
	#	    if [[ "$output" != *"$expected"* ]]; then
	#			echo "PASS: (NOT) $expected"
	#	    else
	#			echo
	#			echo "FAIL: $cmd"
	#			echo "Expected to NOT contain: $expected"
	#			echo "----"
	#			echo "$output"
	#			echo "----"
	#	    fi
	#	else
	#	    # Check if expected is in output
	#	    if [[ "$output" == *"$expected"* ]]; then
	#			echo "PASS: $expected"
	#	    else
	#			echo
	#			echo "FAIL: $cmd"
	#			echo "Expected to contain: $expected"
	#			echo "----"
	#			echo "$output"
	#			echo "----"
	#		fi
	#	fi

	# Grok
	# You're correct; both command substitution and eval in their basic forms do not 
	# allow for capturing both the output and the exit status of a command 
	# simultaneously in a straightforward way. However, there are workarounds to achieve this:
	# Using a Subshell for Capturing Both Output and Exit Status:
	# One way to capture both the output and the exit status is by using a subshell and command grouping:
	# Capture output and exit status
	#	output=$( { command_to_run 2>&1; echo $? >&3; } 3>&1 | cat )
	#	exit_status=${output##*$'\n'}
	#	output=${output%$'\n'*}
	# Now $output contains the command's output (including stderr),
	# and $exit_status contains the exit status
	# Here's the breakdown:
    #	- { command_to_run 2>&1; echo $? >&3; } is a command group where 
	#	  command_to_run is executed, its stdout and stderr are combined (2>&1), 
	#	  followed by echoing its exit status to file descriptor 3.
    #	- 3>&1 redirects file descriptor 3 to stdout before the group starts, allowing us 
	#	  to capture the exit status outside the group.
    #	- | cat ensures that the entire output (including the exit status) is passed to 
	#	  the command substitution.
    #	- We then split the output to separate the command output from the exit status:
    #		- exit_status=${output##*$'\n'} removes everything up to and 
	#		  including the last newline, leaving only the exit status.
	#		- output=${output%$'\n'*} removes the last line (which is the exit status) from the output.


    # Capture command output and exit status
    local full_output=$( { eval "$cmd" 2>&1; echo $? >&3; } 3>&1 | cat )
    local exit_status=${full_output##*$'\n'}
    local output=${full_output%$'\n'*}
	output=${output%$'\n'} # Remove the last newline

	local ok="no"
	local status_ok="no"
	status_matches "$exit_status" "$expected_status" && status_ok="YES"
	if [ "$not_flag" = "true" ]; then
	    # Check if expected is NOT in output
		if ! [[ "$output" =~ $expected_regex ]]; then
			ok="YES"
			if status_matches "$exit_status" "$expected_status" && [ "$verbose_mode" != "true" ]; then
				echo "PASS: [$cmd][$exit_status] ! \"$expected_regex\", line no. [${BASH_LINENO[0]}]"
				return 0
			fi 
		fi

		echo
		if [ "$ok" = "YES" ] && [ "$status_ok" = "YES" ]; then
			echo "# PASS: [$cmd][$exit_status], line no. [${BASH_LINENO[0]}]"
		else
			echo "# FAIL: [$cmd][$exit_status], line no. [${BASH_LINENO[0]}]"
		fi
		echo "# Expected EXIT status [$status_ok]: [$expected_status]"
		echo "# Expected to NOT contain [$ok]: \"$expected_regex\""
		echo "#----"
		echo "$output" | sed 's/^/  /'
		echo "#----"
		echo

		if [ "$ok" = "no" ] || ! status_matches "$exit_status" "$expected_status"; then
		  if [ "$continue_mode" != "true" ]; then
			echo "To be continued ..."
			echo
			exit 1
		  fi
		fi
	else
	    # Check if expected is in output
		if [[ "$output" =~ $expected_regex ]]; then
			ok="YES"
			if status_matches "$exit_status" "$expected_status" && [ "$verbose_mode" != "true" ]; then
				echo "PASS: [$cmd][$exit_status] \"$expected_regex\", line no. [${BASH_LINENO[0]}]"
				return 0
			fi
		fi

		echo
		if [ "$ok" = "YES" ] && [ "$status_ok" = "YES" ]; then
			echo "# PASS: [$cmd][$exit_status], line no. [${BASH_LINENO[0]}]"
		else
			echo "# FAIL: [$cmd][$exit_status], line no. [${BASH_LINENO[0]}]"
		fi
		echo "# Expected EXIT status [$status_ok]: [$expected_status]"
		echo "# Expected to contain [$ok]: \"$expected_regex\""
		echo "#----"
		echo "$output" | sed 's/^/  /'
		echo "#----"
		echo

		if [ "$ok" = "no" ] || ! status_matches "$exit_status" "$expected_status"; then
		  if [ "$continue_mode" != "true" ]; then
			echo "To be continued ..."
			echo
			exit 1
		  fi
		fi
	fi
}

#	output="File: [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]: [test] \"file with spaces.txt\" -- OK"
#	pattern="File: \[8470d5654.*6bb3f0d60b69\]: \[test\] \"file with spaces.txt\" -- OK"
#	[[ "$output" =~ $pattern ]] && echo 1 || echo 0
#	
#	# ----
#	
#	escape_brackets() {
#	    local raw_pattern="$1"
#	    echo "$raw_pattern" | sed 's/\[/\\[/g; s/\]/\\]/g'
#	}
#	
#	compare_file_string() {
#	    local file_pattern="$1"
#	    local target_string="File: [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]: [test] \"file with spaces.txt\" -- OK"
#	    if [[ $target_string =~ $file_pattern ]]; then
#	        return 0 # Match
#	    else
#	        return 1 # No match
#	    fi
#	}
#	
#	# Example usage
#	file_pattern_raw="File: [8470d5654.*6bb3f0d60b69]: [test] \"file with spaces\.txt\" -- OK"
#	file_pattern=$(escape_brackets "$file_pattern_raw")
#	compare_file_string "$file_pattern"
#	if [[ $? -eq 0 ]]; then
#	    echo "Match found"
#	else
#	    echo "No match"
#	fi

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Helpers used by the step gate and discovery loop.
#
# A numbered unit (test_NN-name.sh) is addressable by either its number or its
# name; an unnumbered unit (test_core.sh) is addressable by its name only.
# unit_resolve takes user input and prints the canonical primary ID.
unit_resolve() {
    local target="$1"
    local i
    for i in "${!UNIT_IDS[@]}"; do
        if [ "${UNIT_IDS[$i]}" = "$target" ] || [ "${UNIT_NAMES[$i]}" = "$target" ]; then
            printf '%s\n' "${UNIT_IDS[$i]}"
            return 0
        fi
    done
    return 1
}

unit_exists() {
    unit_resolve "$1" >/dev/null
}

unit_index() {
    local target="$1"
    local i
    for i in "${!UNIT_IDS[@]}"; do
        if [ "${UNIT_IDS[$i]}" = "$target" ]; then
            printf '%s\n' "$i"
            return 0
        fi
    done
    return 1
}

# Always lists every discovered unit. During a step pause, units that have
# already been sourced are marked "done" — the table still shows them for
# context, but the `l` handler refuses to jump there.
print_unit_list() {
    local in_step="false"
    [ -n "${CURRENT_UNIT_ID:-}" ] && in_step="true"
    if [ "$in_step" = "true" ]; then
        printf 'Available units (current: %s):\n' "$CURRENT_UNIT_ID" >&2
    else
        printf 'Available units:\n' >&2
    fi
    local i status label start_idx
    start_idx="${CURRENT_UNIT_INDEX:-0}"
    for i in "${!UNIT_IDS[@]}"; do
        status=""
        if [ "$in_step" = "true" ]; then
            if [ "$i" -lt "$start_idx" ]; then
                status="  ■  (done)"
            elif [ "${UNIT_IDS[$i]}" = "$CURRENT_UNIT_ID" ]; then
                status="<-- current"
            fi
        fi
        if [ "${UNIT_IDS[$i]}" = "${UNIT_NAMES[$i]}" ]; then
            label="[${UNIT_IDS[$i]}]"
        else
            label="[${UNIT_IDS[$i]}]-[${UNIT_NAMES[$i]}]"
        fi
        if [ -n "$status" ]; then
            printf '  unit:%-18s unit_test/%-24s %s\n' "$label" "[${UNIT_FILES[$i]##*/}]" "$status" >&2
        else
            printf '  unit:%-18s unit_test/%s\n' "$label" "[${UNIT_FILES[$i]##*/}]" >&2
        fi
    done
}

# Discover unit_test/test_*.sh and source them in order. Numbered files
# (test_NN-...) run first by numeric value, then unnumbered files
# alphabetically. UNIT_TEST_CORE overrides discovery for single-file
# regression rigs (see verbose-mode tests in test_core.sh).
UNIT_IDS=()
UNIT_NAMES=()
UNIT_FILES=()

if [ -n "${UNIT_TEST_CORE:-}" ]; then
    UNIT_IDS=("core")
    UNIT_NAMES=("core")
    UNIT_FILES=("$UNIT_TEST_CORE")
else
    _sortkeys=()
    for f in unit_test/test_*.sh; do
        [ -e "$f" ] || continue
        bn="${f##*/}"; bn="${bn%.sh}"; bn="${bn#test_}"
        if [[ "$bn" =~ ^([0-9]+)(-(.+))?$ ]]; then
            id="${BASH_REMATCH[1]}"
            name="${BASH_REMATCH[3]}"
            [ -z "$name" ] && name="$id"
            sk=$(printf '0_%010d' "$id")
        else
            id="$bn"
            name="$bn"
            sk="1_$bn"
        fi
        UNIT_IDS+=("$id"); UNIT_NAMES+=("$name"); UNIT_FILES+=("$f"); _sortkeys+=("$sk")
    done

    if [ "${#UNIT_IDS[@]}" -eq 0 ]; then
        echo "ERROR: no test units found in unit_test/test_*.sh" >&2
        exit 1
    fi

    indices=( $(for i in "${!_sortkeys[@]}"; do
                    printf '%s\t%s\n' "${_sortkeys[$i]}" "$i"
                done | sort | awk -F'\t' '{print $2}') )
    sorted_ids=()
    sorted_names=()
    sorted_files=()
    for i in "${indices[@]}"; do
        sorted_ids+=("${UNIT_IDS[$i]}")
        sorted_names+=("${UNIT_NAMES[$i]}")
        sorted_files+=("${UNIT_FILES[$i]}")
    done
    UNIT_IDS=("${sorted_ids[@]}")
    UNIT_NAMES=("${sorted_names[@]}")
    UNIT_FILES=("${sorted_files[@]}")

    # Catch collisions between any pair of (id, name) across all units.
    seen=""
    for i in "${!UNIT_IDS[@]}"; do
        id="${UNIT_IDS[$i]}"
        name="${UNIT_NAMES[$i]}"
        case " $seen " in *" $id "*)
            echo "ERROR: duplicate test unit identifier [$id]" >&2
            exit 1 ;;
        esac
        seen="$seen $id"
        if [ "$name" != "$id" ]; then
            case " $seen " in *" $name "*)
                echo "ERROR: duplicate test unit identifier [$name]" >&2
                exit 1 ;;
            esac
            seen="$seen $name"
        fi
    done
fi

# Apply --units filter (comma-separated list of IDs/names). Preserves
# discovery order so behaviour is independent of how the user listed them.
if [ -n "$units_filter" ]; then
    selected_ids=""
    IFS=',' read -ra _req <<< "$units_filter"
    for req in "${_req[@]}"; do
        if [ -z "$req" ]; then
            echo "units: empty entry in [$units_filter]" >&2
            usage
            exit 1
        fi
        if resolved=$(unit_resolve "$req"); then
            case " $selected_ids " in
                *" $resolved "*) ;;  # already selected — silently de-dup
                *) selected_ids="$selected_ids $resolved" ;;
            esac
        else
            echo "units: unknown test unit [$req]" >&2
            usage
            exit 1
        fi
    done

    new_ids=(); new_names=(); new_files=()
    for i in "${!UNIT_IDS[@]}"; do
        case " $selected_ids " in *" ${UNIT_IDS[$i]} "*)
            new_ids+=("${UNIT_IDS[$i]}")
            new_names+=("${UNIT_NAMES[$i]}")
            new_files+=("${UNIT_FILES[$i]}")
            ;;
        esac
    done
    UNIT_IDS=("${new_ids[@]}")
    UNIT_NAMES=("${new_names[@]}")
    UNIT_FILES=("${new_files[@]}")
fi

if [ "$list_units_mode" = "true" ]; then
    print_unit_list
    exit 0
fi

# Validate --step now that we know which units will run.
if [ -n "$step_line" ]; then
    if [ -z "$step_unit" ]; then
        if [ "${#UNIT_IDS[@]}" -ne 1 ]; then
            echo "step: expected ID,LINE (multiple test units present)" >&2
            usage
            exit 1
        fi
        step_unit="${UNIT_IDS[0]}"
    else
        if resolved=$(unit_resolve "$step_unit"); then
            step_unit="$resolved"
        else
            echo "step: unknown test unit [$step_unit]" >&2
            usage
            exit 1
        fi
    fi
fi

for _i in "${!UNIT_IDS[@]}"; do
    CURRENT_UNIT_ID="${UNIT_IDS[$_i]}"
    CURRENT_UNIT_INDEX="$_i"
    source "${UNIT_FILES[$_i]}"
done

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

echo
echo "Done."
echo



