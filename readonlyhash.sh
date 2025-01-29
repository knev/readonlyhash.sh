#!/bin/bash

#FPATH_BIN="./roh.fpath.sh"
FPATH_BIN="roh.fpath"
#GIT_BIN="./roh.git.sh"
GIT_BIN="roh.git"
HASH="sha256"

usage() {
	echo
    echo "Usage: $(basename "$0") <COMMAND|<verify|copy> --retarget BASEPATH:TARGET_BASEPATH> [OPTIONS] <FPATH> [--resume-at STRING]"
	echo "      init            ..."
	echo "      verify          ..."
	echo "      archive         ..."
	echo "      extract         ..."
	echo "      copy            ..."
    echo "Options:"
	echo "      --resume-at     ..."
	echo "      --directory     Operate on a single directory specified in FPATH, instead of a .loop.txt"
	echo "      --retarget      ..."
    echo "  -v, --version       Display the version and exit"
    echo "  -h, --help          Display this help and exit"
    echo
}

# Check if a command is provided
if [ $# -eq 0 ]; then
	usage
    exit 1
fi

cmd="_INVALID_"
# Parse command
case "$1" in
    init) 
        ;;
    verify) 
        ;;
    archive) 
        ;;
    extract) 
        ;;
	copy)
	    ;;
#    delete) 
#        ;;
    -v)
		echo "$(basename "$0") version: $VERSION"
        exit 0
        ;;
    -h)
		usage
        exit 0
        ;;
	--version)
	    echo "$(basename "$0") version: $VERSION"
	    exit 0
	    ;;
    --help)
		usage
        exit 0
        ;;
    *)
        echo "ERROR: unknown command: [$1]"
		usage
        exit 1
        ;;
esac
cmd="$1"

shift

directory_mode="false"
retarget_mode="false"
rebase_string="_INVALID_"

while getopts "dh-:" opt; do
  # echo "Option: $opt, Arg: $OPTARG, OPTIND: $OPTIND"
  case $opt in
    h)
      usage
      exit 0
      ;;	  
    -)
      case "${OPTARG}" in
		directory)
		  directory_mode="true"
		  ;;
        retarget)
		  retarget_mode="true"
          rebase_string="${!OPTIND}"
          OPTIND=$((OPTIND + 1))
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
      echo "ERROR: invalid option: [-${OPTARG}]" >&2
      usage
      exit 1
      ;;
    :)
      echo "ERROR: option [-$OPTARG] requires an argument." >&2
      usage
      exit 1
      ;;
  esac
done

# capture all remaining arguments after the options have been processed
shift $((OPTIND-1))
file_path="$1"
LOOP_TXT_RO="${file_path%.loop.txt}~ro.loop.txt"

shift
skipping_mode="false"
resume_string=""
if [ $# -eq 2 ] && [ "$1" = "--resume-at" ]; then
	resume_string="$2"
	skipping_mode="true"
fi

#------------------------------------------------------------------------------------------------------------------------------------------
# captured output : NO spurious echo/printf outputs!

rename_to_ro() {
    local dir="$1"
    local dir_ro="${dir}"

	# Rename the directory by adding '.ro' if it doesn't already have it
    if [[ "$dir" != "." && "$dir" != ".." && ! $dir == *.ro ]]; then
        dir_ro="${dir}.ro"
        mv "$dir" "$dir_ro"
    fi
    echo "$dir_ro"	
}

#	validate_rebase_string() {
#	    local string="$1"
#	    [[ "$string" =~ ^[^:]+:[^:]+$ ]]
#	    return $?
#	}
#	validate_rebase_string "path:to" && echo "Valid" || echo "Invalid"
#	validate_rebase_string "path::to" && echo "Valid" || echo "Invalid"
#	validate_rebase_string "::to" && echo "Valid" || echo "Invalid"
#	validate_rebase_string ":to" && echo "Valid" || echo "Invalid"
#	validate_rebase_string "path:" && echo "Valid" || echo "Invalid"
#	validate_rebase_string "path" && echo "Valid" || echo "Invalid"

rebase_directory() {
    local dir="$1"
    local rebase_string="$2"

    if ! [[ "$rebase_string" =~ ^([^:]+):([^:]+)$ ]]; then
		echo "_INVALID_"
		return
	fi

	local basepath="${BASH_REMATCH[1]}"
	local target_basepath="${BASH_REMATCH[2]}"

	abs_basepath="$(readlink -f "$basepath")"
	abs_target_basepath="$(readlink -f "$target_basepath")"

    # Remove the common parent from the path
    local suffix="${dir#$abs_basepath/}"

	# Remove '.ro' from the end of the suffix if it exists
    if [[ "$suffix" = *.ro ]]; then
        suffix="${suffix%.ro}"
    fi

	echo "$abs_target_basepath/$suffix"
}

#------------------------------------------------------------------------------------------------------------------------------------------

init_directory() {
	local dir="$1"

	ROH_DIR="$dir/.roh.git"

	echo "Looping on: [$dir]"
 	$FPATH_BIN write "$dir"
 	if [ $? -ne 0 ]; then
        echo "ERROR: [$FPATH_BIN write] failed for directory: [$dir]"
 		echo
 		exit 1
 	fi		

	if [ ! -d "$ROH_DIR/.git" ]; then
 		$GIT_BIN -C "$dir" init

		echo ".DS_Store.$HASH" > "$ROH_DIR"/.gitignore
		$GIT_BIN -C "$dir" add .gitignore
		$GIT_BIN -C "$dir" commit -m "Initial ignores."
		# $GIT_BIN -C "$dir" status
	fi

	git_status=$($GIT_BIN -C "$dir" status)
	if ! [[ "$git_status" =~ "nothing to commit, working tree clean" ]]; then
		$GIT_BIN -C "$dir" add "*"
		$GIT_BIN -C "$dir" commit -m "Initial hashes."
		$GIT_BIN -C "$dir" status
	fi

	dir_ro="$(rename_to_ro "$dir")"
	if ! [ "$dir" = "$dir_ro" ]; then
		echo "Renamed [$dir] to [$dir_ro]"
	fi
	echo "$dir_ro" >> "$LOOP_TXT_RO"
}

verify_directory() {
	local dir="$1"

	local archive_name="_.roh.git.zip"
	if [ -f "$dir/$archive_name" ]; then
		tmp_dir=$(mktemp -d)

		unzip -q "$dir/$archive_name" -d "$tmp_dir"
		if [ $? -eq 0 ]; then
		    echo "Extracted [$tmp_dir] from [$dir/$archive_name]"
		else
		    echo "ERROR: failed to extract [$tmp_dir] from [$dir/$archive_name]"
		    echo
		    exit 1
		fi

		ROH_DIR="$tmp_dir/.roh.git"

		$FPATH_BIN verify --roh-dir "$ROH_DIR" "$dir"
		if [ $? -ne 0 ]; then
	        echo "ERROR: [$FPATH_BIN verify --roh-dir] failed for directory: [$dir]"
			echo
			exit 1
		fi		
		git_status=$($GIT_BIN -C "$tmp_dir" status)
		echo "$git_status"
		if ! [[ "$git_status" =~ "nothing to commit, working tree clean" ]]; then
			echo
	        echo "ERROR: local repo [$ROH_DIR] not clean"
			echo
			exit 1
		fi

		rm -r "$tmp_dir"
		echo "Removed [$tmp_dir]"

	else
		ROH_DIR="$dir/.roh.git"

		$FPATH_BIN verify "$dir"
		if [ $? -ne 0 ]; then
	        echo "ERROR: [$FPATH_BIN verify] failed for directory: [$dir]"
			echo
			exit 1
		fi		

		if [ ! -d "$ROH_DIR/.git" ]; then
			echo "ERROR: local repo [$ROH_DIR/.git] does not exist"
			echo
			exit 1
		fi

		git_status=$($GIT_BIN -C "$dir" status)
		echo "$git_status"
		if ! [[ "$git_status" =~ "nothing to commit, working tree clean" ]]; then
			echo
	        echo "ERROR: local repo [$ROH_DIR] not clean"
			echo
			exit 1
		fi

	fi
}

archive_directory() {
	local dir="$1"

	ROH_DIR="$dir/.roh.git"

	if [ -f "$dir/_.roh.git.zip" ]; then
		echo "SKIP: directory [$dir] -- [$dir/_.roh.git.zip] exists"
		return 0
	fi

	if [ ! -d "$ROH_DIR/.git" ]; then
		echo "ERROR: local repo [$ROH_DIR/.git] does not exist"
		echo
		exit 1
	fi

	# local tmp=$(find "$dir" -name '*.sha256' -type f -not -path '*/.roh.git/*')
	# echo "$tmp"

	verify_directory "$dir"
	$GIT_BIN -zC "$dir" 
}

extract_directory() {
	local dir="$1"

	$GIT_BIN -xC "$dir" 
}

# - get the absolute path of $TARGET
# - for each (non-comment) dir in fpath_ro 
# 	- 2] get the common parent with $TARGET; get remainder of dir
# 	- 1] cut off the .ro extension
# 	- 3] paste remainder onto the absolute of $TARGET gives result
# 	- 4] do a roh.fpath verify of result, with --roh-dir $ROH_DIR
#
verify_target() {
	local dir="$1"
	local rebase_string="$2"
	local dir_rebased=$(rebase_directory "$dir" "$rebase_string")
	if [ "$dir_rebased" = "_INVALID_" ]; then
        echo "ERROR: invalid rebase string [$rebase_string]"
 		echo
 		exit 1
	fi
	# echo "* $dir => $dir_rebased"

	ROH_DIR="$dir/.roh.git"

	$FPATH_BIN verify --roh-dir "$ROH_DIR" "$dir_rebased"
	if [ $? -ne 0 ]; then
        echo "ERROR: [$FPATH_BIN verify --roh-dir] failed for directory: [$dir_rebased]"
		echo
		exit 1
	fi		
}

copy_to_target() {
	local dir="$1"
	local rebase_string="$2"
	local dir_rebased=$(rebase_directory "$dir" "$rebase_string")
	if [ "$dir_rebased" = "_INVALID_" ]; then
        echo "ERROR: invalid rebase string [$rebase_string]"
 		echo
 		exit 1
	fi
	# echo "* $dir => $dir_rebased"

	ROH_DIR="$dir/.roh.git"

	cp -R "$ROH_DIR" "$dir_rebased/."
	echo "Copied [$ROH_DIR] to [$dir_rebased/.]"

	dir_rebased_ro=$(rename_to_ro "$dir_rebased")
	if ! [ "$dir_rebased" = "$dir_rebased_ro" ]; then
		echo "Renamed [$dir_rebased] to [$dir_rebased_ro]"
	fi
	echo "$dir_rebased_ro" >> "$LOOP_TXT_RO"
}

#------------------------------------------------------------------------------------------------------------------------------------------

if [ "$directory_mode" = "true" ]; then
	init_directory "$file_path" "false"
	echo
	exit 0
# Check if the file ends with .ro.txt
elif [[ ! "$file_path" =~ \.loop\.txt$ ]]; then
    echo "ERROR: No file path argument ending with '.loop.txt' found."
	usage
    exit 1
fi

#------------------------------------------------------------------------------------------------------------------------------------------


if [ "$cmd" = "init" ] || [ "$cmd" = "copy" ]; then
	echo "# $(basename "$0") [" > "$LOOP_TXT_RO"
fi

# Read directories from the file
while IFS= read -r dir; do
	# Skip lines that start with '#'
	if [[ "$dir" =~ ^#.* ]]; then
		continue
	fi

    # Check if the directory exists
    if [ -d "$dir" ]; then

		#---

		base_dir="$dir"
		if [[ "$dir" == *.ro ]]; then
			base_dir=${dir%.ro}
		fi
		# echo "* base_dir: [$base_dir]"
		if [ "$skipping_mode" = "true" ] && [[ ! "$base_dir" == *"$resume_string" ]]; then
			echo "  OK: directory entry [$dir] -- SKIPPING"
			if [ "$cmd" = "init" ] || [ "$cmd" = "copy" ]; then
				echo "$dir" >> "$LOOP_TXT_RO"
			fi
			continue
		fi
		skipping_mode="false"

		#---

		if [ "$cmd" = "init" ]; then
			init_directory "$dir"

		elif [ "$cmd" = "verify" ]; then
			if [ "$retarget_mode" = "true" ]; then
				verify_target "$dir" "$rebase_string"
			else
				verify_directory "$dir"
			fi

		elif [ "$cmd" = "archive" ]; then
			archive_directory "$dir"

		elif [ "$cmd" = "extract" ]; then
			extract_directory "$dir"

		elif [ "$cmd" = "copy" ]; then
			copy_to_target "$dir" "$rebase_string"

		elif [ "$cmd" = "delete" ]; then
			echo delete
			
		fi

    else
        echo "ERROR: Directory [$dir] does not exist."
		echo
		exit 1
    fi
	echo "■"

done < "$file_path"

if [ "$cmd" = "init" ] || [ "$cmd" = "copy" ]; then
	echo "# ]" >> "$LOOP_TXT_RO"

	# Filter out comments at the end of lines and compare
	if diff <(sed 's/#.*$//' "$file_path") <(sed 's/#.*$//' "$LOOP_TXT_RO") > /dev/null 2>&1; then
		rm "$LOOP_TXT_RO"
	fi
fi

