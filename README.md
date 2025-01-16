# `readonlyhash` (ROH)

The purpose of ROH is to write hashes to disk for each file in a particular directory so that the directory can be periodically checked for integrity (before a backup). The aim of ROH is directories that are primarily static, with minimal changes over time e.g., foto catalogs from years gone by, zip files of projects that are archived, or a directory of installable executables. 

Features:
- Ignores hidden (dot) files, by design
- Does not alter the target files in any way. All target files are only read to create a hash and nothing more, so the modified date should not change.
- Hashes are stored relative to the top level target so as to not pollute the directory structure with files.

Note: ROH does not follow symlnks.

## Installation

`make install` just copies the scripts the local `~/bin` directory and sets the executable permissions. You will need to add `~/bin` to your `$PATH` if you want to be able to use the script from a relative path.

There is a `make clean` for your convenience.
## Unit testing

Before using the mini-suite, it is suggested to run `test.sh` or `make test` to make sure the scripts are compatible with your system. 

## Usage

`Fotos.loop.txt`
```
/Users/ ... /Fotos [space]/1999
/Users/ ... /2002
```

ROH operates on a `.loop.txt` text file with consists of a list of ABSOLUTE path directories. One directory per line, lines can be commented by starting the line with a hash (`#`) symbol. 
	NOTE: relative paths might a future feature 

### Init

The first command is usually `init`, which will write all the hashes, create the `git` repository and commit the hashes. All directories will be renamed with the extension `.ro` to denote a readonly directory. This is also why it is a good idea to have very few top level directories (e.g., CDs), rather than a bunch of small directories (e.g., each CD album directory: Sting, AC/DC, Taylor Swift).

```
$ readonlyhash init Fotos.loop.txt
```

The `init` command will generate a new loop text file for you with the resulting new names. This new file can be renamed and used for subsequent `verify` commands.

`Fotos~.loop.txt`
```
/Users/ ... /Fotos [space]/1999.ro
/Users/ ... /2002.ro
```

### Archive


### Verify

...





#### New Target

Given two directories with the same directory structure, but located at different parent locations, it is possible to tell ROH to use the hashes from directories listed in the loop text, but verify them against a different directory with the same directory structure. 

For example, if the following loop text exists: 
`Fotos.loop.txt`
```
/Users/ ... /Fotos [space]/1999.ro
/Users/ ... /2002.ro
```

And, the following directories exist:
`/Users/ ... NEW_TARGET/Fotos [space]/1999`
`/Users/ ... NEW_TARGET/2002`
Note, that the target directories do not have the `.ro` extension.

Then, it is possible to tell ROH to verify against the `NEW_TARGET`.
```
$ readonlyhash verify --new-target NEW_TARGET Fotos.loop.txt
```

## Underlying tools
### `roh.fpath`

Used by ROH to write, verify, show and hide hashes for a single directory.

`ROH_DIR` is  equal to `.roh.git` by default.

#### Verify



#### Show/Hide

Sometimes maintenance must be done on a directory (e.g, rename, moving or delete files). When doing such maintenance, you want to also operate on the hash simultaneously. `roh.fpath` can be instructed to show all the hashes, namely moving hashes from the hidden `ROH_DIR` to along side each file. 

```
roh.fpath show <fpath>
```

Hash have the same name as each file, but with a hash extension (e.g., `.sha256`) representing the hashing algorithm used.

After the maintenance has been completed, hashes can be moved back to `ROH_DIR` and used for verifying the files. Note: that hashes are usually stored in a git repository, so any changes will have to be updated in the repo. `roh.git` or just `git` with `ROH_DIR` can be used for this.
```
roh.fpath hide <fpath>
```

#### Recover

In the event that files were moved or renamed without the hashes also having been moved or renamed, recover can attempt to correlated files to orphaned hashes.

For every file in the read-only directory searches through the hashes to find one that has the same store hash and no no corresponding file; moves the hash to correlate to that file. 

### `roh.git`

Rather than having to refer to the `ROH_DIR` each time when using git to check the status of the hashes repo, `roh.git` allows the user to just refer to the target directory. It has has some extra features related to manipulating the ROH_DIR e.g., archiving.

Note: you will have to put the wildcard in quotes:
```
roh.git -C test add "*"
```
If you use roh.git -C test add * without quotes, the * is expanded by your shell before the arguments are passed to your script. This means if you have files file1, file2, and file3 in your directory, the command passed to git would look like git -C test add file1 file2 file3.

## Worst case scenarios

ROH is designed not to clutter the disk space. There is the general worst case scenario, where the program is functioning normally, but the user has decided to reverse the changes by ROH. Dealing with this means:

Deleting the `ROH_DIR` (default `.roh.git`) directory inside the read-only directory.
```
rm -rf <FPATH>.ro/.roh.git
```
And, removing the `.ro` extension off the read-only directory.
```
mv <FPATH>.ro <FPATH>
```

In the event that the program has failed, there is one more detrimental state possible. The program could clutter your disk with hashes, if the program fails during a `show` or `hide` operation; this would leave hashes partially cluttering the read-only directory. If the error can be correct, then running `show`|`hide` again should correct the problem. 

But in the event that is not the case, all hash files (default extension `.sha256`) can be deleted recursively; deleting `ROH_DIR` and removing the extension off the read-only directory would reverse the effects of ROH, but the hash history would be gone.

```
find <FPATH> -name '*.sha256' -type f -delete
```

Hashes are usually stored in a `git` repo. Checking out the removed hashes from the `git` repository should make the read-only directory verifiably correct.
```
roh.git -C <FPATH> checkout .
```

