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
echo "OMN" > "$TEST/$SUBDIR_WITH_SPACES/omn's_.txt"
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

run_test "$FPATH_BIN write --hash test/sub-directory\ with\ spaces/*" "0" "$(escape_expected "OK: [20562d3970dd399e658eaca0a7a6ff1bacd9cd4fbb67328b6cd805dc3c2ce1b1]: \"omn's_.txt\".*OK: [1656fd07685d515a7c4cae4e1cad7a99447d8db7aac1eb2814b2572df0e6181f]: \"pno.txt\".*WARN: [test/sub-directory with spaces/sub-sub-directory] not a file -- SKIPPING")"
run_test "ls -al test/sub-directory\ with\ spaces" "0" "$(escape_expected "omn's_.txt.sha256.*pno.txt.sha256")"

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
run_test "$FPATH_BIN write --force $TEST" "0" "$(escape_expected "  OK:.* stored [0000000000000000000000000000000000000000000000000000000000000000][$ROH_DIR/file with spaces.txt.sha256] -- removed (FORCED)!.*OK:.* computed [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69][test/file with spaces.txt].* stored [0000000000000000000000000000000000000000000000000000000000000000][$TEST/file with spaces.txt.sha256] -- removed (FORCED)!")"

$FPATH_BIN delete "$TEST"
run_test "$FPATH_BIN write+index --db \"\" --verbose $TEST" "0" "$(escape_expected "db: [test/.roh.sqlite3] -- initialized.* IDX: .* >1656fd07685d515a7c4cae4e1cad7a99447d8db7aac1eb2814b2572df0e6181f<: [test/.roh.git/sub-directory with spaces/pno.txt.sha256] -- INSERTED")"
run_test "$FPATH_BIN write+index --db \"\" --verbose $TEST" "0" "$(escape_expected "[1656fd07685d515a7c4cae4e1cad7a99447d8db7aac1eb2814b2572df0e6181f]: [test/.roh.git/sub-directory with spaces/pno.txt.sha256] -- already exists, skipping")"
rm -rf "$TEST/.roh.sqlite3"

# exist-R=F         , exist-D=T (eq-D=T) // sh= F
# exist-R=F         , exist-D=F			 // sh= F
# exist-R=T (eq-R=T), exist-D=T (eq-D=T) // sh= F
# exist-R=T (eq-R=T), exist-D=F          // sh= F

mv "$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256" 
run_test "$FPATH_BIN write --verbose $TEST" "0" "$(escape_expected "OK: [test/file with spaces.txt] -- hash file [test/.roh.git/file with spaces.txt.sha256] -- moved(hidden)")"
run_test "ls -al $TEST/file\ with\ spaces.txt.sha256" "1" "$TEST/file with spaces.txt.sha256: No such file or directory"

rm "$ROH_DIR/file with spaces.txt.sha256"
run_test "$FPATH_BIN write --verbose $TEST" "0" "$(escape_expected " OK: [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]: [test/file with spaces.txt]")"

cp "$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256" 
run_test "$FPATH_BIN write $TEST" "1" "$(escape_expected "ERROR: [test/file with spaces.txt] -- not moving/(not hidden).* destination [test/.roh.git/file with spaces.txt.sha256] -- exists.* for source [test/file with spaces.txt.sha256]")"
run_test "$FPATH_BIN write --verbose --force $TEST" "0" "$(escape_expected "OK: [test/file with spaces.txt] -- hash file [test/.roh.git/file with spaces.txt.sha256] -- moved(hidden)")"
 
run_test "$FPATH_BIN write $TEST" "0" "$(escape_expected "ERROR: ")" "true"

# exist-R=F         , exist-D=T (eq-D=T) // sh= T
# exist-R=F         , exist-D=F			 // sh= T
# exist-R=T (eq-R=T), exist-D=T (eq-D=T) // sh= T
# exist-R=T (eq-R=T), exist-D=F          // sh= T

mv "$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256" 
run_test "$FPATH_BIN write --show $TEST" "0" "$(escape_expected "OK: [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]: [test] \"file with spaces.txt\"")" "true"
run_test "ls -al $ROH_DIR/file\ with\ spaces.txt.sha256" "1" "$ROH_DIR/file with spaces.txt.sha256: No such file or directory"

rm "$TEST/file with spaces.txt.sha256"
run_test "$FPATH_BIN write --verbose --show $TEST" "0" "$(escape_expected " OK: [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]: [test/file with spaces.txt]")"
run_test "ls -al $TEST/file\ with\ spaces.txt.sha256" "0" "$TEST/file with spaces.txt.sha256: No such file or directory" "true"

mkdir -p "$ROH_DIR"
cp "$TEST/file with spaces.txt.sha256" "$ROH_DIR/file with spaces.txt.sha256" 
run_test "$FPATH_BIN write --show $TEST" "1" "$(escape_expected "ERROR: [test/file with spaces.txt] -- not moving/(not shown).*destination [test/file with spaces.txt.sha256] -- exists.* for source [test/.roh.git/file with spaces.txt.sha256]")"
run_test "$FPATH_BIN write --verbose --show --force $TEST" "0" "$(escape_expected "OK: [test/file with spaces.txt] -- hash file [test/file with spaces.txt.sha256] -- moved(shown)")"
 
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
run_test "$FPATH_BIN write --verbose $TEST" "0" "$(escape_expected "  OK: [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff]: [$TEST/file with spaces.txt]")"

rm "$ROH_DIR/file with spaces.txt.$HASH" 
chmod 000 "$ROH_DIR"
run_test "$FPATH_BIN write $TEST" "1" "$(escape_expected "ERROR: [$TEST/file with spaces.txt] -- failed to write hash to [$ROH_DIR/file with spaces.txt.sha256]")"
chmod 700 "$ROH_DIR"
$FPATH_BIN write "$TEST" >/dev/null 2>&1

run_test "$FPATH_BIN write $TEST" "0" "$(escape_expected "  OK: ")" "true"

mv "$TEST/$SUBDIR_WITH_SPACES/omn's_.txt" "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/OMG.txt"
run_test "$FPATH_BIN write $TEST" "0" "$(escape_expected "OK: -- orphaned hash [20562d3970dd399e658eaca0a7a6ff1bacd9cd4fbb67328b6cd805dc3c2ce1b1]: [test/.roh.git/sub-directory with spaces/omn's_.txt.sha256] -- removed")"
mv "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/OMG.txt" "$TEST/$SUBDIR_WITH_SPACES/omn's_.txt"
$FPATH_BIN recover "$TEST" >/dev/null 2>&1

# delete
echo
echo "# delete"

mv "$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256" 
run_test "$FPATH_BIN delete --verbose $TEST" "0" "$(escape_expected "  OK: [$TEST/file with spaces.txt] -- hash file [test/file with spaces.txt.sha256] -- deleted")"
run_test "ls -al test/$ROH_DIR" "1" "test/$ROH_DIR: No such file or directory"

$FPATH_BIN write "$TEST" >/dev/null 2>&1
run_test "$FPATH_BIN delete --verbose $TEST" "0" "$(escape_expected "  OK: [$TEST/file with spaces.txt] -- hash file [test/.roh.git/file with spaces.txt.sha256] -- deleted")"

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
run_test "$FPATH_BIN verify $TEST" "0" "$(escape_expected "WARN: -- [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff]: [$TEST/file with spaces.txt] -- NO hash found")"
$FPATH_BIN write "$TEST" >/dev/null 2>&1

mkdir "$ROH_DIR/this_is_a_directory.sha256"
run_test "$FPATH_BIN verify $TEST" "0" "$(escape_expected "$ROH_DIR/this_is_a_directory.sha256")" "true"
# rmdir "$ROH_DIR/this_is_a_directory.sha256" # gets removed automagically now (on delete and write)
run_test "ls -al $ROH_DIR" "0" "this_is_a_directory.sha256"
run_test "$FPATH_BIN write --verbose $TEST" "0" "$(escape_expected "OK: -- orphaned hash directory [test/.roh.git/this_is_a_directory.sha256] -- removed")"

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
run_test "$FPATH_BIN verify $TEST" "1" "$(escape_expected "ERROR: -- [c5a8fb450fb0b568fc69a9485b8e531f119ca6e112fe1015d03fceb64b9c0e65]: [$TEST/.roh.git/sub-directory with spaces/sub-sub-directory/jkl.txt.sha256].* [$TEST/sub-directory with spaces/sub-sub-directory/jkl.txt] -- NO corresponding file")"
echo "JKL" > "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/jkl.txt"

# index
echo
echo "# index"

$FPATH_BIN index --verbose "$TEST" >/dev/null 2>&1
run_test "$FPATH_BIN query --db $TEST/.roh.sqlite3 c5a8fb450fb0b568fc69a9485b8e531f119ca6e112fe1015d03fceb64b9c0e65" "0" "$(escape_expected "query hash: [c5a8fb450fb0b568fc69a9485b8e531f119ca6e112fe1015d03fceb64b9c0e65].*[/Users/dev/Project-@knev/readonlyhash.sh.git/test/sub-directory with spaces/sub-sub-directory/jkl.txt:/Users/dev/Project-@knev/readonlyhash.sh.git/test/.roh.git/sub-directory with spaces/sub-sub-directory/jkl.txt.sha256]")"

# create two files with the same hash to test the building of the index below
echo "JKL" > "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/jkl copy.txt"
$FPATH_BIN write --verbose "$TEST" >/dev/null 2>&1

run_test "$FPATH_BIN index --verbose $TEST" "0" "$(escape_expected "IDX: >c5a8fb450fb0b568fc69a9485b8e531f119ca6e112fe1015d03fceb64b9c0e65<: [test/.roh.git/sub-directory with spaces/sub-sub-directory/jkl copy.txt.sha256] -- INSERTED")"
run_test "$FPATH_BIN query --db $TEST/.roh.sqlite3 c5a8fb450fb0b568fc69a9485b8e531f119ca6e112fe1015d03fceb64b9c0e65" "0" "$(escape_expected "query hash: [c5a8fb450fb0b568fc69a9485b8e531f119ca6e112fe1015d03fceb64b9c0e65].*[/Users/dev/Project-@knev/readonlyhash.sh.git/test/sub-directory with spaces/sub-sub-directory/jkl.txt:/Users/dev/Project-@knev/readonlyhash.sh.git/test/.roh.git/sub-directory with spaces/sub-sub-directory/jkl.txt.sha256].*[/Users/dev/Project-@knev/readonlyhash.sh.git/test/sub-directory with spaces/sub-sub-directory/jkl copy.txt:/Users/dev/Project-@knev/readonlyhash.sh.git/test/.roh.git/sub-directory with spaces/sub-sub-directory/jkl copy.txt.sha256]")"
rm -rf "$TEST/.roh.sqlite3"

$FPATH_BIN delete --verbose "$TEST" >/dev/null 2>&1
cp -R "$TEST/sub-directory with spaces" "$TEST/sub-dir copy"
echo "IOP" > "$TEST/sub-directory with spaces/iop.txt"
echo "XGY" > "$TEST/sub-directory with spaces/xgy.txt"
$FPATH_BIN write --verbose "$TEST/sub-directory with spaces" >/dev/null 2>&1
$FPATH_BIN write --verbose "$TEST/sub-dir copy" >/dev/null 2>&1
$FPATH_BIN index --db $TEST/.roh.sqlite3 --verbose "$TEST/sub-directory with spaces" >/dev/null 2>&1
$FPATH_BIN index --db $TEST/.roh.sqlite3 --verbose "$TEST/sub-dir copy" >/dev/null 2>&1

$FPATH_BIN write+index --verbose "$TEST" >/dev/null 2>&1
run_test "$FPATH_BIN write+index --verbose $TEST" "0" "$(escape_expected "-- inserted")" "true"

# recover
echo
echo "# recover"

# multiple copies with the same hash (escaping required)
mv "$TEST/sub-dir copy/omn's_.txt" "$TEST/omn's_.txt"
cp "$TEST/omn's_.txt" "$TEST/omn''s_.txt"
	
$FPATH_BIN write+index --verbose "$TEST" >/dev/null 2>&1
run_test "$FPATH_BIN recover --db $TEST/.roh.sqlite3 --verbose $TEST/sub-dir\ copy" "0" "$(escape_expected "... [/Users/dev/Project-@knev/readonlyhash.sh.git/test/sub-directory with spaces/omn's_.txt] -- duplicate FOUND.* ... [/Users/dev/Project-@knev/readonlyhash.sh.git/test/omn's_.txt] -- duplicate FOUND.* ... [/Users/dev/Project-@knev/readonlyhash.sh.git/test/omn''s_.txt] -- duplicate FOUND.* ■: -- orphaned hash [20562d3970dd399e658eaca0a7a6ff1bacd9cd4fbb67328b6cd805dc3c2ce1b1]: [test/sub-dir copy/.roh.git/omn's_.txt.sha256] -- removed")"
	
# orphaned hashes, with found fpath and not found fpath
rm "$TEST/sub-dir copy/sub-sub-directory/jkl copy.txt"
# generate an error too
echo "_jkl_" > "$TEST/sub-directory with spaces/sub-sub-directory/jkl copy.txt"

run_test "$FPATH_BIN recover --db $TEST/.roh.sqlite3 --verbose $TEST/sub-dir\ copy" "1" "$(escape_expected "ERROR:    ... [/Users/dev/Project-@knev/readonlyhash.sh.git/test/sub-directory with spaces/sub-sub-directory/jkl copy.txt] -- hash mismatch:.* computed [fcfd9ff0ceaae9e70fa27b6333f0f40a2909c5b4e595062ff399b32a5e9ebfe7].* stored [c5a8fb450fb0b568fc69a9485b8e531f119ca6e112fe1015d03fceb64b9c0e65].* ■: -- orphaned hash [c5a8fb450fb0b568fc69a9485b8e531f119ca6e112fe1015d03fceb64b9c0e65]: [test/sub-dir copy/.roh.git/sub-sub-directory/jkl copy.txt.sha256] -- removed")"
# run_test "$FPATH_BIN recover --db $TEST/.roh.sqlite3 --verbose $TEST/sub-directory\ with\ spaces" "0" "$(escape_expected " ... indexed, but missing [/Users/dev/Project-@knev/readonlyhash.sh.git/test/sub-dir copy/sub-sub-directory/jkl copy.txt].* OK: -- orphaned hash [c5a8fb450fb0b568fc69a9485b8e531f119ca6e112fe1015d03fceb64b9c0e65]: [test/sub-directory with spaces/.roh.git/sub-sub-directory/jkl copy.txt.sha256] -- removed")"
echo "JKL" > "$TEST/sub-directory with spaces/sub-sub-directory/jkl copy.txt"

# deleted fpath
rm "$TEST/sub-directory with spaces/pno.txt" 
rm "$TEST/sub-dir copy/pno.txt"
	
run_test "$FPATH_BIN recover --db $TEST/.roh.sqlite3 --verbose $TEST/sub-dir\ copy" "0" "$(escape_expected "WARN:    ... hash not in IDX [test/sub-dir copy/pno.txt] -- file DELETED !?")"
run_test "$FPATH_BIN recover --db $TEST/.roh.sqlite3 --verbose $TEST/sub-directory\ with\ spaces" "0" "$(escape_expected "WARN:    ... hash not in IDX [test/sub-directory with spaces/pno.txt] -- file DELETED !?")"
echo "PNO" > "$TEST/sub-directory with spaces/pno.txt" 
echo "PNO" > "$TEST/sub-dir copy/pno.txt"

# if I change xgy.txt in its current location, then recover will NOT pick it up!
# when doing write+index below, an existing hash will be found; this is a job for write/verify
echo "_XGY_" > "$TEST/sub-directory with spaces/xgy.txt"
run_test "$FPATH_BIN write+index --verbose $TEST" "0" "$(escape_expected "IDX: [4b89c7c236e2422752ebb01e9d8e2aafef94cd1e559ee5dc45ee4b013b535793]: [test/sub-directory with spaces/xgy.txt] -- already exists, skipping")"
echo "XGY" > "$TEST/sub-directory with spaces/xgy.txt"

# force "generated hash not found" in its current location will not produce anything
# we only process ORPHANED hashes, not ill corresponding hashes; this is a job for write/verify
echo "9dcccfb25c7ed7e3fb5c910d9a28ec8df138a35a2f8f5e15de797a37ae9fe6ec" > "$TEST/sub-directory with spaces/.roh.git/xgy.txt.sha256"
run_test "$FPATH_BIN verify --verbose $TEST/sub-directory\ with\ spaces" "1" "$(escape_expected "ERROR: -- hash mismatch:.*  stored [9dcccfb25c7ed7e3fb5c910d9a28ec8df138a35a2f8f5e15de797a37ae9fe6ec][test/sub-directory with spaces/.roh.git/xgy.txt.sha256]")"
run_test "$FPATH_BIN recover --db $TEST/.roh.sqlite3 --verbose $TEST/sub-directory\ with\ spaces" "0" "$(escape_expected "RECOVER")" "true"

# force "generated hash not found" in a different location
# the index will find the original hash and hash location, double check the hashes, but the hashes won't match
mv "$TEST/sub-directory with spaces/xgy.txt" "$TEST/sub-dir copy/xgy.txt"
run_test "$FPATH_BIN recover --db $TEST/.roh.sqlite3 --verbose $TEST/sub-directory\ with\ spaces" "1" "$(escape_expected "ERROR:    ... hash mismatch:.* indexed [4b89c7c236e2422752ebb01e9d8e2aafef94cd1e559ee5dc45ee4b013b535793]: [/Users/dev/Project-@knev/readonlyhash.sh.git/test/sub-directory with spaces/.roh.git/xgy.txt.sha256].* stored [9dcccfb25c7ed7e3fb5c910d9a28ec8df138a35a2f8f5e15de797a37ae9fe6ec]: [/Users/dev/Project-@knev/readonlyhash.sh.git/test/sub-directory with spaces/.roh.git/xgy.txt.sha256]")"
echo "4b89c7c236e2422752ebb01e9d8e2aafef94cd1e559ee5dc45ee4b013b535793" > "$TEST/sub-directory with spaces/.roh.git/xgy.txt.sha256"

# change two location AND alter one of the file
echo "_XGY_" > "$TEST/sub-dir copy/xgy.txt"
echo "_XGY_" > "$TEST/sub-dir copy/sub-sub-directory/xgy.txt"
run_test "$FPATH_BIN write+index --verbose $TEST" "0" "$(escape_expected "OK: [9dcccfb25c7ed7e3fb5c910d9a28ec8df138a35a2f8f5e15de797a37ae9fe6ec]: [test/sub-dir copy/sub-sub-directory/xgy.txt] -- written.* IDX: >9dcccfb25c7ed7e3fb5c910d9a28ec8df138a35a2f8f5e15de797a37ae9fe6ec<: [test/.roh.git/sub-dir copy/sub-sub-directory/xgy.txt.sha256] -- INSERTED")"

run_test "$FPATH_BIN recover --db $TEST/.roh.sqlite3 --verbose $TEST/sub-directory\ with\ spaces" "0" "$(escape_expected "matching filename found [/Users/dev/Project-@knev/readonlyhash.sh.git/test/sub-dir copy/xgy.txt] -- hash mismatch:.* computed [9dcccfb25c7ed7e3fb5c910d9a28ec8df138a35a2f8f5e15de797a37ae9fe6ec].* stored [4b89c7c236e2422752ebb01e9d8e2aafef94cd1e559ee5dc45ee4b013b535793].* matching filename found [/Users/dev/Project-@knev/readonlyhash.sh.git/test/sub-dir copy/sub-sub-directory/xgy.txt] -- hash mismatch:.* computed [9dcccfb25c7ed7e3fb5c910d9a28ec8df138a35a2f8f5e15de797a37ae9fe6ec].* stored [4b89c7c236e2422752ebb01e9d8e2aafef94cd1e559ee5dc45ee4b013b535793]")"

# this should not produce anythign, because from the perspective of this recover it is a just a new file
run_test "$FPATH_BIN recover --db $TEST/.roh.sqlite3 --verbose $TEST/sub-dir\ copy" "0" "$(escape_expected "RECOVER")" "true"

# remove an indexed file that matches filename
rm "$TEST/sub-dir copy/sub-sub-directory/xgy.txt"
run_test "$FPATH_BIN recover --db $TEST/.roh.sqlite3 --verbose $TEST/sub-directory\ with\ spaces" "0" "$(escape_expected "[xgy.txt]: [/Users/dev/Project-@knev/readonlyhash.sh.git/test/sub-dir copy/sub-sub-directory/xgy.txt] -- indexed, but missing")"

# make the fpath/hash combo found at a diff location be mismatched 
echo "adfb713b694a25d45e07a4f781c4ff71bb20aa21c34d210d0563ad3951a5c843" > "$TEST/.roh.git/sub-dir copy/xgy.txt.sha256"
run_test "$FPATH_BIN recover --db $TEST/.roh.sqlite3 --verbose $TEST/sub-directory\ with\ spaces" "1" "$(escape_expected "ERROR:    ... matching filename found [/Users/dev/Project-@knev/readonlyhash.sh.git/test/sub-dir copy/xgy.txt] -- hash mismatch:.* computed [9dcccfb25c7ed7e3fb5c910d9a28ec8df138a35a2f8f5e15de797a37ae9fe6ec].* stored [adfb713b694a25d45e07a4f781c4ff71bb20aa21c34d210d0563ad3951a5c843]")"
echo "XGY" > "$TEST/sub-directory with spaces/xgy.txt"
echo "9dcccfb25c7ed7e3fb5c910d9a28ec8df138a35a2f8f5e15de797a37ae9fe6ec" > "$TEST/.roh.git/sub-dir copy/xgy.txt.sha256"
 
rm "$TEST/sub-directory with spaces/iop.txt"
run_test "$FPATH_BIN recover --db $TEST/.roh.sqlite3 --verbose $TEST/sub-directory\ with\ spaces" "0" "$(escape_expected "WARN:    ... hash not in IDX [test/sub-directory with spaces/iop.txt] -- file DELETED !?.* ■: -- orphaned hash [48ab83fb303c2bb91a0b15a0a9a1e35b05918f0d482d11f03c30d3be400054d3]: [test/sub-directory with spaces/.roh.git/iop.txt.sha256] -- NOOP!")"

rm "$TEST/omn's_.txt"
rm "$TEST/omn''s_.txt"
rm -rf "$TEST/sub-dir copy"
rm -rf "$TEST/$SUBDIR_WITH_SPACES/.roh.git"
rm "$TEST/$SUBDIR_WITH_SPACES/xgy.txt"
rm "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/jkl copy.txt"
$FPATH_BIN write --verbose "$TEST" >/dev/null 2>&1
rm "$TEST/.roh.sqlite3"

#TODO: $ROH_DIR doesn't exist
#TODO: two orphaned hashes exist, two orphaned files
#TODO: two orphaned hashes exist, two orphaned files; same HASH! do both get recovered in one pass?! order?
#TODO; one orphaned, one not orphaned (order!)

#cp "$TEST/$SUBDIR_WITH_SPACES/omn's_.txt" "$TEST/$SUBDIR_WITH_SPACES/dup.txt"
#run_test "$FPATH_BIN recover $TEST" "0" "$(escape_expected "WARN: --       ... stored [$TEST/.roh.git/sub-directory with spaces/omn's_.txt.sha256] -- identical file.* for computed [$TEST/sub-directory with spaces/dup.txt][20562d3970dd399e658eaca0a7a6ff1bacd9cd4fbb67328b6cd805dc3c2ce1b1]")"
#rm "$TEST/$SUBDIR_WITH_SPACES/dup.txt"

#mv "$TEST/$SUBDIR_WITH_SPACES/omn's_.txt" "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/OMG.txt"
#run_test "$FPATH_BIN recover $TEST" "0" "$(escape_expected "Recovered: --          hash in [$TEST/.roh.git/sub-directory with spaces/omn's_.txt.sha256][20562d3970dd399e658eaca0a7a6ff1bacd9cd4fbb67328b6cd805dc3c2ce1b1].* restored for [$TEST/sub-directory with spaces/sub-sub-directory/OMG.txt].* in [$TEST/.roh.git/sub-directory with spaces/sub-sub-directory/OMG.txt.sha256]")" 
#run_test "$FPATH_BIN verify $TEST" "0" "$(escape_expected "ERROR")" "true"

#rm "$ROH_DIR/$SUBDIR_WITH_SPACES/omn's_.txt.$HASH"
#mv "$TEST/directory with spaces/abc.txt" "$TEST/directory with spaces/zyxw.txt"
#mv "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/OMG.txt" "$TEST/$SUBDIR_WITH_SPACES/omn's_.txt"
#echo "OMN-D" > "$TEST/$SUBDIR_WITH_SPACES/omn's_.txt"
#run_test "$FPATH_BIN recover $TEST" "1" "$(escape_expected "ERROR: -- could not recover hash for file [$TEST/sub-directory with spaces/omn's_.txt][697359ec47aef76de9a0b5001e47d7b7e93021ed8f0100e1e7e739ccdf0a5f8e]")" 
#rm "$ROH_DIR/$SUBDIR_WITH_SPACES/$SUBSUBDIR/OMG.txt.$HASH"
#$FPATH_BIN write "$TEST" >/dev/null 2>&1

# show/hide
echo
echo "# show/hide"

# $FPATH_BIN show "$TEST" >/dev/null 2>&1
# run_test "$FPATH_BIN verify $TEST" "1" "$(escape_expected "ERROR:.* -- hash file [.*] exists/(NOT hidden)")"
# $FPATH_BIN hide "$TEST" >/dev/null 2>&1

cp "$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256" 
run_test "$FPATH_BIN show $TEST" "1" "$(escape_expected "ERROR: [test/file with spaces.txt] -- not moving/(not shown).*destination [test/file with spaces.txt.sha256] -- exists.*for source [test/.roh.git/file with spaces.txt.sha256]")"
run_test "$FPATH_BIN show --verbose --force $TEST" "0" "$(escape_expected "OK: [$TEST/file with spaces.txt] -- hash file [test/file with spaces.txt.sha256] -- moved(shown)")"

run_test "$FPATH_BIN hide --verbose $TEST" "0" "$(escape_expected "OK: [$TEST/file with spaces.txt] -- hash file [$ROH_DIR/file with spaces.txt.sha256] -- moved(hidden)")"

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
rm "$TEST/$SUBDIR_WITH_SPACES/omn's_.txt"
rm "$TEST/$SUBDIR_WITH_SPACES/pno.txt"
rmdir "$TEST/$SUBDIR_WITH_SPACES"
rm "$TEST/file with spaces.txt"
rmdir "$TEST"

run_test "ls -alR $TEST" "1" "$(escape_expected "ls: $TEST: No such file or directory")"

echo
