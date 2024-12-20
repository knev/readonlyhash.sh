#!/bin/bash

# This is a basic unit test script for the hash management script

# Path to the hash script
ROH_SCRIPT="./readonlyhash.sh"
chmod +x $ROH_SCRIPT

#TODO:
# -x exit the script on first failure
# -v always print the output

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

HASH="sha256"
ROH_DIR=".roh.git"
TEST="test"
SUBDIR_WITH_SPACES="sub-directory with spaces"
SUBSUBDIR="sub-sub-directory"
rm -rf "$TEST"

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# write_hash()
echo
echo "# write_hash()"

mkdir -p "$TEST"
echo "ABC" > "$TEST/file with spaces.txt"
mkdir -p "$TEST/$SUBDIR_WITH_SPACES"
echo "OMN" > "$TEST/$SUBDIR_WITH_SPACES/omn.txt"
mkdir -p "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR"
echo "JKL" > "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/jkl.txt"

echo "c5a8fb450fb0b568fc69a9485b8e531f119ca6e112fe1015d03fceb64b9c0e65" > "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/jkl.txt.$HASH"
run_test "$ROH_SCRIPT -w $TEST" "1" "$(escape_expected "ERROR: [$TEST/sub-directory with spaces/sub-sub-directory] \"jkl.txt\" -- hash file [$TEST/sub-directory with spaces/sub-sub-directory/jkl.txt.sha256] exists/(NOT hidden)")"
rm "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/jkl.txt.sha256"

run_test "$ROH_SCRIPT -w $TEST" "0" "$(escape_expected "File: [20562d3970dd399e658eaca0a7a6ff1bacd9cd4fbb67328b6cd805dc3c2ce1b1]: [test/sub-directory with spaces] \"omn.txt\" -- OK")" "true"

echo "0000000000000000000000000000000000000000000000000000000000000000" > "$TEST/$ROH_DIR/file with spaces.txt.$HASH"
run_test "$ROH_SCRIPT -w --force $TEST" "0" "$(escape_expected "File: [test] \"file with spaces.txt\" -- hash mismatch: --.*stored [0000000000000000000000000000000000000000000000000000000000000000]: [test/.roh.git/file with spaces.txt.sha256].*computed [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]: [test/file with spaces.txt] -- new hash stored -- FORCED!")"

echo "0000000000000000000000000000000000000000000000000000000000000000" > "$TEST/$ROH_DIR/file with spaces.txt.$HASH"
chmod 000 "$TEST/$ROH_DIR/file with spaces.txt.sha256" 
run_test "$ROH_SCRIPT -w --force $TEST" "1" "$(escape_expected "ERROR: [test] \"file with spaces.txt\" -- failed to write hash to [test/$ROH_DIR/file with spaces.txt.sha256] -- (FORCED)")"
chmod 700 "$TEST/$ROH_DIR/file with spaces.txt.sha256" 
$ROH_SCRIPT -w --force $TEST >/dev/null 2>&1

echo "ZYXW" > "$TEST/file with spaces.txt"
run_test "$ROH_SCRIPT -w $TEST" "1" "$(escape_expected "ERROR: [test] \"file with spaces.txt\" -- hash mismatch, [test/$ROH_DIR/file with spaces.txt.sha256] exists with stored [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]")"
#echo "ABC" > "$TEST/file with spaces.txt"

rm "$TEST/$ROH_DIR/file with spaces.txt.$HASH" 
run_test "$ROH_SCRIPT -w $TEST" "0" "$(escape_expected "File: [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff]: [$TEST] \"file with spaces.txt\" -- OK")"

chmod 000 "$TEST/$ROH_DIR/file with spaces.txt.$HASH" 
run_test "$ROH_SCRIPT -w --force $TEST" "1" "$(escape_expected "ERROR: [test] \"file with spaces.txt\" -- failed to write hash to [test/$ROH_DIR/file with spaces.txt.sha256] -- (FORCED)")"
chmod 700 "$TEST/$ROH_DIR/file with spaces.txt.$HASH" 

run_test "$ROH_SCRIPT -w $TEST" "0" "$(escape_expected "File: ")" "true"

# delete_hash()
echo
echo "# delete_hash()"

mv "$TEST/$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256" 
run_test "$ROH_SCRIPT -d $TEST" "1" "$(escape_expected "ERROR: [test] \"file with spaces.txt\" -- hash file [test/file with spaces.txt.sha256] exists/(NOT hidden); can only delete hidden hashes")"

mv "$TEST/file with spaces.txt.sha256" "$TEST/$ROH_DIR/file with spaces.txt.sha256" 
echo "ABC" > "$TEST/file with spaces.txt"
run_test "$ROH_SCRIPT -d $TEST" "1" "$(escape_expected "ERROR: [test] \"file with spaces.txt\" -- hash mismatch, cannot delete [test/$ROH_DIR/file with spaces.txt.sha256] with stored [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff]")"

run_test "$ROH_SCRIPT -d --force $TEST" "0" "$(escape_expected "File: [test] \"file with spaces.txt\" -- hash mismatch, [test/$ROH_DIR/file with spaces.txt.sha256] deleted with stored [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff] -- FORCED!")"

echo "ZYXW" > "$TEST/file with spaces.txt"
$ROH_SCRIPT -w "$TEST" >/dev/null 2>&1
run_test "$ROH_SCRIPT -d $TEST" "0" "$(escape_expected "File: [test] \"file with spaces.txt\" -- hash file in [test/$ROH_DIR] deleted -- OK")"
echo "ABC" > "$TEST/file with spaces.txt"

run_test "$ROH_SCRIPT -d $TEST" "0" "$(escape_expected "File: ")" "true"

# verify_hash
echo
echo "# verify_hash()"

mkdir "$TEST-empty"
run_test "$ROH_SCRIPT -v $TEST-empty" "1" "$(escape_expected "ERROR: [test-empty] -- not a READ-ONLY directory, missing [$ROH_DIR]")"
rm -rf "$TEST-empty"

echo "8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69" > "$TEST/file with spaces.txt.$HASH"
run_test "$ROH_SCRIPT -v $TEST" "1" "$(escape_expected "ERROR: [test] \"file with spaces.txt\" -- hash file [test/file with spaces.txt.sha256] exists/(NOT hidden)")"
# see also first test in manage_hash_visibility: ERROR:.* -- hash file [.*] exists/(NOT hidden)
rm "$TEST/file with spaces.txt.$HASH"

rm "$TEST/$ROH_DIR/file with spaces.txt.$HASH"
run_test "$ROH_SCRIPT -v $TEST" "1" "$(escape_expected "ERROR: [test] \"file with spaces.txt\" --.* hash file [test/.roh.git/file with spaces.txt.sha256] -- NOT found.* for [test/file with spaces.txt][8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]")"

$ROH_SCRIPT -w "$TEST" >/dev/null 2>&1
run_test "$ROH_SCRIPT -v $TEST" "0" "$(escape_expected "File: [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]: [test] \"file with spaces.txt\" -- [test/file with spaces.txt] -- OK")"

echo "ZYXW" > "$TEST/file with spaces.txt"
run_test "$ROH_SCRIPT -v $TEST" "1" "$(escape_expected "ERROR: [test] \"file with spaces.txt\" -- hash mismatch:.* stored [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]: [test/$ROH_DIR/file with spaces.txt.sha256].* computed [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff]: [test/file with spaces.txt]")"
echo "ABC" > "$TEST/file with spaces.txt"

mkdir "$TEST/$ROH_DIR/this_is_a_directory.sha256"
run_test "$ROH_SCRIPT -v $TEST" "0" "$(escape_expected "ERROR: [test] -- NO file [.*] found for corresponding hash [test/$ROH_DIR/this_is_a_directory.sha256][.*]")" "true"
rmdir "$TEST/$ROH_DIR/this_is_a_directory.sha256"

# verify_hash, process_directory()
rm "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/jkl.txt"
run_test "$ROH_SCRIPT -v $TEST" "1" "$(escape_expected "ERROR: [test/sub-directory with spaces/sub-sub-directory] --.* file [test/sub-directory with spaces/sub-sub-directory/jkl.txt] -- NOT found.* for corresponding hash [test/.roh.git/sub-directory with spaces/sub-sub-directory/jkl.txt.sha256][c5a8fb450fb0b568fc69a9485b8e531f119ca6e112fe1015d03fceb64b9c0e65]")"
echo "JKL" > "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/jkl.txt"

# recover_hash
echo
echo "# recover_hash()"

cp "$TEST/$SUBDIR_WITH_SPACES/omn.txt" "$TEST/$SUBDIR_WITH_SPACES/dup.txt"
run_test "$ROH_SCRIPT -r $TEST" "1" "$(escape_expected "WARN: [test/sub-directory with spaces] \"dup.txt\" --.* stored [test/.roh.git/sub-directory with spaces/omn.txt.sha256] -- identical file.* for computed [test/sub-directory with spaces/dup.txt][20562d3970dd399e658eaca0a7a6ff1bacd9cd4fbb67328b6cd805dc3c2ce1b1].*ERROR: [test/sub-directory with spaces] \"dup.txt\" -- could not recover hash for file [test/sub-directory with spaces/dup.txt][20562d3970dd399e658eaca0a7a6ff1bacd9cd4fbb67328b6cd805dc3c2ce1b1]")"
rm "$TEST/$SUBDIR_WITH_SPACES/dup.txt"

mv "$TEST/$SUBDIR_WITH_SPACES/omn.txt" "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/OMG.txt"
run_test "$ROH_SCRIPT -r $TEST" "0" "$(escape_expected "Recovered: [test/sub-directory with spaces/sub-sub-directory] \"OMG.txt\" -- hash in [test/.roh.git/sub-directory with spaces/omn.txt.sha256][20562d3970dd399e658eaca0a7a6ff1bacd9cd4fbb67328b6cd805dc3c2ce1b1].* restored for [test/sub-directory with spaces/sub-sub-directory/OMG.txt].* in [test/.roh.git/sub-directory with spaces/sub-sub-directory/OMG.txt.sha256]")" 
run_test "$ROH_SCRIPT -v $TEST" "0" "$(escape_expected "ERROR")" "true"

#rm "$TEST/$ROH_DIR/$SUBDIR_WITH_SPACES/omn.txt.$HASH"
#mv "$TEST/directory with spaces/abc.txt" "$TEST/directory with spaces/zyxw.txt"
mv "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/OMG.txt" "$TEST/$SUBDIR_WITH_SPACES/omn.txt"
echo "OMN-D" > "$TEST/$SUBDIR_WITH_SPACES/omn.txt"
run_test "$ROH_SCRIPT -r $TEST" "1" "$(escape_expected "ERROR: [test/sub-directory with spaces] \"omn.txt\" -- could not recover hash for file [test/sub-directory with spaces/omn.txt][697359ec47aef76de9a0b5001e47d7b7e93021ed8f0100e1e7e739ccdf0a5f8e]")" 
rm "$TEST/$ROH_DIR/$SUBDIR_WITH_SPACES/$SUBSUBDIR/OMG.txt.$HASH"
$ROH_SCRIPT -w "$TEST" >/dev/null 2>&1

# manage_hash_visibility
echo
echo "# manage_hash_visibility()"

$ROH_SCRIPT -s "$TEST" >/dev/null 2>&1
run_test "$ROH_SCRIPT -v $TEST" "1" "$(escape_expected "ERROR:.* -- hash file [.*] exists/(NOT hidden)")"
$ROH_SCRIPT -i "$TEST" >/dev/null 2>&1

cp "$TEST/$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256" 
run_test "$ROH_SCRIPT -s $TEST" "1" "$(escape_expected "ERROR: [test] \"file with spaces.txt\" -- hash mismatch:.* [test/file with spaces.txt.sha256][8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69] exists/(shown), not moving/(showing)")"
$ROH_SCRIPT -i "$TEST" >/dev/null 2>&1
rm "$TEST/file with spaces.txt.sha256"

run_test "$ROH_SCRIPT -s $TEST" "0" "$(escape_expected "File: [test] \"file with spaces.txt\" -- hash file [test/file with spaces.txt.sha256] moved(shown) -- OK")"
$ROH_SCRIPT -i "$TEST" >/dev/null 2>&1

mv "$TEST/$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256"
run_test "$ROH_SCRIPT -s $TEST" "0" "$(escape_expected "File: [test] \"file with spaces.txt\" -- hash file [test/file with spaces.txt.sha256] exists(shown), NOT moving/(showing) -- OK")"

rm "$TEST/file with spaces.txt.sha256"
run_test "$ROH_SCRIPT -s $TEST" "1" "$(escape_expected "ERROR: [test] \"file with spaces.txt\" -- NO hash file found [test/.roh.git/file with spaces.txt.sha256] for [test/file with spaces.txt], not showing")"
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

rm "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/jkl.txt"
rmdir "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR"
rm "$TEST/$SUBDIR_WITH_SPACES/omn.txt"
rmdir "$TEST/$SUBDIR_WITH_SPACES"
rm "$TEST/file with spaces.txt"

rm -rf "$TEST/$ROH_DIR/.git"
rmdir "$TEST/$ROH_DIR/$SUBDIR_WITH_SPACES/$SUBSUBDIR"
rmdir "$TEST/$ROH_DIR/$SUBDIR_WITH_SPACES"
rmdir "$TEST/$ROH_DIR"
rmdir "$TEST"

run_test "ls -alR $TEST" "1" "$(escape_expected "ls: $TEST: No such file or directory")"

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Requirements
echo
echo "# Requirements"

TEST="test.ro"
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
run_test "$ROH_SCRIPT -v" "1" "$(escape_expected "ERROR: [.] \"four.txt\" --.* hash file [./.roh.git/four.txt.sha256] -- NOT found.* for [./four.txt][ab929fcd5594037960792ea0b98caf5fdaf6b60645e4ef248c28db74260f393e]")"

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
run_test "$ROH_SCRIPT -v" "1" "$(escape_expected "ERROR: [.] --.* file [./four.txt] -- NOT found.* for corresponding hash [./.roh.git/four.txt.sha256][ab929fcd5594037960792ea0b98caf5fdaf6b60645e4ef248c28db74260f393e]")"

# remove orphaned hashes (in bulk)
run_test "$ROH_SCRIPT -s" "1" "$(escape_expected "ERROR: [.] --.*file [./four.txt] -- NOT found.* for corresponding hash [./.roh.git/four.txt.sha256][ab929fcd5594037960792ea0b98caf5fdaf6b60645e4ef248c28db74260f393e]")"
# it should be safe to remove the hashes (!NOT the ROH_DIR!), because hashes have been moved next to files, but we don't want to kill the git repo
run_test "rm -v $ROH_DIR/*.sha256" "0" ".roh.git/four.txt.sha256"
run_test "$ROH_SCRIPT -i" "0" "$(escape_expected "ERROR:.* NO file.* found for corresponding hash")" "true"

# File Renamed 
echo
echo "# File Renamed: The name of a file is changed"
# File Moved 
echo "# File Moved: A file is moved either within the directory or outside of it"

mv "five.txt" "seven.txt"
run_test "$ROH_SCRIPT -v" "1" "$(escape_expected "ERROR: [.] \"seven.txt\" --.* hash file [./.roh.git/seven.txt.sha256] -- NOT found.* for [./seven.txt][ac169f9fb7cb48d431466d7b3bf2dc3e1d2e7ad6630f6b767a1ac1801c496b35].*ERROR: [.] --.* file [./five.txt] -- NOT found.* for corresponding hash [./.roh.git/five.txt.sha256][ac169f9fb7cb48d431466d7b3bf2dc3e1d2e7ad6630f6b767a1ac1801c496b35]")"
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

# Subdirectory Added
echo
echo "# Subdirectory Added: A new subdirectory is created within the directory."

mkdir "this_does_not_exit"
run_test "$ROH_SCRIPT -v" "1" "$(escape_expected "ERROR: [./this_does_not_exit] -- not a ROH directory, missing [$ROH_DIR]")"
rmdir "this_does_not_exit"

# Subdirectory Removed
echo
echo "# Subdirectory Removed: An existing subdirectory is deleted"

rm -rf "$SUBDIR"
run_test "$ROH_SCRIPT -v" "1" "$(escape_expected "")"

# Subdirectory Renamed
echo
echo "# Subdirectory Renamed: The name of a subdirectory is changed."
# Subdirectory Moved
echo "# Subdirectory Moved: A subdirectory is moved either within the directory or outside of it."


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

run_test "ls -alR $TEST" "1" "$(escape_expected "ls: $TEST: No such file or directory")"

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

echo "Done."
echo



