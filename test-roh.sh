#!/bin/bash

# This is a basic unit test script for the hash management script

# Path to the hash script
ROH_SCRIPT="./readonlyhash.sh"
chmod +x $ROH_SCRIPT

# Helper function to run commands and check their output
run_test() {
    local cmd="$1"
    local expected="$2"
    local not_flag="${3:-false}"  # Default not_flag to false if not provided
    local output=$(eval "$cmd" 2>&1)

    if [ "$not_flag" = "true" ]; then
        # Check if expected is NOT in output
        if [[ "$output" != *"$expected"* ]]; then
			echo "PASS: (NOT) $expected"
        else
			echo
			echo "FAIL: $cmd"
			echo "Expected to NOT contain: $expected"
			echo "----"
			echo "$output"
			echo "----"
        fi
    else
        # Check if expected is in output
        if [[ "$output" == *"$expected"* ]]; then
			echo "PASS: $expected"
        else
			echo
			echo "FAIL: $cmd"
			echo "Expected to contain: $expected"
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
run_test "$ROH_SCRIPT -w test" "File: [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]: [$TEST] file with spaces.txt -- OK"
run_test "$ROH_SCRIPT -w test" "File: " "true"

mv "$TEST/$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256" 
run_test "$ROH_SCRIPT -w test" "ERROR: [$TEST] file with spaces.txt -- hash file [$TEST/file with spaces.txt.sha256] exists and is NOT hidden"

mv "$TEST/file with spaces.txt.sha256" "$TEST/$ROH_DIR/file with spaces.txt.sha256" 
echo "ZYXW" > "$TEST/file with spaces.txt"
run_test "$ROH_SCRIPT -w test" "ERROR: [test] file with spaces.txt -- hash mismatch, [test/.roh/file with spaces.txt.sha256] exists with stored [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]"

chmod 000 "$TEST/$ROH_DIR/file with spaces.txt.sha256" 
run_test "$ROH_SCRIPT -w --force test" "ERROR: [test] file with spaces.txt -- failed to write hash to [test/.roh/file with spaces.txt.sha256] -- (FORCED)"

chmod 700 "$TEST/$ROH_DIR/file with spaces.txt.sha256" 
run_test "$ROH_SCRIPT -w --force test" "File: [test] file with spaces.txt -- hash mismatch, [test/.roh/file with spaces.txt.sha256] exists; new hash stored [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff] -- FORCED!"

# delete_hash()
echo
echo "delete_hash()"

mv "$TEST/$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256" 
run_test "$ROH_SCRIPT -d test" "ERROR: [test] file with spaces.txt -- found existing hash in [test]; can only delete hidden hashes"

mkdir -p "$TEST/$ROH_DIR"
mv "$TEST/file with spaces.txt.sha256" "$TEST/$ROH_DIR/file with spaces.txt.sha256" 
cp "$TEST/$ROH_DIR/file with spaces.txt.sha256" "$TEST/$ROH_DIR/file with spaces.txt.sha256~" 
echo "ABC" > "$TEST/file with spaces.txt"
run_test "$ROH_SCRIPT -d test" "ERROR: [test] file with spaces.txt -- hash mismatch, cannot delete [test/.roh/file with spaces.txt.sha256] with stored [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff]"

run_test "$ROH_SCRIPT -d --force test" "File: [test] file with spaces.txt -- hash mismatch, [test/.roh/file with spaces.txt.sha256] deleted with stored [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff] -- FORCED!"

mv "$TEST/$ROH_DIR/file with spaces.txt.sha256~" "$TEST/$ROH_DIR/file with spaces.txt.sha256" 
echo "ZYXW" > "$TEST/file with spaces.txt"
run_test "$ROH_SCRIPT -d test" "File: [test] file with spaces.txt -- hash file in [test/.roh] deleted -- OK"

run_test "$ROH_SCRIPT -d test" "File: " "true"

# verify_hash
echo
echo "verify_hash()"

run_test "$ROH_SCRIPT -v test" "ERROR: [test] file with spaces.txt -- no hash file exists in [test/.roh]"

$ROH_SCRIPT -w test >/dev/null 2>&1
run_test "$ROH_SCRIPT -v test" "File: [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff]: [test]  -- OK"

echo "ABC" > "$TEST/file with spaces.txt"
run_test "$ROH_SCRIPT -v test" "ERROR: [test] file with spaces.txt - hash mismatch: [test/.roh/file with spaces.txt.sha256] stored [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff], computed [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]"

# manage_hash_visibility
echo
echo "manage_hash_visibility()"

cp "$TEST/$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256" 
run_test "$ROH_SCRIPT -s test" "ERROR: [test] file with spaces.txt -- hash mismatch, [test/file with spaces.txt.sha256] exists with stored [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff], not moving (show)"

rm "$TEST/$ROH_DIR/file with spaces.txt.sha256"
echo "ZYXW" > "$TEST/file with spaces.txt"
run_test "$ROH_SCRIPT -s test" "File: [test] file with spaces.txt -- hash file [test/file with spaces.txt.sha256] exists, not moving (show) -- OK"

mv "$TEST/file with spaces.txt.sha256" "$TEST/$ROH_DIR/file with spaces.txt.sha256" 
run_test "$ROH_SCRIPT -s test" "File: [test] file with spaces.txt -- showing hash file [test/file with spaces.txt.sha256] -- OK"

rm "$TEST/file with spaces.txt.sha256"
run_test "$ROH_SCRIPT -s test" "ERROR: [test] file with spaces.txt -- NO hash file found in [test/.roh], not showing"

# process_directory()
echo
echo "process_directory()"

touch "$TEST/$ROH_DIR/file with spaces.txt.sha256~"
run_test "$ROH_SCRIPT -d test" "Directory [test/.roh] not empty" 

rm "$TEST/$ROH_DIR/file with spaces.txt.sha256~"
run_test "$ROH_SCRIPT -d test" "Directory [test/.roh] not empty" "true"


# Parse command line options
echo
echo "Parse command line options"

run_test "$ROH_SCRIPT -dw" "Usage: readonlyhash.sh"
run_test "$ROH_SCRIPT -v --force" "Usage: readonlyhash.sh"
run_test "$ROH_SCRIPT -v THIS_DIR_SHOULD_NOT_EXIST" "Error: Directory THIS_DIR_SHOULD_NOT_EXIST does not exist"


# Clean up test files
echo
echo "Clean up test files"

rm "$TEST/file with spaces.txt"
rmdir "$TEST"
#  rm -f test_file.txt .roh/test_file.txt.sha256 test_file.txt.sha256 .roh-restricted .roh-ignore
#  rmdir .roh

echo "Done."
echo
