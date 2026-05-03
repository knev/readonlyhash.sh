# `readonlyhash` (ROH)

The purpose of ROH is to write hashes to disk for each file in a particular directory so that the directory can be periodically checked for integrity (before a backup). The aim of ROH is directories that are primarily static, with minimal changes over time e.g., foto catalogs from years gone by, zip files of projects that are archived, or a directory of installable executables. 

Features:
- Ignores hidden (dot) files, by design
- Optional `.rohignore` file (next to `.roh.git`) for additional skip patterns — see [.rohignore](#rohignore) below
- Does not alter the target files in any way. All target files are only read to create a hash and nothing more, so the modified date should not change.
- Hashes are stored relative to the top level target so as to not pollute the directory structure with files.

Note: ROH does not follow symlnks.

## Installation

Executing `make install` in the terminal copies the scripts the local `~/bin` directory and sets the executable permissions. You will need to add `~/bin` to your `$PATH` if you want to be able to use the script from a relative path.

There is a `make clean` for your convenience.
#### Requires
`make` (apt: `build-essential`) and `sqlite3`

## Unit testing

Before using the mini-suite, it is suggested to run `test.sh` or `make test` to make sure the scripts are compatible with your system. 

```
readonlyhash.sh.git $ ./test.sh
```
## Usage

`readonlyhash <C|COMMAND> [OPTIONS|--resume-at STRING] < <FN.roh.txt>`

Each command has a corresponding single letter alternative.

The file `.roh.txt` is a simple list of (relative) directories. ROH supports directories with a `.ro` suffix to indicate the directory is read-only, but it is not a requirement.

`johndoe.roh.txt`:
```
johndoe/Fotos/2014.ro
johndoe/Fotos/2015.ro
johndoe/Familyshare/Fotos/2015.ro
johndoe/Zipped.ro
johndoe/Music/Mixes.ro
```

If the list of directories are relative paths. you would run `readonlyhash` in the directory containing the `johndoe` directory.

Lines can be commented by preceding the line with a hash (`#`) symbol. 
```
#johndoe/Fotos/2015.ro
johndoe/Familyshare/Fotos/2015.ro
```

### Initializing a read-only directory

The best way to initialize a single read-only directory is to use `roh.fpath` to write hashes for the directory, followed by using `roh.git` to initialize the same directory; it will create a repository and immediately add all the newly written hashes to the repository.

### Option: `--resume-at`

You can instruct `readonlyhash` to continue at a particular line by providing a string matching the last part of the line (`.ro` is not needed). You must provide enough context to make the match unique e.g., `2015` is ambiguous in `johndoe.roh.txt` and would just take the first occurrance.

```
--resume-at Familyshare/Fotos/2015 // would resume on line 3 of johndoe.roh.txt 
```

### Command: `v|verify`

`readonlyhash verify ...`

Verify each listed directory, with the added check to see if the git repository for each is also clean.

### Command: `v|index`

Indexing while verifying is basically free, so allow for `verify index` in `readonlyhash`.

### Command: `a|archive`

`readonlyhash archive ...`

Archive each listed directory and remove the index file (`.roh.sqlite3`), if it exists.

### Command: `e|extract`

`readonlyhash extract ...

Extract each listed directory 

### while; done
The script `readonlyhash` is actually just sugar coating for a `while;do` statement using the underlying tools. However! `readonlyhash` has an added feature to allow for resuming at a particular line in the `roh.txt` file.
```
while IFS= read -r line; do <COMMAND> "$line"; done < FILENAME.roh.txt
```

#### Example: index all hashes to a single database
```
while IFS= read -r line; do roh.fpath index --db all.sqlite3 "$line"; done < johndoe.roh.txt
```

#### Example: make a backup of all hash zips
```
while IFS= read -r line; do echo "$line"; roh.copy --rebase "johndoe:backup/johndoe" "$line"; done < /home/Fractal/johndoe.roh.txt
```

---
## Underlying tools
### `roh.fpath`

Most of the heavy lifting in the mini-suite is done by `roh.fpath`. The basic idea is to use `roh.fpath` to write hashes for the files of a particular directory. Then the same utility can be used to verify if the hashes correspond the files e.g., the the files change in contents, move or where they renamed.

The `ROH_DIR` is  equal to `.roh.git` by default. This can be change with `--roh-dir`

#### FILEs or HASHes or both

The `roh.fpath` script runs in a maximum of 3 phases i.e., indexing, processing files and maintaining hashes. Each of the `roh.fpath` commands operates in distinct phases. The following tables shows what command operates on which phase:

| Operation  | FILEs | HASHes |
| ---------- | :---: | :----: |
| write      |   X   |   –    |
| delete     |   X   |   –    |
| show\|hide |   X   |   –    |
| verify     |   X   |   X    |
| recover    |   X   |   X    |
| sweep      |   –   |   X    |
| index      |   –   |   X    |
| query      |   –   |   –    |
It is possible to run multiple command simultaneously (see below).

#### Command: `w|write`
Recursively work through all files and calculate a hash for each file, saving the hash in the `ROH_DIR` directory, with a directory structure that mirrors the one being recursed through. The `show`  command can be issued to save the hash next to each file instead. This makes it possible to sort files, before hiding the hashes again.

By default, `write` does NOT print when a file has been hashed successfully, except when `--verbose` is added as switch.

Combining `write` with `sweep` should produce a clean result, except if there are hashes that are conflicting with saved values. In that case `--force` might be need to overwrite the conflict.
#### Command: `v|verify`

`verify` is the most strict command. It ensures that all hashes correspond to files and that there are no un-hashed files or orphaned hashes.

`verify` accepts an optional sub-command that asserts the *exclusive* location of every hash. `verify` does **not** move any files — it only reports.

- `verify hide` (default; same as bare `verify`): emits an `ERROR` for every hash that is not exclusively hidden — i.e., the hash is sitting next to the file (shown), or both a hidden and a shown copy exist with mismatched values.
- `verify show`: emits an `ERROR` for every hash that is not exclusively shown — i.e., the hash is in `ROH_DIR` (hidden), or both copies exist and disagree.

When both a hidden and a shown copy exist with **equal** stored values, `verify hide`/`verify show` emit a `WARN` ("two hash files exist but EQUAL") rather than an error — the duplication is redundant, not inconsistent.

#### Command: `i|index`
This command operates on all the hashes, building and index of all hashes (including those that are orphaned; having no valid file path). There are two possible index phase. The first can occur before a `recover` or `query`, the other one is after files are processed. 

The index is saved along side the `ROH_DIR` and is called `.roh.sqlite3` by default. It is possible to change this behavior using the `--db` switch. 

An index must be built before a `recover` can be done. Note, that indexes are made to be discarded and no upkeep is done for them; this avoids having to maintain consistency between files, hashes and index.
#### Command: `d|delete`
This is a safe `delete` command. Instead of just removing the `ROH_DIR`, this command goes through all files and removes the corresponding hashes. 

#### Command: `h|hide`, `s|show`

Sometimes maintenance must be done on a directory (e.g, rename, moving or delete files). When doing such maintenance, you want to also operate on the hash simultaneously. `roh.fpath` can be instructed to `show` all the hashes, namely moving hashes from the hidden `ROH_DIR` to next to each file. 

Hashes have the same name as each file, but with a hash extension (e.g., `.sha256` representing the hashing algorithm used) appended to it.

After the maintenance is complete, hashes can be moved back to `ROH_DIR` using the `hide` command. While hashes are shown you can run `verify show` to check them in place; running plain `verify` (i.e., `verify hide`) on a shown tree will report each shown hash as an `ERROR: hash NOT hidden`.

#### Command: `q|query`

If you want to check which indexes exist in the database related to a specific hash, it is possible to use the `query` command to get a list. Note, that an index is required in order to be able to query.

#### Command: `r|recover`
The most ideal way to change a read-only directory is to `show` the hashes and then operate on both the files and hashes simultaneously. In cases where updates to the files were made without updating the hashes, the `recover` command will attempt to match orphaned hashes to files again. 

Recover requires a valid index in order to be able to operate. The index is a list of all hashes with their corresponding file path. If the file path is invalid, then a `NULL` entry is recorded instead. 

Recover operates on both files and hashes. First it goes through all files; if a file does not have a corresponding hash, calculate the hash value and query the index to see if it has already been indexed. 
- If so, the hash is written out to the correct corresponding location and the hash is added to the index (note outdated hashes are not removed at this point)
- If the hash is not found, then the index is queried for files with similar names and those are output for the user to inspect.
After passing through all files, recover goes through all hashes. Any hash that is a duplicate (another hash has been indexed with the same value) is removed, leaving all orphaned hashes for which no corresponding file has been found.  

It is possible to limit `recover` to only one of the phases using `--only-files` and `--only-hashes`, but this is not recommend, unless you understand the interplay between the phases and the index properly.

It is possible to do a recover across different read-only directories. The `--db` switch can be used to build a common index for all read-only directories. 

Or, used to check if restored files correspond to missing files in a read-only directory. 
For example, the command ...
```
roh.fpath write index Fotos-2019-restored
```
... will write the hashes to the `ROH_DIR` of and then index them in `Fotos-2019-restored/.roh.sqlite3`.  It is the possible to reuse the index on the original `Fotos-2019` folder to see if you haver correctly restored deleted files.
```
roh.fpath r --db Fotos-2019-restored/.roh.sqlite3 --only-hashes Fotos-2019.ro
```
The above command would for each orphaned check if it exists in the index of the restored files, if so, remove the orphaned hash. In this situation there is no reason to go through the files of `Fotos-2019.ro`, so the `--only-hashes` switch is used.

#### Command: `e|sweep`

`sweep` removes **orphaned** hashes — hash files whose corresponding file no longer exists — and prunes any hash subdirectories left empty as a result. Use it once you've confirmed those removed files are indeed ok.

`sweep` does **not** touch mismatched hashes (hash files whose stored value disagrees with the current file's content). To act on a mismatch, first detect it with `verify`, then either fix the file or use `write --force` to overwrite the stored hash.
#### PATHSPEC

Instead of having to restart an entire `verify`, `write` or other operation, it is possible to pass a `PATHSPEC` to `roh.fpath` as the last argument after a `--`. The `ROOT` that is specified will be used along with its `ROH_DIR`, but only the `PATHSPEC` will be operated on.
```
roh.fpath verify Fotos -- "Uncle Bob" // Fotos is used as ROOT
```

#### GLOBSPEC

The `roh.fpath` script can be used to just one off some files with hashes. In this case the `GLOBSPEC` is used without specify a `ROOT`. Hashes are always shown next to the files.
```
roh.fpath write -- "Fotos/Uncle Bob"
```

#### `.rohignore`

A `.rohignore` file at the top of `ROOT` (next to `.roh.git` in the default layout) lists additional patterns to silently skip during `write`, `verify`, `show`, `hide`, `delete`, and `recover`.

Hidden (dot) files are skipped structurally regardless of whether `.rohignore` exists; the file cannot opt those back in. Skipped entries — both hidden ones and `.rohignore` matches — are recorded to `.roh.logs/files-ignored.exported.txt` for review.

Patterns are simple shell globs, one per line. Comments start with `#`; blank lines are allowed.

- **Basename pattern** (no `/` in the pattern): matched against the basename of every entry, at any depth. `__*` skips both `__skip.txt` and `projects/__nested/`.
- **Anchored path pattern** (contains `/`): matched against the entry path relative to `ROOT`. The leading `/` is optional and stripped — `/foo/bar` and `foo/bar` both pin to `$ROOT/foo/bar`. Use this when you want to skip exactly one subtree without affecting same-named directories elsewhere.

Example `Fotos/.rohignore`:
```
# Editor scratch files anywhere
__*
*.__.md
Thumbs.db

# Specific subtree only
projects/old/junk
/archive/raw_dumps
```

When `--roh-dir` relocates `ROH_DIR` outside `ROOT`, `.rohignore` still lives at `$ROOT/.rohignore` — it describes the data tree, not the metadata directory.

#### Multiple commands

Commands are potentially long running operations. In order to limit the times the user must interact, multiple commands can be issued simultaneously, and also using the single letter notations. For example ...

```
roh.fpath wi ...
roh.fpath ir ...
roh.fpath we ...
```

Currently `ir` is the only operation that adds a third phase to the execution, namely indexing, processing files and maintaining hashes. The other double commands operate on their respective phases as listed above.

#### Example: identify duplicates
If you have a folder of spurious files e.g., `2013-restored`
You can `write index` that directory to obtain the `.roh.sqlite3` index.
```
roh.fpath wi 2013-restored // will output 2013-restored/.roh.sqlite3
```

If you then have a folder that contains new files ...
```
roh.fpath v johndoe/Fotos/2015.ro
...
WARN: [johndoe/Fotos/2015.ro/sub-sub-directory] -- NEW DIRECTORY!?
...
Number of ERRORs encountered: [0]
Number of ...       WARNings: [1]
```

Then recovering using the index of the restored files will write hashes (in the `johndoe/Fotos/2015.ro` repo) for those files found i the `restored` directory.
```
roh.fpath r --only-files --db 2013-restored/.roh.sqlite3 johndoe/Fotos/2015.ro
roh.fpath i johndoe/Fotos/2015.ro // outputs johndoe/Fotos/2015.ro/.roh.sqlite3
```
Verifying `johndoe/Fotos/2015.ro` hereafter will still identify files that were not found in the restored directory. Now we need to identify those files in the `restored` directory that were not found in the `2015` directory. 
```
cd 2013-restored
mkdir tmp
mv .roh.git tmp/.
roh.fpath r --only-hashes --db johndoe/Fotos/2015.ro/.roh.sqlite3 tmp
```
The last line will remove all the orphaned hashes of the files that were found in the `2015` directory. Verifying `tmp` will list all files that are still "orphaned" (files that were NOT found in the 2015 directory). In other words, keep the files corresponding to the orphaned hashes. If the repo is move back out of `tmp`.
```
cd 2013-restored
mv tmp/.roh.git .
rmdir tmp
cd ..
roh.fpath v 2013-restored
```
Every file that is listed as NEW by the last verify line above has been found in the `2015` directory.

---
### `roh.git`

The `roh.git` script operates on the `ROH_DIR` directory of the root. This is normally `.roh.git`, so to spare the user from having to type `git -C ROOT/.roh.git command`, the `roh.git` command allows the user to just operate on the `ROOT`. Extra switches allow for more operations on the `ROH_DIR`.

Note: you will have to put the wildcard in quotes:
```
roh.git -C test add "*"
```
If you use `roh.git -C test add *` without quotes, the `*` is expanded by your shell before the arguments are passed to your script. This means if you have files `file1`,` file2`, and `file3` in your directory, the command passed to git would look like `git -C test add file1 file2 file3`.

The `readonlyhash` script expects hashes to be stored in a git repository, so any changes will have to be updated in the repo. `roh.git` or just `git` with `ROH_DIR` can be used for this.

#### Switch: `-i`
Initializes the git repository: creates the repository, adds the initial hashes and commits them.
```
roh.git -iC test
```
#### Switch: `-z`
Archives the `ROH_DIR` to `_.roh.git.zip`
#### Switch: `-x`
Extracts the `_.roh.git.zip` to `ROH_DIR`

#### Switches: `--v1`, `--v2`

Selects the archive/extract routine used by `-zC` and `-xC`:

- `--v2` (default): deterministic tar + content-hash + `.zip~` drift tracking (current format)
- `--v1`: legacy `tar + zip -m` / `unzip -j + tar -xf` routine from `da76c41`'s parent

---
### `roh.copy`

The `roh.copy` script is useful for two reasons. 
- Migrating `ROH_DIR` directories to a new location, or
- making a backup of existing `ROH_DIR` directories.
The script operates on either `ROH_DIR` directories or `_.roh.git.zip` archives. Whichever is present.

#### `--rebase`

The rebase switch is required. The switch will cause the program to replace what matches of the prefix of `PATHSPEC`, with what appears after the `':'`. 

If the following `roh.txt` exists: 
`Fotos.roh.txt:`
```
/Users/johndoe/ ... /Fotos [space]/1999.ro
/Users/johndoe/ ... /2002.ro
```

Specifying a `--rebase` of 
```
roh.copy copy --rebase "/Users/johndoe:/Users/NEW_TARGET" Fotos.roh.txt
```

Would copy the `ROH_DIR` directories the following directories:
`/Users/NEW_TARGET/ ... /Fotos [space]/1999.ro`
`/Users/NEW_TARGET/ ... /2002.ro`
The idea is that the same directory hierarchy is used, but at a different location. 

If the new target location does not exist, then it is created (a backup is created)
```
roh.copy copy --rebase johndoe:johndoe-bkup Fotos.roh.txt // backup
```

---
## Examples

### Ex: Remove duplicates comparing a directory to a main.

This example will deal with fotos. It is possible to make an index of a main readonly directory using the `index` command. If there are multiple read only directories with fotos, say one readonly directory per year, it is possible to make a single index of hashes across all of the readonly directories using `index --db`. 
```
while IFS= read -r line; do roh.fpath i --db fotos.db "$line"; done < fotos.roh.txt
```

Given a folder of restored fotos, with some fotos already in the main directory and some not, perhaps the idea is to avoid duplicates. The `write` command can be used to write hashes of all files in the restored directory. 
```
roh.fpath w _2019-11-11_restored
```

The `recover` comman is responsible for attempting to recover hashes for files in two phases; the first writes hashes for files already indexed, the second removes hashes that were found in the index. By making ALL hashes of the restored directory orphans, `recover` is then triggered to try and recover them. We do not need the first phase, since all hashes are made orphans.
```
roh.fpath r --only-hashes --roh-dir _2019-11-11_restored/.roh.git --db fotos.db _tmp
```
The `--only-hashes` switch skips phase 1. By pointing the recover to an empty `_tmp` directory, all files are missing and so all hashes are orphans. The index specified by `--db` is the index of ALL fotos in the main and `--roh-dir` specifies the directory where the orphaned hashes are found. 

Recover will go through the orphaned hashes found in the specified ROH_DIR; look up the hash in the index specified by `--db`; if found, remove the hash; if not state the file is missing. Hashes that were recovered, indicates that the corresponding file was in the index and therefore in the main directory. Those that remaining missing are new to the main.

It is possible to use the LOG output `hashes-deleted.exported.txt` to remove the duplicates. Note: that the entries need to be converted from hashes to files (remove the `.roh.git` directory and the `.sha256` extension). A future update will make this possible via a ROH tool.

To get file names instead of hashes, it is possible to run `verify` again. It will generate a new files log with new files (those for which the hashes were removed).
```
roh.fpath w _2019-11-11_restored
```

Then use a while loop to iterate through the new files LOG.
```
while IFS= read -r line; do rm -rf "$line"; done < _2019-11-11_restored/.roh.git/../.roh.new-files.txt
```

Running verify again should leave with a clean directory with no duplcates.

---
## Worst case scenarios

This mini-suite is designed not to clutter the disk space. In the case where the user has decided to manually reverse the changes by ROH. This can be done by:

Deleting the `ROH_DIR` (default `.roh.git`) directory inside the read-only directory.
```
rm -rf <FPATH>.ro/.roh.git
```
And, removing the `.ro` extension off the read-only directory.
```
mv <FPATH>.ro <FPATH>
```

In the event that the program has failed, there is one more detrimental state possible. The program could clutter your disk with hashes, if the program fails during a `show` or `hide` operation; this would leave hashes partially cluttering the read-only directory. If the cause of failure can be correct, then running `show`|`hide` again should move hashes to the correct location. 

All hash files can be safely deleted recursively using the `delete` command.
```
roh.fpath delete <FPATH>
```

Any and all hash can be deleted by removing all files with the extension `.sha256`
```
find <FPATH> -name '*.sha256' -type f -delete
```

Hashes are usually stored in a `git` repo. Checking out the removed hashes from the `git` repository should make the read-only directory verifiably correct.
```
roh.git -C <FPATH> checkout .
```

All `ROH_DIR` directories can be deleted with the following command:
```
find . -type d -name ".roh.git" -exec rm -rfv {} +
```

