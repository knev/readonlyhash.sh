#!/bin/bash

#set -x

usage() {
    echo "Usage:"
	echo "      $(basename "$0") [--force] <[-i|-[a|z]|-x] -[i|[a|z]|x]C PATHSPEC> [ARGUMENTS]"
	echo
    echo "Options:"
	echo "  -i             Initialize the roh.git storage"
	echo "  -[a|z]         Archive the roh.git storage"
	echo "  -x             Extract the roh.git storage"
	echo "  -C             Specify the working directory"
    echo "      --force    Force operation"
	echo "      --v1       Use the legacy tar+zip routine (pre-content-hash format)"
	echo "      --v2       Use the deterministic tar+content-hash routine (default)"
    echo "      --version  Display the version and exit"
    echo "  -h, --help     Display this help and exit"
	echo
	echo "Examples:"
	echo "      \$ $(basename "$0") -zC <PATH>"
	echo "      \$ $(basename "$0") -C <PATH> add \"*\""
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

CWD=""
force_mode="false"
archive_version="v2"

# Parse command line options
while getopts ":iazxC:h-:" opt; do
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
    C)
	  CWD="$OPTARG"
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
		v1)
		  archive_version="v1"
		  ;;
		v2)
		  archive_version="v2"
		  ;;
	    version)
	      echo "$(basename "$0") version: $VERSION"
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
if ! contains "init" && ! contains "archive" && ! contains "extract"; then
	if [ $# -eq 0 ]; then
		echo "ERROR: not enough arguments." >&2
		echo
		usage
		exit 1
	fi

elif contains "archive" && contains "extract"; then
		echo "ERROR: archive and extract operations are mutually exclusive." >&2
		echo
		usage
		exit 1
fi

if [ -z "$CWD" ] || ! [ -d "$CWD" ]; then
	echo "ERROR: invalid working directory [$CWD]." >&2
	echo
	usage
	exit 1
fi

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

	git -C "$dir/$ROH_DIR" init

	echo ".DS_Store.$HASH" > "$dir/$ROH_DIR"/.gitignore
	git -C "$dir/$ROH_DIR" add .gitignore
	git -C "$dir/$ROH_DIR" commit -m "Initial ignores."
	# git -C "$CWD/$ROH_DIR" status

	git_status=$(git -C "$dir/$ROH_DIR" status)
	if ! [[ "$git_status" =~ "nothing to commit, working tree clean" ]]; then
		git -C "$dir/$ROH_DIR" add "*"
		git -C "$dir/$ROH_DIR" commit -m "Initial hashes."
		git -C "$dir/$ROH_DIR" status
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

	git_status=$(git -C "$dir/$ROH_DIR" status)
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
		unzip -jq "$dir/$archive_name" -d "$dir" && tar -xf "$dir/$ROH_DIR.tar" -C "$dir" && rm -f "$dir/$ROH_DIR.tar" "$dir/$archive_name"
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

	git_dirty=$(git -C "$dir/$ROH_DIR" status --porcelain 2>/dev/null)
	if [ -n "$git_dirty" ]; then
        echo "ERROR: local repo [$dir/$ROH_DIR] not clean"
		echo "Abort."
		echo
		exit 1
	fi

	# Build a content tar of just the .sha256 files (excluding .git/), hash it,
	# replace the .sha256 tree with the tar + tar's hash file, then zip the
	# whole .roh.git directory deterministically.
	local content_tar=".SHA256-HASHES.tar"
	local content_hash_file=".SHA256-HASHES.tar.sha256"

	# Carry forward the previous archive's content hash from the backup zip
	# kept by the last extract ($ROH_DIR.zip~), so we can warn on content
	# drift across cycles. (The in-tree copy is removed during extract.)
	local prev_hash=""
	if [ -f "$dir/$ROH_DIR.zip~" ]; then
		prev_hash=$(unzip -p "$dir/$ROH_DIR.zip~" "$ROH_DIR/$content_hash_file" 2>/dev/null | tr -d '[:space:]')
	fi

	# Normalize all mtimes (including the .roh.git/ directory itself, since
	# its mtime is bumped by file ops/extract) BEFORE tarring, so the tar's
	# bytes — and hence its hash — are reproducible across archive cycles.
	find "$dir/$ROH_DIR" -exec touch -t 197001010000.00 {} +

	# Tar to a temp file first so the tar isn't archiving itself in-place.
	local tmp_tar
	tmp_tar=$(mktemp)
	tar -cf "$tmp_tar" -C "$dir/$ROH_DIR" \
		--exclude=".git" \
		--exclude="$content_tar" \
		--exclude="$content_hash_file" \
		--exclude=".DS_Store" \
		. 2>/dev/null
	if [ $? -ne 0 ]; then
		rm -f "$tmp_tar"
		echo "ERROR: failed to build [$content_tar] for [$dir/$ROH_DIR]"
		echo "Abort."
		echo
		exit 1
	fi
	local new_hash
	new_hash=$(shasum -a 256 "$tmp_tar" | awk '{print $1}')

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
		# The .zip~ kept around for prev_hash comparison is now stale —
		# _.roh.git.zip is the current archive. Drop it; the next extract
		# (or forced clobber) will reseed it from the fresh archive.
		rm -f "$dir/$ROH_DIR.zip~"
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
		local content_tar=".SHA256-HASHES.tar"
		local content_hash_file=".SHA256-HASHES.tar.sha256"
		if [ -f "$dir/$ROH_DIR/$content_tar" ]; then
			tar -xf "$dir/$ROH_DIR/$content_tar" -C "$dir/$ROH_DIR"
			rm -f "$dir/$ROH_DIR/$content_tar"
		fi
		rm -f "$dir/$ROH_DIR/$content_hash_file"
		echo "Extracted [$dir/$ROH_DIR] from [$archive_name]"

		if [ -d "$dir/$ROH_DIR" ]; then
			local preserved="$dir/$ROH_DIR.zip~"
			if [ -f "$preserved" ]; then
				echo "WARN: [$preserved] exists -- overwriting"
			fi
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

	# Now, $@ contains all arguments after -C PATH
	git -C "$CWD/$ROH_DIR" "$@"

	unset GIT_ADVICE_IMPLICIT_IDENTITY
	unset GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0
fi

