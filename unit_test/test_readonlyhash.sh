#! /bin/echo Please-source

# Path to the hash script
ROH_BIN="./readonlyhash.sh"
chmod +x $ROH_BIN
FPATH_BIN="./roh.fpath.sh"
chmod +x $FPATH_BIN
GIT_BIN="./roh.git.sh"
chmod +x $GIT_BIN
ROH_COPY="./roh.copy.sh"
chmod +x $ROH_COPY
fpath="Fotos.roh.txt"
fpath_ro="Fotos~ro.roh.txt"
fpath_ro_ro="Fotos~ro~ro.roh.txt"
TARGET="_target~"

HASH="sha256"
ROH_DIR=".roh.git"

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
echo "#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
echo "# unit_test: roh.sh"

rm -rf "__MACOSX"
rm -rf "2002" >/dev/null 2>&1
rm -rf "2002.ro" >/dev/null 2>&1
rm -rf "2002.ro.ORIG" >/dev/null 2>&1
rm -rf "Fotos [space]" >/dev/null 2>&1
rm -rf "blammy"
rm -rf "backup-target"
rm -rf "$TARGET"
unzip Fotos.zip >/dev/null 2>&1
rm -rf "__MACOSX"

rm "$fpath" >/dev/null 2>&1
rm "$fpath_ro" >/dev/null 2>&1

# args
echo
echo "# args"

run_test "$GIT_BIN Fotos\ \[space\]/2003" "1" "$(escape_expected "ERROR: invalid working directory [].")"
run_test "$ROH_BIN extract THIS_FILE_DOES_NOT_EXIST.roh.txt" "1" "$(escape_expected "ERROR: [THIS_FILE_DOES_NOT_EXIST.roh.txt] not found")"

touch "$fpath"
run_test "$ROH_BIN extract --rebase junk:more_junk $fpath" "1" "$(escape_expected "ERROR: invalid option: [--rebase]")"
rm "$fpath" >/dev/null 2>&1

# init
echo
echo "# init"

run_test "$GIT_BIN -iC Fotos\ \[space\]/2003" "0" "$(escape_expected "Initialized empty Git repository in /Users/dev/Project-@knev/readonlyhash.sh.git/Fotos [space]/2003/.roh.git/.git/")"
run_test "$GIT_BIN -iC Fotos\ \[space\]/2003" "1" "$(escape_expected "ERROR: [Fotos [space]/2003/.roh.git/.git] exists already.*Abort.")"
rm -rf 'Fotos [space]/2003/.roh.git' >/dev/null 2>&1

# 2003: git

echo "$PWD/Fotos [space]/2003" > "$fpath"
echo "$PWD/Fotos [space]/1999" >> "$fpath"
echo "$PWD/2002.ro" >> "$fpath"
#run_test "$ROH_BIN init $fpath" "0" "Initialized empty Git repository"
$FPATH_BIN write "Fotos [space]/2003" >/dev/null 2>&1
$FPATH_BIN write "Fotos [space]/1999" >/dev/null 2>&1
$FPATH_BIN write '2002' >/dev/null 2>&1
$GIT_BIN -iC "Fotos [space]/2003" >/dev/null 2>&1
$GIT_BIN -iC "Fotos [space]/1999" >/dev/null 2>&1
$GIT_BIN -iC "2002" >/dev/null 2>&1
run_test "$GIT_BIN -C $PWD/Fotos\ \[space\]/1999 status" "0" "nothing to commit, working tree clean"
run_test "$GIT_BIN -C $PWD/2002 status" "0" "nothing to commit, working tree clean"
mv $PWD/2002 $PWD/2002.ro 

#run_test "ls -al $fpath_ro" "0" "$fpath_ro"

# test skipping function
echo "$PWD/1999" > "Fake.roh.txt"
cat "$fpath" >> "Fake.roh.txt"
run_test "$ROH_BIN verify Fake.roh.txt --resume-at Fotos\ \[space\]/1999" "0" "$(escape_expected "OK: directory entry [$PWD/1999] -- SKIPPING")"
rm "Fake.roh.txt"

run_test "$ROH_BIN verify $fpath --resume_at 2002" "1" "$(escape_expected "ERROR: invalid option [--resume_at 2002]")"
run_test "$ROH_BIN verify $fpath --resume-at 2002" "0" "$(escape_expected "Looping on: [/Users/dev/Project-@knev/readonlyhash.sh.git/2002].* -- SKIPPING")" "true"
run_test "$ROH_BIN verify $fpath --resume-at 2002.ro" "0" "$(escape_expected "Looping on: [/Users/dev/Project-@knev/readonlyhash.sh.git/2002].* -- SKIPPING")" "true"

#run_test "ls -al $fpath_ro_ro" "1" "ls: $fpath_ro_ro: No such file or directory" 
#run_test "$ROH_BIN init $fpath_ro" "0" "Archived .roh.git to.* _.roh.git.zip" "true"
#run_test "ls -al $fpath_ro_ro" "1" "ls: $fpath_ro_ro: No such file or directory" 

# archive
echo
echo "# archive"

$FPATH_BIN delete sweep "$PWD"/2002.ro >/dev/null 2>&1
rm -rf "2002.ro/.roh.git"
$GIT_BIN -iC "2002.ro" >/dev/null 2>&1
$FPATH_BIN write show "$PWD"/2002.ro >/dev/null 2>&1
run_test "$GIT_BIN -zC 2002.ro" "1" "$(escape_expected "ERROR: hashes not exclusively hidden in [2002.ro/.roh.git]")"

$FPATH_BIN hide "$PWD"/2002.ro >/dev/null 2>&1
run_test "$ROH_BIN archive $fpath" "1" "$(escape_expected "ERROR: local repo [$PWD/2002.ro/.roh.git] not clean")"

git -C "2002.ro/$ROH_DIR" add .
git -C "2002.ro/$ROH_DIR" commit -m manual. >/dev/null 2>&1
run_test "$ROH_BIN archive $fpath" "0" "$(escape_expected "SKIP: directory [$PWD/Fotos [space]/1999] -- [$PWD/Fotos [space]/1999/_.roh.git.zip] exists.*Archived [.roh.git] to [$PWD/2002.ro/_.roh.git.zip].*Removed [$PWD/2002.ro/.roh.git]")"

mkdir 2002
cp "$PWD/2002.ro/_.roh.git.zip" "2002/."
mv "2002.ro" "2002.ro.ORIG"
run_test "$GIT_BIN -xC 2002" "0" "$(escape_expected "Extracted [2002/.roh.git] from [_.roh.git.zip].*Removed [2002/_.roh.git.zip]")"
rm -rf 2002
mv "2002.ro.ORIG" "2002.ro"

run_test "ls -al $PWD/Fotos\ \[space\]/1999/_.roh.git.zip" "0" "$(escape_expected "$PWD/Fotos [space]/1999/_.roh.git.zip")"
run_test "ls -al $PWD/2002.ro/_.roh.git.zip" "0" "$(escape_expected "$PWD/2002.ro/_.roh.git.zip")"

# extract
echo
echo "# extract"

# run_test "$ROH_BIN verify $fpath_ro" "0" "ERROR" "true"
# run_test "$ROH_BIN verify $fpath_ro" "0" "$(escape_expected "On branch master.*nothing to commit, working tree clean.*Removed [/var/folders/.*/tmp.*].*On branch master.*nothing to commit, working tree clean.*Removed [/var/folders/.*/tmp.*]")"

run_test "$ROH_BIN extract $fpath" "0" "$(escape_expected "Extracted [/Users/dev/Project-@knev/readonlyhash.sh.git/Fotos [space]/2003/.roh.git] from [_.roh.git.zip].*Removed [/Users/dev/Project-@knev/readonlyhash.sh.git/Fotos [space]/2003/_.roh.git.zip]")"

run_test "$ROH_BIN verify $fpath" "0" "ERROR" "true"

echo "0000000000000000000000000000000000000000000000000000000000000000" > "2002.ro/$ROH_DIR/2002_FIRE!/Untitled-001.jpg.$HASH"
run_test "$ROH_BIN verify $fpath" "1" "$(escape_expected "ERROR: hash mismatch:.*stored [0000000000000000000000000000000000000000000000000000000000000000][$PWD/2002.ro/.roh.git/2002_FIRE!/Untitled-001.jpg.sha256].* computed [816d2fd63482855aaadd92294ef84c4a415945df194734c8834e06dd57538dc4][$PWD/2002.ro/2002_FIRE!/Untitled-001.jpg]")"
echo "816d2fd63482855aaadd92294ef84c4a415945df194734c8834e06dd57538dc4" > "2002.ro/$ROH_DIR/2002_FIRE!/Untitled-001.jpg.$HASH"

echo "0000000000000000000000000000000000000000000000000000000000000000" > "2002.ro/$ROH_DIR/2002_FIRE!/.HIDDEN_FILE"
run_test "$ROH_BIN verify $fpath" "1" "$(escape_expected "ERROR: local repo [$PWD/2002.ro/$ROH_DIR] not clean")"
rm "2002.ro/$ROH_DIR/2002_FIRE!/.HIDDEN_FILE"

run_test "$ROH_BIN verify $fpath" "0" "ERROR" "true"

# extract && verify
echo
echo "# extract && verify"

#REINSTATE run_test "$ROH_BIN verify $fpath" "0" "$(escape_expected "Removed [/var/folders/.*/tmp.*].*Removed [/var/folders/.*/tmp.*]")" "true"
#REINSTATE run_test "$ROH_BIN verify $fpath" "0" "$(escape_expected "Done..*On branch master.*nothing to commit, working tree clean.*Done..*On branch master.*nothing to commit, working tree clean")"


# copy --rebase
echo
echo "# copy --rebase"

# fpath_ro
# $Fractal/blammy/cheeze/Fotos [space]/1999.ro
# $Fractal/blammy/cheeze/2002.ro
# 1]	$Fractal/blammy/cheeze/Fotos [space]/1999
# 1]	$Fractal/blammy/cheeze/2002
# 2]		; Fotos [space]/1999
# 2]		; 2002
# 3]			$Fractal/_target~/Fotos [space]/1999
# 3]			$Fractal/_target~/2002
#
#"$Fractal/blammy/cheeze:$Fractal/_target~"

mkdir -p "blammy/cheeze"
mv "$PWD/Fotos [space]" "$PWD/blammy/cheeze/." 
mv "$PWD/2002.ro" "$PWD/blammy/cheeze/." 
echo "$PWD/blammy/cheeze/Fotos [space]/1999.ro" > "$fpath_ro"
echo "$PWD/blammy/cheeze/2002.ro" >> "$fpath_ro"
unzip Fotos.zip -d $TARGET >/dev/null 2>&1
rm -rf "$TARGET/__MACOSX"

run_test "$ROH_COPY --rebase blammy/cheeze $fpath_ro" "1" "$(escape_expected "ERROR: invalid rebase string [blammy/cheeze]" )"

run_test "$ROH_COPY --rebase blammy/cheeze:$TARGET blammy/cheeze/Fotos\ \[space\]/1999.ro" "1" "$(escape_expected "ERROR: rebase origin [blammy/cheeze/Fotos [space]/1999.ro] not accessible")"

run_test "$ROH_COPY --rebase blammy/cheeze:$TARGET blammy/cheeze/Fotos\ \[space\]/1999" "0" "$(escape_expected "Copied [blammy/cheeze/Fotos [space]/1999/.roh.git] to [$TARGET/Fotos [space]/1999/.]")"
run_test "ls -al $PWD/_target~/Fotos\ [space]/1999/$ROH_DIR" "0" "$(escape_expected "$PWD/_target~/Fotos\ [space]/1999.ro/$ROH_DIR: No such file or directory")" "true"
run_test "$FPATH_BIN verify _target~/Fotos\ \[space\]/1999" "0" "ERROR:" "true"
rm -rf '_target~/Fotos [space]/1999/.roh.git'

run_test "$ROH_COPY --rebase blammy/cheeze:backup-target blammy/cheeze/Fotos\ \[space\]/1999" "0" "$(escape_expected "Copied [blammy/cheeze/Fotos [space]/1999/.roh.git] to [backup-target/Fotos [space]/1999/.]")"
run_test "ls -al backup-target/Fotos\ [space]/1999/$ROH_DIR" "0" "$(escape_expected "$PWD/_target~/Fotos\ [space]/1999.ro/$ROH_DIR: No such file or directory")" "true"
rm -rf "backup-target"

$GIT_BIN -zC "blammy/cheeze/Fotos [space]/1999"
run_test "$ROH_COPY --rebase blammy/cheeze:backup-target blammy/cheeze/Fotos\ \[space\]/1999" "0" "$(escape_expected "Copied [blammy/cheeze/Fotos [space]/1999/_.roh.git.zip] to [backup-target/Fotos [space]/1999/.]")"
run_test "ls -al backup-target/Fotos\ [space]/1999/_.roh.git.zip" "0" "$(escape_expected "$PWD/_target~/Fotos\ [space]/1999.ro/$ROH_DIR: No such file or directory")" "true"
rm -rf "backup-target"

#run_test "$ROH_BIN --rebase blammy/cheeze:$TARGET $fpath_ro" "0" "$(escape_expected "Copied [blammy/cheeze/Fotos [space]/1999.ro/.roh.git] to [$TARGET/Fotos [space]/1999/.].*Copied [blammy/cheeze/2002.ro/.roh.git] to [$TARGET/2002/.]")"

#TODO: readonlyhash: do the copy and then the verify?
#run_test "$ROH_BIN verify --rebase blammy/cheeze:$TARGET $fpath_ro" "0" "ERROR" "true"

#TMP run_test "$ROH_BIN verify $fpath_ro_ro" "0" "ERROR" "true"

rm -rf "$TARGET"
mv "$PWD/blammy/cheeze/Fotos [space]" "$PWD/."
mv "$PWD/blammy/cheeze/2002.ro" "$PWD/." 
rmdir "blammy/cheeze"
rmdir "blammy"

# Clean up test files
echo
echo "# Clean up test files"

rm -rf "2002.ro" >/dev/null 2>&1
rm -rf "Fotos [space]/1999" >/dev/null 2>&1
rm -rf "Fotos [space]/2003" >/dev/null 2>&1
rm "Fotos [space]/.DS_Store"
rmdir "Fotos [space]"
# rm "$fpath_ro_ro" >/dev/null 2>&1
rm "$fpath_ro"
rm "$fpath"
 
run_test "ls -alR 2002.ro" "1" "$(escape_expected "ls: 2002.ro: No such file or directory")"
# run_test "ls -alR Fotos\ \[space\]" "1" "$(escape_expected "ls: Fotos [space]: No such file or directory")"
# run_test "ls -alR $TARGET" "1" "$(escape_expected "ls: $TARGET: No such file or directory")"

echo 
