#! /bin/echo Please-source

# Path to the hash script
LOOP_SCRIPT="./readonlyhash.sh"
ROH_GIT="roh.git"
chmod +x $LOOP_SCRIPT
fpath="Fotos.loop.txt"
fpath_ro="Fotos~.loop.txt"
fpath_ro_ro="Fotos~~.loop.txt"

HASH="sha256"
ROH_DIR=".roh.git"

# Loop script 
echo
echo "# Loop script"

rm -rf "__MACOSX"
rm -rf "2002" >/dev/null 2>&1
rm -rf "2002.ro" >/dev/null 2>&1
rm -rf "Fotos [space]" >/dev/null 2>&1
unzip Fotos.zip >/dev/null 2>&1
rm -rf "__MACOSX"

rm "$fpath" >/dev/null 2>&1
rm "$fpath_ro" >/dev/null 2>&1

run_test "$LOOP_SCRIPT init -d /Users/dev/Project-@knev/readonlyhash.sh.git/Fotos\ \[space\]/2003" "0" "ERROR" "true"

echo "/Users/dev/Project-@knev/readonlyhash.sh.git/Fotos/2003" > "$fpath"
run_test "$LOOP_SCRIPT init $fpath" "1" "$(escape_expected "ERROR: Directory [/Users/dev/Project-@knev/readonlyhash.sh.git/Fotos/2003] does not exist.")"
run_test "ls -al $fpath_ro" "0" "$fpath_ro"
rm "$fpath_ro"

echo "/Users/dev/Project-@knev/readonlyhash.sh.git/Fotos [space]/1999" > "$fpath"
echo "/Users/dev/Project-@knev/readonlyhash.sh.git/2002" >> "$fpath"
run_test "$LOOP_SCRIPT init $fpath" "0" "Initialized empty Git repository"
run_test "ls -al $fpath_ro" "0" "$fpath_ro"
rm "$fpath"
run_test "ls -al /Users/dev/Project-@knev/readonlyhash.sh.git/Fotos\ \[space\]/1999.ro/_.roh.git.zip" "0" "$(escape_expected "/Users/dev/Project-@knev/readonlyhash.sh.git/Fotos [space]/1999.ro/_.roh.git.zip")"
run_test "ls -al /Users/dev/Project-@knev/readonlyhash.sh.git/2002.ro/_.roh.git.zip" "0" "$(escape_expected "/Users/dev/Project-@knev/readonlyhash.sh.git/2002.ro/_.roh.git.zip")"
run_test "$ROH_GIT -C /Users/dev/Project-@knev/readonlyhash.sh.git/Fotos\ \[space\]/1999.ro status" "0" "nothing to commit, working tree clean"
run_test "$ROH_GIT -C /Users/dev/Project-@knev/readonlyhash.sh.git/2002.ro status" "0" "nothing to commit, working tree clean"

run_test "$LOOP_SCRIPT init $fpath_ro" "0" "Initialized empty Git repository" "true"
run_test "ls -al $fpath_ro_ro" "1" "ls: $fpath_ro_ro: No such file or directory" 
run_test "$LOOP_SCRIPT init $fpath_ro" "0" "Archived .roh.git to.* _.roh.git.zip" "true"
run_test "ls -al $fpath_ro_ro" "1" "ls: $fpath_ro_ro: No such file or directory" 

echo "0000000000000000000000000000000000000000000000000000000000000000" > "2002.ro/$ROH_DIR/2002_FIRE!/Untitled-001.jpg.$HASH"
run_test "$LOOP_SCRIPT verify $fpath_ro" "1" "$(escape_expected "\"Untitled-001.jpg\" -- hash mismatch:.* stored [0000000000000000000000000000000000000000000000000000000000000000].* verify] failed for directory")"
echo "816d2fd63482855aaadd92294ef84c4a415945df194734c8834e06dd57538dc4" > "2002.ro/$ROH_DIR/2002_FIRE!/Untitled-001.jpg.$HASH"

echo "0000000000000000000000000000000000000000000000000000000000000000" > "2002.ro/$ROH_DIR/2002_FIRE!/.SECRET_FILE"
run_test "$LOOP_SCRIPT verify $fpath_ro" "1" "$(escape_expected "ERROR: local repo [/Users/dev/Project-@knev/readonlyhash.sh.git/2002.ro/$ROH_DIR] not clean")"
rm "2002.ro/$ROH_DIR/2002_FIRE!/.SECRET_FILE"

run_test "$LOOP_SCRIPT verify $fpath_ro" "0" "ERROR" "true"


exit

# Clean up test files
echo
echo "# Clean up test files"

rm -rf "2002.ro" >/dev/null 2>&1
rm -rf "Fotos [space]/1999.ro" >/dev/null 2>&1
rm -rf "Fotos [space]/2003.ro" >/dev/null 2>&1
rm "Fotos [space]/.DS_Store"
rmdir "Fotos [space]"
rm "$fpath_ro"

run_test "ls -alR 2002.ro" "1" "$(escape_expected "ls: 2002.ro: No such file or directory")"
run_test "ls -alR Fotos\ \[space\]" "1" "$(escape_expected "ls: Fotos [space]: No such file or directory")"

