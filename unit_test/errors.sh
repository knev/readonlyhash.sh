#! /bin/echo Please-source

ROH_SCRIPT="./roh.fpath.sh"
chmod +x $ROH_SCRIPT
GIT_BIN="roh.git"

HASH="sha256"

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Parse command line options
echo
echo "# Parse command line options"

run_test "$ROH_SCRIPT" "1" "Usage: roh.fpath.sh"
run_test "$ROH_SCRIPT shablam" "1" "$(escape_expected "ERROR: unknown command: [shablam]")"
run_test "$ROH_SCRIPT -h" "0" "Usage: roh.fpath.sh"
run_test "$ROH_SCRIPT write --gobbligook" "1" "$(escape_expected "ERROR: invalid option: [--gobbligook]")"
run_test "$ROH_SCRIPT write -g" "1" "$(escape_expected "ERROR: invalid option: [-]")" #TODO: should print [-g]

run_test "$ROH_SCRIPT verify --roh-dir DOES_NOT_EXIST" "1" "$(escape_expected "Using ROH_DIR [DOES_NOT_EXIST]")"

# run_test "$ROH_SCRIPT -v --force" "1" "ERROR: --force can only be used with -d/--delete or -w/--write."
# run_test "$ROH_SCRIPT --force -i" "1" "ERROR: --force can only be used with -d/--delete or -w/--write."
# run_test "$ROH_SCRIPT --force -s" "1" "ERROR: --force can only be used with -d/--delete or -w/--write."
# run_test "$ROH_SCRIPT --force -r" "1" "ERROR: --force can only be used with -d/--delete or -w/--write."
# run_test "$ROH_SCRIPT -h --force" "0" "Usage: readonlyhash"

run_test "$ROH_SCRIPT verify SPECIFYING_A_DIR_THAT_SHOULD_NOT_EXIST" "1" "$(escape_expected "ERROR: Directory [SPECIFYING_A_DIR_THAT_SHOULD_NOT_EXIST] does not exist")"

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

TEST="test"
ROH_DIR="$TEST/.roh.git"
SUBDIR_WITH_SPACES="sub-directory with spaces"
SUBSUBDIR="sub-sub-directory"
rm -rf "$TEST"

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

# Weird b3-Excito cyclic symlink
pushd "$TEST" >/dev/null 2>&1
ln -s . X11
popd >/dev/null 2>&1
run_test "$ROH_SCRIPT write $TEST" "0" "$(escape_expected "WARN: Avoiding symlink [test/X11] like the Plague")"
rm "$TEST/X11"

echo "c5a8fb450fb0b568fc69a9485b8e531f119ca6e112fe1015d03fceb64b9c0e65" > "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/jkl.txt.$HASH"
run_test "$ROH_SCRIPT write $TEST" "1" "$(escape_expected "ERROR: [$TEST/sub-directory with spaces/sub-sub-directory] \"jkl.txt\" -- hash file [$TEST/sub-directory with spaces/sub-sub-directory/jkl.txt.sha256] exists/(NOT hidden)")"
rm "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/jkl.txt.$HASH"

run_test "$ROH_SCRIPT write $TEST" "0" "$(escape_expected "File: [20562d3970dd399e658eaca0a7a6ff1bacd9cd4fbb67328b6cd805dc3c2ce1b1]: [test/sub-directory with spaces] \"omn.txt\" -- OK")" "true"

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
run_test "$ROH_SCRIPT write $TEST" "0" "$(escape_expected "File: [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff]: [$TEST] \"file with spaces.txt\" -- OK")"

rm "$ROH_DIR/file with spaces.txt.$HASH" 
chmod 000 "$ROH_DIR"
run_test "$ROH_SCRIPT write $TEST" "1" "$(escape_expected "ERROR: [$TEST] \"file with spaces.txt\" -- failed to write hash to [$ROH_DIR/file with spaces.txt.sha256]")"
chmod 700 "$ROH_DIR"
$ROH_SCRIPT write "$TEST" >/dev/null 2>&1

run_test "$ROH_SCRIPT write $TEST" "0" "$(escape_expected "File: ")" "true"

# delete_hash()
echo
echo "# delete_hash()"

mv "$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256" 
run_test "$ROH_SCRIPT delete $TEST" "1" "$(escape_expected "ERROR: [$TEST] \"file with spaces.txt\" -- hash file [$TEST/file with spaces.txt.sha256] exists/(NOT hidden); can only delete hidden hashes")"

mkdir "$ROH_DIR"
mv "$TEST/file with spaces.txt.sha256" "$ROH_DIR/file with spaces.txt.sha256" 
echo "ABC" > "$TEST/file with spaces.txt"
run_test "$ROH_SCRIPT delete $TEST" "1" "$(escape_expected "ERROR: [$TEST] \"file with spaces.txt\" -- hash mismatch, cannot delete [$ROH_DIR/file with spaces.txt.sha256] with stored [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff]")"

run_test "$ROH_SCRIPT delete --force $TEST" "0" "$(escape_expected "File: [$TEST] \"file with spaces.txt\" -- hash mismatch, [$ROH_DIR/file with spaces.txt.sha256] deleted with stored [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff] -- FORCED!")"

echo "ZYXW" > "$TEST/file with spaces.txt"
$ROH_SCRIPT write "$TEST" >/dev/null 2>&1
run_test "$ROH_SCRIPT delete $TEST" "0" "$(escape_expected "File: [$TEST] \"file with spaces.txt\" -- hash file in [$ROH_DIR] deleted -- OK")"
echo "ABC" > "$TEST/file with spaces.txt"

run_test "$ROH_SCRIPT delete $TEST" "0" "$(escape_expected "File: ")" "true"
$ROH_SCRIPT write "$TEST" >/dev/null 2>&1

# verify_hash
echo
echo "# verify_hash()"

mkdir "$TEST-empty"
# we don't care about empty directories
run_test "$ROH_SCRIPT verify $TEST-empty" "1" "$(escape_expected "ERROR: [$TEST-empty] -- missing [$TEST-empty/.roh.git]. Aborting.")"
# run_test "$ROH_SCRIPT -v $TEST-empty" "0" "$(escape_expected "Processing directory: [test-empty]")"
# run_test "$ROH_SCRIPT -v $TEST-empty" "0" "$(escape_expected "Done.")"
rm -rf "$TEST-empty"

echo "8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69" > "$TEST/file with spaces.txt.$HASH"
run_test "$ROH_SCRIPT verify $TEST" "1" "$(escape_expected "ERROR: [$TEST] \"file with spaces.txt\" -- hash file [$TEST/file with spaces.txt.sha256] exists/(NOT hidden)")"
# see also first test in manage_hash_visibility: ERROR:.* -- hash file [.*] exists/(NOT hidden)
rm "$TEST/file with spaces.txt.$HASH"

rm "$ROH_DIR/file with spaces.txt.$HASH"
run_test "$ROH_SCRIPT verify $TEST" "1" "$(escape_expected "WARN: [$TEST] \"file with spaces.txt\" --.* hash file [$TEST/.roh.git/file with spaces.txt.sha256] -- NOT found.* for [$TEST/file with spaces.txt][8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]")"

$ROH_SCRIPT write "$TEST" >/dev/null 2>&1
run_test "$ROH_SCRIPT verify $TEST" "0" "$(escape_expected "File: [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]: [$TEST] \"file with spaces.txt\" -- [$TEST/file with spaces.txt] -- OK")"

echo "ZYXW" > "$TEST/file with spaces.txt"
run_test "$ROH_SCRIPT verify $TEST" "1" "$(escape_expected "ERROR: [$TEST] \"file with spaces.txt\" -- hash mismatch:.* stored [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]: [$ROH_DIR/file with spaces.txt.sha256].* computed [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff]: [$TEST/file with spaces.txt]")"
echo "ABC" > "$TEST/file with spaces.txt"

mkdir "$ROH_DIR/this_is_a_directory.sha256"
run_test "$ROH_SCRIPT verify $TEST" "0" "$(escape_expected "ERROR: [$TEST] -- NO file [.*] found for corresponding hash [$ROH_DIR/this_is_a_directory.sha256][.*]")" "true"
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
run_test "$ROH_SCRIPT verify $TEST" "0" ".DS_Store.$HASH" "true"

# test --roh-dir 
TMP="_tmp~"
rm -rf "$TMP"
# run_test "$ROH_SCRIPT -w $TEST" "0" "$(escape_expected "File: ")" 
mkdir "$TMP"
mv "$ROH_DIR" "$TMP"
run_test "$ROH_SCRIPT verify --roh-dir $TMP/.roh.git $TEST" "0" "$(escape_expected "ERROR: ")" "true"
mv "$TMP/.roh.git" "$TEST"
rmdir "$TMP"
run_test "$ROH_SCRIPT verify $TEST" "0" "$(escape_expected "ERROR: ")" "true"

# verify_hash, process_directory()
rm -v "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/jkl.txt"
run_test "$ROH_SCRIPT verify $TEST" "1" "$(escape_expected "ERROR: --.* file [$TEST/sub-directory with spaces/sub-sub-directory/jkl.txt] -- NOT found.* for corresponding hash [$TEST/.roh.git/sub-directory with spaces/sub-sub-directory/jkl.txt.sha256][c5a8fb450fb0b568fc69a9485b8e531f119ca6e112fe1015d03fceb64b9c0e65]")"
echo "JKL" > "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/jkl.txt"

# recover_hash
echo
echo "# recover_hash()"

cp "$TEST/$SUBDIR_WITH_SPACES/omn.txt" "$TEST/$SUBDIR_WITH_SPACES/dup.txt"
run_test "$ROH_SCRIPT recover $TEST" "1" "$(escape_expected "WARN: [$TEST/sub-directory with spaces] \"dup.txt\" --.* stored [$TEST/.roh.git/sub-directory with spaces/omn.txt.sha256] -- identical file.* for computed [$TEST/sub-directory with spaces/dup.txt][20562d3970dd399e658eaca0a7a6ff1bacd9cd4fbb67328b6cd805dc3c2ce1b1].*ERROR: [$TEST/sub-directory with spaces] \"dup.txt\" -- could not recover hash for file [$TEST/sub-directory with spaces/dup.txt][20562d3970dd399e658eaca0a7a6ff1bacd9cd4fbb67328b6cd805dc3c2ce1b1]")"
rm "$TEST/$SUBDIR_WITH_SPACES/dup.txt"

mv "$TEST/$SUBDIR_WITH_SPACES/omn.txt" "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/OMG.txt"
run_test "$ROH_SCRIPT recover $TEST" "0" "$(escape_expected "Recovered: [$TEST/sub-directory with spaces/sub-sub-directory] \"OMG.txt\" -- hash in [$TEST/.roh.git/sub-directory with spaces/omn.txt.sha256][20562d3970dd399e658eaca0a7a6ff1bacd9cd4fbb67328b6cd805dc3c2ce1b1].* restored for [$TEST/sub-directory with spaces/sub-sub-directory/OMG.txt].* in [$TEST/.roh.git/sub-directory with spaces/sub-sub-directory/OMG.txt.sha256]")" 
run_test "$ROH_SCRIPT verify $TEST" "0" "$(escape_expected "ERROR")" "true"

#rm "$ROH_DIR/$SUBDIR_WITH_SPACES/omn.txt.$HASH"
#mv "$TEST/directory with spaces/abc.txt" "$TEST/directory with spaces/zyxw.txt"
mv "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/OMG.txt" "$TEST/$SUBDIR_WITH_SPACES/omn.txt"
echo "OMN-D" > "$TEST/$SUBDIR_WITH_SPACES/omn.txt"
run_test "$ROH_SCRIPT recover $TEST" "1" "$(escape_expected "ERROR: [$TEST/sub-directory with spaces] \"omn.txt\" -- could not recover hash for file [$TEST/sub-directory with spaces/omn.txt][697359ec47aef76de9a0b5001e47d7b7e93021ed8f0100e1e7e739ccdf0a5f8e]")" 
rm "$ROH_DIR/$SUBDIR_WITH_SPACES/$SUBSUBDIR/OMG.txt.$HASH"
$ROH_SCRIPT write "$TEST" >/dev/null 2>&1

# manage_hash_visibility
echo
echo "# manage_hash_visibility()"

$ROH_SCRIPT show "$TEST" >/dev/null 2>&1
run_test "$ROH_SCRIPT verify $TEST" "1" "$(escape_expected "ERROR:.* -- hash file [.*] exists/(NOT hidden)")"
$ROH_SCRIPT hide "$TEST" >/dev/null 2>&1

# cp "$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256" 
# run_test "$ROH_SCRIPT -s $TEST" "1" "$(escape_expected "ERROR: [$TEST] \"file with spaces.txt\" -- hash mismatch:.* [$TEST/file with spaces.txt.sha256][8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69] exists/(shown), not moving/(not shown)")"
# $ROH_SCRIPT -i "$TEST" >/dev/null 2>&1
# rm "$TEST/file with spaces.txt.sha256"

run_test "$ROH_SCRIPT show $TEST" "0" "$(escape_expected "File: [$TEST] \"file with spaces.txt\" -- hash file [$TEST/file with spaces.txt.sha256] moved(shown) -- OK")"
$ROH_SCRIPT hide "$TEST" >/dev/null 2>&1

# mv "$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256"
# run_test "$ROH_SCRIPT -s $TEST" "0" "$(escape_expected "File: [$TEST] \"file with spaces.txt\" -- hash file [$TEST/file with spaces.txt.sha256] exists(shown), NOT moving/(NOT shown) -- OK")"

rm "$ROH_DIR/file with spaces.txt.sha256"
# rm "$TEST/file with spaces.txt.sha256"
run_test "$ROH_SCRIPT show $TEST" "1" "$(escape_expected "ERROR: [$TEST] \"file with spaces.txt\" -- NO hash file found [$TEST/.roh.git/file with spaces.txt.sha256] for [$TEST/file with spaces.txt], not shown")"
$ROH_SCRIPT hide "$TEST" >/dev/null 2>&1
$ROH_SCRIPT write "$TEST" >/dev/null 2>&1

# worst case
echo
echo "# worst case"

mv "$ROH_DIR/file with spaces.txt.$HASH" "$TEST/file with spaces.txt.$HASH" 
$ROH_SCRIPT hide "$TEST" >/dev/null 2>&1
run_test "$ROH_SCRIPT verify $TEST" "0" "$(escape_expected "ERROR: ")" "true"

# process_directory()
echo
echo "# process_directory()"

touch "$TEST/file with spaces.rslsz"
run_test "$ROH_SCRIPT write $TEST" "1" "$(escape_expected "ERROR: [$TEST] \"file with spaces.rslsz\" -- file with restricted extension")"

run_test "$ROH_SCRIPT delete $TEST" "0" "$(escape_expected "ERROR: [$TEST] \"file with spaces.rslsz\" -- file with restricted extension")" "true"
rm "$TEST/file with spaces.rslsz"
 
#	mkdir -p "$ROH_DIR"
#	touch "$ROH_DIR/file with spaces.txt.sha256~"
#	run_test "$ROH_SCRIPT -d $TEST" "1" "Directory [test/$ROH_DIR] not empty" 
	
#	rm "$ROH_DIR/file with spaces.txt.sha256~"
#	run_test "$ROH_SCRIPT -d $TEST" "0" "Directory [test/$ROH_DIR] not empty" "true"

# Clean up test files
echo
echo "# Clean up test files"

$ROH_SCRIPT delete "$TEST" >/dev/null 2>&1

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

