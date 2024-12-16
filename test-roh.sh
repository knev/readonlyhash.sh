#!/bin/bash

# This is a basic unit test script for the hash management script

# Path to the hash script
ROH_SCRIPT="./readonlyhash.sh"
chmod +x $ROH_SCRIPT

# Helper function to run commands and check their output
run_test() {
    local cmd="$1"
    local expected="$2"
    local output=$(eval "$cmd" 2>&1)
    
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
}

ROH_DIR=".roh"
TEST="test"
rm -rf test

# write_hash()
mkdir -p "$TEST"
echo "ABC" > "$TEST/file with spaces.txt"
run_test "$ROH_SCRIPT -w test" "File: [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]: [$TEST] file with spaces.txt -- OK"
run_test "$ROH_SCRIPT -w test" "ASASDF"

mv "$TEST/$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256" 
run_test "$ROH_SCRIPT -w test" "ERROR: [test] file with spaces.txt -- hash file [test/file with spaces.txt.sha256] exists and is NOT hidden"

mv "$TEST/file with spaces.txt.sha256" "$TEST/$ROH_DIR/file with spaces.txt.sha256" 
echo "ZYXW" > "$TEST/file with spaces.txt"
run_test "$ROH_SCRIPT -w test" "ERROR: [test] file with spaces.txt -- hash mismatch, [test/.roh/file with spaces.txt.sha256] exists with stored [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]"

run_test "$ROH_SCRIPT -w --force test" "File: [test] file with spaces.txt -- hash mismatch, [test/.roh/file with spaces.txt.sha256] exists; new hash stored [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff] -- FORCED!"

#  # Test hash()
#  run_test "$ROH_SCRIPT hash test_file.txt" "098f6bcd4621d373cade4e832627b4f6"
#  
#  # Test stored_hash()
#  echo "test_hash" > .roh/test_file.txt.sha256
#  run_test "$ROH_SCRIPT stored_hash test_file.txt" "test_hash"
#  
#  # Test generate_hash (write mode)
#  rm -rf .roh
#  mkdir .roh
#  run_test "$ROH_SCRIPT -w test_file.txt" "hash written: [098f6bcd4621d373cade4e832627b4f6]"
#  
#  # Test delete_hash
#  run_test "$ROH_SCRIPT -d . test_file.txt" "hash deleted: [./.roh/test_file.txt.sha256] -- OK"
#  run_test "$ROH_SCRIPT -d . test_file.txt" "NO hash file found in"
#  
#  # Test manage_hash_visibility (show)
#  echo "test_hash" > .roh/test_file.txt.sha256
#  run_test "$ROH_SCRIPT -s test_file.txt" "Hash shown"
#  
#  # Test manage_hash_visibility (hide)
#  mv test_file.txt.sha256 .roh/test_file.txt.sha256
#  run_test "$ROH_SCRIPT -i test_file.txt" "Hash hided"
#  
#  # Test compare_hash (verify mode)
#  echo "098f6bcd4621d373cade4e832627b4f6" > .roh/test_file.txt.sha256
#  run_test "$ROH_SCRIPT -v test_file.txt" "Hash matches: 098f6bcd4621d373cade4e832627b4f6"
#  
#  # Test check_extension with .roh-restricted
#  echo "test_file.txt" > .roh-restricted
#  run_test "$ROH_SCRIPT check_extension test_file.txt" "0"  # 0 means restricted
#  run_test "$ROH_SCRIPT check_extension other_file.txt" "1"  # 1 means not restricted
#  
#  # Test check_ignore with .roh-ignore
#  echo "test_file.txt" > .roh-ignore
#  run_test "$ROH_SCRIPT check_ignore test_file.txt" "0"  # 0 means ignored
#  run_test "$ROH_SCRIPT check_ignore other_file.txt" "1"  # 1 means not ignored
#  
#  # Clean up test files
#  rm -f test_file.txt .roh/test_file.txt.sha256 test_file.txt.sha256 .roh-restricted .roh-ignore
#  rmdir .roh

echo
