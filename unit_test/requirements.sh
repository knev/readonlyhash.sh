#! /bin/echo Please-source

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
echo "# unit_test: requirements.sh"

rm -rf "$TEST.ro"
TEST="test.ro"
SUBDIR="subdir"
rm -rf "$TEST"
mkdir "$TEST"

pushd "$TEST" >/dev/null 2>&1

ROH_DIR="./.roh.git"
mkdir -p "$ROH_DIR"
ROH_SCRIPT="../roh.fpath.sh"
GIT_BIN="../roh.git.sh"
HASH="sha256"

# roh.git
echo
echo "# roh.git"

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

$ROH_SCRIPT write >/dev/null 2>&1
$GIT_BIN add *.sha256 >/dev/null 2>&1
$GIT_BIN commit -m "File Added" >/dev/null 2>&1
echo "four" > "four.txt"
# roh will report files that don't have a corresponding hash file
run_test "$ROH_SCRIPT verify" "0" "$(escape_expected "WARN: --.* hash file [./.roh.git/four.txt.sha256] -- NOT found.* for [./four.txt][ab929fcd5594037960792ea0b98caf5fdaf6b60645e4ef248c28db74260f393e]")"

$ROH_SCRIPT write >/dev/null 2>&1
# git will show hashes that are untracked
run_test "$GIT_BIN -C "." status" "0" "four.txt.sha256"

# File Modified 
echo
echo "# File Modified: Content of a file is altered, which updates the file's last modified timestamp"

echo "six" > "two.txt"
run_test "$ROH_SCRIPT verify" "1" "$(escape_expected "ERROR: -- hash mismatch:.* stored [27dd8ed44a83ff94d557f9fd0412ed5a8cbca69ea04922d88c01184a07300a5a][$ROH_DIR/two.txt.sha256].* computed [fe2547fe2604b445e70fc9d819062960552f9145bdb043b51986e478a4806a2b][./two.txt]")"
echo "two" > "two.txt"

# File Removed 
echo
echo "# File Removed: A file is deleted from the directory"

rm "four.txt"
run_test "$ROH_SCRIPT verify" "1" "$(escape_expected "ERROR: --.* file [./four.txt] -- NOT found.* for corresponding hash [./.roh.git/four.txt.sha256][ab929fcd5594037960792ea0b98caf5fdaf6b60645e4ef248c28db74260f393e]")"

# remove orphaned hashes (in bulk)
run_test "$ROH_SCRIPT show" "1" "$(escape_expected "ERROR: --.*file [./four.txt] -- NOT found.* for corresponding hash [./.roh.git/four.txt.sha256][ab929fcd5594037960792ea0b98caf5fdaf6b60645e4ef248c28db74260f393e]")"
# it should be safe to remove the hashes (!NOT the ROH_DIR!), because hashes have been moved next to files, but we don't want to kill the git repo
run_test "rm -v $ROH_DIR/*.sha256" "0" ".roh.git/four.txt.sha256"
run_test "$ROH_SCRIPT hide" "0" "$(escape_expected "ERROR:.* NO file.* found for corresponding hash")" "true"

# File Renamed 
echo
echo "# File Renamed: The name of a file is changed"
# File Moved 
echo "# File Moved: A file is moved either within the directory or outside of it"

mv "five.txt" "seven.txt"
run_test "$ROH_SCRIPT verify" "1" "$(escape_expected "WARN: --.* hash file [./.roh.git/seven.txt.sha256] -- NOT found.* for [./seven.txt][ac169f9fb7cb48d431466d7b3bf2dc3e1d2e7ad6630f6b767a1ac1801c496b35].*ERROR: --.* file [./five.txt] -- NOT found.* for corresponding hash [./.roh.git/five.txt.sha256][ac169f9fb7cb48d431466d7b3bf2dc3e1d2e7ad6630f6b767a1ac1801c496b35]")"
run_test "$ROH_SCRIPT recover" "0" "$(escape_expected "Recovered: --          hash in [./.roh.git/five.txt.sha256][ac169f9fb7cb48d431466d7b3bf2dc3e1d2e7ad6630f6b767a1ac1801c496b35].* restored for [./seven.txt].* in [./.roh.git/seven.txt.sha256]")"

# File Permissions Changed: The permissions (read, write, execute) of a file are modified.
echo
echo "#File Permissions Changed: The permissions (read, write, execute) of a file are modified"

chmod 777 "seven.txt"
run_test "ls -al" "0" "$(escape_expected "-rwxrwxrwx   1 dev  staff.*seven.txt")"
run_test "$ROH_SCRIPT verify" "0" "$(escape_expected "Number of ERRORs encountered:")" "true"

chmod 000 "seven.txt"
run_test "ls -al" "0" "$(escape_expected "----------   1 dev  staff.*seven.txt")"
run_test "$ROH_SCRIPT verify" "1" "$(escape_expected "ERROR: -- file [./seven.txt] not readable or permission denied")"

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
run_test "$ROH_SCRIPT verify" "0" "$(escape_expected "WARN: --.* hash file [./.roh.git/subdir/this_does_not_exist/this_does.txt.sha256] -- NOT found.* for [./subdir/this_does_not_exist/this_does.txt][65cb0ca932c81498259bb87f57c982cef5df83a8b8faf169121b7df3af40b477]")"
$ROH_SCRIPT -w >/dev/null 2>&1

# Subdirectory Removed
echo
echo "# Subdirectory Removed: An existing subdirectory is deleted"

# we don't care about empty directories (being removed)
mkdir "$SUBDIR/this_does_not_exist_either"
run_test "$ROH_SCRIPT write" "0" "$(escape_expected "[./subdir/this_does_not_exist_either]")" "true"
rmdir "$SUBDIR/this_does_not_exist_either"
run_test "$ROH_SCRIPT verify" "0" "$(escape_expected "[./subdir/this_does_not_exist_either]")" "true"

# we don't care about empty directories (but, we DO care if files are removed along with directories)
run_test "$ROH_SCRIPT verify" "0" "$(escape_expected "ERROR")" "true"
rm -rf "$SUBDIR/this_does_not_exist"
run_test "$ROH_SCRIPT verify" "1" "$(escape_expected "ERROR: --.* file [./subdir/this_does_not_exist/this_does.txt] -- NOT found.* for corresponding hash [./.roh.git/subdir/this_does_not_exist/this_does.txt.sha256][65cb0ca932c81498259bb87f57c982cef5df83a8b8faf169121b7df3af40b477]")"
rm "$ROH_DIR/$SUBDIR/this_does_not_exist/this_does.txt.sha256"

# Subdirectory Renamed
echo
echo "# Subdirectory Renamed: The name of a subdirectory is changed."
# Subdirectory Moved
echo "# Subdirectory Moved: A subdirectory is moved either within the directory or outside of it."

run_test "$ROH_SCRIPT verify" "0" "$(escape_expected "ERROR")" "true"
mkdir "$SUBDIR/this_does_not_exist"
echo "this_does" > "$SUBDIR/this_does_not_exist/this_does.txt"
echo "and_so_does_this" > "$SUBDIR/this_does_not_exist/and_so_does_this.txt"
$ROH_SCRIPT write >/dev/null 2>&1
mv "$SUBDIR/this_does_not_exist" "$SUBDIR/ok_it_does_exist"

#$ROH_SCRIPT -v
run_test "$ROH_SCRIPT recover" "0" "$(escape_expected "Recovered: --          hash in [./.roh.git/subdir/this_does_not_exist/and_so_does_this.txt.sha256][e5f9ed562b3724db0a83e7797d00492c83594548c5fe8e0a5c885e2bd2ac081d].* restored for [./subdir/ok_it_does_exist/and_so_does_this.txt].* in [./.roh.git/subdir/ok_it_does_exist/and_so_does_this.txt.sha256].*Recovered: --          hash in [./.roh.git/subdir/this_does_not_exist/this_does.txt.sha256][65cb0ca932c81498259bb87f57c982cef5df83a8b8faf169121b7df3af40b477].* restored for [./subdir/ok_it_does_exist/this_does.txt].* in [./.roh.git/subdir/ok_it_does_exist/this_does.txt.sha256]")"
run_test "$ROH_SCRIPT verify" "0" "$(escape_expected "ERROR")" "true"
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

$ROH_SCRIPT delete >/dev/null 2>&1

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

echo
