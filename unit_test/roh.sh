#! /bin/echo Please-source

# Path to the hash script
ROH_BIN="./readonlyhash.sh"
chmod +x $ROH_BIN
FPATH_BIN="./roh.fpath.sh"
chmod +x $FPATH_BIN
GIT_BIN="./roh.git.sh"
chmod +x $GIT_BIN
fpath="Fotos.loop.txt"
fpath_ro="Fotos~ro.loop.txt"
fpath_ro_ro="Fotos~ro~ro.loop.txt"
TARGET="_target~"

HASH="sha256"
ROH_DIR=".roh.git"

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
echo "# unit_test: roh.sh"

rm -rf "__MACOSX"
rm -rf "2002" >/dev/null 2>&1
rm -rf "2002.ro" >/dev/null 2>&1
rm -rf "Fotos [space]" >/dev/null 2>&1
rm -rf "$TARGET"
unzip Fotos.zip >/dev/null 2>&1
rm -rf "__MACOSX"

rm "$fpath" >/dev/null 2>&1
rm "$fpath_ro" >/dev/null 2>&1

# init
echo
echo "# init"

$FPATH_BIN write --hash Fotos\ \[space\]/2003/2003-11-29\ Digital\ Reality/* >/dev/null 2>&1
run_test "$ROH_BIN init --directory Fotos\ \[space\]/2003" "0" "ERROR" "true"
rm -rf "Fotos [space]/2003.ro/$ROH_DIR"
#mv "Fotos [space]/2003.ro" "Fotos [space]/2003"
run_test "ls -al Fotos\ \[space\]/2003~ro.loop.txt" "0" "$(escape_expected "Fotos [space]/2003~ro.loop.txt" "0")"
rm "Fotos [space]/2003~ro.loop.txt"

echo "$PWD/Fotos/2003" > "$fpath"
run_test "$ROH_BIN init $fpath" "1" "$(escape_expected "ERROR: Directory [$PWD/Fotos/2003] does not exist.")"
run_test "ls -al $fpath_ro" "0" "$fpath_ro"
rm "$fpath_ro"

echo "$PWD/Fotos [space]/1999" > "$fpath"
echo "$PWD/2002" >> "$fpath"
run_test "$ROH_BIN init $fpath" "0" "Initialized empty Git repository"
run_test "ls -al $fpath_ro" "0" "$fpath_ro"
rm "$fpath"
run_test "$GIT_BIN -C $PWD/Fotos\ \[space\]/1999.ro status" "0" "nothing to commit, working tree clean"
run_test "$GIT_BIN -C $PWD/2002.ro status" "0" "nothing to commit, working tree clean"

run_test "$ROH_BIN init $fpath_ro --resume-at 2002" "0" "$(escape_expected "  OK: directory entry [$PWD/Fotos [space]/1999.ro] -- SKIPPING")"

run_test "$ROH_BIN init $fpath_ro" "0" "Initialized empty Git repository" "true"
run_test "ls -al $fpath_ro_ro" "1" "ls: $fpath_ro_ro: No such file or directory" 
run_test "$ROH_BIN init $fpath_ro" "0" "Archived .roh.git to.* _.roh.git.zip" "true"
run_test "ls -al $fpath_ro_ro" "1" "ls: $fpath_ro_ro: No such file or directory" 

# archive
echo
echo "# archive"

$FPATH_BIN show "$PWD"/2002.ro >/dev/null 2>&1
run_test "$ROH_BIN archive $fpath_ro" "1" "$(escape_expected "WARN: hashes not exclusively hidden in [$PWD/2002.ro/.roh.git].*ERROR: local repo [$PWD/2002.ro/.roh.git] not clean")"

$FPATH_BIN hide "$PWD"/2002.ro >/dev/null 2>&1
run_test "$ROH_BIN archive $fpath_ro" "0" "$(escape_expected "SKIP: directory [$PWD/Fotos [space]/1999.ro] -- [$PWD/Fotos [space]/1999.ro/_.roh.git.zip] exists.*Archived [.roh.git] to [$PWD/2002.ro/_.roh.git.zip].*Removed [$PWD/2002.ro/.roh.git]")"

run_test "ls -al $PWD/Fotos\ \[space\]/1999.ro/_.roh.git.zip" "0" "$(escape_expected "$PWD/Fotos [space]/1999.ro/_.roh.git.zip")"
run_test "ls -al $PWD/2002.ro/_.roh.git.zip" "0" "$(escape_expected "$PWD/2002.ro/_.roh.git.zip")"

# verify/extract
echo
echo "# verify/extract"

run_test "$ROH_BIN verify $fpath_ro" "0" "ERROR" "true"
run_test "$ROH_BIN verify $fpath_ro" "0" "$(escape_expected "On branch master.*nothing to commit, working tree clean.*Removed [/var/folders/.*/tmp.*].*On branch master.*nothing to commit, working tree clean.*Removed [/var/folders/.*/tmp.*]")"

run_test "$ROH_BIN extract $fpath_ro" "0" "ERROR" "true"
run_test "$ROH_BIN verify $fpath_ro" "0" "ERROR" "true"
run_test "$ROH_BIN verify $fpath_ro" "0" "$(escape_expected "Removed [/var/folders/.*/tmp.*].*Removed [/var/folders/.*/tmp.*]")" "true"
run_test "$ROH_BIN verify $fpath_ro" "0" "$(escape_expected "Done..*On branch master.*nothing to commit, working tree clean.*Done..*On branch master.*nothing to commit, working tree clean")"

echo "0000000000000000000000000000000000000000000000000000000000000000" > "2002.ro/$ROH_DIR/2002_FIRE!/Untitled-001.jpg.$HASH"
run_test "$ROH_BIN verify $fpath_ro" "1" "$(escape_expected "ERROR: -- hash mismatch:.* stored [0000000000000000000000000000000000000000000000000000000000000000][$PWD/2002.ro/.roh.git/2002_FIRE!/Untitled-001.jpg.sha256].* computed [816d2fd63482855aaadd92294ef84c4a415945df194734c8834e06dd57538dc4][$PWD/2002.ro/2002_FIRE!/Untitled-001.jpg]")"
echo "816d2fd63482855aaadd92294ef84c4a415945df194734c8834e06dd57538dc4" > "2002.ro/$ROH_DIR/2002_FIRE!/Untitled-001.jpg.$HASH"

echo "0000000000000000000000000000000000000000000000000000000000000000" > "2002.ro/$ROH_DIR/2002_FIRE!/.SECRET_FILE"
run_test "$ROH_BIN verify $fpath_ro" "1" "$(escape_expected "ERROR: local repo [$PWD/2002.ro/$ROH_DIR] not clean")"
rm "2002.ro/$ROH_DIR/2002_FIRE!/.SECRET_FILE"

run_test "$ROH_BIN verify $fpath_ro" "0" "ERROR" "true"

# fpath_ro
# $PWD/Fotos [space]/1999.ro
# $PWD/2002.ro
# 1]	$PWD/Fotos [space]/1999
# 1]	$PWD/2002
# 2]		$PWD
# 2]		; Fotos [space]/1999
# 2]		; 2002
# 3]			$PWD/_target~/Fotos [space]/1999
# 3]			$PWD/_target~/2002
# 
# _target~
# $PWD/_target~/

unzip Fotos.zip -d $TARGET >/dev/null 2>&1
rm -rf "$TARGET/__MACOSX"
run_test "$ROH_BIN verify --new-target $TARGET $fpath_ro" "0" "ERROR" "true"

run_test "$ROH_BIN transfer --new-target $TARGET $fpath_ro" "0" "$(escape_expected "Moved [$PWD/Fotos [space]/1999.ro/.roh.git] to [$PWD/_target~/Fotos [space]/1999/.].*Moved [$PWD/2002.ro/.roh.git] to [$PWD/_target~/2002/.]")"
run_test "$ROH_BIN verify $fpath_ro_ro" "0" "ERROR" "true"
rm -rf "$TARGET"

# Clean up test files
echo
echo "# Clean up test files"

rm -rf "2002.ro" >/dev/null 2>&1
rm -rf "Fotos [space]/1999.ro" >/dev/null 2>&1
rm -rf "Fotos [space]/2003.ro" >/dev/null 2>&1
rm "Fotos [space]/.DS_Store"
rmdir "Fotos [space]"
rm "$fpath_ro"
rm "$fpath_ro_ro" >/dev/null 2>&1

run_test "ls -alR 2002.ro" "1" "$(escape_expected "ls: 2002.ro: No such file or directory")"
run_test "ls -alR Fotos\ \[space\]" "1" "$(escape_expected "ls: Fotos [space]: No such file or directory")"
run_test "ls -alR $TARGET" "1" "$(escape_expected "ls: $TARGET: No such file or directory")"

echo 
