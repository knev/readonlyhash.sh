#! /bin/echo Please-source

FPATH_BIN="./roh.fpath.sh"
chmod +x $FPATH_BIN
GIT_BIN="./roh.git.sh"
chmod +x $GIT_BIN

HASH="sha256"

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
echo "# unit_test: error.sh"

# Parse command line options
echo
echo "# Parse command line options"

run_test "$FPATH_BIN" "1" "Usage: roh.fpath.sh"
run_test "$FPATH_BIN shablam" "1" "$(escape_expected "ERROR: unknown command: [shablam]")"
run_test "$FPATH_BIN -h" "0" "Usage: roh.fpath.sh"
run_test "$FPATH_BIN write --gobbligook" "1" "$(escape_expected "ERROR: invalid option: [--gobbligook]")"
run_test "$FPATH_BIN write -g" "1" "$(escape_expected "ERROR: invalid option: [-]")" #TODO: should print [-g]

run_test "$FPATH_BIN verify --roh-dir DOES_NOT_EXIST DOES_NOT_EXIST" "1" "$(escape_expected "Using ROH_DIR [DOES_NOT_EXIST]")"

run_test "$FPATH_BIN verify --force" "1" "ERROR: --force can only be used with: write|show|hide."
# run_test "$FPATH_BIN --force -i" "1" "ERROR: --force can only be used with -d/--delete or -w/--write."
# run_test "$FPATH_BIN --force -s" "1" "ERROR: --force can only be used with -d/--delete or -w/--write."
# run_test "$FPATH_BIN --force -r" "1" "ERROR: --force can only be used with -d/--delete or -w/--write."
# run_test "$FPATH_BIN -h --force" "0" "Usage: readonlyhash"

run_test "$FPATH_BIN verify SPECIFYING_A_DIR_THAT_SHOULD_NOT_EXIST" "1" "$(escape_expected "ERROR: Directory [SPECIFYING_A_DIR_THAT_SHOULD_NOT_EXIST] does not exist")"

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
echo "PNO" > "$TEST/$SUBDIR_WITH_SPACES/pno.txt"
echo "OMN" > "$TEST/$SUBDIR_WITH_SPACES/omn.txt"
mkdir -p "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR"
echo "JKL" > "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/jkl.txt"

#	run_test "$FPATH_BIN -w $TEST" "0" "$(escape_expected "File: ")" 
#	$GIT_BIN -C "$TEST" init >/dev/null 2>&1
#	echo ".DS_Store" > "$TEST/.gitignore"
#	
#	TEST=$PWD/Fotos\ \[space\]/1999.ro
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

# --hash
echo
echo "# --hash"

run_test "$FPATH_BIN write --hash test/sub-directory\ with\ spaces/*" "0" "$(escape_expected "OK: [20562d3970dd399e658eaca0a7a6ff1bacd9cd4fbb67328b6cd805dc3c2ce1b1]: \"omn.txt\".*OK: [1656fd07685d515a7c4cae4e1cad7a99447d8db7aac1eb2814b2572df0e6181f]: \"pno.txt\".*WARN: [test/sub-directory with spaces/sub-sub-directory] not a file -- SKIPPING")"
run_test "ls -al test/sub-directory\ with\ spaces" "0" "$(escape_expected "omn.txt.sha256.*pno.txt.sha256")"

run_test "$FPATH_BIN verify --hash test/sub-directory\ with\ spaces/*" "0" "ERROR: " "true"
rm "$TEST/$SUBDIR_WITH_SPACES/pno.txt.$HASH"
rm "$TEST/$SUBDIR_WITH_SPACES/omn.txt.$HASH"

# write
echo
echo "# write"

# Weird b3-Excito cyclic symlink
pushd "$TEST" >/dev/null 2>&1
ln -s . X11
popd >/dev/null 2>&1
run_test "$FPATH_BIN write $TEST" "0" "$(escape_expected " WARN: Avoiding symlink [test/X11] like the plague")"
rm "$TEST/X11"

$FPATH_BIN write "$TEST" >/dev/null 2>&1
echo "0000000000000000000000000000000000000000000000000000000000000000" > "$ROH_DIR/file with spaces.txt.$HASH"
echo "0000000000000000000000000000000000000000000000000000000000000000" > "$TEST/file with spaces.txt.$HASH"
run_test "$FPATH_BIN write $TEST" "0" "$(escape_expected "WARN:.* stored [0000000000000000000000000000000000000000000000000000000000000000][$ROH_DIR/file with spaces.txt.sha256].*WARN:.* stored [0000000000000000000000000000000000000000000000000000000000000000][$TEST/file with spaces.txt.sha256]")"
run_test "$FPATH_BIN write --force $TEST" "0" "$(escape_expected "WARN:.* stored [0000000000000000000000000000000000000000000000000000000000000000][$ROH_DIR/file with spaces.txt.sha256] -- removed (FORCED)!.*WARN:.* stored [0000000000000000000000000000000000000000000000000000000000000000][$TEST/file with spaces.txt.sha256] -- removed (FORCED)!.*OK: [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]: [test/file with spaces.txt]")"

# exist-R=F         , exist-D=T (eq-D=T) // sh= F
# exist-R=F         , exist-D=F			 // sh= F
# exist-R=T (eq-R=T), exist-D=T (eq-D=T) // sh= F
# exist-R=T (eq-R=T), exist-D=F          // sh= F

mv "$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256" 
run_test "$FPATH_BIN write $TEST" "0" "$(escape_expected "OK: [test/file with spaces.txt] -- hash file [test/.roh.git/file with spaces.txt.sha256] -- moved(hidden)")"
run_test "ls -al $TEST/file\ with\ spaces.txt.sha256" "1" "$TEST/file with spaces.txt.sha256: No such file or directory"

rm "$ROH_DIR/file with spaces.txt.sha256"
run_test "$FPATH_BIN write $TEST" "0" "$(escape_expected " OK: [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]: [test/file with spaces.txt]")"

cp "$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256" 
run_test "$FPATH_BIN write $TEST" "1" "$(escape_expected "ERROR: [test/file with spaces.txt] -- not moving/(not hidden).* destination [test/.roh.git/file with spaces.txt.sha256] -- exists.* for source [test/file with spaces.txt.sha256]")"
run_test "$FPATH_BIN write --force $TEST" "0" "$(escape_expected "OK: [test/file with spaces.txt] -- hash file [test/.roh.git/file with spaces.txt.sha256] -- moved(hidden)")"
 
run_test "$FPATH_BIN write $TEST" "0" "$(escape_expected "ERROR: ")" "true"

# exist-R=F         , exist-D=T (eq-D=T) // sh= T
# exist-R=F         , exist-D=F			 // sh= T
# exist-R=T (eq-R=T), exist-D=T (eq-D=T) // sh= T
# exist-R=T (eq-R=T), exist-D=F          // sh= T

mv "$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256" 
run_test "$FPATH_BIN write --show $TEST" "0" "$(escape_expected "OK: [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]: [test] \"file with spaces.txt\"")" "true"
run_test "ls -al $ROH_DIR/file\ with\ spaces.txt.sha256" "1" "$ROH_DIR/file with spaces.txt.sha256: No such file or directory"

rm "$TEST/file with spaces.txt.sha256"
run_test "$FPATH_BIN write --show $TEST" "0" "$(escape_expected " OK: [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]: [test/file with spaces.txt]")"
run_test "ls -al $TEST/file\ with\ spaces.txt.sha256" "0" "$TEST/file with spaces.txt.sha256: No such file or directory" "true"

mkdir -p "$ROH_DIR"
cp "$TEST/file with spaces.txt.sha256" "$ROH_DIR/file with spaces.txt.sha256" 
run_test "$FPATH_BIN write --show $TEST" "1" "$(escape_expected "ERROR: [test/file with spaces.txt] -- not moving/(not shown).*destination [test/file with spaces.txt.sha256] -- exists.* for source [test/.roh.git/file with spaces.txt.sha256]")"
run_test "$FPATH_BIN write --show --force $TEST" "0" "$(escape_expected "OK: [test/file with spaces.txt] -- hash file [test/file with spaces.txt.sha256] -- moved(shown)")"
 
run_test "$FPATH_BIN write --show $TEST" "0" "$(escape_expected "ERROR: ")" "true"
run_test "ls -al $ROH_DIR" "1" "$ROH_DIR: No such file or directory"

run_test "$FPATH_BIN hide $TEST" "0" "$(escape_expected "ERROR: ")" "true"

# OLD write tests

echo "c5a8fb450fb0b568fc69a9485b8e531f119ca6e112fe1015d03fceb64b9c0e65" > "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/jkl.txt.$HASH"
run_test "$FPATH_BIN write $TEST" "1" "$(escape_expected "ERROR: [test/sub-directory with spaces/sub-sub-directory/jkl.txt] -- not moving/(not hidden).*destination [test/.roh.git/sub-directory with spaces/sub-sub-directory/jkl.txt.sha256] -- exists.*for source [test/sub-directory with spaces/sub-sub-directory/jkl.txt.sha256]")"
rm "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/jkl.txt.$HASH"

echo "ZYXW" > "$TEST/file with spaces.txt"
run_test "$FPATH_BIN write $TEST" "0" "$(escape_expected "WARN: -- hash mismatch:.* computed [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff][test/file with spaces.txt].*  stored [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69][test/.roh.git/file with spaces.txt.sha256]")"

rm "$ROH_DIR/file with spaces.txt.$HASH" 
run_test "$FPATH_BIN write $TEST" "0" "$(escape_expected "  OK: [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff]: [$TEST/file with spaces.txt]")"

rm "$ROH_DIR/file with spaces.txt.$HASH" 
chmod 000 "$ROH_DIR"
run_test "$FPATH_BIN write $TEST" "1" "$(escape_expected "ERROR: [$TEST/file with spaces.txt] -- failed to write hash to [$ROH_DIR/file with spaces.txt.sha256]")"
chmod 700 "$ROH_DIR"
$FPATH_BIN write "$TEST" >/dev/null 2>&1

run_test "$FPATH_BIN write $TEST" "0" "$(escape_expected "  OK: ")" "true"

mv "$TEST/$SUBDIR_WITH_SPACES/omn.txt" "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/OMG.txt"
run_test "$FPATH_BIN write $TEST" "0" "$(escape_expected "OK: -- orphaned hash [test/.roh.git/sub-directory with spaces/omn.txt.sha256][20562d3970dd399e658eaca0a7a6ff1bacd9cd4fbb67328b6cd805dc3c2ce1b1] -- removed")"
mv "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/OMG.txt" "$TEST/$SUBDIR_WITH_SPACES/omn.txt"
$FPATH_BIN recover "$TEST" >/dev/null 2>&1

# delete
echo
echo "# delete"

mv "$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256" 
run_test "$FPATH_BIN delete $TEST" "0" "$(escape_expected "  OK: [$TEST/file with spaces.txt] -- hash file [test/file with spaces.txt.sha256] -- deleted")"
run_test "ls -al test/$ROH_DIR" "1" "test/$ROH_DIR: No such file or directory"

$FPATH_BIN write "$TEST" >/dev/null 2>&1
run_test "$FPATH_BIN delete $TEST" "0" "$(escape_expected "  OK: [$TEST/file with spaces.txt] -- hash file [test/.roh.git/file with spaces.txt.sha256] -- deleted")"
run_test "ls -al test/$ROH_DIR" "1" "test/$ROH_DIR: No such file or directory"

run_test "$FPATH_BIN delete $TEST" "0" "$(escape_expected "  OK: ")" "true"
$FPATH_BIN write "$TEST" >/dev/null 2>&1

# verify
echo
echo "# verify"

mkdir "$TEST-empty"
# we don't care about empty directories
run_test "$FPATH_BIN verify $TEST-empty" "0" "$(escape_expected "Done.")"
rm -rf "$TEST-empty"

echo "8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69" > "$TEST/file with spaces.txt.$HASH"
run_test "$FPATH_BIN verify $TEST" "1" "$(escape_expected "ERROR: -- two hash files exist.* hidden [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff][test/.roh.git/file with spaces.txt.sha256].* shown [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69][test/file with spaces.txt.sha256].*computed [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff][test/file with spaces.txt]")"
# see also first test in manage_hash_visibility: ERROR:.* -- hash file [.*] exists/(NOT hidden)
rm "$TEST/file with spaces.txt.$HASH"

run_test "$FPATH_BIN verify $TEST" "0" "$(escape_expected "ERROR: ")" "true"

#echo "ABC" > "$TEST/file with spaces.txt"
#echo "ZYXW" > "$TEST/file with spaces.txt"

echo "8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69" > "$ROH_DIR/file with spaces.txt.$HASH"
run_test "$FPATH_BIN verify $TEST" "1" "$(escape_expected "ERROR: -- hash mismatch:.* stored [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69][$ROH_DIR/file with spaces.txt.sha256].* computed [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff][$TEST/file with spaces.txt]")"
echo "349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff" > "$ROH_DIR/file with spaces.txt.$HASH"

mv "$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256" 
run_test "$FPATH_BIN verify $TEST" "0" "$(escape_expected "WARN: hashes not exclusively hidden in [$ROH_DIR]")"
$FPATH_BIN write "$TEST" >/dev/null 2>&1

run_test "$FPATH_BIN verify $TEST" "0" "$(escape_expected "ERROR: ")" "true"

mv "$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256" 
echo "8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69" > "$TEST/file with spaces.txt.$HASH"
run_test "$FPATH_BIN verify $TEST" "1" "$(escape_expected "ERROR: -- hash mismatch:.* stored [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69][$TEST/file with spaces.txt.sha256].* computed [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff][$TEST/file with spaces.txt]")"
echo "349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff" > "$TEST/file with spaces.txt.$HASH"

rm "$TEST/file with spaces.txt.$HASH"
run_test "$FPATH_BIN verify $TEST" "0" "$(escape_expected "WARN: --.* hash file [$TEST/.roh.git/file with spaces.txt.sha256] -- NOT found.* for [$TEST/file with spaces.txt][349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff]")"
$FPATH_BIN write "$TEST" >/dev/null 2>&1

mkdir "$ROH_DIR/this_is_a_directory.sha256"
run_test "$FPATH_BIN verify $TEST" "0" "$(escape_expected "$ROH_DIR/this_is_a_directory.sha256")" "true"
# rmdir "$ROH_DIR/this_is_a_directory.sha256" # gets removed automagically now (on delete and write)
run_test "ls -al $ROH_DIR" "0" "this_is_a_directory.sha256"
run_test "$FPATH_BIN write $TEST" "0" "$(escape_expected "OK: -- orphaned hash directory [test/.roh.git/this_is_a_directory.sha256] -- removed")"

echo "DS_Store" > "$ROH_DIR/.DS_Store"
$GIT_BIN -C "$TEST" init >/dev/null 2>&1
run_test "$FPATH_BIN verify $TEST" "0" ".DS_Store.$HASH" "true"

# test --roh-dir 
TMP="_tmp~"
rm -rf "$TMP"
# run_test "$FPATH_BIN -w $TEST" "0" "$(escape_expected "File: ")" 
mkdir "$TMP"
mv "$ROH_DIR" "$TMP"
run_test "$FPATH_BIN verify --roh-dir $TMP/.roh.git $TEST" "0" "$(escape_expected "ERROR: ")" "true"
mv "$TMP/.roh.git" "$TEST"
rmdir "$TMP"
run_test "$FPATH_BIN verify $TEST" "0" "$(escape_expected "ERROR: ")" "true"

# verify_hash, process_directory()
rm -v "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/jkl.txt"
run_test "$FPATH_BIN verify $TEST" "1" "$(escape_expected "ERROR: --.* file [$TEST/sub-directory with spaces/sub-sub-directory/jkl.txt] -- NOT found.* for corresponding hash [$TEST/.roh.git/sub-directory with spaces/sub-sub-directory/jkl.txt.sha256][c5a8fb450fb0b568fc69a9485b8e531f119ca6e112fe1015d03fceb64b9c0e65]")"
echo "JKL" > "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/jkl.txt"

# recover
echo
echo "# recover"

cp "$TEST/$SUBDIR_WITH_SPACES/omn.txt" "$TEST/$SUBDIR_WITH_SPACES/dup.txt"
run_test "$FPATH_BIN recover $TEST" "1" "$(escape_expected "WARN: --       ... stored [$TEST/.roh.git/sub-directory with spaces/omn.txt.sha256] -- identical file.* for computed [$TEST/sub-directory with spaces/dup.txt][20562d3970dd399e658eaca0a7a6ff1bacd9cd4fbb67328b6cd805dc3c2ce1b1].*ERROR: -- could not recover hash for file [$TEST/sub-directory with spaces/dup.txt][20562d3970dd399e658eaca0a7a6ff1bacd9cd4fbb67328b6cd805dc3c2ce1b1]")"
rm "$TEST/$SUBDIR_WITH_SPACES/dup.txt"

mv "$TEST/$SUBDIR_WITH_SPACES/omn.txt" "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/OMG.txt"
run_test "$FPATH_BIN recover $TEST" "0" "$(escape_expected "Recovered: --          hash in [$TEST/.roh.git/sub-directory with spaces/omn.txt.sha256][20562d3970dd399e658eaca0a7a6ff1bacd9cd4fbb67328b6cd805dc3c2ce1b1].* restored for [$TEST/sub-directory with spaces/sub-sub-directory/OMG.txt].* in [$TEST/.roh.git/sub-directory with spaces/sub-sub-directory/OMG.txt.sha256]")" 
run_test "$FPATH_BIN verify $TEST" "0" "$(escape_expected "ERROR")" "true"

#rm "$ROH_DIR/$SUBDIR_WITH_SPACES/omn.txt.$HASH"
#mv "$TEST/directory with spaces/abc.txt" "$TEST/directory with spaces/zyxw.txt"
mv "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/OMG.txt" "$TEST/$SUBDIR_WITH_SPACES/omn.txt"
echo "OMN-D" > "$TEST/$SUBDIR_WITH_SPACES/omn.txt"
run_test "$FPATH_BIN recover $TEST" "1" "$(escape_expected "ERROR: -- could not recover hash for file [$TEST/sub-directory with spaces/omn.txt][697359ec47aef76de9a0b5001e47d7b7e93021ed8f0100e1e7e739ccdf0a5f8e]")" 
rm "$ROH_DIR/$SUBDIR_WITH_SPACES/$SUBSUBDIR/OMG.txt.$HASH"
$FPATH_BIN write "$TEST" >/dev/null 2>&1

# show/hide
echo
echo "# show/hide"

# $FPATH_BIN show "$TEST" >/dev/null 2>&1
# run_test "$FPATH_BIN verify $TEST" "1" "$(escape_expected "ERROR:.* -- hash file [.*] exists/(NOT hidden)")"
# $FPATH_BIN hide "$TEST" >/dev/null 2>&1

cp "$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256" 
run_test "$FPATH_BIN show $TEST" "1" "$(escape_expected "ERROR: [test/file with spaces.txt] -- not moving/(not shown).*destination [test/file with spaces.txt.sha256] -- exists.*for source [test/.roh.git/file with spaces.txt.sha256]")"
run_test "$FPATH_BIN show --force $TEST" "0" "$(escape_expected "OK: [$TEST/file with spaces.txt] -- hash file [test/file with spaces.txt.sha256] -- moved(shown)")"

run_test "$FPATH_BIN hide $TEST" "0" "$(escape_expected "OK: [$TEST/file with spaces.txt] -- hash file [$ROH_DIR/file with spaces.txt.sha256] -- moved(hidden)")"

mv "$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256"
run_test "$FPATH_BIN show $TEST" "0" "$(escape_expected "OK: [$TEST/file with spaces.txt] -- hash file [$TEST/file with spaces.txt.sha256] exists(shown) -- NOT moving/(NOT shown)")"

rm "$TEST/file with spaces.txt.sha256"
run_test "$FPATH_BIN hide $TEST" "1" "$(escape_expected "ERROR: [$TEST/file with spaces.txt] -- NO hash file found [$TEST/file with spaces.txt.sha256] -- not hidden")"
$FPATH_BIN write "$TEST" >/dev/null 2>&1

# worst case
echo
echo "# worst case"

mv "$ROH_DIR/file with spaces.txt.$HASH" "$TEST/file with spaces.txt.$HASH" 
$FPATH_BIN hide "$TEST" >/dev/null 2>&1
run_test "$FPATH_BIN verify $TEST" "0" "$(escape_expected "ERROR: ")" "true"

# roh.git
echo
echo "# roh.git"

run_test "$GIT_BIN" "1" "$(escape_expected "ERROR: not enough arguments.")" 
#run_test "$GIT_BIN status" "1" "$(escape_expected "ERROR: invalid working directory [].")" 
run_test "$GIT_BIN --force" "1" "$(escape_expected "ERROR: not enough arguments.")" 
#run_test "$GIT_BIN --force -x" "1" "$(escape_expected "ERROR: invalid working directory [].")" 
run_test "$GIT_BIN -xC" "1" "$(escape_expected "ERROR: option [-C] requires an argument.")" 
run_test "$GIT_BIN -xC FAKE_FPATH" "1" "$(escape_expected "ERROR: invalid working directory [FAKE_FPATH].")" 
run_test "$GIT_BIN -zxC ." "1" "$(escape_expected "ERROR: archive and extract operations are mutually exclusive.")" 
run_test "$GIT_BIN -C FAKE_FPATH" "1" "$(escape_expected "ERROR: not enough arguments.")" 
run_test "$GIT_BIN -C ." "1" "$(escape_expected "ERROR: not enough arguments.")" 
run_test "$GIT_BIN -C FAKE_FPATH status" "1" "$(escape_expected "ERROR: invalid working directory [FAKE_FPATH].")" 

$GIT_BIN -C "$TEST" add "*" >/dev/null 2>&1
$GIT_BIN -C "$TEST" commit -m "Initial hashes" >/dev/null 2>&1
run_test "$GIT_BIN -C $TEST status" "0" "nothing to commit, working tree clean"

run_test "$GIT_BIN -zC $TEST" "0" "$(escape_expected "Archived [.roh.git] to [test/_.roh.git.zip].*Removed [test/.roh.git]")"
run_test "$GIT_BIN -zC $TEST" "1" "$(escape_expected "ERROR: archive [_.roh.git.zip] exists in [test]; aborting")"
mv "$TEST/_.roh.git.zip" "$TEST/_.roh.git.zip~"
run_test "$GIT_BIN -zC $TEST" "1" "$(escape_expected "ERROR: directory [.roh.git] does NOT exist in [test]")"

mv "$TEST/_.roh.git.zip~" "$TEST/_.roh.git.zip"
run_test "$GIT_BIN -xC $TEST" "0" "$(escape_expected "Extracted [.roh.git] from [test/_.roh.git.zip].*Removed [test/_.roh.git.zip]")"
run_test "$GIT_BIN -xC $TEST" "1" "$(escape_expected "ERROR: directory [.roh.git] exists in [test]; aborting")"
mv "$ROH_DIR" "$ROH_DIR~"
run_test "$GIT_BIN -xC $TEST" "1" "$(escape_expected "ERROR: archive [_.roh.git.zip] does NOT exist in [test]")"
mv "$ROH_DIR~" "$ROH_DIR"

cp -R "$ROH_DIR" "$ROH_DIR~"
$GIT_BIN -zC "$TEST" >/dev/null 2>&1
mv "$ROH_DIR~" "$ROH_DIR"
run_test "$GIT_BIN --force -zC $TEST" "0" "$(escape_expected "Removed [test/_.roh.git.zip]")"

cp "$TEST/_.roh.git.zip" "$TEST/_.roh.git.zip~"
$GIT_BIN -xC "$TEST" >/dev/null 2>&1
mv "$TEST/_.roh.git.zip~" "$TEST/_.roh.git.zip"
run_test "$GIT_BIN --force -xC $TEST" "0" "$(escape_expected "Removed [test/.roh.git]")"

# if show/hide dies while processing; recover
mv "$ROH_DIR/file with spaces.txt.$HASH" "$TEST/file with spaces.txt.$HASH" 
find "$TEST" -name "*.$HASH" -type f -delete 
$GIT_BIN -C "$TEST" checkout . >/dev/null 2>&1
run_test "$FPATH_BIN verify $TEST" "0" "$(escape_expected "ERROR: ")" "true"

# process_directory()
echo
echo "# process_directory()"

touch "$TEST/file with spaces.rslsz"
run_test "$FPATH_BIN write $TEST" "1" "$(escape_expected "ERROR: [$TEST] \"file with spaces.rslsz\" -- file with restricted extension")"

run_test "$FPATH_BIN delete $TEST" "0" "$(escape_expected "ERROR: [$TEST] \"file with spaces.rslsz\" -- file with restricted extension")" "true"
rm "$TEST/file with spaces.rslsz"
 
#	mkdir -p "$ROH_DIR"
#	touch "$ROH_DIR/file with spaces.txt.sha256~"
#	run_test "$FPATH_BIN -d $TEST" "1" "Directory [test/$ROH_DIR] not empty" 
	
#	rm "$ROH_DIR/file with spaces.txt.sha256~"
#	run_test "$FPATH_BIN -d $TEST" "0" "Directory [test/$ROH_DIR] not empty" "true"

# Clean up test files
echo
echo "# Clean up test files"

$FPATH_BIN delete "$TEST" >/dev/null 2>&1

find "$TEST" -name '.DS_Store' -type f -delete
rm -rf "$ROH_DIR/.git"
rmdir "$ROH_DIR"

rm "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/jkl.txt"
rmdir "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR"
rm "$TEST/$SUBDIR_WITH_SPACES/omn.txt"
rm "$TEST/$SUBDIR_WITH_SPACES/pno.txt"
rmdir "$TEST/$SUBDIR_WITH_SPACES"
rm "$TEST/file with spaces.txt"
rmdir "$TEST"

run_test "ls -alR $TEST" "1" "$(escape_expected "ls: $TEST: No such file or directory")"

echo
