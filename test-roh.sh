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
		echo "# Expected to NOT contain [$ok]: \"$expected_regex\""
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
run_test "$ROH_SCRIPT -w $TEST" "1" "$(escape_expected "ERROR: [$TEST] \"file with spaces.txt\" -- hash file [$TEST/file with spaces.txt.sha256] exists/(NOT hidden)")"

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

echo "8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69" > "$TEST/file with spaces.txt.sha256"
run_test "$ROH_SCRIPT -v $TEST" "1" "$(escape_expected "ERROR: [test] \"file with spaces.txt\" -- hash file [test/file with spaces.txt.sha256] exists/(NOT hidden)")"
# see also first test in manage_hash_visibility: ERROR:.* -- hash file [.*] exists/(NOT hidden)
rm "$TEST/file with spaces.txt.sha256"

run_test "$ROH_SCRIPT -v $TEST" "1" "$(escape_expected "ERROR: [test] \"file with spaces.txt\" -- NO hash file found in [test/$ROH_DIR] for [test/file with spaces.txt]")"

$ROH_SCRIPT -w "$TEST" >/dev/null 2>&1
run_test "$ROH_SCRIPT -v $TEST" "0" "$(escape_expected "File: [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff]: [test] \"file with spaces.txt\" -- [test/file with spaces.txt] -- OK")"

echo "ABC" > "$TEST/file with spaces.txt"
run_test "$ROH_SCRIPT -v $TEST" "1" "$(escape_expected "ERROR: [test] \"file with spaces.txt\" -- hash mismatch:.* stored [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff]: [test/$ROH_DIR/file with spaces.txt.sha256].* computed [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]: [test/file with spaces.txt]")"
echo "ZYXW" > "$TEST/file with spaces.txt"

mkdir "$TEST/$ROH_DIR/this_is_a_directory.sha256"
run_test "$ROH_SCRIPT -v $TEST" "0" "$(escape_expected "ERROR: [test] -- NO file [.*] found for corresponding hash [test/$ROH_DIR/this_is_a_directory.sha256][.*]")" "true"
rmdir "$TEST/$ROH_DIR/this_is_a_directory.sha256"

rm "$TEST/file with spaces.txt"
run_test "$ROH_SCRIPT -v $TEST" "1" "$(escape_expected "ERROR: [test] -- NO file [test/file with spaces.txt] found for corresponding hash [test/$ROH_DIR/file with spaces.txt.sha256][349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff]")" 
echo "ZYXW" > "$TEST/file with spaces.txt"

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

$ROH_SCRIPT -s "$TEST" >/dev/null 2>&1
run_test "$ROH_SCRIPT -v $TEST" "1" "$(escape_expected "ERROR:.* -- hash file [.*] exists/(NOT hidden)")"
$ROH_SCRIPT -i "$TEST" >/dev/null 2>&1

cp "$TEST/$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256" 
run_test "$ROH_SCRIPT -s $TEST" "1" "$(escape_expected "ERROR: [test] \"file with spaces.txt\" -- hash mismatch, [test/file with spaces.txt.sha256] exists/(shown) with stored [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff], not moving/(showing)")"
$ROH_SCRIPT -i "$TEST" >/dev/null 2>&1
rm "$TEST/file with spaces.txt.sha256"

run_test "$ROH_SCRIPT -s $TEST" "0" "$(escape_expected "File: [test] \"file with spaces.txt\" -- hash file [test/file with spaces.txt.sha256] moved(shown) -- OK")"
$ROH_SCRIPT -i "$TEST" >/dev/null 2>&1

mv "$TEST/$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256"
run_test "$ROH_SCRIPT -s $TEST" "0" "$(escape_expected "File: [test] \"file with spaces.txt\" -- hash file [test/file with spaces.txt.sha256] exists(shown), NOT moving/(showing) -- OK")"

rm "$TEST/file with spaces.txt.sha256"
run_test "$ROH_SCRIPT -s $TEST" "1" "$(escape_expected "ERROR: [test] \"file with spaces.txt\" -- NO hash file found in [test/$ROH_DIR], not showing")"
$ROH_SCRIPT -i "$TEST" >/dev/null 2>&1
$ROH_SCRIPT -w "$TEST" >/dev/null 2>&1

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

$ROH_SCRIPT -d "$TEST" >/dev/null 2>&1

rm -rf "$TEST/directory with spaces/$ROH_DIR/.git"
rmdir "$TEST/directory with spaces/$ROH_DIR"
rm "$TEST/directory with spaces/zyxw.txt"
rmdir "$TEST/directory with spaces"
rm -rf "$TEST/$ROH_DIR/.git"
rmdir "$TEST/$ROH_DIR"
rm "$TEST/abc.txt"
rm "$TEST/file with spaces.txt"
rmdir "$TEST"

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Requirements
echo
echo "# Requirements"

TEST="test.roh"
SUBDIR="subdir"
rm -rf "$TEST"
mkdir -p "$TEST/$ROH_DIR"

pushd "$TEST" >/dev/null 2>&1
ROH_SCRIPT="../readonlyhash.sh"

roh_git init >/dev/null 2>&1

#--
# File Changes:
#

# File Added
echo
echo "# File Added: A new file is added to the directory"

echo "one" > "one.txt"
echo "two" > "two.txt"
echo "five" > "five.txt"

mkdir $SUBDIR
echo "ten" > "$SUBDIR/ten.txt"
echo "eleven" > "$SUBDIR/eleven.txt"
echo "23" > "$SUBDIR/[23].txt"

$ROH_SCRIPT -w >/dev/null 2>&1
roh_git add *.sha256 >/dev/null 2>&1
roh_git commit -m "File Added" >/dev/null 2>&1
echo "four" > "four.txt"
# roh will report files that don't have a corresponding hash file
run_test "$ROH_SCRIPT -v" "1" "$(escape_expected "ERROR: [.] \"four.txt\" -- NO hash file found in [./$ROH_DIR] for [./four.txt][ab929fcd5594037960792ea0b98caf5fdaf6b60645e4ef248c28db74260f393e]")"

$ROH_SCRIPT -w >/dev/null 2>&1
# git will show hashes that are untracked
run_test "git -C $ROH_DIR status" "0" "four.txt.sha256"

# File Modified 
echo
echo "# File Modified: Content of a file is altered, which updates the file's last modified timestamp"

echo "six" > "two.txt"
run_test "$ROH_SCRIPT -v" "1" "$(escape_expected "ERROR: [.] \"two.txt\" -- hash mismatch:.* stored [27dd8ed44a83ff94d557f9fd0412ed5a8cbca69ea04922d88c01184a07300a5a]: [./$ROH_DIR/two.txt.sha256].* computed [fe2547fe2604b445e70fc9d819062960552f9145bdb043b51986e478a4806a2b]: [./two.txt]")"
echo "two" > "two.txt"

# File Removed 
echo
echo "# File Removed: A file is deleted from the directory"

rm "four.txt"
run_test "$ROH_SCRIPT -v" "1" "$(escape_expected "ERROR: [.] -- NO file [./four.txt] found for corresponding hash [./$ROH_DIR/four.txt.sha256][ab929fcd5594037960792ea0b98caf5fdaf6b60645e4ef248c28db74260f393e]")"

# remove orphaned hashes (in bulk)
run_test "$ROH_SCRIPT -s" "1" "$(escape_expected "ERROR: [.] -- NO file [./four.txt] found for corresponding hash [./$ROH_DIR/four.txt.sha256][ab929fcd5594037960792ea0b98caf5fdaf6b60645e4ef248c28db74260f393e]")"
# it should be safe to remove the hashes (!NOT the ROH_DIR!), because hashes have been moved next to files, but we don't want to kill the git repo
run_test "rm -v $ROH_DIR/*.sha256" "0" ".roh.git/four.txt.sha256"
run_test "$ROH_SCRIPT -i" "0" "$(escape_expected "ERROR:.* NO file.* found for corresponding hash")" "true"

# File Renamed 
echo
echo "# File Renamed: The name of a file is changed"
# File Moved 
echo "# File Moved: A file is moved either within the directory or outside of it"

mv "five.txt" "seven.txt"
run_test "$ROH_SCRIPT -v" "1" "$(escape_expected "ERROR: [.] \"seven.txt\" -- NO hash file found in [./$ROH_DIR] for [./seven.txt][ac169f9fb7cb48d431466d7b3bf2dc3e1d2e7ad6630f6b767a1ac1801c496b35].*ERROR: [.] -- NO file [./five.txt] found for corresponding hash [./$ROH_DIR/five.txt.sha256][ac169f9fb7cb48d431466d7b3bf2dc3e1d2e7ad6630f6b767a1ac1801c496b35]")"
run_test "$ROH_SCRIPT -r" "0" "$(escape_expected "Recovered: [.] \"seven.txt\" -- hash in [./.roh.git/five.txt.sha256][ac169f9fb7cb48d431466d7b3bf2dc3e1d2e7ad6630f6b767a1ac1801c496b35].* restored for [./seven.txt].* in [./.roh.git/seven.txt.sha256]")"

# File Permissions Changed: The permissions (read, write, execute) of a file are modified.
echo
echo "#File Permissions Changed: The permissions (read, write, execute) of a file are modified"

chmod 777 "seven.txt"
run_test "ls -al" "0" "$(escape_expected "-rwxrwxrwx   1 dev  staff.*seven.txt")"
run_test "$ROH_SCRIPT -v" "0" "$(escape_expected "Number of ERRORs encountered:")" "true"

chmod 000 "seven.txt"
run_test "ls -al" "0" "$(escape_expected "----------   1 dev  staff.*seven.txt")"
run_test "$ROH_SCRIPT -v" "1" "$(escape_expected "shasum: ./seven.txt: Permission denied")"

chmod 644 "seven.txt"

# File Ownership Changed: The owner or group of a file is changed.
#echo
#echo "#File Ownership Changed: The owner or group of a file is changed"

# File Attributes Changed: Other metadata like timestamps (creation, last access) or file attributes (hidden, system) are modified.
#echo
#echo "#File Attributes Changed: Other metadata like timestamps (creation, last access) or file attributes (hidden, system) are modified"

#--
#  Directory Structure Changes:
# 

# Subdirectory Added: A new subdirectory is created within the directory.


# Subdirectory Removed
echo
echo "# Subdirectory Removed: An existing subdirectory is deleted"

rm -rf "$SUBDIR"




# Subdirectory Moved: A subdirectory is moved either within the directory or outside of it.
# Subdirectory Renamed: The name of a subdirectory is changed.
# Directory Permissions Changed: The permissions of the directory itself are modified.
# Directory Ownership Changed: The owner or group of the directory is changed.
# 
# # Miscellaneous Changes:
# 
# Missing Directory: The entire directory might be removed or become inaccessible due to permissions or other system issues.
# Corrupted Files: Files within the directory could become corrupted, although this might not directly change the directory listing but would affect file integrity.
# Symlinks: Creation, deletion, or modification of symbolic links within the directory.
# Hard Links: Changes in hard links could affect how files appear within the directory, although this is less common and more OS-specific.
# 
# # System-Related Changes:
# 
# Mount Points: If the directory is a mount point, changes in the mounted filesystem (like unmounting or remounting) would affect the directory's content or availability.
# Network Drives: For directories on network drives, network issues or server-side changes can lead to perceived changes in the directory.

# Clean up test files
echo
echo "# Clean up test files"

popd >/dev/null 2>&1
rm -rf "$TEST"

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

echo "Done."
echo



