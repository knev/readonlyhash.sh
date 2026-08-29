#!/bin/bash

VERSION="2.2.60"

HASH="sha256"

#set -x

usage() {
    echo "Usage:"
	echo "      $(basename "$0") [--force] <[-i|-[a|z]|-x|-_] -[i|[a|z]|x|_]C PATHSPEC> [ARGUMENTS]"
	echo
    echo "Options:"
	echo "  -i             Initialize the roh.git storage"
	echo "  -[a|z]         Archive the roh.git storage"
	echo "  -x             Extract the roh.git storage"
	echo "  -_, --revert   Revert an extract: discard the roh.git storage and restore the archive from .roh.git.zip~"
	echo "                 (refuses if the repo is dirty or its hashes differ from the archive, unless --force)"
	echo "  -C             Specify the working directory"
    echo "  -f, --force    Force operation"
	echo "      --v1       Use the legacy tar+zip routine (pre-content-hash format)"
	echo "      --v2       Use the deterministic tar+content-hash routine (default)"
    echo "      --version  Display the version and exit"
    echo "  -h, --help     Display this help and exit"
	echo
	echo "Examples:"
	echo "      \$ $(basename "$0") -zC <PATH>"
	echo "      \$ $(basename "$0") -C <PATH> add \"*\""
	echo
	echo "Passthrough git (after -C PATH), plus one synthesized command:"
	echo "      \$ $(basename "$0") -C <PATH> status"
	echo "      \$ $(basename "$0") -C <PATH> commit -A [-m \"message\"]   # git add -A + commit (incl. untracked)"
	echo
	echo "Other operations: "
	echo "      git restore --staged \$(git diff --cached --name-only --diff-filter=D) # unstage deleted files"
	echo
}

commands=()  # normal array is fine even in 3.2

contains() {
    local needle="$1"
    local item
    for item in "${commands[@]}"; do
        [[ "$item" == "$needle" ]] && return 0
    done
    return 1
}

# check_pre_reqs <cmd>...
# Abort with a clear message listing every required external tool that is
# missing. command -v is a shell builtin, so this works even on environments
# where `which` itself isn't installed (e.g. some Git-Bash setups).
check_pre_reqs() {
    local req missing=()
    for req in "$@"; do
        command -v "$req" >/dev/null 2>&1 || missing+=("$req")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        echo "ERROR: $(basename "$0") requires missing tool(s): ${missing[*]}" >&2
        echo "Abort." >&2
        echo >&2
        exit 1
    fi
}

# git_path <path>
#   Return a path that native git can chdir into. Git for Windows can't `git -C`
#   into a POSIX-style absolute path containing '[' or ']' (it mangles them), so
#   convert to a Windows path via cygpath there. On macOS/Linux cygpath is
#   absent and the path is returned unchanged.
git_path() {
    if command -v cygpath >/dev/null 2>&1; then
        cygpath -w "$1"
    else
        printf '%s' "$1"
    fi
}

CWD=""
force_mode="false"
archive_version="v2"

# Parse command line options
while getopts ":iazx_C:fh-:" opt; do
  case $opt in
	i)
	  commands+=("init")
	  ;;
	a|z)
	  commands+=("archive")
	  ;;
	x)
	  commands+=("extract")
	  ;;
	_)
	  commands+=("revert")
	  ;;
    C)
	  CWD="$OPTARG"
      ;;
	f)
	  force_mode="true"
	  ;;
    h)
      usage
      exit 0
      ;;
    -)
      case "${OPTARG}" in
		force)
          force_mode="true"
          ;;
		revert)
		  commands+=("revert")
		  ;;
		v1)
		  archive_version="v1"
		  ;;
		v2)
		  archive_version="v2"
		  ;;
	    version)
	      echo "$(basename "$0") version: v$VERSION"
		  echo
	      exit 0
	      ;;
        help)
          usage
          exit 0
          ;;
        *)
          echo "ERROR: invalid option: [--${OPTARG}]" >&2
          usage
          exit 1
          ;;
      esac
      ;;
    \?)
      echo "ERROR: invalid option: [-$OPTARG]" >&2
      usage
      exit 1
      ;;
    :)
      echo "ERROR: option [-$OPTARG] requires an argument." >&2
	  echo
      usage
      exit 1
      ;;
  esac
done

# Shift off the options and their arguments
shift $((OPTIND-1))

ROH_DIR=".roh.git"

# echo "* CWD: [$CWD]"
# echo "* [$#][$@]"

# Check if any mode is set or if positional arguments are needed
if ! contains "init" && ! contains "archive" && ! contains "extract" && ! contains "revert"; then
	if [ $# -eq 0 ]; then
		echo "ERROR: not enough arguments." >&2
		echo
		usage
		exit 1
	fi

else
	_ops=0
	contains "archive" && _ops=$((_ops + 1))
	contains "extract" && _ops=$((_ops + 1))
	contains "revert"  && _ops=$((_ops + 1))
	if [ $_ops -gt 1 ]; then
		echo "ERROR: archive, extract and revert operations are mutually exclusive." >&2
		echo
		usage
		exit 1
	fi
	unset _ops
fi

if [ -z "$CWD" ] || ! [ -d "$CWD" ]; then
	echo "ERROR: invalid working directory [$CWD]." >&2
	echo
	usage
	exit 1
fi

# Required external tools depend on the operation, so check now that the command
# is known but before any git/archive work. git is always needed (this is a git
# wrapper, including the bare -C passthrough). archive writes a zip, reads the
# prior zip (unzip), builds a tar, and hashes it (openssl). extract reads the
# zip (unzip) and, on --v1, untars.
reqs=(git)
contains "archive" && reqs+=(zip unzip tar openssl)
contains "extract" && reqs+=(unzip tar)
contains "revert"  && reqs+=(unzip tar openssl)
check_pre_reqs "${reqs[@]}"

# Archives normalize all mtimes to the epoch for reproducible tar bytes, and
# GNU tar (Linux, Git Bash) warns "implausibly old time stamp" on extracting
# any member with mtime <= 0. Suppress that known-benign warning where the
# flag exists; bsdtar (macOS) has neither the warning nor the flag.
TAR_NO_TS_WARN=""
tar --version 2>/dev/null | grep -q GNU && TAR_NO_TS_WARN="--warning=no-timestamp"

#------------------------------------------------------------------------------------------------------------------------------------------

init_roh() {
    local dir="$1"

	mkdir -p "$dir/$ROH_DIR"

	if [ -d "$dir/$ROH_DIR/.git" ]; then
		echo "ERROR: [$dir/$ROH_DIR/.git] exists already."
		echo "Abort."
		echo
		return 1
	fi

	# GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.directory GIT_CONFIG_VALUE_0="$dir/$ROH_DIR" git status
	export GIT_CONFIG_COUNT=1
	export GIT_CONFIG_KEY_0=advice.defaultBranchName
	export GIT_CONFIG_VALUE_0="false"

	git -C "$(git_path "$dir/$ROH_DIR")" init

	echo ".DS_Store.$HASH" > "$dir/$ROH_DIR"/.gitignore
	git -C "$(git_path "$dir/$ROH_DIR")" add .gitignore
	git -C "$(git_path "$dir/$ROH_DIR")" commit -m "Initial ignores."
	# git -C "$CWD/$ROH_DIR" status

	git_status=$(git -C "$(git_path "$dir/$ROH_DIR")" status)
	if ! [[ "$git_status" =~ "nothing to commit, working tree clean" ]]; then
		git -C "$(git_path "$dir/$ROH_DIR")" add "*"
		git -C "$(git_path "$dir/$ROH_DIR")" commit -m "Initial hashes."
		git -C "$(git_path "$dir/$ROH_DIR")" status
	fi

	unset GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0

# 	dir_ro="$(rename_to_ro "$dir")"
# 	if [ "$dir" != "$dir_ro" ] && mv "$dir" "$dir_ro"; then
# 		echo "Renamed [$dir] to [$dir_ro]"
# 	fi
# 	echo "$dir_ro" >> "$LOOP_TXT_RO"
}

archive_roh_v1() {
    local dir="$1"
    local force_mode="$2"

    local archive_name="_$ROH_DIR.zip"

	if [ -f "$dir/$archive_name" ]; then
		if [ "$force_mode" = "true" ]; then
			rm "$dir/$archive_name"
			echo "Clobber [$dir/$archive_name] (FORCED)!"
		else
			echo "ERROR: archive [$archive_name] exists in [$dir]."
			echo "Abort."
			echo
			exit 1
		fi
	fi

    if [ ! -d "$dir/$ROH_DIR" ]; then
        echo "ERROR: directory [$ROH_DIR] does NOT exist in [$dir]"
		echo "Abort."
		echo
        exit 1
    fi

	if [ ! -d "$dir/$ROH_DIR/.git" ]; then
		echo "ERROR: local repo [$dir/$ROH_DIR/.git] does not exist"
		echo "Abort."
		echo
		exit 1
	fi

	if [ -n "$(find "$dir" -mindepth 1 -path "*/.roh.git/*" -prune -o -name "*.sha256" -print -quit)" ]; then
		echo "ERROR: hashes not exclusively hidden in [$dir/$ROH_DIR]"
		echo "Abort."
		echo
		return 1
	fi

	git_status=$(git -C "$(git_path "$dir/$ROH_DIR")" status)
	if ! [[ "$git_status" =~ "nothing to commit, working tree clean" ]]; then
        echo "ERROR: local repo [$dir/$ROH_DIR] not clean"
		echo "Abort."
		echo
		exit 1
	fi

	tar -cvf "$dir/$ROH_DIR.tar" -C "$dir" "$ROH_DIR" >/dev/null 2>&1 && zip -qm "$dir/$archive_name" "$dir/$ROH_DIR.tar"
    if [ $? -eq 0 ]; then
        echo "Archived [$ROH_DIR] to [$dir/$archive_name]"
    else
        echo "ERROR: failed to archive [$dir/$ROH_DIR] to [$dir/$archive_name]"
		echo "Abort."
		echo
        exit 1
    fi

	if [ -f "$dir/$archive_name" ]; then
		rm -rf "$dir/$ROH_DIR"
		echo "Removed [$dir/$ROH_DIR]"
	fi

	return 0
}

extract_roh_v1() {
    local dir="$1"
    local force_mode="$2"

    local archive_name="_$ROH_DIR.zip"

	if [ -d "$dir/$ROH_DIR" ]; then
		if [ "$force_mode" = "true" ]; then
			rm -rf "$dir/$ROH_DIR"
			echo "Clobber [$dir/$ROH_DIR] (FORCED)!"
		else
			echo "ERROR: directory [$ROH_DIR] exists in [$dir]"
			echo "Abort."
			echo
			exit 1
		fi
	fi

	if [ -f "$dir/$archive_name" ]; then
		unzip -jq "$dir/$archive_name" -d "$dir" && tar -xf "$dir/$ROH_DIR.tar" $TAR_NO_TS_WARN -C "$dir" && rm -f "$dir/$ROH_DIR.tar" "$dir/$archive_name"
		if [ $? -eq 0 ]; then
		    echo "Extracted [$dir/$ROH_DIR] from [$archive_name]"
		else
		    echo "ERROR: failed to extract [$dir/$ROH_DIR] from [$dir/$archive_name]"
			echo "Abort."
		    echo
		    exit 1
		fi

		if [ -d "$dir/$ROH_DIR" ]; then
			rm -rf "$dir/$archive_name"
			echo "Removed [$dir/$archive_name]"
		fi

	else
        echo "ERROR: archive [$archive_name] does NOT exist in [$dir]"
		echo "Abort."
		echo
        exit 1
    fi
}

# CONTENT_TAR / CONTENT_HASH_FILE
#   The two metadata files an archive carries inside .roh.git/: the tar of the
#   .sha256 tree, and that tar's hash (the archive's content identity).
CONTENT_TAR=".SHA256-HASHES.tar"
CONTENT_HASH_FILE=".SHA256-HASHES.tar.sha256"

# archived_content_hash <dir>
#   Print the content hash recorded inside <dir>/.roh.git.zip~ (the backup an
#   extract leaves behind), or nothing if there is no backup / no hash.
archived_content_hash() {
	local dir="$1"
	[ -f "$dir/$ROH_DIR.zip~" ] || return 0
	unzip -p "$dir/$ROH_DIR.zip~" "$ROH_DIR/$CONTENT_HASH_FILE" 2>/dev/null | tr -d '[:space:]'
}

# build_content_tar <dir> <out_tar>
#   Normalize all mtimes under <dir>/.roh.git (including the directory itself,
#   since file ops/extract bump it) so the tar bytes -- and hence its hash --
#   are reproducible across cycles; tar the .sha256 tree (excluding .git/ and
#   the metadata files) to <out_tar>; print the tar's sha256. Shared by
#   archive (which installs the tar) and revert (which only needs the hash).
build_content_tar() {
	local dir="$1"
	local out_tar="$2"

	find "$dir/$ROH_DIR" -exec touch -t 197001010000.00 {} +
	tar -cf "$out_tar" -C "$dir/$ROH_DIR" \
		--exclude=".git" \
		--exclude="$CONTENT_TAR" \
		--exclude="$CONTENT_HASH_FILE" \
		--exclude=".DS_Store" \
		. 2>/dev/null
	if [ $? -ne 0 ]; then
		echo "ERROR: failed to build [$CONTENT_TAR] for [$dir/$ROH_DIR]" >&2
		echo "Abort." >&2
		echo >&2
		return 1
	fi
	# stdin feed matches roh.fpath generate_hash() (CRLF- and MSYS-path-safe)
	openssl sha256 < "$out_tar" | awk '{print $NF}' | head -c 64
}

# revert_roh <dir> <force>
#   Undo an extract without re-archiving: discard <dir>/.roh.git and put the
#   backup .roh.git.zip~ back as _.roh.git.zip. Refuses if that would throw
#   something away -- a dirty repo, or hash content that differs from what
#   the backup records (same content hash -z uses) -- unless --force, which
#   is the "I messed up the extracted tree, the archive is the truth" case.
revert_roh() {
    local dir="$1"
    local force_mode="$2"

    local archive_name="_$ROH_DIR.zip"

	if [ ! -d "$dir/$ROH_DIR" ]; then
		echo "ERROR: directory [$ROH_DIR] does NOT exist in [$dir]"
		echo "Abort."
		echo
		exit 1
	fi
	if [ ! -f "$dir/$ROH_DIR.zip~" ]; then
		echo "ERROR: backup [$dir/$ROH_DIR.zip~] does NOT exist -- nothing to revert to"
		echo "Abort."
		echo
		exit 1
	fi
	if [ -f "$dir/$archive_name" ]; then
		echo "ERROR: archive [$archive_name] exists in [$dir]."
		echo "Abort."
		echo
		exit 1
	fi

	if [ "$force_mode" != "true" ]; then
		if [ -d "$dir/$ROH_DIR/.git" ]; then
			git_dirty=$(git -C "$(git_path "$dir/$ROH_DIR")" status --porcelain 2>/dev/null)
			if [ -n "$git_dirty" ]; then
				echo "ERROR: local repo [$dir/$ROH_DIR] not clean -- archive with -z, or --force to discard"
				echo "Abort."
				echo
				exit 1
			fi
		fi

		local prev_hash cur_hash tmp_tar
		prev_hash=$(archived_content_hash "$dir")
		tmp_tar=$(mktemp)
		cur_hash=$(build_content_tar "$dir" "$tmp_tar") || { rm -f "$tmp_tar"; exit 1; }
		rm -f "$tmp_tar"
		if [ -n "$prev_hash" ] && [ "$prev_hash" != "$cur_hash" ]; then
			echo "ERROR: [$dir/$ROH_DIR] content differs from [$dir/$ROH_DIR.zip~] -- archive with -z, or --force to discard"
			echo "       archived [$prev_hash]"
			echo "        current [$cur_hash]"
			echo "Abort."
			echo
			exit 1
		fi
	else
		echo "Discarding [$dir/$ROH_DIR] (FORCED)!"
	fi

	rm -rf "$dir/$ROH_DIR"
	echo "Removed [$dir/$ROH_DIR]"
	mv -f "$dir/$ROH_DIR.zip~" "$dir/$archive_name"
	echo "Reverted [$dir/$ROH_DIR.zip~] to [$dir/$archive_name]"
}

archive_roh() {
    local dir="$1"
    local force_mode="$2"

    local archive_name="_$ROH_DIR.zip"

	# If force_mode is true, move the existing archive aside as the .zip~
	# backup so the prev_hash drift check below picks it up — the same as
	# the post-extract path. mv -f overwrites any older .zip~.
	if [ -f "$dir/$archive_name" ]; then
		if [ "$force_mode" = "true" ]; then
			mv -f "$dir/$archive_name" "$dir/$ROH_DIR.zip~"
			echo "Clobber [$dir/$archive_name] (FORCED)!"
		else
			echo "ERROR: archive [$archive_name] exists in [$dir]."
			echo "Abort."
			echo
			exit 1
		fi
	fi
        
    if [ ! -d "$dir/$ROH_DIR" ]; then
        echo "ERROR: directory [$ROH_DIR] does NOT exist in [$dir]"
		echo "Abort."
		echo
        exit 1
    fi

	if [ ! -d "$dir/$ROH_DIR/.git" ]; then
		echo "ERROR: local repo [$dir/$ROH_DIR/.git] does not exist"
		echo "Abort."
		echo
		exit 1
	fi

	# searching for hashes, because .git exists
	if [ -n "$(find "$dir" -mindepth 1 -path "*/.roh.git/*" -prune -o -name "*.sha256" -print -quit)" ]; then
		echo "ERROR: hashes not exclusively hidden in [$dir/$ROH_DIR]"
		echo "Abort."
		echo
		return 1
	fi

	git_dirty=$(git -C "$(git_path "$dir/$ROH_DIR")" status --porcelain 2>/dev/null)
	if [ -n "$git_dirty" ]; then
        echo "ERROR: local repo [$dir/$ROH_DIR] not clean"
		echo "Abort."
		echo
		exit 1
	fi

	# Build a content tar of just the .sha256 files (excluding .git/), hash it,
	# replace the .sha256 tree with the tar + tar's hash file, then zip the
	# whole .roh.git directory deterministically.
	local content_tar="$CONTENT_TAR"
	local content_hash_file="$CONTENT_HASH_FILE"

	# Carry forward the previous archive's content hash from the backup zip
	# kept by the last extract ($ROH_DIR.zip~), so we can warn on content
	# drift across cycles. (The in-tree copy is removed during extract.)
	local prev_hash
	prev_hash=$(archived_content_hash "$dir")

	# Tar to a temp file first so the tar isn't archiving itself in-place.
	local tmp_tar new_hash
	tmp_tar=$(mktemp)
	new_hash=$(build_content_tar "$dir" "$tmp_tar") || { rm -f "$tmp_tar"; exit 1; }

	if [ -n "$prev_hash" ]; then
		if [ "$prev_hash" != "$new_hash" ]; then
			echo "WARN: [$dir/$ROH_DIR] content changed since last archive"
			echo "       previous [$prev_hash]"
			echo "        current [$new_hash]"
		elif [ "$force_mode" = "true" ]; then
			# On a forced clobber, confirm the new archive is byte-identical
			# (vs. the prior one we just renamed to .zip~). Silent on the
			# normal post-extract path to avoid noise on every cycle.
			echo "WARN: [$dir/$ROH_DIR] content unchanged from clobbered archive [$new_hash]"
		fi
	fi

	# Drop the original .sha256 tree (everything in .roh.git/ except .git/ and
	# the metadata files we're about to install). Then move the tar in.
	find "$dir/$ROH_DIR" -mindepth 1 -maxdepth 1 \
		! -name ".git" \
		! -name "$content_tar" \
		! -name "$content_hash_file" \
		-exec rm -rf {} +
	mv "$tmp_tar" "$dir/$ROH_DIR/$content_tar"
	echo "$new_hash" > "$dir/$ROH_DIR/$content_hash_file"

	# Re-normalize: the tar+hash file we just installed have current mtimes,
	# and writing them bumps .roh.git/'s dir mtime. -X strips Unix uid/gid/
	# atime extras so equal content -> byte-identical zip.
	find "$dir/$ROH_DIR" -exec touch -t 197001010000.00 {} +
	(cd "$dir" && zip -qXr "$archive_name" "$ROH_DIR") 2>/dev/null
	if [ $? -eq 0 ]; then
		echo "Archived [$ROH_DIR] to [$dir/$archive_name]"
	else
		echo "ERROR: failed to archive [$dir/$ROH_DIR] to [$dir/$archive_name]"
		echo "Abort."
		echo
		exit 1
	fi

	if [ -f "$dir/$archive_name" ]; then
		rm -rf "$dir/$ROH_DIR"
		echo "Removed [$dir/$ROH_DIR]"
		# Drop the .zip~ only when the new archive is content-identical to
		# it (the backup adds no information). On drift, leave .zip~ as
		# residue so the user can inspect the prior state; readonlyhash
		# (archive_directory) cleans it up like it does .roh.sqlite3 and
		# .roh.logs.
		if [ -n "$prev_hash" ] && [ "$prev_hash" = "$new_hash" ]; then
			rm -f "$dir/$ROH_DIR.zip~"
		fi
	fi

	return 0
}

extract_roh() {
    local dir="$1"
    local force_mode="$2"

    local archive_name="_$ROH_DIR.zip"
    
	if [ -d "$dir/$ROH_DIR" ]; then
		if [ "$force_mode" = "true" ]; then
			rm -rf "$dir/$ROH_DIR"
			echo "Clobber [$dir/$ROH_DIR] (FORCED)!"
		else
			echo "ERROR: directory [$ROH_DIR] exists in [$dir]"
			echo "Abort."
			echo
			exit 1
		fi
	fi

	if [ -f "$dir/$archive_name" ]; then
		# Unpack the zip recursively into $dir, restoring .roh.git/ with .git/
		# and the .SHA256-HASHES.tar metadata files.
		unzip -q "$dir/$archive_name" -d "$dir"
		if [ $? -ne 0 ] || [ ! -d "$dir/$ROH_DIR" ]; then
		    echo "ERROR: failed to extract [$dir/$ROH_DIR] from [$dir/$archive_name]"
			echo "Abort."
		    echo
		    exit 1
		fi

		# Restore the .sha256 tree from the embedded content tar, then drop both
		# metadata files. The backup zip ($ROH_DIR.zip~, created below) keeps
		# the prior content-hash available for the next archive's drift check.
		local content_tar="$CONTENT_TAR"
		local content_hash_file="$CONTENT_HASH_FILE"
		if [ -f "$dir/$ROH_DIR/$content_tar" ]; then
			tar -xf "$dir/$ROH_DIR/$content_tar" $TAR_NO_TS_WARN -C "$dir/$ROH_DIR"
			rm -f "$dir/$ROH_DIR/$content_tar"
		fi
		rm -f "$dir/$ROH_DIR/$content_hash_file"
		echo "Extracted [$dir/$ROH_DIR] from [$archive_name]"

		if [ -d "$dir/$ROH_DIR" ]; then
			local preserved="$dir/$ROH_DIR.zip~"
			# Silently overwrite any existing .zip~ — drift residue from a
			# prior -zC, or stale backup from a previous extract, is
			# always superseded by the archive we just unpacked.
			mv -f "$dir/$archive_name" "$preserved"
			echo "Backed: up [$dir/$archive_name] as [$preserved]"
		fi

	else
        echo "ERROR: archive [$archive_name] does NOT exist in [$dir]"
		echo "Abort."
		echo
        exit 1
    fi
}

# commit_all <dir> <gpath> <commit-args...>
#   Handle the synthesized `commit -A`. Git has NO single verb that stages
#   untracked files and commits (`commit -a`/`--all` skip untracked, and
#   `commit -A` is a plain error), so we intercept it: run `git add -A` to
#   stage everything (tracked mods/deletes AND untracked), then `git commit`
#   with the -A token stripped and every other arg (-m "msg", etc.) passed
#   straight through. Env guards are set by the caller (the passthrough below).
#   Post-condition: the repo MUST be clean afterward — anything left means the
#   commit failed or state changed under us, so surface it rather than succeed.
commit_all() {
    local dir="$1"
    local gpath="$2"
    shift 2

	# Rebuild the commit args without the synthetic -A token.
	local commit_args=() a
	for a in "$@"; do
		[ "$a" = "-A" ] || commit_args+=("$a")
	done

	if ! git -C "$gpath" add -A; then
		echo "ERROR: [git add -A] failed in [$dir/$ROH_DIR]"
		echo "Abort."
		echo
		return 1
	fi

	git -C "$gpath" "${commit_args[@]}"

	local dirty
	dirty=$(git -C "$gpath" status --porcelain 2>/dev/null)
	if [ -n "$dirty" ]; then
		echo "ERROR: local repo [$dir/$ROH_DIR] not clean after commit"
		echo "$dirty"
		echo "Abort."
		echo
		return 1
	fi

	return 0
}

#------------------------------------------------------------------------------------------------------------------------------------------

if contains "init"; then
	init_roh "$CWD"

elif contains "archive"; then
	if [ "$archive_version" = "v1" ]; then
		archive_roh_v1 "$CWD" "$force_mode"
	else
		archive_roh "$CWD" "$force_mode"
	fi

elif contains "extract"; then
	if [ "$archive_version" = "v1" ]; then
		extract_roh_v1 "$CWD" "$force_mode"
	else
		extract_roh "$CWD" "$force_mode"
	fi

elif contains "revert"; then
	revert_roh "$CWD" "$force_mode"

else
	# External drive fatal error, because ownership ids are from another system
	# fatal: detected dubious ownership in repository at '/Volumes/Fractal/o1oc/INST.ro/.roh.git'
	# To add an exception for this directory, call:
	# git config --global --add safe.directory <PATH>

	# GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.directory GIT_CONFIG_VALUE_0="$CWD/$ROH_DIR" git status
	export GIT_CONFIG_COUNT=1
	export GIT_CONFIG_KEY_0=safe.directory
	export GIT_CONFIG_VALUE_0="$CWD/$ROH_DIR"

	# Your name and email address were configured automatically based
	# on your username and hostname. Please check that they are accurate.
	# You can suppress this message by setting them explicitly. Run the
	# following command and follow the instructions in your editor to edit
	# your configuration file:
	#     git config --global --edit
	# After doing this, you may fix the identity used for this commit with:
	#     git commit --amend --reset-author
	export GIT_ADVICE_IMPLICIT_IDENTITY=false

	gpath="$(git_path "$CWD/$ROH_DIR")"

	# `commit -A` is not a real git command (git errors on -A for commit). We
	# define it as stage-all-including-untracked + commit — see commit_all().
	# Detect a standalone -A token following `commit`; everything else (status,
	# log, a plain `commit -m`, etc.) passes straight through to git untouched.
	has_A=false
	for a in "$@"; do
		if [ "$a" = "-A" ]; then has_A=true; break; fi
	done

	if [ "$1" = "commit" ] && [ "$has_A" = "true" ]; then
		commit_all "$CWD" "$gpath" "$@"
	else
		# Now, $@ contains all arguments after -C PATH
		git -C "$gpath" "$@"
	fi

	unset GIT_ADVICE_IMPLICIT_IDENTITY
	unset GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0
fi

