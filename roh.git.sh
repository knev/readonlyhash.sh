#!/bin/bash

#set -x

usage() {
    echo "Usage:"
	echo "      $(basename "$0") [--force] <[-i|-z|-x] -[i|z|x]C PATHSPEC> [ARGUMENTS]"
	echo
    echo "Options:"
	echo "  -i             Initialize the roh.git storage"
	echo "  -z             Archive the roh.git storage"
	echo "  -x             Extract the roh.git storage"
	echo "  -C             Specify the working directory"
    echo "      --force    Force operation"	
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

# Parse command line options
while getopts ":izxC:h-:" opt; do
  case $opt in
	i)
	  commands+=("init")
	  ;;
	z)
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

archive_roh() {
    local dir="$1"
    local force_mode="$2"

    local archive_name="_$ROH_DIR.zip"
    
	# If force_mode is true, remove existing archive before creating a new one
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

	# searching for hashes, because .git exists
	if [ -n "$(find "$dir" -mindepth 1 -path "*/.roh.git/*" -prune -o -name "*.sha256" -print -quit)" ]; then
		echo "ERROR: hashes not exclusively hidden in [$dir/$ROH_DIR]"
		echo "Abort."
		echo
		return 1
	fi

	git_status=$(git -C "$dir/$ROH_DIR" status)
	# echo "$git_status"
	if ! [[ "$git_status" =~ "nothing to commit, working tree clean" ]]; then
        echo "ERROR: local repo [$dir/$ROH_DIR] not clean"
		echo "Abort."
		echo
		exit 1
	fi

	#tar -cvf "$dir/$archive_name" -C "$dir" "$ROH_DIR" >/dev/null 2>&1 # tar.gz
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
		# tar -xzvf "$dir/$archive_name" -C "$dir" >/dev/null 2>&1 # tar.gz
		# unzip -q "$dir/$archive_name" -d "$dir"
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

#------------------------------------------------------------------------------------------------------------------------------------------

if contains "init"; then
	init_roh "$CWD"

elif contains "archive"; then
	archive_roh "$CWD" "$force_mode"

elif contains "extract"; then
	extract_roh "$CWD" "$force_mode"

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

