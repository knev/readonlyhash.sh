#!/bin/bash

# This is a basic unit test script for the hash management script

# Path to the hash script
ROH_SCRIPT="./readonlyhash.sh"
chmod +x $ROH_SCRIPT

# Helper function to run commands and check their output
run_test() {
    local cmd="$1"
    local expected_status="$2"
    local expected_output="$3"
    local not_flag="${4:-false}"  # Default not_flag to false if not provided

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


	if [ "$not_flag" = "true" ]; then
	    # Check if expected is NOT in output
		if [ "$exit_status" == "$expected_status" ] && [[ "$output" != *"$expected_output"* ]]; then
			echo "PASS: [$exit_status] ! \"$expected_output\""
		else
			echo
			echo "FAIL: $cmd"
			echo "Exit status: [$exit_status]"
			echo "Expected to NOT contain: \"$expected_output\""
			echo "----"
			echo "$output"
			echo "----"
		fi
	else
	    # Check if expected is in output
		if [ "$exit_status" == "$expected_status" ] && [[ "$output" == *"$expected_output"* ]]; then
			echo "PASS: [$exit_status] \"$expected_output\""
		else
			echo
			echo "FAIL: $cmd"
			echo "Exit status: [$exit_status]"
			echo "Expected to contain: \"$expected_output\""
			echo "----"
			echo "$output"
			echo "----"
		fi
	fi
}

ROH_DIR=".roh"
TEST="test"
rm -rf "$TEST"

# write_hash()
echo
echo "write_hash()"

mkdir -p "$TEST"
echo "ABC" > "$TEST/file with spaces.txt"
run_test "$ROH_SCRIPT -w test" "0" "File: [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]: [$TEST] \"file with spaces.txt\" -- OK"
run_test "$ROH_SCRIPT -w test" "0" "File: " "true"

mv "$TEST/$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256" 
run_test "$ROH_SCRIPT -w test" "1" "ERROR: [$TEST] \"file with spaces.txt\" -- hash file [$TEST/file with spaces.txt.sha256] exists and is NOT hidden" "1"

mv "$TEST/file with spaces.txt.sha256" "$TEST/$ROH_DIR/file with spaces.txt.sha256" 
echo "ZYXW" > "$TEST/file with spaces.txt"
run_test "$ROH_SCRIPT -w test" "1" "ERROR: [test] \"file with spaces.txt\" -- hash mismatch, [test/.roh/file with spaces.txt.sha256] exists with stored [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]"

chmod 000 "$TEST/$ROH_DIR/file with spaces.txt.sha256" 
run_test "$ROH_SCRIPT -w --force test" "1" "ERROR: [test] \"file with spaces.txt\" -- failed to write hash to [test/.roh/file with spaces.txt.sha256] -- (FORCED)"

chmod 700 "$TEST/$ROH_DIR/file with spaces.txt.sha256" 
run_test "$ROH_SCRIPT -w --force test" "0" "File: [test] \"file with spaces.txt\" -- hash mismatch, [test/.roh/file with spaces.txt.sha256] exists; new hash stored [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff] -- FORCED!"

# delete_hash()
echo
echo "delete_hash()"

mv "$TEST/$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256" 
run_test "$ROH_SCRIPT -d test" "1" "ERROR: [test] \"file with spaces.txt\" -- found existing hash in [test]; can only delete hidden hashes"

mkdir -p "$TEST/$ROH_DIR"
mv "$TEST/file with spaces.txt.sha256" "$TEST/$ROH_DIR/file with spaces.txt.sha256" 
echo "ABC" > "$TEST/file with spaces.txt"
run_test "$ROH_SCRIPT -d test" "1" "ERROR: [test] \"file with spaces.txt\" -- hash mismatch, cannot delete [test/.roh/file with spaces.txt.sha256] with stored [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff]"

run_test "$ROH_SCRIPT -d --force test" "0" "File: [test] \"file with spaces.txt\" -- hash mismatch, [test/.roh/file with spaces.txt.sha256] deleted with stored [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff] -- FORCED!"

echo "ZYXW" > "$TEST/file with spaces.txt"
$ROH_SCRIPT -w test >/dev/null 2>&1
run_test "$ROH_SCRIPT -d test" "0" "File: [test] \"file with spaces.txt\" -- hash file in [test/.roh] deleted -- OK"

run_test "$ROH_SCRIPT -d test" "0" "File: " "true"

# verify_hash
echo
echo "verify_hash()"

run_test "$ROH_SCRIPT -v test" "1" "ERROR: [test] \"file with spaces.txt\" -- no hash file exists in [test/.roh]"

$ROH_SCRIPT -w test >/dev/null 2>&1
run_test "$ROH_SCRIPT -v test" "0" "File: [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff]: [test] \"file with spaces.txt\" -- OK"

echo "ABC" > "$TEST/file with spaces.txt"
run_test "$ROH_SCRIPT -v test" "1" "ERROR: [test] \"file with spaces.txt\" - hash mismatch: [test/.roh/file with spaces.txt.sha256] stored [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff], computed [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]"

# manage_hash_visibility
echo
echo "manage_hash_visibility()"

cp "$TEST/$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256" 
run_test "$ROH_SCRIPT -s test" "1" "ERROR: [test] \"file with spaces.txt\" -- hash mismatch, [test/file with spaces.txt.sha256] exists with stored [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff], not moving (show)"

rm "$TEST/$ROH_DIR/file with spaces.txt.sha256"
echo "ZYXW" > "$TEST/file with spaces.txt"
run_test "$ROH_SCRIPT -s test" "0" "File: [test] \"file with spaces.txt\" -- hash file [test/file with spaces.txt.sha256] exists, not moving (show) -- OK"

mv "$TEST/file with spaces.txt.sha256" "$TEST/$ROH_DIR/file with spaces.txt.sha256" 
run_test "$ROH_SCRIPT -s test" "0" "File: [test] \"file with spaces.txt\" -- showing hash file [test/file with spaces.txt.sha256] -- OK"

rm "$TEST/file with spaces.txt.sha256"
run_test "$ROH_SCRIPT -s test" "1" "ERROR: [test] \"file with spaces.txt\" -- NO hash file found in [test/.roh], not showing"

# process_directory()
echo
echo "process_directory()"

touch "$TEST/$ROH_DIR/file with spaces.txt.sha256~"
run_test "$ROH_SCRIPT -d test" "1" "Directory [test/.roh] not empty" 

rm "$TEST/$ROH_DIR/file with spaces.txt.sha256~"
run_test "$ROH_SCRIPT -d test" "0" "Directory [test/.roh] not empty" "true"


# Parse command line options
echo
echo "Parse command line options"

run_test "$ROH_SCRIPT -dw" "1" "Usage: readonlyhash.sh"
run_test "$ROH_SCRIPT -v --force" "1" "Usage: readonlyhash.sh"
run_test "$ROH_SCRIPT -v THIS_DIR_SHOULD_NOT_EXIST" "1" "Error: Directory THIS_DIR_SHOULD_NOT_EXIST does not exist"


# Clean up test files
echo
echo "Clean up test files"

rm "$TEST/file with spaces.txt"
rmdir "$TEST"
#  rm -f test_file.txt .roh/test_file.txt.sha256 test_file.txt.sha256 .roh-restricted .roh-ignore
#  rmdir .roh

echo "Done."
echo
