#!/bin/bash

# This is a basic unit test script for the hash management script

usage() {
	echo
    echo "Usage: $(basename "$0") [-c|-v] [--step-test=<LINENO>]"
    echo "Options:"
    echo "    -c, --continue          Continue processing tests even in the event of failure."
	echo "    -v, --verbose           Display all output regardless if pass or fail."
    echo "    -h, --help              Display this help and exit"
    echo "    --step-test=<LINENO>    Pause before each run_test call whose caller line in unit_test/test_core.sh is >= LINENO." 
	echo "                            Prompts: [Enter]=run, c=continue without stepping, l=continue to line N, s=skip, q=quit."
	echo
	echo "Note: options -c and -v are mutually exclusive."
	echo
}

# Parse command line options
continue_mode="false"
verbose_mode="false"
step_test_line=""
while getopts "cvh-:" opt; do
  case $opt in
    c)
      continue_mode="true"
      ;;
    v)
      verbose_mode="true"
      ;;
    h)
      usage
      exit 0
      ;;
    -)
      case "${OPTARG}" in
        continue)
          continue_mode="true"
          ;;
        verbose)
          verbose_mode="true"
          ;;
        help)
          usage
          exit 0
          ;;
        step-test=*)
          step_test_line="${OPTARG#*=}"
          if ! [[ "$step_test_line" =~ ^[0-9]+$ ]]; then
            echo "step-test: expected numeric line number, got [$step_test_line]" >&2
            usage
            exit 1
          fi
          ;;
        step-test)
          echo "step-test: missing value (use --step-test=<LINENO>)" >&2
          usage
          exit 1
          ;;
        *)
          echo "Invalid option: --${OPTARG}" >&2
          usage
          exit 1
          ;;
      esac
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      exit 1
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

    # --step-test: pause before running once the caller's line number in
    # test_core.sh is >= $step_test_line. Reads keystrokes from /dev/tty so
    # tests that pipe stdin into the command under test aren't affected.
    local caller_line=${BASH_LINENO[0]}
    if [ -n "$step_test_line" ] && [ "$caller_line" -ge "$step_test_line" ]; then
        printf '\n--- step [test_core.sh:%d] ---\n' "$caller_line" >&2
        printf '  $ %s\n' "$cmd" >&2
        local not_suffix=""
        [ "$not_flag" = "true" ] && not_suffix=" (NOT)"
        printf '  Expected EXIT status:[%s] regex:[%s]%s\n' \
            "$expected_status" "$expected_regex" "$not_suffix" >&2
        printf '[ENTER]=run, [c]ontinue/to [l]ine, [s]kip, [q]uit ? ' >&2
        local key=""
        read -rsn1 key < /dev/tty
        printf '\n' >&2
        case "$key" in
            q|Q) echo "step-test: quit at [test_core.sh:$caller_line]" >&2; exit 0 ;;
            c|C) step_test_line="" ;;
            l|L)
                local target=""
                printf 'continue to line: ' >&2
                read -r target < /dev/tty
                if [[ "$target" =~ ^[0-9]+$ ]]; then
                    step_test_line="$target"
                else
                    echo "step-test: expected numeric line number, got [$target] — staying at [$caller_line]" >&2
                fi
                ;;
            s|S) echo "step-test: skipped [test_core.sh:$caller_line]" >&2; return 0 ;;
            *)   ;;
        esac
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
		if [ "$verbose_mode" = "true" ]; then
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
		if [ "$verbose_mode" = "true" ]; then
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

source "unit_test/test_core.sh"
source "unit_test/test_readonlyhash.sh"

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

echo
echo "Done."
echo



