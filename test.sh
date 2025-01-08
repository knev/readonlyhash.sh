#!/bin/bash

# This is a basic unit test script for the hash management script

# Path to the hash script
ROH_SCRIPT="./readonlyhash.sh"
chmod +x $ROH_SCRIPT
GIT_BIN="roh.git"

usage() {
	echo
    echo "Usage: $(basename "$0") [-c|-v]"
    echo "Options:"
    echo "  -c, --continue   Continue processing tests even in the event of failure."
	echo "  -v, --verbose    Display all output regardless if pass or fail."
    echo "  -h, --help       Display this help and exit"
	echo 
	echo "Note: options -c and -v are mutually exclusive."
	echo 
}

# Parse command line options
continue_mode="false"
verbose_mode="false"
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
			if [ "$exit_status" == "$expected_status" ] && [ "$verbose_mode" != "true" ]; then
				echo "PASS: [$cmd][$exit_status] ! \"$expected_regex\""
				return 0
			fi 
		fi

		echo
		if [ "$verbose_mode" = "true" ]; then
			echo "# TEST: [$exit_status][$cmd]"
		else
			echo "# FAIL: [$exit_status][$cmd]"
		fi
		echo "# Expected EXIT status: [$expected_status]"
		echo "# Expected to NOT contain [$ok]: \"$expected_regex\""
		echo "#----"
		echo "$output" | sed 's/^/  /'
		echo "#----"
		echo

		if [ "$ok" = "no" ] || [ "$exit_status" != "$expected_status" ]; then
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
			if [ "$exit_status" == "$expected_status" ] && [ "$verbose_mode" != "true" ]; then
				echo "PASS: [$cmd][$exit_status] \"$expected_regex\""
				return 0
			fi
		fi

		echo
		if [ "$verbose_mode" = "true" ]; then
			echo "# TEST: [$exit_status][$cmd]"
		else
			echo "# FAIL: [$exit_status][$cmd]"
		fi
		echo "# Expected EXIT status: [$expected_status]"
		echo "# Expected to contain [$ok]: \"$expected_regex\""
		echo "#----"
		echo "$output" | sed 's/^/  /'
		echo "#----"
		echo

		if [ "$ok" = "no" ] || [ "$exit_status" != "$expected_status" ]; then
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

HASH="sha256"
TEST="test"
ROH_DIR="$TEST/.roh.git"
SUBDIR_WITH_SPACES="sub-directory with spaces"
SUBSUBDIR="sub-sub-directory"
rm -rf "$TEST"
rm -rf "$TEST.ro"

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

mkdir -p "$TEST"
echo "DS_Store" > "$TEST/.DS_Store"
echo "ABC" > "$TEST/file with spaces.txt"
mkdir -p "$TEST/$SUBDIR_WITH_SPACES"
echo "OMN" > "$TEST/$SUBDIR_WITH_SPACES/omn.txt"
mkdir -p "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR"
echo "JKL" > "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/jkl.txt"

#	run_test "$ROH_SCRIPT -w $TEST" "0" "$(escape_expected "File: ")" 
#	$GIT_BIN -C "$TEST" init >/dev/null 2>&1
#	echo ".DS_Store" > "$TEST/.gitignore"
#	
#	TEST=/Users/dev/Project-@knev/readonlyhash.sh.git/Fotos\ \[space\]/1999.ro
#	
#	while IFS= read -r roh_hash_fpath; do
#		echo "[$roh_hash_fpath]"
#	# exclude "$ROH_DIR/.git" using --prune, return only files
#	# sort, because we want lower directories removed first, so upper directories can be empty and removed
#	# done < <(find "$ROH_DIR" -path "$ROOT/$ROH_DIR/.*" -prune -o -type f -name "*" -print)
#	#done < <(find "ROH_DIR" -path "$ROOT/$ROH_DIR/.*" -prune -o -print | sort -r)
#	#done < <(find "ROH_DIR" \( -name ".*" -prune \) -o -print | sort -r)
#	#done < <(find "ROH_DIR" \( -path "*/.*" -prune \) -o -type f -print | sort -r)
#	#done < <(find "ROH_DIR" -path "*/.git/*" -prune -o -type f -not -name ".*" -print | sort -r)
#	done < <(find "ROH_DIR" -path "*/.git/*" -prune -o -not -name ".*" -print | sort -r)
#	exit

# write_hash()
echo
echo "# write_hash()"

echo "c5a8fb450fb0b568fc69a9485b8e531f119ca6e112fe1015d03fceb64b9c0e65" > "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/jkl.txt.$HASH"
run_test "$ROH_SCRIPT -w $TEST" "1" "$(escape_expected "ERROR: [$TEST/sub-directory with spaces/sub-sub-directory] \"jkl.txt\" -- hash file [$TEST/sub-directory with spaces/sub-sub-directory/jkl.txt.sha256] exists/(NOT hidden)")"
rm "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/jkl.txt.$HASH"

run_test "$ROH_SCRIPT -w $TEST" "0" "$(escape_expected "File: [20562d3970dd399e658eaca0a7a6ff1bacd9cd4fbb67328b6cd805dc3c2ce1b1]: [test/sub-directory with spaces] \"omn.txt\" -- OK")" "true"

# echo "0000000000000000000000000000000000000000000000000000000000000000" > "$ROH_DIR/file with spaces.txt.$HASH"
# run_test "$ROH_SCRIPT -w --force $TEST" "0" "$(escape_expected "File: [$TEST] \"file with spaces.txt\" -- hash mismatch: --.*stored [0000000000000000000000000000000000000000000000000000000000000000]: [$ROH_DIR/file with spaces.txt.sha256].*computed [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]: [$TEST/file with spaces.txt] -- new hash stored -- FORCED!")"

# echo "0000000000000000000000000000000000000000000000000000000000000000" > "$ROH_DIR/file with spaces.txt.$HASH"
# chmod 000 "$ROH_DIR/file with spaces.txt.sha256" 
# run_test "$ROH_SCRIPT -w --force $TEST" "1" "$(escape_expected "ERROR: [$TEST] \"file with spaces.txt\" -- failed to write hash to [$ROH_DIR/file with spaces.txt.sha256] -- (FORCED)")"
# chmod 700 "$ROH_DIR/file with spaces.txt.sha256" 
# $ROH_SCRIPT -w --force $TEST >/dev/null 2>&1

echo "ZYXW" > "$TEST/file with spaces.txt"
# run_test "$ROH_SCRIPT -w $TEST" "1" "$(escape_expected "ERROR: [$TEST] \"file with spaces.txt\" -- hash mismatch, [$ROH_DIR/file with spaces.txt.sha256] exists with stored [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]")"
# #echo "ABC" > "$TEST/file with spaces.txt"

rm "$ROH_DIR/file with spaces.txt.$HASH" 
run_test "$ROH_SCRIPT -w $TEST" "0" "$(escape_expected "File: [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff]: [$TEST] \"file with spaces.txt\" -- OK")"

rm "$ROH_DIR/file with spaces.txt.$HASH" 
chmod 000 "$ROH_DIR"
run_test "$ROH_SCRIPT -w $TEST" "1" "$(escape_expected "ERROR: [$TEST] \"file with spaces.txt\" -- failed to write hash to [$ROH_DIR/file with spaces.txt.sha256]")"
chmod 700 "$ROH_DIR"
$ROH_SCRIPT -w "$TEST" >/dev/null 2>&1

run_test "$ROH_SCRIPT -w $TEST" "0" "$(escape_expected "File: ")" "true"

# delete_hash()
echo
echo "# delete_hash()"

mv "$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256" 
run_test "$ROH_SCRIPT -d $TEST" "1" "$(escape_expected "ERROR: [$TEST] \"file with spaces.txt\" -- hash file [$TEST/file with spaces.txt.sha256] exists/(NOT hidden); can only delete hidden hashes")"

mkdir "$ROH_DIR"
mv "$TEST/file with spaces.txt.sha256" "$ROH_DIR/file with spaces.txt.sha256" 
echo "ABC" > "$TEST/file with spaces.txt"
run_test "$ROH_SCRIPT -d $TEST" "1" "$(escape_expected "ERROR: [$TEST] \"file with spaces.txt\" -- hash mismatch, cannot delete [$ROH_DIR/file with spaces.txt.sha256] with stored [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff]")"

run_test "$ROH_SCRIPT -d --force $TEST" "0" "$(escape_expected "File: [$TEST] \"file with spaces.txt\" -- hash mismatch, [$ROH_DIR/file with spaces.txt.sha256] deleted with stored [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff] -- FORCED!")"

echo "ZYXW" > "$TEST/file with spaces.txt"
$ROH_SCRIPT -w "$TEST" >/dev/null 2>&1
run_test "$ROH_SCRIPT -d $TEST" "0" "$(escape_expected "File: [$TEST] \"file with spaces.txt\" -- hash file in [$ROH_DIR] deleted -- OK")"
echo "ABC" > "$TEST/file with spaces.txt"

run_test "$ROH_SCRIPT -d $TEST" "0" "$(escape_expected "File: ")" "true"
$ROH_SCRIPT -w "$TEST" >/dev/null 2>&1

# verify_hash
echo
echo "# verify_hash()"

mkdir "$TEST-empty"
# we don't care about empty directories
run_test "$ROH_SCRIPT -v $TEST-empty" "1" "$(escape_expected "ERROR: [$TEST-empty] -- not a READ-ONLY directory, missing [$TEST-empty/.roh.git]. Aborting.")"
# run_test "$ROH_SCRIPT -v $TEST-empty" "0" "$(escape_expected "Processing directory: [test-empty]")"
# run_test "$ROH_SCRIPT -v $TEST-empty" "0" "$(escape_expected "Done.")"
rm -rf "$TEST-empty"

echo "8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69" > "$TEST/file with spaces.txt.$HASH"
run_test "$ROH_SCRIPT -v $TEST" "1" "$(escape_expected "ERROR: [$TEST] \"file with spaces.txt\" -- hash file [$TEST/file with spaces.txt.sha256] exists/(NOT hidden)")"
# see also first test in manage_hash_visibility: ERROR:.* -- hash file [.*] exists/(NOT hidden)
rm "$TEST/file with spaces.txt.$HASH"

rm "$ROH_DIR/file with spaces.txt.$HASH"
run_test "$ROH_SCRIPT -v $TEST" "1" "$(escape_expected "WARN: [$TEST] \"file with spaces.txt\" --.* hash file [$TEST/.roh.git/file with spaces.txt.sha256] -- NOT found.* for [$TEST/file with spaces.txt][8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]")"

$ROH_SCRIPT -w "$TEST" >/dev/null 2>&1
run_test "$ROH_SCRIPT -v $TEST" "0" "$(escape_expected "File: [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]: [$TEST] \"file with spaces.txt\" -- [$TEST/file with spaces.txt] -- OK")"

echo "ZYXW" > "$TEST/file with spaces.txt"
run_test "$ROH_SCRIPT -v $TEST" "1" "$(escape_expected "ERROR: [$TEST] \"file with spaces.txt\" -- hash mismatch:.* stored [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]: [$ROH_DIR/file with spaces.txt.sha256].* computed [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff]: [$TEST/file with spaces.txt]")"
echo "ABC" > "$TEST/file with spaces.txt"

mkdir "$ROH_DIR/this_is_a_directory.sha256"
run_test "$ROH_SCRIPT -v $TEST" "0" "$(escape_expected "ERROR: [$TEST] -- NO file [.*] found for corresponding hash [$ROH_DIR/this_is_a_directory.sha256][.*]")" "true"
# rmdir "$ROH_DIR/this_is_a_directory.sha256" # gets removed automagically now

#	dev@m2:readonly $ readonlyhash -s Zipped.ro  
#	ERROR: --                ... file [Zipped.ro/.gitignore] -- NOT found
#	       ... for corresponding hash [Zipped.ro/.roh.git/.gitignore][.DS_Store.sha256]
#	Number of ERRORs encountered: [1]
#	
#	
#	dev@m2:readonly $ readonlyhash -i Zipped.ro 
#	ERROR: --                ... file [Zipped.ro/.gitignore] -- NOT found
#	       ... for corresponding hash [Zipped.ro/.roh.git/.gitignore][.DS_Store.sha256]
#	Number of ERRORs encountered: [1]

echo "DS_Store" > "$ROH_DIR/.DS_Store"
$GIT_BIN -C "$TEST" init >/dev/null 2>&1
run_test "$ROH_SCRIPT -v $TEST" "0" ".DS_Store.$HASH" "true"

# verify_hash, process_directory()
rm -v "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/jkl.txt"
run_test "$ROH_SCRIPT -v $TEST" "1" "$(escape_expected "ERROR: --.* file [$TEST/sub-directory with spaces/sub-sub-directory/jkl.txt] -- NOT found.* for corresponding hash [$TEST/.roh.git/sub-directory with spaces/sub-sub-directory/jkl.txt.sha256][c5a8fb450fb0b568fc69a9485b8e531f119ca6e112fe1015d03fceb64b9c0e65]")"
echo "JKL" > "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/jkl.txt"

# recover_hash
echo
echo "# recover_hash()"

cp "$TEST/$SUBDIR_WITH_SPACES/omn.txt" "$TEST/$SUBDIR_WITH_SPACES/dup.txt"
run_test "$ROH_SCRIPT -r $TEST" "1" "$(escape_expected "WARN: [$TEST/sub-directory with spaces] \"dup.txt\" --.* stored [$TEST/.roh.git/sub-directory with spaces/omn.txt.sha256] -- identical file.* for computed [$TEST/sub-directory with spaces/dup.txt][20562d3970dd399e658eaca0a7a6ff1bacd9cd4fbb67328b6cd805dc3c2ce1b1].*ERROR: [$TEST/sub-directory with spaces] \"dup.txt\" -- could not recover hash for file [$TEST/sub-directory with spaces/dup.txt][20562d3970dd399e658eaca0a7a6ff1bacd9cd4fbb67328b6cd805dc3c2ce1b1]")"
rm "$TEST/$SUBDIR_WITH_SPACES/dup.txt"

mv "$TEST/$SUBDIR_WITH_SPACES/omn.txt" "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/OMG.txt"
run_test "$ROH_SCRIPT -r $TEST" "0" "$(escape_expected "Recovered: [$TEST/sub-directory with spaces/sub-sub-directory] \"OMG.txt\" -- hash in [$TEST/.roh.git/sub-directory with spaces/omn.txt.sha256][20562d3970dd399e658eaca0a7a6ff1bacd9cd4fbb67328b6cd805dc3c2ce1b1].* restored for [$TEST/sub-directory with spaces/sub-sub-directory/OMG.txt].* in [$TEST/.roh.git/sub-directory with spaces/sub-sub-directory/OMG.txt.sha256]")" 
run_test "$ROH_SCRIPT -v $TEST" "0" "$(escape_expected "ERROR")" "true"

#rm "$ROH_DIR/$SUBDIR_WITH_SPACES/omn.txt.$HASH"
#mv "$TEST/directory with spaces/abc.txt" "$TEST/directory with spaces/zyxw.txt"
mv "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/OMG.txt" "$TEST/$SUBDIR_WITH_SPACES/omn.txt"
echo "OMN-D" > "$TEST/$SUBDIR_WITH_SPACES/omn.txt"
run_test "$ROH_SCRIPT -r $TEST" "1" "$(escape_expected "ERROR: [$TEST/sub-directory with spaces] \"omn.txt\" -- could not recover hash for file [$TEST/sub-directory with spaces/omn.txt][697359ec47aef76de9a0b5001e47d7b7e93021ed8f0100e1e7e739ccdf0a5f8e]")" 
rm "$ROH_DIR/$SUBDIR_WITH_SPACES/$SUBSUBDIR/OMG.txt.$HASH"
$ROH_SCRIPT -w "$TEST" >/dev/null 2>&1

# manage_hash_visibility
echo
echo "# manage_hash_visibility()"

$ROH_SCRIPT -s "$TEST" >/dev/null 2>&1
run_test "$ROH_SCRIPT -v $TEST" "1" "$(escape_expected "ERROR:.* -- hash file [.*] exists/(NOT hidden)")"
$ROH_SCRIPT -i "$TEST" >/dev/null 2>&1

# cp "$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256" 
# run_test "$ROH_SCRIPT -s $TEST" "1" "$(escape_expected "ERROR: [$TEST] \"file with spaces.txt\" -- hash mismatch:.* [$TEST/file with spaces.txt.sha256][8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69] exists/(shown), not moving/(not shown)")"
# $ROH_SCRIPT -i "$TEST" >/dev/null 2>&1
# rm "$TEST/file with spaces.txt.sha256"

run_test "$ROH_SCRIPT -s $TEST" "0" "$(escape_expected "File: [$TEST] \"file with spaces.txt\" -- hash file [$TEST/file with spaces.txt.sha256] moved(shown) -- OK")"
$ROH_SCRIPT -i "$TEST" >/dev/null 2>&1

# mv "$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256"
# run_test "$ROH_SCRIPT -s $TEST" "0" "$(escape_expected "File: [$TEST] \"file with spaces.txt\" -- hash file [$TEST/file with spaces.txt.sha256] exists(shown), NOT moving/(NOT shown) -- OK")"

rm "$ROH_DIR/file with spaces.txt.sha256"
# rm "$TEST/file with spaces.txt.sha256"
run_test "$ROH_SCRIPT -s $TEST" "1" "$(escape_expected "ERROR: [$TEST] \"file with spaces.txt\" -- NO hash file found [$TEST/.roh.git/file with spaces.txt.sha256] for [$TEST/file with spaces.txt], not shown")"
$ROH_SCRIPT -i "$TEST" >/dev/null 2>&1
$ROH_SCRIPT -w "$TEST" >/dev/null 2>&1

# process_directory()
echo
echo "# process_directory()"

touch "$TEST/file with spaces.rslsz"
run_test "$ROH_SCRIPT -w $TEST" "1" "$(escape_expected "ERROR: [$TEST] \"file with spaces.rslsz\" -- file with restricted extension")"

run_test "$ROH_SCRIPT -d $TEST" "0" "$(escape_expected "ERROR: [$TEST] \"file with spaces.rslsz\" -- file with restricted extension")" "true"
rm "$TEST/file with spaces.rslsz"
 
#	mkdir -p "$ROH_DIR"
#	touch "$ROH_DIR/file with spaces.txt.sha256~"
#	run_test "$ROH_SCRIPT -d $TEST" "1" "Directory [test/$ROH_DIR] not empty" 
	
#	rm "$ROH_DIR/file with spaces.txt.sha256~"
#	run_test "$ROH_SCRIPT -d $TEST" "0" "Directory [test/$ROH_DIR] not empty" "true"

# Parse command line options
echo
echo "# Parse command line options"

run_test "$ROH_SCRIPT -vw" "1" "ERROR: options -v, -w, -d, -i, -s and -r are mutually exclusive. Please use only one."
run_test "$ROH_SCRIPT -vd" "1" "ERROR: options -v, -w, -d, -i, -s and -r are mutually exclusive. Please use only one."
run_test "$ROH_SCRIPT -vi" "1" "ERROR: options -v, -w, -d, -i, -s and -r are mutually exclusive. Please use only one."
run_test "$ROH_SCRIPT -vs" "1" "ERROR: options -v, -w, -d, -i, -s and -r are mutually exclusive. Please use only one."
run_test "$ROH_SCRIPT -vr" "1" "ERROR: options -v, -w, -d, -i, -s and -r are mutually exclusive. Please use only one."
run_test "$ROH_SCRIPT -wd" "1" "ERROR: options -v, -w, -d, -i, -s and -r are mutually exclusive. Please use only one."
run_test "$ROH_SCRIPT -wi" "1" "ERROR: options -v, -w, -d, -i, -s and -r are mutually exclusive. Please use only one."
run_test "$ROH_SCRIPT -ws" "1" "ERROR: options -v, -w, -d, -i, -s and -r are mutually exclusive. Please use only one."
run_test "$ROH_SCRIPT -wr" "1" "ERROR: options -v, -w, -d, -i, -s and -r are mutually exclusive. Please use only one."
run_test "$ROH_SCRIPT -di" "1" "ERROR: options -v, -w, -d, -i, -s and -r are mutually exclusive. Please use only one."
run_test "$ROH_SCRIPT -ds" "1" "ERROR: options -v, -w, -d, -i, -s and -r are mutually exclusive. Please use only one."
run_test "$ROH_SCRIPT -dr" "1" "ERROR: options -v, -w, -d, -i, -s and -r are mutually exclusive. Please use only one."
run_test "$ROH_SCRIPT -is" "1" "ERROR: options -v, -w, -d, -i, -s and -r are mutually exclusive. Please use only one."
run_test "$ROH_SCRIPT -ir" "1" "ERROR: options -v, -w, -d, -i, -s and -r are mutually exclusive. Please use only one."
run_test "$ROH_SCRIPT -sr" "1" "ERROR: options -v, -w, -d, -i, -s and -r are mutually exclusive. Please use only one."

run_test "$ROH_SCRIPT -vh" "0" "Usage: readonlyhash"
run_test "$ROH_SCRIPT -wh" "0" "Usage: readonlyhash"
run_test "$ROH_SCRIPT -dh" "0" "Usage: readonlyhash"
run_test "$ROH_SCRIPT -ih" "0" "Usage: readonlyhash"
run_test "$ROH_SCRIPT -sh" "0" "Usage: readonlyhash"
run_test "$ROH_SCRIPT -rh" "0" "Usage: readonlyhash"

run_test "$ROH_SCRIPT -v --roh-dir DOES_NOT_EXIST" "1" "$(escape_expected "Using ROH_DIR [DOES_NOT_EXIST]")"

run_test "$ROH_SCRIPT -v --force" "1" "ERROR: --force can only be used with -d/--delete or -w/--write."
run_test "$ROH_SCRIPT --force -i" "1" "ERROR: --force can only be used with -d/--delete or -w/--write."
run_test "$ROH_SCRIPT --force -s" "1" "ERROR: --force can only be used with -d/--delete or -w/--write."
run_test "$ROH_SCRIPT --force -r" "1" "ERROR: --force can only be used with -d/--delete or -w/--write."
run_test "$ROH_SCRIPT -h --force" "0" "Usage: readonlyhash"

run_test "$ROH_SCRIPT -v SPECIFYING_A_DIR_THAT_SHOULD_NOT_EXIST" "1" "$(escape_expected "ERROR: Directory [SPECIFYING_A_DIR_THAT_SHOULD_NOT_EXIST] does not exist")"

# Clean up test files
echo
echo "# Clean up test files"

$ROH_SCRIPT -d "$TEST" >/dev/null 2>&1

find "$TEST" -name '.DS_Store' -type f -delete
rm -rf "$ROH_DIR/.git"
rmdir "$ROH_DIR"

rm "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/jkl.txt"
rmdir "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR"
rm "$TEST/$SUBDIR_WITH_SPACES/omn.txt"
rmdir "$TEST/$SUBDIR_WITH_SPACES"
rm "$TEST/file with spaces.txt"
rmdir "$TEST"

run_test "ls -alR $TEST" "1" "$(escape_expected "ls: $TEST: No such file or directory")"

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Requirements
echo
echo "# Requirements"

TEST="test.ro"
SUBDIR="subdir"
rm -rf "$TEST"
mkdir "$TEST"

pushd "$TEST" >/dev/null 2>&1

ROH_DIR="./.roh.git"
mkdir -p "$ROH_DIR"
ROH_SCRIPT="../readonlyhash.sh"

$GIT_BIN init >/dev/null 2>&1
run_test "ls -al $ROH_DIR" "0" "drwxr-xr-x.* .git"

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
$GIT_BIN add *.sha256 >/dev/null 2>&1
$GIT_BIN commit -m "File Added" >/dev/null 2>&1
echo "four" > "four.txt"
# roh will report files that don't have a corresponding hash file
run_test "$ROH_SCRIPT -v" "1" "$(escape_expected "WARN: [.] \"four.txt\" --.* hash file [./.roh.git/four.txt.sha256] -- NOT found.* for [./four.txt][ab929fcd5594037960792ea0b98caf5fdaf6b60645e4ef248c28db74260f393e]")"

$ROH_SCRIPT -w >/dev/null 2>&1
# git will show hashes that are untracked
run_test "$GIT_BIN status" "0" "four.txt.sha256"

# File Modified 
echo
echo "# File Modified: Content of a file is altered, which updates the file's last modified timestamp"

echo "six" > "two.txt"
run_test "$ROH_SCRIPT -v" "1" "$(escape_expected "ERROR: [.] \"two.txt\" -- hash mismatch:.* stored [27dd8ed44a83ff94d557f9fd0412ed5a8cbca69ea04922d88c01184a07300a5a]: [$ROH_DIR/two.txt.sha256].* computed [fe2547fe2604b445e70fc9d819062960552f9145bdb043b51986e478a4806a2b]: [./two.txt]")"
echo "two" > "two.txt"

# File Removed 
echo
echo "# File Removed: A file is deleted from the directory"

rm "four.txt"
run_test "$ROH_SCRIPT -v" "1" "$(escape_expected "ERROR: --.* file [./four.txt] -- NOT found.* for corresponding hash [./.roh.git/four.txt.sha256][ab929fcd5594037960792ea0b98caf5fdaf6b60645e4ef248c28db74260f393e]")"

# remove orphaned hashes (in bulk)
run_test "$ROH_SCRIPT -s" "1" "$(escape_expected "ERROR: --.*file [./four.txt] -- NOT found.* for corresponding hash [./.roh.git/four.txt.sha256][ab929fcd5594037960792ea0b98caf5fdaf6b60645e4ef248c28db74260f393e]")"
# it should be safe to remove the hashes (!NOT the ROH_DIR!), because hashes have been moved next to files, but we don't want to kill the git repo
run_test "rm -v $ROH_DIR/*.sha256" "0" ".roh.git/four.txt.sha256"
run_test "$ROH_SCRIPT -i" "0" "$(escape_expected "ERROR:.* NO file.* found for corresponding hash")" "true"

# File Renamed 
echo
echo "# File Renamed: The name of a file is changed"
# File Moved 
echo "# File Moved: A file is moved either within the directory or outside of it"

mv "five.txt" "seven.txt"
run_test "$ROH_SCRIPT -v" "1" "$(escape_expected "WARN: [.] \"seven.txt\" --.* hash file [./.roh.git/seven.txt.sha256] -- NOT found.* for [./seven.txt][ac169f9fb7cb48d431466d7b3bf2dc3e1d2e7ad6630f6b767a1ac1801c496b35].*ERROR: --.* file [./five.txt] -- NOT found.* for corresponding hash [./.roh.git/five.txt.sha256][ac169f9fb7cb48d431466d7b3bf2dc3e1d2e7ad6630f6b767a1ac1801c496b35]")"
run_test "$ROH_SCRIPT -r" "0" "$(escape_expected "Recovered: [.] \"seven.txt\" -- hash in [./.roh.git/five.txt.sha256][ac169f9fb7cb48d431466d7b3bf2dc3e1d2e7ad6630f6b767a1ac1801c496b35].* restored for [./seven.txt].* in [./.roh.git/seven.txt.sha256]")"

# File Permissions Changed: The permissions (read, write, execute) of a file are modified.
echo
echo "#File Permissions Changed: The permissions (read, write, execute) of a file are modified"

chmod 777 "seven.txt"
run_test "ls -al" "0" "$(escape_expected "-rwxrwxrwx   1 dev  staff.*seven.txt")"
run_test "$ROH_SCRIPT -v" "0" "$(escape_expected "Number of ERRORs encountered:")" "true"

chmod 000 "seven.txt"
run_test "ls -al" "0" "$(escape_expected "----------   1 dev  staff.*seven.txt")"
run_test "$ROH_SCRIPT -v" "1" "$(escape_expected "ERROR: -- file [./seven.txt] not readable or permission denied")"

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

# we don't care about empty directories (but, we DO care if files are added to empty directories)
mkdir "$SUBDIR/this_does_not_exist"
echo "this_does" > "$SUBDIR/this_does_not_exist/this_does.txt"
run_test "$ROH_SCRIPT -v" "1" "$(escape_expected "WARN: [./subdir/this_does_not_exist] \"this_does.txt\" --.* hash file [./.roh.git/subdir/this_does_not_exist/this_does.txt.sha256] -- NOT found.* for [./subdir/this_does_not_exist/this_does.txt][65cb0ca932c81498259bb87f57c982cef5df83a8b8faf169121b7df3af40b477]")"
$ROH_SCRIPT -w >/dev/null 2>&1

# Subdirectory Removed
echo
echo "# Subdirectory Removed: An existing subdirectory is deleted"

# we don't care about empty directories (being removed)
mkdir "$SUBDIR/this_does_not_exist_either"
run_test "$ROH_SCRIPT -w" "0" "$(escape_expected "[./subdir/this_does_not_exist_either]")" "true"
rmdir "$SUBDIR/this_does_not_exist_either"
run_test "$ROH_SCRIPT -v" "0" "$(escape_expected "[./subdir/this_does_not_exist_either]")" "true"

# we don't care about empty directories (but, we DO care if files are removed along with directories)
run_test "$ROH_SCRIPT -v" "0" "$(escape_expected "ERROR")" "true"
rm -rf "$SUBDIR/this_does_not_exist"
run_test "$ROH_SCRIPT -v" "1" "$(escape_expected "ERROR: --.* file [./subdir/this_does_not_exist/this_does.txt] -- NOT found.* for corresponding hash [./.roh.git/subdir/this_does_not_exist/this_does.txt.sha256][65cb0ca932c81498259bb87f57c982cef5df83a8b8faf169121b7df3af40b477]")"
rm "$ROH_DIR/$SUBDIR/this_does_not_exist/this_does.txt.sha256"

# Subdirectory Renamed
echo
echo "# Subdirectory Renamed: The name of a subdirectory is changed."
# Subdirectory Moved
echo "# Subdirectory Moved: A subdirectory is moved either within the directory or outside of it."

run_test "$ROH_SCRIPT -v" "0" "$(escape_expected "ERROR")" "true"
mkdir "$SUBDIR/this_does_not_exist"
echo "this_does" > "$SUBDIR/this_does_not_exist/this_does.txt"
echo "and_so_does_this" > "$SUBDIR/this_does_not_exist/and_so_does_this.txt"
$ROH_SCRIPT -w >/dev/null 2>&1
mv "$SUBDIR/this_does_not_exist" "$SUBDIR/ok_it_does_exist"

#$ROH_SCRIPT -v
run_test "$ROH_SCRIPT -r" "0" "$(escape_expected "Recovered: [./subdir/ok_it_does_exist] \"and_so_does_this.txt\" -- hash in [./.roh.git/subdir/this_does_not_exist/and_so_does_this.txt.sha256][e5f9ed562b3724db0a83e7797d00492c83594548c5fe8e0a5c885e2bd2ac081d].* restored for [./subdir/ok_it_does_exist/and_so_does_this.txt].* in [./.roh.git/subdir/ok_it_does_exist/and_so_does_this.txt.sha256].*Recovered: [./subdir/ok_it_does_exist] \"this_does.txt\" -- hash in [./.roh.git/subdir/this_does_not_exist/this_does.txt.sha256][65cb0ca932c81498259bb87f57c982cef5df83a8b8faf169121b7df3af40b477].* restored for [./subdir/ok_it_does_exist/this_does.txt].* in [./.roh.git/subdir/ok_it_does_exist/this_does.txt.sha256]")"
run_test "$ROH_SCRIPT -v" "0" "$(escape_expected "ERROR")" "true"
rm "$ROH_DIR/$SUBDIR/ok_it_does_exist/this_does.txt.$HASH"
rm "$ROH_DIR/$SUBDIR/ok_it_does_exist/and_so_does_this.txt.$HASH"
rm -rf "$SUBDIR/ok_it_does_exist"

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

$ROH_SCRIPT -d >/dev/null 2>&1

find . -name '.DS_Store' -type f -delete

rm "$SUBDIR/ten.txt"
rm "$SUBDIR/eleven.txt"
rm "$SUBDIR/[23].txt"
rmdir $SUBDIR
rm "one.txt"
rm "two.txt"
rm "seven.txt"

rm -rf "$ROH_DIR/.git"
rmdir "$ROH_DIR"

popd >/dev/null 2>&1

rmdir "$TEST"

run_test "ls -alR $TEST" "1" "$(escape_expected "ls: $TEST: No such file or directory")"

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Path to the hash script
LOOP_SCRIPT="./loop-ro.sh"
chmod +x $LOOP_SCRIPT
fpath="Fotos.loop.txt"
fpath_ro="Fotos~.loop.txt"

ROH_GIT=".roh.git"

# Loop script 
echo
echo "# Loop script"

mv "/Users/dev/Project-@knev/readonlyhash.sh.git/2002.ro" "/Users/dev/Project-@knev/readonlyhash.sh.git/2002" >/dev/null 2>&1
mv "/Users/dev/Project-@knev/readonlyhash.sh.git/Fotos [space]/1999.ro" "/Users/dev/Project-@knev/readonlyhash.sh.git/Fotos [space]/1999" >/dev/null 2>&1

rm "/Users/dev/Project-@knev/readonlyhash.sh.git/2002"/_${ROH_GIT}.zip >/dev/null 2>&1
rm "/Users/dev/Project-@knev/readonlyhash.sh.git/Fotos [space]/1999"/_${ROH_GIT}.zip >/dev/null 2>&1

rm -rf "/Users/dev/Project-@knev/readonlyhash.sh.git/2002"/$ROH_GIT >/dev/null 2>&1
rm -rf "/Users/dev/Project-@knev/readonlyhash.sh.git/Fotos [space]/1999"/$ROH_GIT >/dev/null 2>&1
# rm -rf "/Users/dev/Project-@knev/readonlyhash.sh.git/Fotos [space]/2003"/$ROH_GIT

echo "/Users/dev/Project-@knev/readonlyhash.sh.git/Fotos/2003" > "$fpath"

run_test "$LOOP_SCRIPT init $fpath" "1" "$(escape_expected "ERROR: Directory [/Users/dev/Project-@knev/readonlyhash.sh.git/Fotos/2003] does not exist.")"
echo "/Users/dev/Project-@knev/readonlyhash.sh.git/Fotos [space]/1999" > "$fpath"
echo "/Users/dev/Project-@knev/readonlyhash.sh.git/2002" >> "$fpath"
#echo "/Users/dev/Project-@knev/readonlyhash.sh.git/Fotos [space]/2003" >> "$fpath"

#run_test "$LOOP_SCRIPT init $fpath" "1" "$(escape_expected "")"
$LOOP_SCRIPT init $fpath
#TODO test that the zip is there
#TODO test that git completed complete and the directory is clean

echo "0000000000000000000000000000000000000000000000000000000000000000" > "2002.ro/$ROH_GIT/2002_FIRE!/Untitled-001.jpg.$HASH"
run_test "$LOOP_SCRIPT verify $fpath_ro" "1" "$(escape_expected "\"Untitled-001.jpg\" -- hash mismatch:.* stored [0000000000000000000000000000000000000000000000000000000000000000]")"
echo "816d2fd63482855aaadd92294ef84c4a415945df194734c8834e06dd57538dc4" > "2002.ro/$ROH_GIT/2002_FIRE!/Untitled-001.jpg.$HASH"


$LOOP_SCRIPT verify $fpath_ro

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

echo "Done."
echo



