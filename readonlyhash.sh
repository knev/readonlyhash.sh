#!/bin/bash

#FPATH_BIN="./roh.fpath.sh"
FPATH_BIN="roh.fpath"
#GIT_BIN="./roh.git.sh"
GIT_BIN="roh.git"
HASH="sha256"

usage() {
	echo
    echo "Usage: $(basename "$0") <COMMAND|<<verify|copy> --rebase BASEPATH:TARGET_BASEPATH> [OPTIONS] <FPATH/FN.roh.txt> [--resume-at STRING]"
	echo "      verify          ..."
	echo "      archive         ..."
	echo "      extract         ..."
	echo "      copy            ..."
    echo "Options:"
	echo "      --rebase        ..."
    echo "      --version       Display the version and exit"
    echo "  -h, --help          Display this help and exit"
	echo 
	echo "Other operations: "
	echo "      --resume-at     ..."
	echo "      while IFS= read -r line; do ... \"\$line\"; done < FILENAME.roh.txt"
    echo
}

# Check if a command is provided
if [ $# -eq 0 ]; then
	usage
    exit 1
fi

# ----

# Compatible with bash 3.2+ (macOS default) and bash 4+

# List of valid full commands
valid_long="init verify archive extract copy"

# Short to long mapping (using case statement instead of assoc array)
get_long() {
    case "$1" in
        i) echo "init" ;;
        v) echo "verify" ;;
        a) echo "archive" ;;
        x) echo "extract" ;;
        c) echo "copy" ;;
        *) echo "" ;;  # empty = invalid
    esac
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

i=1
while [ $i -le $# ]; do
    arg=$(eval echo "\$$i")

    # Stop on any switch-like argument
    case "$arg" in
        -*) break ;;
    esac

    # 1. Try full word match
    if echo "$valid_long" | grep -qw "$arg"; then
        commands+=("$arg")
        i=$((i+1))
        continue
    fi

    # 2. Try short letters (consecutive, no separators)
    if echo "$arg" | grep -qE '^[vwidhsqre]+$'; then
        invalid=0
        for ((j=0; j<${#arg}; j++)); do
            c="${arg:$j:1}"
            long=$(get_long "$c")
            if [ -n "$long" ]; then
                commands+=("$long")
            else
                echo "ERROR: unknown short operation '$c' in '$arg'" >&2
                invalid=1
                break
            fi
        done
        if [ $invalid -eq 0 ]; then
            i=$((i+1))
            continue
        fi
    fi

	if [ ${#commands[@]} -eq 0 ]; then
		# If we get here → error
		echo "ERROR: invalid command [$arg]" >&2
		# echo "Allowed full: verify write index delete hide show query recover sweep" >&2
		# echo "     short:  v      w     i      d      h    s    q     r      e" >&2
		# echo "Shorts can be concatenated like: vwidhsqre" >&2
		usage
		exit 1
	fi
	break
done
# echo "Parsed commands (${#commands[@]}):"
# for cmd in "${commands[@]}"; do
#     echo "  - $cmd"
# done

# Reset positional parameters to remaining arguments only
shift $((i-1))   # now $1 is the first -something argument

# -----

while getopts "h-:" opt; do
  # echo "Option: $opt, Arg: $OPTARG, OPTIND: $OPTIND"
  case $opt in
    h)
      usage
      exit 0
      ;;	  
    -)
      case "${OPTARG}" in
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
ROH_TXT="$1"
ALT_TXT="${ROH_TXT%.roh.txt}~ro.roh.txt"

# Check if the file ends with .ro.txt
if [[ ! "$ROH_TXT" =~ \.roh\.txt$ ]]; then
    echo "ERROR: no file path argument ending with '.roh.txt' found."
	usage
    exit 1
fi
if [ ! -f "$ROH_TXT" ]; then
	echo "ERROR: [$ROH_TXT] not found"
	usage
	exit 1
fi

shift
skipping_mode="false"
resume_string=""
if [ $# -ne 0 ]; then
	if [ $# -eq 2 ] && [ "$1" = "--resume-at" ]; then
		resume_string="$2"
		skipping_mode="true"
	else
		echo "ERROR: invalid option [$@]"
		usage
		exit 1
	fi
fi

#------------------------------------------------------------------------------------------------------------------------------------------
# captured output : NO spurious echo/printf outputs!

rename_to_ro() {
    local dir="$1"
    local dir_ro="${dir}"

	# Rename the directory by adding '.ro' if it doesn't already have it
    if [[ "$dir" != "." && "$dir" != ".." && ! $dir == *.ro ]]; then
        dir_ro="${dir}.ro"
    fi
    echo "$dir_ro"	
}

#------------------------------------------------------------------------------------------------------------------------------------------

verify_directory() {
	local dir="$1"

	local archive_name="_.roh.git.zip"
	if [ -f "$dir/$archive_name" ]; then
		echo "ERROR: found archived ROH_DIR [$dir/$archive_name] at [$dir]"
		echo
		return 0

# 		tmp_dir=$(mktemp -d)
# 		echo "tmp_dir [$tmp_dir]"
# 
# 		#TODO: should use roh.git with a --ROH_DIR flag perhaps?
# 		unzip -jq "$dir/$archive_name" -d "$tmp_dir" && tar -xf "$tmp_dir/.roh.git.tar" -C "$tmp_dir" && rm -f "$tmp_dir/.roh.git.tar"
# 		if [ $? -eq 0 ]; then
# 		    echo "Extracted [$tmp_dir] from [$dir/$archive_name]"
# 		else
# 		    echo "ERROR: failed to extract [$tmp_dir] from [$dir/$archive_name]"
# 		    echo
# 		    exit 1
# 		fi
# 
# 		ROH_DIR="$tmp_dir/.roh.git"
# 
# 		$FPATH_BIN verify --roh-dir "$ROH_DIR" "$dir"
# 		# $FPATH_BIN verify "$dir"
# 		if [ $? -ne 0 ]; then
# 	        echo "ERROR: [$FPATH_BIN verify --roh-dir] failed for directory: [$dir]"
# 			echo
# 			exit 1
# 		fi		
# 		git_status=$($GIT_BIN -C "$tmp_dir" status)
# 		echo "$git_status"
# 		if ! [[ "$git_status" =~ "nothing to commit, working tree clean" ]]; then
# 			echo
# 	        echo "ERROR: local repo [$ROH_DIR] not clean"
# 			echo
# 			exit 1
# 		fi
# 
# 		rm -r "$tmp_dir"
# 		echo "Removed [$tmp_dir]"

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
	else
		$GIT_BIN -zC "$dir" 
		[ $? -ne 0 ] && exit 1
	fi

	if [ -f "$dir/.roh.sqlite3" ]; then
		rm -r "$dir/.roh.sqlite3"
		echo "DB_SQL [$dir/.roh.sqlite3] -- removed"
	fi
}

extract_directory() {
	local dir="$1"

	$GIT_BIN -xC "$dir" 
	[ $? -ne 0 ] && exit 1
}

# - get the absolute path of $TARGET
# - for each (non-comment) dir in fpath_ro 
# 	- 2] get the common parent with $TARGET; get remainder of dir
# 	- 1] cut off the .ro extension
# 	- 3] paste remainder onto the absolute of $TARGET gives result
# 	- 4] do a roh.fpath verify of result, with --roh-dir $ROH_DIR
#
# verify_target() {
# 	local dir="$1"
# 	local rebase_string="$2"
#     IFS=':' read -r rebase_origin rebase_target <<< "$rebase_string"
# 
# 	local dir_rebased=$(rebase_directory "$dir" "$rebase_origin" "$rebase_target")
# 	if [ "$dir_rebased" = "_INVALID_" ]; then
#         echo "ERROR: invalid rebase string [$rebase_string]"
#  		echo
#  		exit 1
# 	fi
# 	# echo "* [$rebase_string] => [$dir_rebased]"
# 
# 	ROH_DIR="$dir/.roh.git"
# 
# 	# echo "Using [${rebase_origin}/${ROH_DIR#*${rebase_origin}/}] to"
# 	echo "Verifying [${rebase_target}/${dir_rebased#*${rebase_target}/}/.]"
# 	$FPATH_BIN verify --roh-dir "$ROH_DIR" "$dir_rebased"
# 	if [ $? -ne 0 ]; then
#         echo "ERROR: [$FPATH_BIN verify --roh-dir] failed for directory: [$dir_rebased]"
# 		echo
# 		exit 1
# 	fi		
# }

#------------------------------------------------------------------------------------------------------------------------------------------

# Read directories from the file
while IFS= read -r dir; do
	# Skip lines that start with '#'
	if [[ "$dir" =~ ^#.* ]]; then
		echo "$dir" >> "$ALT_TXT"
		continue
	fi

	echo "Looping on: [$dir]"

	#---

	base_dir=${dir%.ro}
	base_resume_string=${resume_string%.ro}
	# echo "* base_dir: [$base_dir]"
	if [ "$skipping_mode" = "true" ] && [[ ! "$base_dir" == *"$base_resume_string" ]]; then
		echo "OK: directory entry [$dir] -- SKIPPING"
		echo "■"
		if [ "$cmd" = "init" ] || [ "$cmd" = "copy" ]; then
			echo "#SKIPPED: $dir" >> "$ALT_TXT"
		fi
		continue
	fi
	skipping_mode="false"

	#---

    # Check if the directory exists
    if [ -d "$dir" ]; then

		if contains "verify"; then
#			if [ "$rebase_mode" = "true" ]; then
#				verify_target "$dir" "$rebase_string"
#			else
			verify_directory "$dir"

		elif contains "archive"; then
			archive_directory "$dir"

		elif contains "extract"; then
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

done < "$ROH_TXT"

if [ "$cmd" = "init" ] || [ "$cmd" = "copy" ]; then
	# Filter out comments at the end of lines and compare
	if diff <(sed 's/#.*$//' "$ROH_TXT") <(sed 's/#.*$//' "$ALT_TXT") > /dev/null 2>&1; then
		rm "$ALT_TXT"
	fi
fi

