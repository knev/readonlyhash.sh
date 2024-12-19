#!/bin/bash

# This is a basic unit test script for the hash management script

# Path to the hash script
ROH_SCRIPT="./readonlyhash.sh"
chmod +x $ROH_SCRIPT

# !!!NOTE:  this means we can not use [] and () in the regex's passed to run_test()
#
escape_expected() {
    local raw_pattern="$1"
    echo "$raw_pattern" | sed 's/\[/\\[/g; s/\]/\\]/g; s/(/\\(/g; s/)/\\)/g'
}
	
# Helper function to run commands and check their output
run_test() {
    local cmd="$1"
    local expected_status="$2"
    local expected_regex="$3"
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
	output=${output%$'\n'} # Remove the last newline

	local ok="no"
	if [ "$not_flag" = "true" ]; then
	    # Check if expected is NOT in output
		if ! [[ "$output" =~ $expected_regex ]]; then
			ok="YES"
			if [ "$exit_status" == "$expected_status" ]; then
				echo "PASS: [$exit_status] ! \"$expected_regex\""
				return 0
			fi 
		fi

		echo
		echo "# FAIL: [$exit_status] $cmd"
		echo "# Expected EXIT status: [$expected_status]"
		echo "# Expected to NOT contain: \"$expected_regex\""
		echo "#----"
		echo "$output" | sed 's/^/  /'
		echo "#----"
		echo
	else
	    # Check if expected is in output
		if [[ "$output" =~ $expected_regex ]]; then
			ok="YES"
			if [ "$exit_status" == "$expected_status" ]; then
				echo "PASS: [$exit_status] \"$expected_regex\""
				return 0
			fi
		fi

		echo
		echo "# FAIL: [$exit_status] $cmd"
		echo "# Expected EXIT status: [$expected_status]"
		echo "# Expected to contain [$ok]: \"$expected_regex\""
		echo "#----"
		echo "$output" | sed 's/^/  /'
		echo "#----"
		echo
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

ROH_DIR=".roh.git"
TEST="test"
rm -rf "$TEST"

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# write_hash()
echo
echo "# write_hash()"

mkdir -p "$TEST"
echo "ABC" > "$TEST/file with spaces.txt"
run_test "$ROH_SCRIPT -w $TEST" "0" "$(escape_expected "File: [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]: [$TEST] \"file with spaces.txt\" -- OK")"
run_test "$ROH_SCRIPT -w $TEST" "0" "$(escape_expected "File: ")" "true"

mv "$TEST/$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256" 
run_test "$ROH_SCRIPT -w $TEST" "1" "$(escape_expected "ERROR: [$TEST] \"file with spaces.txt\" -- hash file [$TEST/file with spaces.txt.sha256] exists and is NOT hidden")"

mv "$TEST/file with spaces.txt.sha256" "$TEST/$ROH_DIR/file with spaces.txt.sha256" 
echo "ZYXW" > "$TEST/file with spaces.txt"
run_test "$ROH_SCRIPT -w $TEST" "1" "$(escape_expected "ERROR: [test] \"file with spaces.txt\" -- hash mismatch, [test/$ROH_DIR/file with spaces.txt.sha256] exists with stored [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]")"

chmod 000 "$TEST/$ROH_DIR/file with spaces.txt.sha256" 
run_test "$ROH_SCRIPT -w --force $TEST" "1" "$(escape_expected "ERROR: [test] \"file with spaces.txt\" -- failed to write hash to [test/$ROH_DIR/file with spaces.txt.sha256] -- (FORCED)")"

chmod 700 "$TEST/$ROH_DIR/file with spaces.txt.sha256" 
run_test "$ROH_SCRIPT -w --force $TEST" "0" "$(escape_expected "File: [test] \"file with spaces.txt\" -- hash mismatch, [test/$ROH_DIR/file with spaces.txt.sha256] exists; new hash stored [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff] -- FORCED!")"

# delete_hash()
echo
echo "# delete_hash()"

mv "$TEST/$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256" 
run_test "$ROH_SCRIPT -d $TEST" "1" "$(escape_expected "ERROR: [test] \"file with spaces.txt\" -- found existing hash in [test]; can only delete hidden hashes")"

mkdir -p "$TEST/$ROH_DIR"
mv "$TEST/file with spaces.txt.sha256" "$TEST/$ROH_DIR/file with spaces.txt.sha256" 
echo "ABC" > "$TEST/file with spaces.txt"
run_test "$ROH_SCRIPT -d $TEST" "1" "$(escape_expected "ERROR: [test] \"file with spaces.txt\" -- hash mismatch, cannot delete [test/$ROH_DIR/file with spaces.txt.sha256] with stored [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff]")"

run_test "$ROH_SCRIPT -d --force $TEST" "0" "$(escape_expected "File: [test] \"file with spaces.txt\" -- hash mismatch, [test/$ROH_DIR/file with spaces.txt.sha256] deleted with stored [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff] -- FORCED!")"

echo "ZYXW" > "$TEST/file with spaces.txt"
$ROH_SCRIPT -w "$TEST" >/dev/null 2>&1
run_test "$ROH_SCRIPT -d $TEST" "0" "$(escape_expected "File: [test] \"file with spaces.txt\" -- hash file in [test/$ROH_DIR] deleted -- OK")"

run_test "$ROH_SCRIPT -d $TEST" "0" "$(escape_expected "File: ")" "true"

# verify_hash
echo
echo "# verify_hash()"

mkdir "$TEST-empty"
run_test "$ROH_SCRIPT -v $TEST-empty" "1" "$(escape_expected "ERROR: [test-empty] -- not a ROH directory, missing [$ROH_DIR]")"
rmdir "$TEST-empty"

run_test "$ROH_SCRIPT -v $TEST" "1" "$(escape_expected "ERROR: [test] \"file with spaces.txt\" -- NO hash file found in [test/$ROH_DIR] for [test/file with spaces.txt]")"

$ROH_SCRIPT -w "$TEST" >/dev/null 2>&1
run_test "$ROH_SCRIPT -v $TEST" "0" "$(escape_expected "File: [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff]: [test] \"file with spaces.txt\" -- OK")"

mkdir "$TEST/$ROH_DIR/this_is_a_directory.sha256"
run_test "$ROH_SCRIPT -v $TEST" "0" "$(escape_expected "ERROR: [test] -- NO file [] found for corresponding hash [test/.roh.git/this_is_a_directory.sha256]")" "true"
rmdir "$TEST/$ROH_DIR/this_is_a_directory.sha256"

echo "ABC" > "$TEST/file with spaces.txt"
run_test "$ROH_SCRIPT -v $TEST" "1" "$(escape_expected "ERROR: [test] \"file with spaces.txt\" -- hash mismatch: stored [test/$ROH_DIR/file with spaces.txt.sha256][349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff], computed [test/file with spaces.txt][8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]")"

# recover_hash
echo
echo "# recover_hash()"

mkdir "$TEST/directory with spaces"
echo "ABC" > "$TEST/abc.txt"
echo "ABC" > "$TEST/directory with spaces/abc.txt"
$ROH_SCRIPT -w "$TEST" >/dev/null 2>&1
mv "$TEST/abc.txt" "$TEST/zyxw.txt"

run_test "$ROH_SCRIPT -r $TEST" "0" "$(escape_expected "WARN: [test] \"zyxw.txt\" -- identical stored [test/directory with spaces/$ROH_DIR/abc.txt.sha256] found for computed [test/zyxw.txt][8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]")" 

mv "$TEST/directory with spaces/abc.txt" "$TEST/directory with spaces/zyxw.txt"
run_test "$ROH_SCRIPT -r $TEST" "0" "$(escape_expected "Recovered: [test/directory with spaces] \"zyxw.txt\" -- hash in [test/directory with spaces/$ROH_DIR/abc.txt.sha256][8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69].* restored for [test/directory with spaces/zyxw.txt].* in [test/directory with spaces/$ROH_DIR/zyxw.txt.sha256]")" 

mv "$TEST/zyxw.txt" "$TEST/abc.txt"
echo "ABC-D" > "$TEST/abc.txt"
run_test "$ROH_SCRIPT -r $TEST" "1" "$(escape_expected "ERROR: [test] \"abc.txt\" -- could not recover hash for file [test/abc.txt][50962f50838f8cacda3a9c00a6c04880bc0b2de8717df3b2f2cc6d8a72f026c8]")" 
rm "$TEST/$ROH_DIR/zyxw.txt.sha256"
$ROH_SCRIPT -w "$TEST" >/dev/null 2>&1

# manage_hash_visibility
echo
echo "# manage_hash_visibility()"

cp "$TEST/$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256" 
run_test "$ROH_SCRIPT -s $TEST" "1" "$(escape_expected "ERROR: [test] \"file with spaces.txt\" -- hash mismatch, [test/file with spaces.txt.sha256] exists with stored [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff], not moving (show)")"

rm "$TEST/$ROH_DIR/file with spaces.txt.sha256"
echo "ZYXW" > "$TEST/file with spaces.txt"
run_test "$ROH_SCRIPT -s $TEST" "0" "$(escape_expected "File: [test] \"file with spaces.txt\" -- hash file [test/file with spaces.txt.sha256] exists, not moving (show) -- OK")"

mv "$TEST/file with spaces.txt.sha256" "$TEST/$ROH_DIR/file with spaces.txt.sha256" 
run_test "$ROH_SCRIPT -s $TEST" "0" "$(escape_expected "File: [test] \"file with spaces.txt\" -- showing hash file [test/file with spaces.txt.sha256] -- OK")"

rm "$TEST/file with spaces.txt.sha256"
run_test "$ROH_SCRIPT -s $TEST" "1" "$(escape_expected "ERROR: [test] \"file with spaces.txt\" -- NO hash file found in [test/$ROH_DIR], not showing")"

# process_directory()
echo
echo "# process_directory()"

touch "$TEST/file with spaces.rslsz"
run_test "$ROH_SCRIPT -w $TEST" "1" "$(escape_expected "ERROR: [test] \"file with spaces.rslsz\" -- file with restricted extension")"

run_test "$ROH_SCRIPT -d $TEST" "0" "$(escape_expected "ERROR: [test] \"file with spaces.rslsz\" -- file with restricted extension")" "true"
rm "$TEST/file with spaces.rslsz"
 
#	mkdir -p "$TEST/$ROH_DIR"
#	touch "$TEST/$ROH_DIR/file with spaces.txt.sha256~"
#	run_test "$ROH_SCRIPT -d $TEST" "1" "Directory [test/$ROH_DIR] not empty" 
	
#	rm "$TEST/$ROH_DIR/file with spaces.txt.sha256~"
#	run_test "$ROH_SCRIPT -d $TEST" "0" "Directory [test/$ROH_DIR] not empty" "true"

# Parse command line options
echo
echo "# Parse command line options"

run_test "$ROH_SCRIPT -vw" "1" "Error: options -v, -w, -d, -i, -s and -r are mutually exclusive. Please use only one."
run_test "$ROH_SCRIPT -vd" "1" "Error: options -v, -w, -d, -i, -s and -r are mutually exclusive. Please use only one."
run_test "$ROH_SCRIPT -vi" "1" "Error: options -v, -w, -d, -i, -s and -r are mutually exclusive. Please use only one."
run_test "$ROH_SCRIPT -vs" "1" "Error: options -v, -w, -d, -i, -s and -r are mutually exclusive. Please use only one."
run_test "$ROH_SCRIPT -vr" "1" "Error: options -v, -w, -d, -i, -s and -r are mutually exclusive. Please use only one."
run_test "$ROH_SCRIPT -wd" "1" "Error: options -v, -w, -d, -i, -s and -r are mutually exclusive. Please use only one."
run_test "$ROH_SCRIPT -wi" "1" "Error: options -v, -w, -d, -i, -s and -r are mutually exclusive. Please use only one."
run_test "$ROH_SCRIPT -ws" "1" "Error: options -v, -w, -d, -i, -s and -r are mutually exclusive. Please use only one."
run_test "$ROH_SCRIPT -wr" "1" "Error: options -v, -w, -d, -i, -s and -r are mutually exclusive. Please use only one."
run_test "$ROH_SCRIPT -di" "1" "Error: options -v, -w, -d, -i, -s and -r are mutually exclusive. Please use only one."
run_test "$ROH_SCRIPT -ds" "1" "Error: options -v, -w, -d, -i, -s and -r are mutually exclusive. Please use only one."
run_test "$ROH_SCRIPT -dr" "1" "Error: options -v, -w, -d, -i, -s and -r are mutually exclusive. Please use only one."
run_test "$ROH_SCRIPT -is" "1" "Error: options -v, -w, -d, -i, -s and -r are mutually exclusive. Please use only one."
run_test "$ROH_SCRIPT -ir" "1" "Error: options -v, -w, -d, -i, -s and -r are mutually exclusive. Please use only one."
run_test "$ROH_SCRIPT -sr" "1" "Error: options -v, -w, -d, -i, -s and -r are mutually exclusive. Please use only one."

run_test "$ROH_SCRIPT -vh" "0" "Usage: readonlyhash"
run_test "$ROH_SCRIPT -wh" "0" "Usage: readonlyhash"
run_test "$ROH_SCRIPT -dh" "0" "Usage: readonlyhash"
run_test "$ROH_SCRIPT -ih" "0" "Usage: readonlyhash"
run_test "$ROH_SCRIPT -sh" "0" "Usage: readonlyhash"
run_test "$ROH_SCRIPT -rh" "0" "Usage: readonlyhash"

run_test "$ROH_SCRIPT -v --force" "1" "Error: --force can only be used with -d/--delete or -w/--write."
run_test "$ROH_SCRIPT --force -i" "1" "Error: --force can only be used with -d/--delete or -w/--write."
run_test "$ROH_SCRIPT --force -s" "1" "Error: --force can only be used with -d/--delete or -w/--write."
run_test "$ROH_SCRIPT --force -r" "1" "Error: --force can only be used with -d/--delete or -w/--write."
run_test "$ROH_SCRIPT -h --force" "0" "Usage: readonlyhash"

run_test "$ROH_SCRIPT -v SPECIFYING_A_DIR_THAT_SHOULD_NOT_EXIST" "1" "$(escape_expected "Error: Directory [SPECIFYING_A_DIR_THAT_SHOULD_NOT_EXIST] does not exist")"

# Clean up test files
echo
echo "# Clean up test files"

rm -rf "$TEST/$ROH_DIR/.git"
rmdir "$TEST/$ROH_DIR"
rm "$TEST/file with spaces.txt"
rmdir "$TEST"
#  rm -f test_file.txt .roh/test_file.txt.sha256 test_file.txt.sha256 .roh-restricted .roh-ignore
#  rmdir .roh

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Requirements
echo
echo "# Requirements"

TEST="test.roh"
rm -rf "$TEST"
mkdir -p "$TEST/$ROH_DIR"

pushd "$TEST" >/dev/null 2>&1
ROH_SCRIPT="../readonlyhash.sh"

roh_git init >/dev/null 2>&1

# File Added
echo
echo "# File Added: A new file is added to the directory"

echo "one" > "one.txt"
echo "two" > "two.txt"
echo "five" > "five.txt"
$ROH_SCRIPT -w >/dev/null 2>&1
roh_git add *.sha256 >/dev/null 2>&1
roh_git commit -m "File Added" >/dev/null 2>&1
echo "four" > "four.txt"
# roh will report files that don't have a corresponding hash file
run_test "$ROH_SCRIPT -v" "1" "$(escape_expected "ERROR: [.] \"four.txt\" -- NO hash file found in [./$ROH_DIR] for [./four.txt]")"

$ROH_SCRIPT -w >/dev/null 2>&1
# git will show hashes that are untracked
run_test "git -C $ROH_DIR status" "0" "four.txt.sha256"

# File Modified 
echo
echo "# File Modified: Content of a file is altered, which updates the file's last modified timestamp"

echo "six" > "two.txt"
run_test "$ROH_SCRIPT -v" "1" "$(escape_expected "ERROR: [.] \"two.txt\" -- hash mismatch: stored [./$ROH_DIR/two.txt.sha256][27dd8ed44a83ff94d557f9fd0412ed5a8cbca69ea04922d88c01184a07300a5a], computed [./two.txt][fe2547fe2604b445e70fc9d819062960552f9145bdb043b51986e478a4806a2b]")"
echo "two" > "two.txt"

# File Renamed 
echo
echo "# File Renamed: The name of a file is changed"

mv "five.txt" "seven.txt"
run_test "$ROH_SCRIPT -v" "1" "$(escape_expected "ERROR: [.] -- NO file found for corresponding hash [./$ROH_DIR/four.txt.sha256]")"
mv "seven.txt" "five.txt"

# File Removed 
echo
echo "# File Removed: A file is deleted from the directory"
# File Moved 
echo "# File Moved: A file is moved either within the directory or outside of it"

rm "four.txt"
run_test "$ROH_SCRIPT -v" "1" "$(escape_expected "ERROR: [.] -- NO file [./four.txt] found for corresponding hash [./$ROH_DIR/four.txt.sha256][ab929fcd5594037960792ea0b98caf5fdaf6b60645e4ef248c28db74260f393e]")"
echo "four" > "four.txt"

# File Permissions Changed: The permissions (read, write, execute) of a file are modified.
echo
echo "#File Permissions Changed: The permissions (read, write, execute) of a file are modified"

chmod 777 "four.txt"
run_test "ls -al" "0" "$(escape_expected "-rwxrwxrwx   1 dev  staff.*four.txt")"
exit
#run_test "$ROH_SCRIPT -v" "1" "ERROR: [.] -- NO file [./four.txt] found for corresponding hash [./$ROH_DIR/four.txt.sha256][ab929fcd5594037960792ea0b98caf5fdaf6b60645e4ef248c28db74260f393e]"

# File Ownership Changed: The owner or group of a file is changed.
echo
echo "#File Ownership Changed: The owner or group of a file is changed"

# File Attributes Changed: Other metadata like timestamps (creation, last access) or file attributes (hidden, system) are modified.
echo
echo "#File Attributes Changed: Other metadata like timestamps (creation, last access) or file attributes (hidden, system) are modified"




# Clean up test files
echo
echo "# Clean up test files"

#rm -rf "$TEST/.git"
#rmdir "$TEST"

popd >/dev/null 2>&1

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

echo "Done."
echo



