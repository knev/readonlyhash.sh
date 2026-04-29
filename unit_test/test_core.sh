#! /bin/echo Please-source

FPATH_BIN="./roh.fpath.sh"
chmod +x $FPATH_BIN
GIT_BIN="./roh.git.sh"
chmod +x $GIT_BIN

HASH="sha256"

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
echo "# unit_test: core.sh"

# Parse command line options
echo
echo "# Parse command line options"

run_test "$FPATH_BIN wsweep --qewrere" "1" "$(escape_expected "ERROR: invalid command [wsweep]")"
run_test "$FPATH_BIN write sweep --qewrere" "1" "$(escape_expected "ERROR: invalid option: [--qewrere]")"
run_test "$FPATH_BIN write sweep --verbose" "1" "$(escape_expected "ERROR: NO valid ROOT specified []")"
run_test "$FPATH_BIN write sweep --" "1" "$(escape_expected "ERROR: expected argument after \"--\"")"
run_test "$FPATH_BIN write sweep --verbose --" "1" "$(escape_expected "ERROR: expected argument after \"--\"")"
run_test "$FPATH_BIN sweep --verbose -- alkjasdflk asflkjasff" "0" "$(escape_expected "WARN: [alkjasdflk] not a file -- SKIPPING.*WARN: [asflkjasff] not a file -- SKIPPING")"
run_test "$FPATH_BIN write sweep KJHJGJK" "1" "$(escape_expected "ERROR: [KJHJGJK] -- directory does not exist")"
run_test "$FPATH_BIN write sweep --verbose . --" "1" "$(escape_expected "ERROR: expected argument after \"--\"")"
run_test "$FPATH_BIN write sweep --verbose . -- \"alkjasdflk asflkjasff\"" "1" "$(escape_expected "ERROR: can't find [./alkjasdflk asflkjasff] for processing")"
run_test "$FPATH_BIN write sweep --verbose KJHJGJK" "1" "$(escape_expected "ERROR: [KJHJGJK] -- directory does not exist")"
run_test "$FPATH_BIN --verbose ." "1" "$(escape_expected "ERROR: invalid command combination []")"
run_test "$FPATH_BIN wn --verbose" "1" "$(escape_expected "ERROR: invalid command [wn]")"
run_test "$FPATH_BIN write recover ." "1" "$(escape_expected "ERROR: invalid double command combination [write recover]")"
run_test "$FPATH_BIN vwidhsqre ." "1" "$(escape_expected "ERROR: invalid command combination [verify write index delete hide show query recover sweep]")"
# echo "ERROR: unknown short operation '$c' in '$arg'" >&2 # should never happen unless the code is defined wrong
run_test "$FPATH_BIN query test/.roh.sqlite3 -- d64e30c3f3448b7979506807650f9b703f9ea276bbbe64fc56442da1d1a471af" "1" "$(escape_expected "ERROR: failed to query db [test/.roh.sqlite3/.roh.sqlite3]")"

run_test "$FPATH_BIN" "1" "Usage:.*roh.fpath.sh"
run_test "$FPATH_BIN shablam" "1" "$(escape_expected "ERROR: invalid command [shablam]")"
run_test "$FPATH_BIN -h" "0" "Usage:.*roh.fpath.sh"
run_test "$FPATH_BIN write --gobbligook" "1" "$(escape_expected "ERROR: invalid option: [--gobbligook]")"
run_test "$FPATH_BIN write -g" "1" "$(escape_expected "ERROR: invalid option: [-]")" #TODO: should print [-g]

run_test "$FPATH_BIN verify --roh-dir DOES_NOT_EXIST ." "1" "$(escape_expected "ROH_DIR: using [DOES_NOT_EXIST]")"

run_test "$FPATH_BIN verify --force ." "1" "$(escape_expected "ERROR: [--force] can only be used with: write|show|hide")"
run_test "$FPATH_BIN delete --force ." "1" "$(escape_expected "ERROR: [--force] can only be used with: write|show|hide")"
run_test "$FPATH_BIN index --force ." "1" "$(escape_expected "ERROR: [--force] can only be used with: write|show|hide")"
run_test "$FPATH_BIN query --force ." "1" "$(escape_expected "ERROR: [--force] can only be used with: write|show|hide")"
#run_test "$FPATH_BIN recover --force ." "1" "$(escape_expected "ERROR: --force can only be used with: write|show|hide")"
run_test "$FPATH_BIN -h --force ." "0" "Usage:.*roh.fpath.sh"

run_test "$FPATH_BIN verify SPECIFYING_A_DIR_THAT_SHOULD_NOT_EXIST" "1" "$(escape_expected "ERROR: [SPECIFYING_A_DIR_THAT_SHOULD_NOT_EXIST] -- directory does not exist")"

run_test "$FPATH_BIN verify -- SPECIFYING_A_DIR_THAT_SHOULD_NOT_EXIST" "0" "$(escape_expected "WARN: [SPECIFYING_A_DIR_THAT_SHOULD_NOT_EXIST] not a file -- SKIPPING")"
run_test "$FPATH_BIN verify SPECIFYING_A_DIR_THAT_SHOULD_NOT_EXIST -- PATHSPEC" "1" "$(escape_expected "ERROR: [SPECIFYING_A_DIR_THAT_SHOULD_NOT_EXIST] -- directory does not exist")"

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

TEST="test"
ROH_DIR="$TEST/.roh.git"
SUBDIR_WITH_SPACES="sub-directory with spaces"
SUBSUBDIR="sub-sub-directory"
SUBDIR_COPY_SLASH_RO="sub-dir copy :slash".ro 
SUBDIR_WITH_SPACES_RO="$SUBDIR_WITH_SPACES".ro
if [ -d $TEST ]; then 
	chmod -R 777 $TEST
	rm -rf "$TEST"
fi
rm -rf "$TEST-empty"

mkdir -p "$TEST"
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

# -- GLOBSPEC
echo
echo "# -- GLOBSPEC"

# extra protection against missing quotes
mkdir "$TEST/2020-09-05 Viggo's 1st YouTube video"
run_test "$FPATH_BIN write test -- 2020-09-05 Viggo''s 1st YouTube video" "1" "$(escape_expected "ERROR: too many arguments after \"--\"")"
rmdir "$TEST/2020-09-05 Viggo's 1st YouTube video"

run_test "$FPATH_BIN write -- test/sub-directory\ with\ spaces/*" "0" "$(escape_expected "OK: [20562d3970dd399e658eaca0a7a6ff1bacd9cd4fbb67328b6cd805dc3c2ce1b1]: [test/sub-directory with spaces/omn's_.txt] -- file hash written.*OK: [1656fd07685d515a7c4cae4e1cad7a99447d8db7aac1eb2814b2572df0e6181f]: [test/sub-directory with spaces/pno.txt] -- file hash written.*WARN: [test/sub-directory with spaces/sub-sub-directory] not a file -- SKIPPING")"
run_test "ls -al test/sub-directory\ with\ spaces" "0" "$(escape_expected "omn's_.txt.sha256.*pno.txt.sha256")"

run_test "$FPATH_BIN write -- test/sub-directory\ with\ spaces/*" "0" "$(escape_expected "txt.sha256] -- file hash written")" "true"
run_test "$FPATH_BIN delete -- test/sub-directory\ with\ spaces/*" "0" "$(escape_expected "OK: [test/sub-directory with spaces/omn's_.txt] -- hash file [test/sub-directory with spaces/omn's_.txt.sha256] -- deleted")"
run_test "$FPATH_BIN verify -- test/sub-directory\ with\ spaces/*" "0" "ERROR: " "true"

# roh.git
echo
echo "# roh.git"

run_test "$GIT_BIN" "1" "$(escape_expected "ERROR: not enough arguments.")" 
#run_test "$GIT_BIN status" "1" "$(escape_expected "ERROR: invalid working directory [].")" 
run_test "$GIT_BIN --force -iC \"\"" "1" "$(escape_expected "ERROR: invalid working directory []")" 
#run_test "$GIT_BIN --force -x" "1" "$(escape_expected "ERROR: invalid working directory [].")" 
run_test "$GIT_BIN -xC" "1" "$(escape_expected "ERROR: option [-C] requires an argument.")" 
run_test "$GIT_BIN -xC FAKE_FPATH" "1" "$(escape_expected "ERROR: invalid working directory [FAKE_FPATH].")" 
run_test "$GIT_BIN -zxC ." "1" "$(escape_expected "ERROR: archive and extract operations are mutually exclusive.")" 
run_test "$GIT_BIN -C FAKE_FPATH" "1" "$(escape_expected "ERROR: not enough arguments.")" 
run_test "$GIT_BIN -C ." "1" "$(escape_expected "ERROR: not enough arguments.")" 
run_test "$GIT_BIN -C FAKE_FPATH status" "1" "$(escape_expected "ERROR: invalid working directory [FAKE_FPATH].")" 

run_test "$FPATH_BIN write --verbose $TEST" 0 "$(escape_expected "ERROR:")" true

$GIT_BIN -C "$TEST" init >/dev/null 2>&1
$GIT_BIN -C "$TEST" add "*" >/dev/null 2>&1
$GIT_BIN -C "$TEST" commit -m "Initial hashes" >/dev/null 2>&1
run_test "$GIT_BIN -C $TEST status" "0" "nothing to commit, working tree clean"

run_test "$GIT_BIN -zC $TEST" "0" "$(escape_expected "Archived [.roh.git] to [test/_.roh.git.zip].*Removed [test/.roh.git]")"

run_test "$GIT_BIN -zC $TEST" "1" "$(escape_expected "ERROR: archive [_.roh.git.zip] exists in [test].*Abort.")"
mv "$TEST/_.roh.git.zip" "$TEST/_.roh.git.zip~"
run_test "$GIT_BIN -zC $TEST" "1" "$(escape_expected "ERROR: directory [.roh.git] does NOT exist in [test]")"

mv "$TEST/_.roh.git.zip~" "$TEST/_.roh.git.zip"
run_test "$GIT_BIN -xC $TEST" "0" "$(escape_expected "Extracted [test/.roh.git] from [_.roh.git.zip].*Backed: up [test/_.roh.git.zip] as [test/.roh.git.zip~]")"
run_test "$GIT_BIN -xC $TEST" "1" "$(escape_expected "ERROR: directory [.roh.git] exists in [test].*Abort.")"
mv "$ROH_DIR" "roh.git-tmp-copy" # move .roh.git to avoid the error above and hit the error below
run_test "$GIT_BIN -xC $TEST" "1" "$(escape_expected "ERROR: archive [_.roh.git.zip] does NOT exist in [test]")"
mv "roh.git-tmp-copy" "$ROH_DIR"

cp -R "$ROH_DIR" "roh.git-tmp-copy"
$GIT_BIN -zC "$TEST" >/dev/null 2>&1
mv "roh.git-tmp-copy" "$ROH_DIR" # putting the copy where the extracted copy should go
run_test "$GIT_BIN --force -zC $TEST" "0" "$(escape_expected "Clobber [test/_.roh.git.zip] (FORCED)!.*WARN: [test/.roh.git] content unchanged from clobbered archive")"

cp "$TEST/_.roh.git.zip" "$TEST/_.roh.git.zip~"
$GIT_BIN -xC "$TEST" >/dev/null 2>&1
mv "$TEST/_.roh.git.zip~" "$TEST/_.roh.git.zip"
run_test "$GIT_BIN --force -xC $TEST" "0" "$(escape_expected "Clobber [test/.roh.git] (FORCED)!.*Backed: up [test/_.roh.git.zip] as [test/.roh.git.zip~]")"

# drift detection: archive with no content change vs. archive after a content change.
# At this point .roh.git/ was just extracted and .roh.git.zip~ holds the prior archive.
run_test "$GIT_BIN -zC $TEST" "0" "WARN: \[test/\.roh\.git\] content changed since last archive" "true"

# Round-trip back so .roh.git/ and .roh.git.zip~ are both present for the next test.
$GIT_BIN -xC "$TEST" >/dev/null 2>&1

# Tweak a tracked file and commit so the working tree is clean; archive should warn.
echo "DRIFT" > "$ROH_DIR/drift-test.$HASH"
$GIT_BIN -C "$TEST" add "drift-test.$HASH" >/dev/null 2>&1
$GIT_BIN -C "$TEST" commit -m "drift test tweak" >/dev/null 2>&1
run_test "$GIT_BIN -zC $TEST" "0" "$(escape_expected "WARN: [test/.roh.git] content changed since last archive")"

# Restore: extract latest, drop the tweak commit so downstream tests see a clean tree.
$GIT_BIN -xC "$TEST" >/dev/null 2>&1
$GIT_BIN -C "$TEST" reset --hard HEAD~1 >/dev/null 2>&1

# Forced clobber with content drift: seed _.roh.git.zip with the prior
# (post-tweak) archive while .roh.git/ now holds pre-tweak content. The
# clobber renames the zip to .zip~ and the drift check fires.
cp "$TEST/.roh.git.zip~" "$TEST/_.roh.git.zip"
run_test "$GIT_BIN --force -zC $TEST" "0" "$(escape_expected "Clobber [test/_.roh.git.zip] (FORCED)!.*WARN: [test/.roh.git] content changed since last archive")"

# Restore .roh.git/ for downstream tests.
$GIT_BIN -xC "$TEST" >/dev/null 2>&1

# Extract with a pre-existing .zip~ should warn that the prior backup is
# being overwritten. (Normal cycles delete .zip~ on archive, so this is
# the recovery / manual-restore case.)
cp "$TEST/.roh.git.zip~" "$TEST/_.roh.git.zip"
rm -rf "$ROH_DIR"
run_test "$GIT_BIN -xC $TEST" "0" "$(escape_expected "WARN: [test/.roh.git.zip~] exists -- overwriting.*Backed: up [test/_.roh.git.zip] as [test/.roh.git.zip~]")"

# --v1 archive/extract: legacy tar+zip routine. Distinct extract wording
# ("Removed [_.roh.git.zip]") signals the v1 path; v1 does NOT preserve a
# .zip~ backup and does NOT do drift detection.
run_test "$GIT_BIN --v1 -zC $TEST" "0" "$(escape_expected "Archived [.roh.git] to [test/_.roh.git.zip].*Removed [test/.roh.git]")"
run_test "$GIT_BIN --v1 -xC $TEST" "0" "$(escape_expected "Extracted [test/.roh.git] from [_.roh.git.zip].*Removed [test/_.roh.git.zip]")"

# --v2 archive/extract: default routine, explicitly selected. Extract uses
# the "Backed: up ... as .zip~" wording.
run_test "$GIT_BIN --v2 -zC $TEST" "0" "$(escape_expected "Archived [.roh.git] to [test/_.roh.git.zip].*Removed [test/.roh.git]")"
run_test "$GIT_BIN --v2 -xC $TEST" "0" "$(escape_expected "Extracted [test/.roh.git] from [_.roh.git.zip].*Backed: up [test/_.roh.git.zip] as [test/.roh.git.zip~]")"

# if show/hide dies while processing; recover
mv "$ROH_DIR/file with spaces.txt.$HASH" "$TEST/file with spaces.txt.$HASH" 
find "$TEST" -name "*.$HASH" -type f -delete 
$GIT_BIN -C "$TEST" checkout . >/dev/null 2>&1
run_test "$FPATH_BIN verify $TEST" "0" "$(escape_expected "ERROR: ")" "true"

# tear down the git internals + preserved-zip artifact left over from this section,
# so subsequent sections that expect .roh.git/ to be sweep-empty can clean up fully.
rm -rf "$ROH_DIR/.git"
rm -f "$ROH_DIR/.gitignore"
rm -f "$TEST/.roh.git.zip~"

# write
echo
echo "# write"

# Weird b3-Excito cyclic symlink
pushd "$TEST" >/dev/null 2>&1
ln -s . X11
popd >/dev/null 2>&1
run_test "$FPATH_BIN write --verbose $TEST" "0" "$(escape_expected "Avoiding symlink [test/X11] like the Plague")"
rm "$TEST/X11"

chmod 000 "$TEST/file with spaces.txt"
run_test "$FPATH_BIN write --verbose --force $TEST" "0" "$(escape_expected "ERROR: [test/file with spaces.txt] file -- not readable or permission denied.*computed [0000000000000000000000000000000000000000000000000000000000000000]: [test/file with spaces.txt]")"
chmod 644 "$TEST/file with spaces.txt"

echo "#NEW_FILE#" >> "$TEST/new-file.txt"
run_test "$FPATH_BIN write --verbose $TEST -- new-file.txt" "0" "$(escape_expected "OK: [d76a514430a56c7d071db6099fc6a3d3917f90f94ed731ae09220e29b09466ab]: [test/new-file.txt] -- file hash written")"
run_test "$FPATH_BIN verify --verbose $TEST -- new-file.txt" "0" "$(escape_expected "OK: [d76a514430a56c7d071db6099fc6a3d3917f90f94ed731ae09220e29b09466ab]: [test/new-file.txt]")"
rm "$TEST/new-file.txt"
rm "$TEST/.roh.git/new-file.txt.$HASH"

echo "0000000000000000000000000000000000000000000000000000000000000000" > "$ROH_DIR/file with spaces.txt.$HASH"
echo "0000000000000000000000000000000000000000000000000000000000000000" > "$TEST/file with spaces.txt.$HASH"
run_test "$FPATH_BIN write --verbose $TEST" "0" "$(escape_expected "OK: [0000000000000000000000000000000000000000000000000000000000000000]: [test/.roh.git/file with spaces.txt.sha256] -- hidden hash exists -- SKIPPING")"
run_test "$FPATH_BIN write --force $TEST" "0" "$(escape_expected "OK: hash mismatch -- stored deleted (FORCED)!.*computed [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]: [test/file with spaces.txt].*stored [0000000000000000000000000000000000000000000000000000000000000000]: [$ROH_DIR/file with spaces.txt.sha256].*OK: hash mismatch -- stored deleted (FORCED)!.*computed [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]: [test/file with spaces.txt].*stored [0000000000000000000000000000000000000000000000000000000000000000]: [$TEST/file with spaces.txt.sha256]")"

$FPATH_BIN delete "$TEST" >/dev/null 2>&1
run_test "$FPATH_BIN write index --db \"\" --verbose $TEST" "0" "$(escape_expected "DB_SQL: [test/.roh.sqlite3] -- initialized.* IDX: .* >1656fd07685d515a7c4cae4e1cad7a99447d8db7aac1eb2814b2572df0e6181f<: [test/.roh.git/sub-directory with spaces/pno.txt.sha256] -- INDEXED")"
run_test "$FPATH_BIN write index --db \"\" --verbose $TEST" "1" "$(escape_expected "ERROR: [test/.roh.git/sub-directory with spaces/pno.txt.sha256] hash NOT UNIQUE -- IDX inconsistency")"
rm -rf "$TEST/.roh.sqlite3"

# exist-R=F         , exist-D=T (eq-D=T) // sh= F
# exist-R=F         , exist-D=F			 // sh= F
# exist-R=T (eq-R=T), exist-D=T (eq-D=T) // sh= F
# exist-R=T (eq-R=T), exist-D=F          // sh= F

mv "$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256" 
run_test "$FPATH_BIN write --verbose --force $TEST" "0" "$(escape_expected "OK: [test/file with spaces.txt]: [test/.roh.git/file with spaces.txt.sha256] hash file -- moved(hidden)")"
run_test "ls -al $TEST/file\ with\ spaces.txt.sha256" "1" "$TEST/file with spaces.txt.sha256.?: No such file or directory"

rm "$ROH_DIR/file with spaces.txt.sha256"
run_test "$FPATH_BIN write --verbose $TEST" "0" "$(escape_expected " OK: [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]: [$TEST/file with spaces.txt] -- file hash written")"

cp "$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256" 
#run_test "$FPATH_BIN write $TEST" "1" "$(escape_expected "ERROR: [test/file with spaces.txt] -- not moving/(not hidden).* destination [test/.roh.git/file with spaces.txt.sha256] -- exists.* for source [test/file with spaces.txt.sha256]")"
run_test "$FPATH_BIN write --verbose --force $TEST" "0" "$(escape_expected "OK: [test/file with spaces.txt]: [test/.roh.git/file with spaces.txt.sha256] hash file -- moved(hidden)")"
 
run_test "$FPATH_BIN write $TEST" "0" "$(escape_expected "ERROR: ")" "true"

# exist-R=F         , exist-D=T (eq-D=T) // sh= T
# exist-R=F         , exist-D=F			 // sh= T
# exist-R=T (eq-R=T), exist-D=T (eq-D=T) // sh= T
# exist-R=T (eq-R=T), exist-D=F          // sh= T

mv "$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256" 
run_test "$FPATH_BIN write show $TEST" "0" "$(escape_expected "OK: [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]: [test] \"file with spaces.txt\"")" "true"
run_test "ls -al $ROH_DIR/file\ with\ spaces.txt.sha256" "1" "$ROH_DIR/file with spaces.txt.sha256.*: No such file or directory"

run_test "$FPATH_BIN sweep $TEST" "0" "$(escape_expected "ERROR:")" "true"
run_test "ls -alR $ROH_DIR" "1" "$ROH_DIR.?: No such file or directory"

# hashes_found=$(find "$TEST/.roh.git" -mindepth 1 -name "*.sha256" -print -quit)
# echo $hashes_found

rm "$TEST/file with spaces.txt.sha256"
run_test "$FPATH_BIN write show --verbose $TEST" "0" "$(escape_expected " OK: [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]: [test/file with spaces.txt] -- file hash written")"
run_test "ls -al $TEST/file\ with\ spaces.txt.sha256" "0" "$TEST/file with spaces.txt.sha256: No such file or directory" "true"

mkdir -p "$ROH_DIR"
cp "$TEST/file with spaces.txt.sha256" "$ROH_DIR/file with spaces.txt.sha256" 
#run_test "$FPATH_BIN write show $TEST" "1" "$(escape_expected "ERROR: [test/file with spaces.txt] -- not moving/(not shown).*destination [test/file with spaces.txt.sha256] -- exists.* for source [test/.roh.git/file with spaces.txt.sha256]")"
run_test "$FPATH_BIN write show --verbose --force $TEST" "0" "$(escape_expected "OK: [test/file with spaces.txt]: [test/file with spaces.txt.sha256] hash file -- moved(shown)")"
 
run_test "$FPATH_BIN wse $TEST" "0" "$(escape_expected "ERROR: ")" "true"
run_test "ls -al $ROH_DIR" "1" "$ROH_DIR.?: No such file or directory"

run_test "$FPATH_BIN hide $TEST" "0" "$(escape_expected "ERROR: ")" "true"

# OLD write tests

# echo "c5a8fb450fb0b568fc69a9485b8e531f119ca6e112fe1015d03fceb64b9c0e65" > "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/jkl.txt.$HASH"
# run_test "$FPATH_BIN write $TEST" "1" "$(escape_expected "ERROR: [test/$SUBDIR_WITH_SPACES/$SUBSUBDIR/jkl.txt] -- not moving/(not hidden).*destination [test/.roh.git/$SUBDIR_WITH_SPACES/$SUBSUBDIR/jkl.txt.sha256] -- exists.*for source [test/$SUBDIR_WITH_SPACES/$SUBSUBDIR/jkl.txt.sha256]")"
# rm "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/jkl.txt.$HASH"

echo "ZYXW" > "$TEST/file with spaces.txt"
run_test "$FPATH_BIN write --force $TEST" "0" "$(escape_expected "OK: hash mismatch -- stored deleted (FORCED)!.*computed [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff]: [test/file with spaces.txt].*stored [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]: [test/.roh.git/file with spaces.txt.sha256]")"

rm "$ROH_DIR/file with spaces.txt.$HASH" 
run_test "$FPATH_BIN write --verbose $TEST" "0" "$(escape_expected "  OK: [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff]: [$TEST/file with spaces.txt] -- file hash written")"

rm "$ROH_DIR/file with spaces.txt.$HASH" 
chmod 000 "$ROH_DIR"
run_test "$FPATH_BIN write $TEST" "1" "$(escape_expected "ERROR: [$TEST/file with spaces.txt] -- failed to write hash to [test/.roh.git/file with spaces.txt.sha256]")"
chmod 700 "$ROH_DIR"
$FPATH_BIN write "$TEST" >/dev/null 2>&1

run_test "$FPATH_BIN write $TEST" "0" "$(escape_expected "  OK: ")" "true"

mv "$TEST/$SUBDIR_WITH_SPACES/omn's_.txt" "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/OMG.txt"
run_test "$FPATH_BIN verify index $TEST" "1" "$(escape_expected "ERROR: [20562d3970dd399e658eaca0a7a6ff1bacd9cd4fbb67328b6cd805dc3c2ce1b1]: [test/.roh.git/$SUBDIR_WITH_SPACES/omn's_.txt.sha256] orphaned hash -- indexing")"
run_test "$FPATH_BIN sweep --verbose $TEST" "0" "$(escape_expected "OK: [20562d3970dd399e658eaca0a7a6ff1bacd9cd4fbb67328b6cd805dc3c2ce1b1]: [test/.roh.git/$SUBDIR_WITH_SPACES/omn's_.txt.sha256] orphaned hash -- DELETED")"
mv "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/OMG.txt" "$TEST/$SUBDIR_WITH_SPACES/omn's_.txt"
rm "$TEST/.roh.sqlite3"

# delete
echo
echo "# delete"

mv "$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256" 
run_test "$FPATH_BIN delete --verbose $TEST" "0" "$(escape_expected "  OK: [$TEST/file with spaces.txt] -- hash file [test/file with spaces.txt.sha256] -- deleted")"
run_test "ls -al test/$ROH_DIR" "1" "test/$ROH_DIR.?: No such file or directory"

$FPATH_BIN write "$TEST" >/dev/null 2>&1
run_test "$FPATH_BIN delete --verbose $TEST" "0" "$(escape_expected "  OK: [$TEST/file with spaces.txt] -- hash file [test/.roh.git/file with spaces.txt.sha256] -- deleted")"

run_test "ls -al test/$ROH_DIR" "1" "test/$ROH_DIR.?: No such file or directory"

run_test "$FPATH_BIN delete $TEST" "0" "$(escape_expected "  OK: ")" "true"
$FPATH_BIN write "$TEST" >/dev/null 2>&1

# verify
echo
echo "# verify"

mkdir "$TEST-empty"
run_test "$FPATH_BIN verify show $TEST-empty" "0" "$(escape_expected "WARN: [test-empty/.roh.git] missing or inaccessible")"
#TODO: verify show

# we don't care about empty directories
run_test "$FPATH_BIN write $TEST-empty" "0" "$(escape_expected "Done.")"
run_test "ls test-empty/.roh.git" "0" "$(escape_expected " ")" "true"
rm -rf "$TEST-empty"

echo "8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69" > "$TEST/file with spaces.txt.$HASH"
run_test "$FPATH_BIN verify $TEST" "1" "$(escape_expected "ERROR: two hash files exist.*hidden [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff]: [test/.roh.git/file with spaces.txt.sha256].*shown [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]: [test/file with spaces.txt.sha256].*computed [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff]: [test/file with spaces.txt]")"
# see also first test in manage_hash_visibility: ERROR:.* -- hash file [.*] exists/(NOT hidden)
rm "$TEST/file with spaces.txt.$HASH"

run_test "$FPATH_BIN verify $TEST" "0" "$(escape_expected "ERROR: ")" "true"

#echo "ABC" > "$TEST/file with spaces.txt"
#echo "ZYXW" > "$TEST/file with spaces.txt"

echo "8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69" > "$ROH_DIR/file with spaces.txt.$HASH"
run_test "$FPATH_BIN verify $TEST" "1" "$(escape_expected "ERROR: hash mismatch.*stored [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]: [$ROH_DIR/file with spaces.txt.sha256].*computed [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff]: [$TEST/file with spaces.txt]")"
echo "349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff" > "$ROH_DIR/file with spaces.txt.$HASH"

mv "$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256" 
run_test "$FPATH_BIN verify $TEST" "0" "$(escape_expected "WARN: hashes not exclusively hidden in [$ROH_DIR]")"
$FPATH_BIN write "$TEST" >/dev/null 2>&1

touch "$TEST/.HIDDEN_FILE"
run_test "$FPATH_BIN verify --verbose $TEST" "0" "$(escape_expected "WARN: directories with hidden entries were detected and exported.*[test/.roh.git/../.roh.logs/files-hidden.exported.txt]")"
rm "$TEST/.HIDDEN_FILE"
rm "$TEST/.roh.logs/files-hidden.exported.txt"

run_test "$FPATH_BIN verify index --verbose $TEST" "0" "$(escape_expected "ERROR: ")" "true"
rm "$TEST/.roh.sqlite3"

# mv "$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256" # already moved
echo "8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69" > "$TEST/file with spaces.txt.$HASH"
run_test "$FPATH_BIN verify $TEST" "1" "$(escape_expected "ERROR: hash mismatch.*stored [8470d56547eea6236d7c81a644ce74670ca0bbda998e13c629ef6bb3f0d60b69]: [$TEST/file with spaces.txt.sha256].*computed [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff]: [$TEST/file with spaces.txt]")"
echo "349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff" > "$TEST/file with spaces.txt.$HASH"

rm "$TEST/file with spaces.txt.$HASH"
run_test "$FPATH_BIN verify $TEST" "0" "$(escape_expected "WARN: [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff]: [$TEST/file with spaces.txt] -- NEW!?")"
$FPATH_BIN write "$TEST" >/dev/null 2>&1

mkdir -p "test/.roh.git/orphaned_hashes"
run_test "$FPATH_BIN verify $TEST" "0" "$(escape_expected "orphaned hash DIRECTORY!")" "true"

mkdir -p "test/.roh.git/orphaned_hashes/tmp-empty"
run_test "$FPATH_BIN verify $TEST" "0" "$(escape_expected "orphaned hash DIRECTORY!")" "true"
rmdir "test/.roh.git/orphaned_hashes/tmp-empty"

touch "test/.roh.git/orphaned_hashes/.HIDDEN_FILE"
run_test "$FPATH_BIN verify $TEST" "1" "$(escape_expected "ERROR: directory [test/.roh.git/orphaned_hashes] contains hidden entries")"
rm "test/.roh.git/orphaned_hashes/.HIDDEN_FILE"

mkdir "test/.roh.git/orphaned_hashes/.HIDDEN_DIR"
run_test "$FPATH_BIN verify $TEST" "1" "$(escape_expected "ERROR: directory [test/.roh.git/orphaned_hashes] contains hidden entries")"
rmdir "test/.roh.git/orphaned_hashes/.HIDDEN_DIR"

mkdir "$TEST/orphaned_hashes"
echo "YHB" > "$TEST/orphaned_hashes/yhb.txt"
$FPATH_BIN write "$TEST" >/dev/null 2>&1
rm -rf "$TEST/orphaned_hashes"
run_test "$FPATH_BIN verify $TEST" "1" "$(escape_expected "ERROR: [test/.roh.git/orphaned_hashes] -- orphaned hash DIRECTORY!")"
$FPATH_BIN sweep "$TEST" >/dev/null 2>&1

mkdir "$ROH_DIR/this_is_a_directory.sha256"
run_test "$FPATH_BIN verify $TEST" "0" "$(escape_expected "$ROH_DIR/this_is_a_directory.sha256")" "true"
# rmdir "$ROH_DIR/this_is_a_directory.sha256" # gets removed automagically now (on delete and write)
run_test "ls -al $ROH_DIR" "0" "this_is_a_directory.sha256"
run_test "$FPATH_BIN sweep --verbose $TEST" "0" "$(escape_expected "OK: orphaned hash directory [test/.roh.git/this_is_a_directory.sha256] -- DELETED")"

echo "DS_Store" > "$ROH_DIR/.DS_Store"
run_test "$FPATH_BIN verify $TEST" "1" ".DS_Store.$HASH" "true"
run_test "$FPATH_BIN verify $TEST" "1" "$(escape_expected "ERROR: directory [test/.roh.git] contains hidden entries")"
rm "$ROH_DIR/.DS_Store"

# write PATHSPEC
run_test "$FPATH_BIN verify --verbose $TEST -- \"$SUBDIR_WITH_SPACES\"" "0" "$(escape_expected "file with spaces.txt")" "true"

# test --roh-dir 
TMP="_tmp~"
rm -rf "$TMP"
# run_test "$FPATH_BIN -w $TEST" "0" "$(escape_expected "File: ")" 
mkdir "$TMP"
mv "$ROH_DIR" "$TMP"
run_test "$FPATH_BIN verify --roh-dir $TMP/.roh.git $TEST" "0" "$(escape_expected "ERROR: ")" "true"
mv "$TMP/.roh.git" "$TEST"
rm -rf "$TMP/.roh.logs"
rmdir "$TMP"
run_test "$FPATH_BIN verify $TEST" "0" "$(escape_expected "ERROR: ")" "true"

cp "$TEST/.roh.git/$SUBDIR_WITH_SPACES/$SUBSUBDIR/jkl.txt.sha256" "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/."
rm -rf "$TEST/.roh.git/$SUBDIR_WITH_SPACES/$SUBSUBDIR"
run_test "$FPATH_BIN verify $TEST" "0" "$(escape_expected "NEW DIRECTORY!?")" "true"

rm "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/jkl.txt.$HASH" 
run_test "$FPATH_BIN verify $TEST" "0" "$(escape_expected "WARN: [test/sub-directory with spaces/sub-sub-directory] -- NEW DIRECTORY!?")"
$FPATH_BIN write "$TEST" >/dev/null 2>&1

# weird symlink to existing file
mkdir  "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/BLAH"
ln -s "../../pno.txt" "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/BLAH/a-symlink"
run_test "$FPATH_BIN verify $TEST" "0" "$(escape_expected "NEW DIRECTORY!?")" "true"
rm "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/BLAH/a-symlink"
rmdir  "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/BLAH"

mkdir "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/tmp-empty" 
run_test "$FPATH_BIN verify $TEST" "0" "$(escape_expected "NEW DIRECTORY!?")" "true"

mkdir "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/tmp-empty/sub-empty" 
run_test "$FPATH_BIN verify $TEST" "0" "$(escape_expected "NEW DIRECTORY!?")" "true"
rmdir "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/tmp-empty/sub-empty" 

touch "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/tmp-empty/.HIDDEN_FILE" 
run_test "$FPATH_BIN verify $TEST" "0" "$(escape_expected "NEW DIRECTORY!?")" "true"
run_test "$FPATH_BIN verify $TEST" "0" "$(escape_expected "WARN: directories with hidden entries were detected and exported")"
rm "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/tmp-empty/.HIDDEN_FILE" 
rm -rf "$TEST/.roh.logs"

mkdir "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/tmp-empty/.HIDDEN_DIR" 
run_test "$FPATH_BIN verify $TEST" "0" "$(escape_expected "NEW DIRECTORY!?")" "true"
run_test "$FPATH_BIN verify $TEST" "0" "$(escape_expected "WARN: directories with hidden entries were detected and exported")"
rmdir "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/tmp-empty/.HIDDEN_DIR" 
rmdir "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/tmp-empty" 
rm -rf "$TEST/.roh.logs"

mkdir "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR-empty"
run_test "$FPATH_BIN write --verbose $TEST" "0" "$(escape_expected "OK:.*sub-sub-directory-empty.*-- written")" "true"
run_test "$FPATH_BIN verify $TEST" "0" "$(escape_expected "WARN: [test/sub-directory with spaces/sub-sub-directory-empty] -- NEW DIRECTORY!?")" "true"
rmdir "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR-empty"

run_test "$GIT_BIN -iC $TEST status" "0" "$(escape_expected "nothing to commit, working tree clean")"
run_test "$GIT_BIN -zC $TEST status" "0" "$(escape_expected "Archived [.roh.git] to [test/_.roh.git.zip]")"
run_test "$FPATH_BIN verify $TEST" "1" "$(escape_expected "ERROR: found archived ROH_DIR [test/_.roh.git.zip] at [test]")"
$GIT_BIN -xC "$TEST" >/dev/null 2>&1
rm -rf "$ROH_DIR/.git"
rm "$ROH_DIR/.gitignore"

# verify_hash, process_directory()
rm -v "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/jkl.txt"
run_test "$FPATH_BIN verify $TEST" "1" "$(escape_expected "ERROR: [c5a8fb450fb0b568fc69a9485b8e531f119ca6e112fe1015d03fceb64b9c0e65]: [$TEST/.roh.git/sub-directory with spaces/sub-sub-directory/jkl.txt.sha256]")"
echo "JKL" > "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/jkl.txt"

# index
echo
echo "# index"

mkdir "$TEST/sql_dir"
run_test "$FPATH_BIN query --db $TEST/sql_dir $TEST -- c5a8fb450fb0b568fc69a9485b8e531f119ca6e112fe1015d03fceb64b9c0e65" "1" "$(escape_expected "ERROR: failed to query db [test/sql_dir]")"
rmdir "$TEST/sql_dir"

run_test "$FPATH_BIN index query $TEST -- c5a8fb450fb0b568fc69a9485b8e531f119ca6e112fe1015d03fceb64b9c0e65" "0" "$(escape_expected "query hash: [c5a8fb450fb0b568fc69a9485b8e531f119ca6e112fe1015d03fceb64b9c0e65].*OK: found -- hash path [$PWD/test/.roh.git/sub-directory with spaces/sub-sub-directory/jkl.txt.sha256.*absolute fpath [$PWD/test/sub-directory with spaces/sub-sub-directory/jkl.txt]")"
run_test "$FPATH_BIN verify $TEST" "0" "$(escape_expected "WARN: database file [test/.roh.sqlite3] exists; has not been deleted")"

# create two files with the same hash to test the building of the index below
echo "JKL" > "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/jkl copy.txt"
$FPATH_BIN write --verbose "$TEST" >/dev/null 2>&1

rm "$TEST/.roh.sqlite3"
run_test "$FPATH_BIN index --verbose $TEST" "0" "$(escape_expected "IDX: >c5a8fb450fb0b568fc69a9485b8e531f119ca6e112fe1015d03fceb64b9c0e65<: [test/.roh.git/sub-directory with spaces/sub-sub-directory/jkl copy.txt.sha256] -- INDEXED")"
run_test "$FPATH_BIN query --db $TEST/.roh.sqlite3 -- c5a8fb450fb0b568fc69a9485b8e531f119ca6e112fe1015d03fceb64b9c0e65" "0" "$(escape_expected "query hash: [c5a8fb450fb0b568fc69a9485b8e531f119ca6e112fe1015d03fceb64b9c0e65].*OK: found -- hash path [$PWD/test/.roh.git/sub-directory with spaces/sub-sub-directory/jkl copy.txt.sha256].*absolute fpath [$PWD/test/sub-directory with spaces/sub-sub-directory/jkl copy.txt]")"
run_test "$FPATH_BIN query --db $TEST/.roh.sqlite3 -- c5a8fb450fb0b568fc69a9485b8e531f119ca6e112fe1015d03fceb64b9c0e65" "0" "$(escape_expected "query hash: [c5a8fb450fb0b568fc69a9485b8e531f119ca6e112fe1015d03fceb64b9c0e65].*OK: found -- hash path [$PWD/test/.roh.git/sub-directory with spaces/sub-sub-directory/jkl.txt.sha256].*absolute fpath [$PWD/test/sub-directory with spaces/sub-sub-directory/jkl.txt]")"

run_test "$FPATH_BIN delete sweep --verbose $TEST" "0" "$(escape_expected "Removing DB_SQL [test/.roh.sqlite3]")"
run_test "ls -alR $ROH_DIR" "1" "$ROH_DIR.?: No such file or directory"
$FPATH_BIN write index --verbose "$TEST" >/dev/null 2>&1
# removing the indexed file, should not write a hash (since there is no file) and also not index
rm "$TEST/file with spaces.txt"

run_test "$FPATH_BIN write index --verbose $TEST" "1" "$(escape_expected "ERROR: [test/.roh.git/file with spaces.txt.sha256] hash NOT UNIQUE -- IDX inconsistency")"
rm "$TEST/.roh.sqlite3"

run_test "$FPATH_BIN write index --verbose $TEST" "0" "$(escape_expected "OK: [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff]: [test/.roh.git/file with spaces.txt.sha256] -- written.*IDX: >349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff<: [test/.roh.git/file with spaces.txt.sha256] -- INDEXED")" "true"
run_test "$FPATH_BIN verify --only-hashes --verbose $TEST" "1" "$(escape_expected "[test/.roh.git/file with spaces.txt.sha256] orphaned hash")"
echo "ZYXW" > "$TEST/file with spaces.txt"
rm "$TEST/.roh.sqlite3"

$FPATH_BIN delete sweep --verbose "$TEST" >/dev/null 2>&1
$FPATH_BIN write index --verbose "$TEST" >/dev/null 2>&1
run_test "$FPATH_BIN write index --verbose $TEST" "1" "$(escape_expected "ERROR: [test/.roh.git/file with spaces.txt.sha256] hash NOT UNIQUE -- IDX inconsistency")"
rm -rf "$TEST/.roh.sqlite3"

# one completely new file
echo "IOP" > "$TEST/$SUBDIR_WITH_SPACES/IOP~.txt"
# one "new" file with an orphaned hash

# write index --dedup (single-invocation)
echo
echo "# write index --dedup (single-invocation)"

DEDUP_TMP=$(mktemp -d)
mkdir -p "$DEDUP_TMP/ro/sub" "$DEDUP_TMP/roh"
printf 'alpha\n' > "$DEDUP_TMP/ro/a.txt"
printf 'beta\n'  > "$DEDUP_TMP/ro/sub/b.txt"
printf 'alpha\n' > "$DEDUP_TMP/ro/sub/c.txt"   # duplicate of a.txt

# single invocation: hash + index with dedup in one walk
run_test "$FPATH_BIN write index --dedup --roh-dir $DEDUP_TMP/roh --db $DEDUP_TMP/.roh.sqlite3 $DEDUP_TMP/ro" "0" \
	"$(escape_expected "IDX: [b6a98d9ce9a2d9149288fa3df42d377c3e42737afdcdaf714e33c0a100b51060]: [$DEDUP_TMP/ro/sub/c.txt] -- duplicate, skipped (--dedup)")"

# canonicals have .sha256; duplicate does not
run_test "ls $DEDUP_TMP/roh/a.txt.sha256 $DEDUP_TMP/roh/sub/b.txt.sha256" "0" "a.txt.sha256.*b.txt.sha256"
run_test "ls $DEDUP_TMP/roh/sub/c.txt.sha256" "1" "c.txt.sha256.?: No such file or directory"

# DB has exactly 2 rows (one per unique hash)
run_test "sqlite3 $DEDUP_TMP/.roh.sqlite3 \"SELECT COUNT(*) FROM hashes;\"" "0" "2"

# NEW log contains only the duplicate (c.txt)
run_test "cat $DEDUP_TMP/.roh.logs/files-new.exported.txt" "0" "$(escape_expected "$DEDUP_TMP/ro/sub/c.txt")"
# and nothing else — canonicals must NOT be logged
run_test "cat $DEDUP_TMP/.roh.logs/files-new.exported.txt" "0" "$(escape_expected "$DEDUP_TMP/ro/a.txt")" "true"

# validation: --dedup without index is rejected
run_test "$FPATH_BIN write --dedup $DEDUP_TMP/ro" "1" "$(escape_expected "ERROR: [--dedup] can only be used with: index")"

rm -rf "$DEDUP_TMP"

# recover
echo
echo "# recover"

$FPATH_BIN write --verbose "$TEST" >/dev/null 2>&1
# $FPATH_BIN verify --verbose "$TEST"
mv "$TEST/$SUBDIR_WITH_SPACES/IOP~.txt" "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/iop.txt"
mv "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/jkl.txt" "$TEST/$SUBDIR_WITH_SPACES/JKL~.txt" 

run_test "$FPATH_BIN index query --verbose $TEST -- c5a8fb450fb0b568fc69a9485b8e531f119ca6e112fe1015d03fceb64b9c0e65" "0" "$(escape_expected "IDX: >48ab83fb303c2bb91a0b15a0a9a1e35b05918f0d482d11f03c30d3be400054d3<: [test/.roh.git/sub-directory with spaces/IOP~.txt.sha256] orphaned hash -- INDEXED.*OK: found -- hash path [$PWD/test/.roh.git/sub-directory with spaces/sub-sub-directory/jkl.txt.sha256].*absolute fpath []")"
run_test "$FPATH_BIN query --db $TEST/.roh.sqlite3 -- 48ab83fb303c2bb91a0b15a0a9a1e35b05918f0d482d11f03c30d3be400054d3" "0" "$(escape_expected "OK: found -- hash path [$PWD/test/.roh.git/sub-directory with spaces/IOP~.txt.sha256].*absolute fpath []")"
run_test "$FPATH_BIN recover --verbose $TEST" "0" "$(escape_expected "IDX: >48ab83fb303c2bb91a0b15a0a9a1e35b05918f0d482d11f03c30d3be400054d3<: [test/sub-directory with spaces/sub-sub-directory/iop.txt] -- written INDEXED.*RECOVER: [48ab83fb303c2bb91a0b15a0a9a1e35b05918f0d482d11f03c30d3be400054d3]: [test/.roh.git/sub-directory with spaces/IOP~.txt.sha256] orphaned hash.*■: DELETED!")"
mv "$TEST/$SUBDIR_WITH_SPACES/JKL~.txt" "$TEST/$SUBDIR_WITH_SPACES/$SUBSUBDIR/jkl.txt" 

# ----

$FPATH_BIN delete --verbose "$TEST" >/dev/null 2>&1
cp -R "$TEST/$SUBDIR_WITH_SPACES" "$TEST/sub-dir copy :slash"
echo "rxn" > "$TEST/$SUBDIR_WITH_SPACES/rxn.txt"

# db doesn't exist at $TEST/sub-dir\ copy\ :slash/.roh.sqlite3
run_test "$FPATH_BIN recover --verbose \"$TEST/$SUBDIR_WITH_SPACES\"" "1" "$(escape_expected "ERROR: [test/$SUBDIR_WITH_SPACES/.roh.sqlite3] -- database file not found")"

echo "XGY" > "$TEST/$SUBDIR_WITH_SPACES/xgy'.txt"
$FPATH_BIN write --verbose "$TEST/$SUBDIR_WITH_SPACES" >/dev/null 2>&1
$FPATH_BIN write --verbose "$TEST/sub-dir copy :slash" >/dev/null 2>&1
mv "$TEST/$SUBDIR_WITH_SPACES" "$TEST/$SUBDIR_WITH_SPACES_RO"
mv "$TEST/sub-dir copy :slash" "$TEST/$SUBDIR_COPY_SLASH_RO"

mv "$TEST/$SUBDIR_WITH_SPACES_RO/rxn.txt" "$TEST/$SUBDIR_WITH_SPACES_RO/rxn-renamed.txt"
run_test "$FPATH_BIN index recover \"$TEST/$SUBDIR_WITH_SPACES_RO\"" "0" "$(escape_expected "IDX: >d64e30c3f3448b7979506807650f9b703f9ea276bbbe64fc56442da1d1a471af<: [test/sub-directory with spaces.ro/rxn-renamed.txt] -- written INDEXED.*RECOVER: [d64e30c3f3448b7979506807650f9b703f9ea276bbbe64fc56442da1d1a471af]: [test/sub-directory with spaces.ro/.roh.git/rxn.txt.sha256] orphaned hash -- DELETED!")"
rm "$TEST/$SUBDIR_WITH_SPACES_RO/.roh.sqlite3"

# $ ./roh.fpath.sh query "test/sub-directory with spaces.ro" -- d64e30c3f3448b7979506807650f9b703f9ea276bbbe64fc56442da1d1a471af
# query hash: [d64e30c3f3448b7979506807650f9b703f9ea276bbbe64fc56442da1d1a471af]
# OK: --      hash path [/Users/dev/Project-@knev/readonlyhash.sh.git/test/sub-directory with spaces.ro/.roh.git/rxn.txt.sha256]
#        absolute fpath []
# OK: --      hash path [/Users/dev/Project-@knev/readonlyhash.sh.git/test/sub-directory with spaces.ro/.roh.git/rxn-renamed.txt.sha256]
#        absolute fpath [/Users/dev/Project-@knev/readonlyhash.sh.git/test/sub-directory with spaces.ro/rxn-renamed.txt]

echo "#RXN#" > "$TEST/$SUBDIR_WITH_SPACES_RO/rxn-new.txt"
run_test "$FPATH_BIN index recover \"$TEST/$SUBDIR_WITH_SPACES_RO\"" "0" "$(escape_expected "WARN: [2a5364040532fd64388c6d6c78f5812d30d499bfffb15be2a822cd0f6fefa872]: [test/sub-directory with spaces.ro/rxn-new.txt] -- NEW!?")"

rm "$TEST/$SUBDIR_WITH_SPACES_RO/rxn-new.txt"
mv "$TEST/$SUBDIR_WITH_SPACES_RO/rxn-renamed.txt" "$TEST/$SUBDIR_WITH_SPACES_RO/rxn.txt"
$FPATH_BIN write sweep --verbose "$TEST/$SUBDIR_WITH_SPACES_RO" >/dev/null 2>&1
rm "$TEST/$SUBDIR_WITH_SPACES_RO/.roh.sqlite3"

# Clean: $TEST/$SUBDIR_WITH_SPACES_RO

### recover_file

# file is found, but at a different path
for i in {11..23}; do
    printf -v num "%02d" "$i"
    mkdir -p "$TEST/$SUBDIR_WITH_SPACES_RO/$SUBSUBDIR/$num"
	cp "$TEST/$SUBDIR_WITH_SPACES_RO/rxn.txt" "$TEST/$SUBDIR_WITH_SPACES_RO/$SUBSUBDIR/$num/rxn.txt"
done
run_test "$FPATH_BIN write index --verbose \"$TEST/$SUBDIR_WITH_SPACES_RO\"" "0" "$(escape_expected " OK: [d64e30c3f3448b7979506807650f9b703f9ea276bbbe64fc56442da1d1a471af]: [test/sub-directory with spaces.ro/sub-sub-directory/15/rxn.txt] -- file hash written.*IDX: >d64e30c3f3448b7979506807650f9b703f9ea276bbbe64fc56442da1d1a471af<: [test/sub-directory with spaces.ro/.roh.git/sub-sub-directory/20/rxn.txt.sha256] -- INDEXED")"
# file is missing, but it was indexed as having a valid fpath -- indexed, but missing
for i in {15..19}; do
    printf -v num "%02d" "$i"
	rm "$TEST/$SUBDIR_WITH_SPACES_RO/$SUBSUBDIR/$num/rxn.txt"
done
# file is missing, indexed as file not found, so fpath == NULL;  orphaned hash
for d in {1..9}; do
	mkdir -p "$TEST/$SUBDIR_WITH_SPACES_RO/.roh.git/$d/"
    printf '%64s\n' | tr ' ' "$d" > "$TEST/$SUBDIR_WITH_SPACES_RO/.roh.git/$d/rxn.txt.sha256"
done
$FPATH_BIN index "$TEST/$SUBDIR_WITH_SPACES_RO" >/dev/null 2>&1
# catalyst
echo "#RXN#" > "$TEST/$SUBDIR_WITH_SPACES_RO/$SUBSUBDIR/rxn.txt"
# verbose
run_test "$FPATH_BIN recover --match-filenames --only-files --verbose \"$TEST/$SUBDIR_WITH_SPACES_RO\"" "0" "$(escape_expected "WARN: [2a5364040532fd64388c6d6c78f5812d30d499bfffb15be2a822cd0f6fefa872]: [test/sub-directory with spaces.ro/sub-sub-directory/rxn.txt] -- NEW!?.*[d64e30c3f3448b7979506807650f9b703f9ea276bbbe64fc56442da1d1a471af]: [$PWD/test/sub-directory with spaces.ro/sub-sub-directory/11/rxn.txt].*[$PWD/test/sub-directory with spaces.ro/sub-sub-directory/19/rxn.txt] -- indexed, but missing.*[9999999999999999999999999999999999999999999999999999999999999999]: [$PWD/test/sub-directory with spaces.ro/.roh.git/9/rxn.txt.sha256] orphaned hash")"
# NOT verbose
run_test "$FPATH_BIN recover -mfn --only-files \"$TEST/$SUBDIR_WITH_SPACES_RO\"" "0" "$(escape_expected "19 more")"

rm -- "$TEST/$SUBDIR_WITH_SPACES_RO/$SUBSUBDIR/"[0-9][0-9]"/rxn.txt"
rmdir -- "$TEST/$SUBDIR_WITH_SPACES_RO/$SUBSUBDIR/"[0-9][0-9]
$FPATH_BIN e "$TEST/$SUBDIR_WITH_SPACES_RO" >/dev/null 2>&1
rm "$TEST/$SUBDIR_WITH_SPACES_RO/$SUBSUBDIR/rxn.txt"
rm "$TEST/$SUBDIR_WITH_SPACES_RO/.roh.sqlite3"

# Clean: $TEST/$SUBDIR_WITH_SPACES_RO

### recover_hash

# diff fpath: same index hash, different location
for i in {11..23}; do
    printf -v num "%02d" "$i"
    mkdir -p "$TEST/$SUBDIR_WITH_SPACES_RO/$SUBSUBDIR/$num"
	cp "$TEST/$SUBDIR_WITH_SPACES_RO/rxn.txt" "$TEST/$SUBDIR_WITH_SPACES_RO/$SUBSUBDIR/$num/rxn.txt"
done
$FPATH_BIN write index "$TEST/$SUBDIR_WITH_SPACES_RO" >/dev/null 2>&1
echo "0000000000000000000000000000000000000000000000000000000000000000" > "$TEST/$SUBDIR_WITH_SPACES_RO/.roh.git/$SUBSUBDIR/15/rxn.txt.$HASH"
# catalyst
rm "$TEST/$SUBDIR_WITH_SPACES_RO/rxn.txt"

# verify IDX
run_test "$FPATH_BIN recover --only-hashes --verbose \"$TEST/$SUBDIR_WITH_SPACES_RO\"" "1" "$(escape_expected "ERROR: [$PWD/test/sub-directory with spaces.ro/.roh.git/sub-sub-directory/15/rxn.txt.sha256] -- IDX inconsistency")"
echo "d64e30c3f3448b7979506807650f9b703f9ea276bbbe64fc56442da1d1a471af" > "$TEST/$SUBDIR_WITH_SPACES_RO/.roh.git/$SUBSUBDIR/15/rxn.txt.$HASH"

# duplicate FOUND
for i in {17..19}; do
    printf -v num "%02d" "$i"
	echo "#RXN#" > "$TEST/$SUBDIR_WITH_SPACES_RO/$SUBSUBDIR/$num/rxn.txt"
done
# we found another orphaned hash, assume the rest of the loop will take care of it
rm "$TEST/$SUBDIR_WITH_SPACES_RO/$SUBSUBDIR/13/rxn.txt"
rm "$TEST/$SUBDIR_WITH_SPACES_RO/$SUBSUBDIR/14/rxn.txt"
rm "$TEST/$SUBDIR_WITH_SPACES_RO/$SUBSUBDIR/21/rxn.txt"
rm "$TEST/$SUBDIR_WITH_SPACES_RO/$SUBSUBDIR/22/rxn.txt"
# verbose
run_test "$FPATH_BIN recover --only-hashes --verbose \"$TEST/$SUBDIR_WITH_SPACES_RO\"" "0" "$(escape_expected "[$PWD/test/sub-directory with spaces.ro/sub-sub-directory/16/rxn.txt] -- duplicate FOUND.*[$PWD/test/sub-directory with spaces.ro/sub-sub-directory/17/rxn.txt] -- hash mismatch:.*■: DELETED!")"
$FPATH_BIN write --force "$TEST/$SUBDIR_WITH_SPACES_RO" >/dev/null 2>&1
rm "$TEST/$SUBDIR_WITH_SPACES_RO/.roh.sqlite3"

# Clean: $TEST/$SUBDIR_WITH_SPACES_RO

echo "rxn" > "$TEST/$SUBDIR_WITH_SPACES_RO/rxn.txt"
for i in {11..23}; do
    printf -v num "%02d" "$i"
    mkdir -p "$TEST/$SUBDIR_WITH_SPACES_RO/$SUBSUBDIR/$num"
	cp "$TEST/$SUBDIR_WITH_SPACES_RO/rxn.txt" "$TEST/$SUBDIR_WITH_SPACES_RO/$SUBSUBDIR/$num/rxn.txt"
done
$FPATH_BIN write index "$TEST/$SUBDIR_WITH_SPACES_RO" >/dev/null 2>&1
# catalyst
rm "$TEST/$SUBDIR_WITH_SPACES_RO/rxn.txt"
# duplicate FOUND
for i in {17..19}; do
    printf -v num "%02d" "$i"
	echo "#RXN#" > "$TEST/$SUBDIR_WITH_SPACES_RO/$SUBSUBDIR/$num/rxn.txt"
done
# we found another orphaned hash, assume the rest of the loop will take care of it
rm "$TEST/$SUBDIR_WITH_SPACES_RO/$SUBSUBDIR/13/rxn.txt"
rm "$TEST/$SUBDIR_WITH_SPACES_RO/$SUBSUBDIR/14/rxn.txt"
rm "$TEST/$SUBDIR_WITH_SPACES_RO/$SUBSUBDIR/21/rxn.txt"
rm "$TEST/$SUBDIR_WITH_SPACES_RO/$SUBSUBDIR/22/rxn.txt"

# NOT verbose
run_test "$FPATH_BIN recover \"$TEST/$SUBDIR_WITH_SPACES_RO\"" "0" "$(escape_expected "RECOVER: [d64e30c3f3448b7979506807650f9b703f9ea276bbbe64fc56442da1d1a471af]: [test/sub-directory with spaces.ro/.roh.git/sub-sub-directory/13/rxn.txt.sha256] orphaned hash -- DELETED!")"
rm -- "$TEST/$SUBDIR_WITH_SPACES_RO/$SUBSUBDIR/"[0-9][0-9]"/rxn.txt"
rmdir -- "$TEST/$SUBDIR_WITH_SPACES_RO/$SUBSUBDIR/"[0-9][0-9]
echo "rxn" > "$TEST/$SUBDIR_WITH_SPACES_RO/rxn.txt"
$FPATH_BIN we "$TEST/$SUBDIR_WITH_SPACES_RO" >/dev/null 2>&1
rm "$TEST/$SUBDIR_WITH_SPACES_RO/.roh.sqlite3"

# Clean: $TEST/$SUBDIR_WITH_SPACES_RO

for i in {14..17}; do
    printf -v num "%02d" "$i"
    mkdir -p "$TEST/$SUBDIR_WITH_SPACES_RO/$SUBSUBDIR/$num"
	echo "#PNO#" > "$TEST/$SUBDIR_WITH_SPACES_RO/$SUBSUBDIR/$num/pno.txt"
done
$FPATH_BIN write index "$TEST/$SUBDIR_WITH_SPACES_RO" >/dev/null 2>&1
# catalyst
rm "$TEST/$SUBDIR_WITH_SPACES_RO/pno.txt"

# run_test "$FPATH_BIN recover --only-hashes --verbose \"$TEST/$SUBDIR_WITH_SPACES_RO\"" "1" "$(escape_expected "ERR: orphaned hash not in IDX [test/sub-directory with spaces.ro/pno.txt] -- file MISSING.*[958b91857252741a9691102780a7eaeefb8aa4922aa9edd9b9357ae30fb30a43]: [$PWD/test/sub-directory with spaces.ro/sub-sub-directory/15/pno.txt]")"

run_test "$FPATH_BIN recover -mfn --only-hashes \"$TEST/$SUBDIR_WITH_SPACES_RO\"" "1" "$(escape_expected "ERROR: [1656fd07685d515a7c4cae4e1cad7a99447d8db7aac1eb2814b2572df0e6181f] -- orphaned hash not in IDX [test/sub-directory with spaces.ro/pno.txt] -- file MISSING.*2 more")"
rm -- "$TEST/$SUBDIR_WITH_SPACES_RO/$SUBSUBDIR/"[0-9][0-9]"/pno.txt"
rmdir -- "$TEST/$SUBDIR_WITH_SPACES_RO/$SUBSUBDIR/"[0-9][0-9]
echo "PNO" > "$TEST/$SUBDIR_WITH_SPACES_RO/pno.txt"
$FPATH_BIN we "$TEST/$SUBDIR_WITH_SPACES_RO" >/dev/null 2>&1
rm "$TEST/$SUBDIR_WITH_SPACES_RO/.roh.sqlite3"

# Clean: $TEST/$SUBDIR_WITH_SPACES_RO


# multiple copies with the same hash (escaping required)
mv "$TEST/$SUBDIR_COPY_SLASH_RO/omn's_.txt" "$TEST/omn's_.txt"
cp "$TEST/omn's_.txt" "$TEST/omn''s_.txt"
cp "$TEST/omn's_.txt" "$TEST/omn'''s_.txt"
cp "$TEST/omn's_.txt" "$TEST/omn''''s_.txt"

$FPATH_BIN index --db $TEST/.roh.sqlite3 --verbose "$TEST/$SUBDIR_WITH_SPACES_RO" >/dev/null 2>&1
$FPATH_BIN index --db $TEST/.roh.sqlite3 --verbose "$TEST/$SUBDIR_COPY_SLASH_RO" >/dev/null 2>&1 # [test/sub-dir copy :slash.ro/.roh.git/omn's_.txt.sha256] -- orphaned hash
run_test "$FPATH_BIN write index $TEST" "1" "$(escape_expected "WARN: [$TEST/$SUBDIR_COPY_SLASH_RO] is a readonlyhash directory -- SKIPPING.*WARN: [$TEST/$SUBDIR_WITH_SPACES_RO] is a readonlyhash directory -- SKIPPING")"

run_test "$FPATH_BIN recover --db $TEST/.roh.sqlite3 --verbose \"$TEST/$SUBDIR_COPY_SLASH_RO\"" "0" "$(escape_expected "... [$PWD/test/sub-directory with spaces.ro/omn's_.txt] -- duplicate FOUND.*■: DELETED!")"

rm "$TEST/omn'''s_.txt"
rm "$TEST/omn''''s_.txt"
$FPATH_BIN write sweep --verbose "$TEST" >/dev/null 2>&1

# orphaned hashes, with found fpath and not found fpath
rm "$TEST/$SUBDIR_COPY_SLASH_RO/$SUBSUBDIR/jkl copy.txt"
# generate an error too
echo "_jkl_" > "$TEST/$SUBDIR_WITH_SPACES_RO/$SUBSUBDIR/jkl copy.txt"

run_test "$FPATH_BIN recover --db $TEST/.roh.sqlite3 --verbose \"$TEST/$SUBDIR_COPY_SLASH_RO\"" "0" "$(escape_expected "[$PWD/test/sub-directory with spaces.ro/sub-sub-directory/jkl copy.txt] -- hash mismatch:.*computed [fcfd9ff0ceaae9e70fa27b6333f0f40a2909c5b4e595062ff399b32a5e9ebfe7].*stored [c5a8fb450fb0b568fc69a9485b8e531f119ca6e112fe1015d03fceb64b9c0e65].*■: DELETED!")"
echo "JKL" > "$TEST/$SUBDIR_WITH_SPACES_RO/$SUBSUBDIR/jkl copy.txt"

# deleted fpath
rm "$TEST/$SUBDIR_WITH_SPACES_RO/pno.txt" 
rm "$TEST/$SUBDIR_COPY_SLASH_RO/pno.txt"
	
run_test "$FPATH_BIN recover --db $TEST/.roh.sqlite3 --verbose \"$TEST/$SUBDIR_COPY_SLASH_RO\"" "1" "$(escape_expected "ERR: orphaned hash not in IDX [test/$SUBDIR_COPY_SLASH_RO/pno.txt] -- file MISSING")"
run_test "$FPATH_BIN recover --db $TEST/.roh.sqlite3 --verbose \"$TEST/$SUBDIR_WITH_SPACES_RO\"" "1" "$(escape_expected "ERR: orphaned hash not in IDX [test/$SUBDIR_WITH_SPACES_RO/pno.txt] -- file MISSING")"
echo "PNO" > "$TEST/$SUBDIR_WITH_SPACES_RO/pno.txt" 
echo "PNO" > "$TEST/$SUBDIR_COPY_SLASH_RO/pno.txt"

# Clean: "$TEST/$SUBDIR_WITH_SPACES_RO" 
# Clean: "$TEST/$SUBDIR_COPY_SLASH_RO"

# force "generated hash not found" in its current location will not produce anything
echo "9dcccfb25c7ed7e3fb5c910d9a28ec8df138a35a2f8f5e15de797a37ae9fe6ec" > "$TEST/$SUBDIR_WITH_SPACES_RO/.roh.git/xgy'.txt.sha256"
run_test "$FPATH_BIN verify --verbose \"$TEST/$SUBDIR_WITH_SPACES_RO\"" "1" "$(escape_expected "ERROR: hash mismatch.*stored [9dcccfb25c7ed7e3fb5c910d9a28ec8df138a35a2f8f5e15de797a37ae9fe6ec]: [test/sub-directory with spaces.ro/.roh.git/xgy'.txt.sha256]")"
echo "4b89c7c236e2422752ebb01e9d8e2aafef94cd1e559ee5dc45ee4b013b535793" > "$TEST/$SUBDIR_WITH_SPACES_RO/.roh.git/xgy'.txt.sha256"

# Clean: "$TEST/$SUBDIR_COPY_SLASH_RO"

# force "generated hash not found" in a different location
# RECOVER [9dccc...] the index will find the original hash and hash location, double check the hashes, but the hashes won't match: FILENAME matches
echo "XGY" >> "$TEST/$SUBDIR_COPY_SLASH_RO/xgy'.txt" # NEW location
echo "XGY" > "$TEST/$SUBDIR_COPY_SLASH_RO/$SUBSUBDIR/xgy'.txt" # NEW location
# catalyst
rm "$TEST/$SUBDIR_WITH_SPACES_RO/xgy'.txt" # orphan the hash
echo "9dcccfb25c7ed7e3fb5c910d9a28ec8df138a35a2f8f5e15de797a37ae9fe6ec" > "$TEST/$SUBDIR_WITH_SPACES_RO/.roh.git/xgy'.txt.sha256" # change the hash
run_test "$FPATH_BIN write index --db $TEST/.roh.sqlite3 --verbose \"$TEST/$SUBDIR_COPY_SLASH_RO\"" "1" "$(escape_expected "OK: [4b89c7c236e2422752ebb01e9d8e2aafef94cd1e559ee5dc45ee4b013b535793]: [test/sub-dir copy :slash.ro/xgy'.txt] -- file hash written.*IDX: >4b89c7c236e2422752ebb01e9d8e2aafef94cd1e559ee5dc45ee4b013b535793<: [test/sub-dir copy :slash.ro/.roh.git/xgy'.txt.sha256] -- INDEXED")"
run_test "$FPATH_BIN recover --match-filenames --db $TEST/.roh.sqlite3 --verbose \"$TEST/$SUBDIR_WITH_SPACES_RO\"" "1" "$(escape_expected "ERR: orphaned hash not in IDX [test/sub-directory with spaces.ro/xgy'.txt] -- file MISSING.*FILENAME matches.*[4b89c7c236e2422752ebb01e9d8e2aafef94cd1e559ee5dc45ee4b013b535793]: [$PWD/test/sub-dir copy :slash.ro/xgy'.txt]")"

# indexed but missing
rm "$TEST/$SUBDIR_COPY_SLASH_RO/$SUBSUBDIR/xgy'.txt" # orphan the hash
run_test "$FPATH_BIN recover --match-filenames --db $TEST/.roh.sqlite3 --verbose \"$TEST/$SUBDIR_WITH_SPACES_RO\"" "1" "$(escape_expected "[/Users/dev/Project-@knev/readonlyhash.sh.git/test/sub-dir copy :slash.ro/sub-sub-directory/xgy'.txt] -- indexed, but missing")"
echo "XGY" >> "$TEST/$SUBDIR_COPY_SLASH_RO/$SUBSUBDIR/xgy'.txt" # orphan the hash

echo "4b89c7c236e2422752ebb01e9d8e2aafef94cd1e559ee5dc45ee4b013b535793" > "$TEST/$SUBDIR_WITH_SPACES_RO/.roh.git/xgy'.txt.sha256"
echo "XGY" >> "$TEST/$SUBDIR_WITH_SPACES_RO/xgy'.txt" # orphan the hash
rm "$TEST/.roh.sqlite3"

# Clean: "$TEST/$SUBDIR_WITH_SPACES_RO" 
# Clean: "$TEST/$SUBDIR_COPY_SLASH_RO"

# change two location AND alter one of the file
mv "$TEST/$SUBDIR_WITH_SPACES_RO/$SUBSUBDIR/iop.txt" "$TEST/$SUBDIR_COPY_SLASH_RO/."
mv "$TEST/$SUBDIR_WITH_SPACES_RO/rxn.txt" "$TEST/$SUBDIR_COPY_SLASH_RO/."
echo "!RXN!" > "$TEST/$SUBDIR_COPY_SLASH_RO/rxn.txt"

mv "$TEST/$SUBDIR_COPY_SLASH_RO/pno.txt" "$TEST/$SUBDIR_WITH_SPACES_RO/pno copy.txt"
mv "$TEST/$SUBDIR_COPY_SLASH_RO/xgy'.txt" "$TEST/$SUBDIR_WITH_SPACES_RO/$SUBSUBDIR/."

# SUBDIR_WITH_SPACES_RO lost $SUBSUBDIR/iop.txt
# SUBDIR_WITH_SPACES_RO lost rxn.txt
# SUBDIR_WITH_SPACES_RO gained pno copy.txt
# SUBDIR_WITH_SPACES_RO gained $SUBSUBDIR/xgy'.txt 

# SUBDIR_COPY_SLASH_RO lost pno.txt
# SUBDIR_COPY_SLASH_RO lost xgy'.txt
# SUBDIR_COPY_SLASH_RO gained iop.txt
# SUBDIR_COPY_SLASH_RO gained rxn.txt # and CHANGED

run_test "$FPATH_BIN verify --verbose --db $TEST/.roh.sqlite3 \"$TEST/$SUBDIR_WITH_SPACES_RO\"" "1" "$(escape_expected "WARN: [1656fd07685d515a7c4cae4e1cad7a99447d8db7aac1eb2814b2572df0e6181f]: [test/sub-directory with spaces.ro/pno copy.txt] -- NEW.*NO corresponding file: [test/sub-directory with spaces.ro/sub-sub-directory/iop.txt]")"
run_test "$FPATH_BIN verify --verbose --db $TEST/.roh.sqlite3 \"$TEST/$SUBDIR_WITH_SPACES_RO\"" "1" "$(escape_expected "WARN: [4b89c7c236e2422752ebb01e9d8e2aafef94cd1e559ee5dc45ee4b013b535793]: [test/sub-directory with spaces.ro/sub-sub-directory/xgy'.txt] -- NEW.*NO corresponding file: [test/sub-directory with spaces.ro/rxn.txt]")"

run_test "$FPATH_BIN verify --verbose --db $TEST/.roh.sqlite3 \"$TEST/$SUBDIR_COPY_SLASH_RO\"" "1" "$(escape_expected "WARN: [48ab83fb303c2bb91a0b15a0a9a1e35b05918f0d482d11f03c30d3be400054d3]: [test/sub-dir copy :slash.ro/iop.txt] -- NEW.*NO corresponding file: [test/sub-dir copy :slash.ro/pno.txt]")"
run_test "$FPATH_BIN verify --verbose --db $TEST/.roh.sqlite3 \"$TEST/$SUBDIR_COPY_SLASH_RO\"" "1" "$(escape_expected "WARN: [e251ad71d0c88bf9ec02f9de65edd8e07655ab946e1014e6181077ee27f7c580]: [test/sub-dir copy :slash.ro/rxn.txt] -- NEW.*NO corresponding file: [test/sub-dir copy :slash.ro/xgy'.txt]")"

$FPATH_BIN index --verbose --db $TEST/.roh.sqlite3 "$TEST/$SUBDIR_WITH_SPACES_RO" >/dev/null 2>&1
$FPATH_BIN index --verbose --db $TEST/.roh.sqlite3 "$TEST/$SUBDIR_COPY_SLASH_RO" >/dev/null 2>&1

# run_test "$FPATH_BIN query --db $TEST/.roh.sqlite3 -- 1656fd07685d515a7c4cae4e1cad7a99447d8db7aac1eb2814b2572df0e6181f" "0" "$(escape_expected "ERROR:")" "true" # pno
# run_test "$FPATH_BIN query --db $TEST/.roh.sqlite3 -- 4b89c7c236e2422752ebb01e9d8e2aafef94cd1e559ee5dc45ee4b013b535793" "0" "$(escape_expected "ERROR:")" "true" # xgy
# run_test "$FPATH_BIN query --db $TEST/.roh.sqlite3 -- d64e30c3f3448b7979506807650f9b703f9ea276bbbe64fc56442da1d1a471af" "0" "$(escape_expected "ERROR:")" "true" # rxn
# run_test "$FPATH_BIN query --db $TEST/.roh.sqlite3 -- 48ab83fb303c2bb91a0b15a0a9a1e35b05918f0d482d11f03c30d3be400054d3" "0" "$(escape_expected "ERROR:")" "true" # iop

# if I were to do a recover of each RO dir, then the file pass of recover would write and index files under the assumption that the maintanence phaes would remove the orphaned hash
# BUT, the orphaned hash is in another RO dir, so it would require that a recover is done on that RO dir too AND then another recover for the files that recover wrote and indexed

run_test "$FPATH_BIN recover --only-files --db $TEST/.roh.sqlite3 --verbose \"$TEST/$SUBDIR_WITH_SPACES_RO\"" "0" "$(escape_expected "OK: [1656fd07685d515a7c4cae4e1cad7a99447d8db7aac1eb2814b2572df0e6181f]: [test/sub-directory with spaces.ro/pno copy.txt] -- file hash written.*IDX: >1656fd07685d515a7c4cae4e1cad7a99447d8db7aac1eb2814b2572df0e6181f<: [test/sub-directory with spaces.ro/pno copy.txt] -- written INDEXED")"
cp "$TEST/$SUBDIR_WITH_SPACES_RO/.roh.git/$SUBSUBDIR/iop.txt.sha256" "$TEST/iop.txt.sha256" # take a copy, because it will get clobbered
run_test "$FPATH_BIN recover --db $TEST/.roh.sqlite3 --verbose \"$TEST/$SUBDIR_WITH_SPACES_RO\"" "1" "$(escape_expected "RECOVER: [1656fd07685d515a7c4cae4e1cad7a99447d8db7aac1eb2814b2572df0e6181f]: [$TEST/$SUBDIR_COPY_SLASH_RO/.roh.git/pno.txt.sha256] orphaned hash.*■: DELETED!")" "true"
mv "$TEST/iop.txt.sha256" "$TEST/$SUBDIR_WITH_SPACES_RO/.roh.git/$SUBSUBDIR/iop.txt.sha256" 
rm "$TEST/$SUBDIR_WITH_SPACES_RO/.roh.git/pno copy.txt.$HASH"

# A better approach is to "write index" of both RO directories and then do the cross RO directory recover. --only-hashes is ok, because we have written all files.

rm "$TEST/.roh.sqlite3"
$FPATH_BIN wi --verbose --db $TEST/.roh.sqlite3 "$TEST/$SUBDIR_WITH_SPACES_RO" >/dev/null 2>&1
$FPATH_BIN wi --verbose --db $TEST/.roh.sqlite3 "$TEST/$SUBDIR_COPY_SLASH_RO" >/dev/null 2>&1

run_test "$FPATH_BIN query --db $TEST/.roh.sqlite3 -- e251ad71d0c88bf9ec02f9de65edd8e07655ab946e1014e6181077ee27f7c580" "0" "$(escape_expected "ERROR:")" "true" # xgy NEW

# should find the indexed hash for iop, BUT rxn changed, so it should NOT remove that hash
run_test "$FPATH_BIN recover --only-hashes --db $TEST/.roh.sqlite3 --verbose \"$TEST/$SUBDIR_WITH_SPACES_RO\"" "1" "$(escape_expected "RECOVER: [d64e30c3f3448b7979506807650f9b703f9ea276bbbe64fc56442da1d1a471af]: [test/sub-directory with spaces.ro/.roh.git/rxn.txt.sha256] orphaned hash.*file MISSING")"

# should find indexed hashes for pno and xgy AND remove the orphaned hashes
run_test "$FPATH_BIN recover --only-hashes --db $TEST/.roh.sqlite3 --verbose \"$TEST/$SUBDIR_COPY_SLASH_RO\"" "0" "$(escape_expected "■: DELETED!.*■: DELETED!")"

mv "$TEST/$SUBDIR_COPY_SLASH_RO/iop.txt" "$TEST/$SUBDIR_WITH_SPACES_RO/$SUBSUBDIR/." 
mv "$TEST/$SUBDIR_COPY_SLASH_RO/rxn.txt" "$TEST/$SUBDIR_WITH_SPACES_RO/." 
echo "rxn" > "$TEST/$SUBDIR_WITH_SPACES_RO/rxn.txt"
mv "$TEST/$SUBDIR_WITH_SPACES_RO/pno copy.txt" "$TEST/$SUBDIR_COPY_SLASH_RO/pno.txt" 
mv "$TEST/$SUBDIR_WITH_SPACES_RO/$SUBSUBDIR/xgy'.txt" "$TEST/$SUBDIR_COPY_SLASH_RO/." 
$FPATH_BIN we --verbose "$TEST/$SUBDIR_WITH_SPACES_RO" >/dev/null 2>&1
$FPATH_BIN we --verbose "$TEST/$SUBDIR_COPY_SLASH_RO" >/dev/null 2>&1
rm "$TEST/.roh.sqlite3"

# Clean: "$TEST/$SUBDIR_WITH_SPACES_RO" 
# Clean: "$TEST/$SUBDIR_COPY_SLASH_RO"

# this should not produce anythign, because from the perspective of this recover it is a just a new file
echo "mju" > "$TEST/$SUBDIR_COPY_SLASH_RO/mju.txt"
run_test "$FPATH_BIN ir --db $TEST/.roh.sqlite3 --verbose \"$TEST/$SUBDIR_COPY_SLASH_RO\"" "0" "$(escape_expected "RECOVER")" "true"
rm "$TEST/$SUBDIR_COPY_SLASH_RO/mju.txt"

# make sure empty hash dirs are removed during recover
mv "$TEST/$SUBDIR_COPY_SLASH_RO/$SUBSUBDIR/iop.txt" "$TEST/$SUBDIR_COPY_SLASH_RO/."
mv "$TEST/$SUBDIR_COPY_SLASH_RO/$SUBSUBDIR/jkl.txt" "$TEST/$SUBDIR_COPY_SLASH_RO/."
rm "$TEST/$SUBDIR_COPY_SLASH_RO/$SUBSUBDIR/xgy'.txt"
$FPATH_BIN index recover "$TEST/$SUBDIR_COPY_SLASH_RO" >/dev/null 2>&1
run_test "ls -al \"$TEST/$SUBDIR_COPY_SLASH_RO/.roh.git/$SUBSUBDIR\"" "1" "$TEST/$SUBDIR_COPY_SLASH_RO/.roh.git/$SUBSUBDIR.?: No such file or directory"
mv "$TEST/$SUBDIR_COPY_SLASH_RO/iop.txt" "$TEST/$SUBDIR_COPY_SLASH_RO/$SUBSUBDIR/."
mv "$TEST/$SUBDIR_COPY_SLASH_RO/jkl.txt" "$TEST/$SUBDIR_COPY_SLASH_RO/$SUBSUBDIR/."
rm "$TEST/$SUBDIR_COPY_SLASH_RO/.roh.sqlite3"
$FPATH_BIN index recover "$TEST/$SUBDIR_COPY_SLASH_RO" >/dev/null 2>&1
rm "$TEST/$SUBDIR_COPY_SLASH_RO/.roh.sqlite3"
 
#rm "$TEST/$SUBDIR_WITH_SPACES_RO/rxn.txt"
#run_test "$FPATH_BIN index recover --verbose \"$TEST/$SUBDIR_WITH_SPACES_RO\"" "1" "$(escape_expected "... [$PWD/test/sub-directory with spaces.ro/rxn.txt] -- indexed, but missing")"

rm "$TEST/.roh.sqlite3"
$FPATH_BIN index --verbose --db $TEST/.roh.sqlite3 "$TEST/$SUBDIR_COPY_SLASH_RO" >/dev/null 2>&1

rm "$TEST/$SUBDIR_WITH_SPACES_RO/rxn.txt"
run_test "$FPATH_BIN recover --db $TEST/.roh.sqlite3 --verbose \"$TEST/$SUBDIR_WITH_SPACES_RO\"" "1" "$(escape_expected "ERR: orphaned hash not in IDX [test/sub-directory with spaces.ro/rxn.txt] -- file MISSING")"
rm "test/$SUBDIR_WITH_SPACES_RO/.roh.git/rxn.txt.sha256"
rm "$TEST/.roh.sqlite3"

rm "$TEST/omn's_.txt"
rm "$TEST/omn''s_.txt"
$FPATH_BIN sweep --verbose "$TEST" >/dev/null 2>&1

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
chmod 000 "$ROH_DIR"
run_test "$FPATH_BIN show $TEST" "1" "$(escape_expected "ERROR: [test/.roh.git] -- missing or inaccessible.*Abort.")"
chmod 755 "$ROH_DIR"

# equal hashes on both sides: show should silently move, no --force needed
cp "$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256"
run_test "$FPATH_BIN show --verbose $TEST" "0" "$(escape_expected "OK: [$TEST/file with spaces.txt]: [test/file with spaces.txt.sha256] hash file -- moved(shown)")"

# restore hidden, then write a DIFFERENT hash to the shown side to exercise the mismatch-ERROR path
cp "$TEST/file with spaces.txt.sha256" "$ROH_DIR/file with spaces.txt.sha256"
echo "0000000000000000000000000000000000000000000000000000000000000000" > "$TEST/file with spaces.txt.sha256"
run_test "$FPATH_BIN show $TEST" "1" "$(escape_expected "ERROR: [test/file with spaces.txt] -- not moving/(not shown).*destination [test/file with spaces.txt.sha256] -- exists.*for source [test/.roh.git/file with spaces.txt.sha256]")"
run_test "$FPATH_BIN show sweep --verbose --force $TEST" "0" "$(escape_expected "OK: [$TEST/file with spaces.txt]: [test/file with spaces.txt.sha256] hash file -- moved(shown)")"
run_test "ls -alR $ROH_DIR" "1" "$ROH_DIR.?: No such file or directory"

run_test "$FPATH_BIN index $TEST" "1" "$(escape_expected "ERROR: nothing to index [test/.roh.git]")"

run_test "$FPATH_BIN hide --verbose $TEST" "0" "$(escape_expected "OK: [$TEST/file with spaces.txt]: [$ROH_DIR/file with spaces.txt.sha256] hash file -- moved(hidden)")"

mv "$ROH_DIR/file with spaces.txt.sha256" "$TEST/file with spaces.txt.sha256"
run_test "$FPATH_BIN show --verbose $TEST" "0" "$(escape_expected "OK: [test/file with spaces.txt]: [test/file with spaces.txt.sha256] hash file already exists(shown) -- nothing to move(show), NOOP")"

rm "$TEST/file with spaces.txt.sha256"
run_test "$FPATH_BIN hide $TEST" "1" "$(escape_expected "ERROR: [test/file with spaces.txt]: [test/file with spaces.txt.sha256] hash file -- NOT found, not hidden")"
$FPATH_BIN write "$TEST" >/dev/null 2>&1

# worst case
echo
echo "# worst case"

mv "$ROH_DIR/file with spaces.txt.$HASH" "$TEST/file with spaces.txt.$HASH" 
$FPATH_BIN hide "$TEST" >/dev/null 2>&1
run_test "$FPATH_BIN verify $TEST" "0" "$(escape_expected "ERROR: ")" "true"

# process_directory()
echo
echo "# process_directory()"

run_test "$FPATH_BIN write --verbose $TEST" "0" "$(escape_expected "WARN: [test/$SUBDIR_COPY_SLASH_RO] is a readonlyhash directory -- SKIPPING.*WARN: [test/$SUBDIR_WITH_SPACES_RO] is a readonlyhash directory -- SKIPPING")"
run_test "$FPATH_BIN verify --verbose $TEST" "0" "$(escape_expected "OK: [349cac0f5dfc74f7e03715cdca2cf2616fb5506e9c7fa58ac0e70a6a0426ecff]: [test/file with spaces.txt].*WARN: [test/$SUBDIR_COPY_SLASH_RO] is a readonlyhash directory -- SKIPPING.*WARN: [test/$SUBDIR_WITH_SPACES_RO] is a readonlyhash directory -- SKIPPING")"

$GIT_BIN -zC "$TEST/$SUBDIR_COPY_SLASH_RO" >/dev/null 2>&1
run_test "$FPATH_BIN verify --verbose $TEST" "0" "$(escape_expected "WARN: [test/$SUBDIR_COPY_SLASH_RO] is a readonlyhash directory -- SKIPPING.*WARN: [test/$SUBDIR_WITH_SPACES_RO] is a readonlyhash directory -- SKIPPING")"
$GIT_BIN -xC "$TEST/$SUBDIR_COPY_SLASH_RO" >/dev/null 2>&1

touch "$TEST/file with spaces.rslsz"
run_test "$FPATH_BIN write $TEST" "1" "$(escape_expected "ERROR: [$TEST] \"file with spaces.rslsz\" -- file with restricted extension")"

run_test "$FPATH_BIN delete sweep $TEST" "0" "$(escape_expected "ERROR: [$TEST] \"file with spaces.rslsz\" -- file with restricted extension")" "true"
rm "$TEST/file with spaces.rslsz"
 
#	mkdir -p "$ROH_DIR"
#	touch "$ROH_DIR/file with spaces.txt.sha256~"
#	run_test "$FPATH_BIN -d $TEST" "1" "Directory [test/$ROH_DIR] not empty" 
	
#	rm "$ROH_DIR/file with spaces.txt.sha256~"
#	run_test "$FPATH_BIN -d $TEST" "0" "Directory [test/$ROH_DIR] not empty" "true"

# Clean up test files
echo
echo "# Clean up test files"

rm "$TEST/$SUBDIR_COPY_SLASH_RO/$SUBSUBDIR/jkl.txt"
rm "$TEST/$SUBDIR_COPY_SLASH_RO/$SUBSUBDIR/iop.txt"
rmdir "$TEST/$SUBDIR_COPY_SLASH_RO/$SUBSUBDIR"
rm "$TEST/$SUBDIR_COPY_SLASH_RO/pno.txt"
rm "$TEST/$SUBDIR_COPY_SLASH_RO/xgy'.txt"
rm -rf "$TEST/$SUBDIR_COPY_SLASH_RO/.roh.logs"
rm -rf "$TEST/$SUBDIR_COPY_SLASH_RO/.roh.git"
rmdir "$TEST/$SUBDIR_COPY_SLASH_RO"

rm "$TEST/$SUBDIR_WITH_SPACES_RO/$SUBSUBDIR/jkl copy.txt"
rm "$TEST/$SUBDIR_WITH_SPACES_RO/$SUBSUBDIR/jkl.txt"
rm "$TEST/$SUBDIR_WITH_SPACES_RO/$SUBSUBDIR/iop.txt"
rmdir "$TEST/$SUBDIR_WITH_SPACES_RO/$SUBSUBDIR"
rm "$TEST/$SUBDIR_WITH_SPACES_RO/xgy'.txt"
rm "$TEST/$SUBDIR_WITH_SPACES_RO/omn's_.txt"
rm "$TEST/$SUBDIR_WITH_SPACES_RO/pno.txt"
rm -rf "$TEST/$SUBDIR_WITH_SPACES_RO/.roh.logs"
rm -rf "$TEST/$SUBDIR_WITH_SPACES_RO/.roh.git"
rmdir "$TEST/$SUBDIR_WITH_SPACES_RO"

find "$TEST" -name '.DS_Store' -type f -delete
rm -rf "$ROH_DIR/.git"
rm "$ROH_DIR/.gitignore"
rmdir "$ROH_DIR"

$FPATH_BIN delete "$TEST" >/dev/null 2>&1
rm "$TEST/file with spaces.txt"
rm -rf "$TEST/.roh.git" "$TEST/.roh.logs"
rm -f "$TEST/.roh.git.zip~"
rmdir "$TEST"

run_test "ls -alR $TEST" "1" "$TEST.?: No such file or directory"
