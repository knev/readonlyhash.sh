#!/bin/bash

#FPATH_BIN="./roh.fpath.sh"
FPATH_BIN="roh.fpath"
#GIT_BIN="./roh.git.sh"
GIT_BIN="roh.git"
HASH="sha256"

usage() {
	echo
    echo "Usage: $(basename "$0") <COMMAND|<verify|transfer> --new-target TARGET_FPATH> [OPTIONS] <FPATH>"
	echo "      init            ..."
	echo "      verify          ..."
	echo "      archive         ..."
	echo "      extract         ..."
	echo "      transfer        ..."
    echo "Options:"
	echo "      --directory     Operate on a single directory specified in FPATH, instead of a .loop.txt"
	echo "      --new-target    adsf"
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
	transfer)
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
target_mode="false"
new_target="_INVALID_"

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
        new-target)
		  target_mode="true"
          new_target="${!OPTIND}"
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

# Function to find common parent directory
find_common_parent() {
    # Convert paths to absolute paths
    local path1=$(realpath "$1")
    local path2=$(realpath "$2")

    # Split paths into arrays of components
    IFS='/' read -ra arr1 <<< "${path1:1}"  # remove leading slash
    IFS='/' read -ra arr2 <<< "${path2:1}"

    local common_path="/"
    local i
    for ((i = 0; i < ${#arr1[@]} && i < ${#arr2[@]}; i++)); do
        if [ "${arr1[i]}" != "${arr2[i]}" ]; then
            break
        fi
        common_path+="${arr1[i]}/"
    done

    # Remove trailing slash if it's not the root directory
    [ "$common_path" != "/" ] && common_path=${common_path%/}

    echo "$common_path"
}

get_target_remainder() {
    local dir="$1"
    local abs_target="$2"
    local common_parent=$(find_common_parent "$dir" "$abs_target")

    # Remove the common parent from the path
    local remainder="${dir#$common_parent/}"

    # If the common parent is just "/", return the path minus the leading slash
    if [ "$common_parent" = "/" ]; then
        remainder="${dir#*/}"
    fi

    # Remove '.ro' from the end of the remainder if it exists
    if [[ "$remainder" = *.ro ]]; then
        remainder="${remainder%.ro}"
    fi

    # Return the remainder
    echo "$remainder"
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
	echo "Renamed [$dir] to [${dir_ro}]"
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

	verify_directory "$dir"

	if [ ! -f "$dir/_.roh.git.zip" ]; then
		$GIT_BIN -zC "$dir" 
	fi
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
	local abs_target="$2" # the absolute path of $new_target

	ROH_DIR="$dir/.roh.git"

	remainder=$(get_target_remainder "$dir" "$abs_target")

	# echo "* $dir : $abs_target : $remainder"
	# echo "* $abs_target/$remainder"

	$FPATH_BIN verify --roh-dir "$ROH_DIR" "$abs_target/$remainder"
	if [ $? -ne 0 ]; then
        echo "ERROR: [$FPATH_BIN verify --roh-dir] failed for directory: [$abs_target/$remainder]"
		echo
		exit 1
	fi		
}

transfer_target() {
	local dir="$1"
	local abs_target="$2" # the absolute path of $new_target

	ROH_DIR="$dir/.roh.git"

	remainder=$(get_target_remainder "$dir" "$abs_target")

	# echo "* $dir : $abs_target : $remainder"
	# echo "* $abs_target/$remainder"

	dir="$abs_target/$remainder"
	mv "$ROH_DIR" "$dir/."
	echo "Moved [$ROH_DIR] to [$dir/.]"

	dir_ro=$(rename_to_ro "$dir")
	echo "Renamed [$dir] to [${dir_ro}]"
	echo "$dir_ro" >> "$LOOP_TXT_RO"
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


if [ "$cmd" = "init" ]; then
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

		if [ "$cmd" = "init" ]; then
			init_directory "$dir"

		elif [ "$cmd" = "verify" ]; then
			if [ "$target_mode" = "true" ]; then
				abs_target="$(readlink -f "$new_target")"
				verify_target "$dir" "$abs_target"
			else
				verify_directory "$dir"
			fi

		elif [ "$cmd" = "archive" ]; then
			archive_directory "$dir"

		elif [ "$cmd" = "extract" ]; then
			extract_directory "$dir"

		elif [ "$cmd" = "transfer" ]; then
			abs_target="$(readlink -f "$new_target")"
			transfer_target "$dir" "$abs_target"

		elif [ "$cmd" = "delete" ]; then
			echo delete
			
		fi

    else
        echo "ERROR: Directory [$dir] does not exist."
		echo
		exit 1
    fi
	echo 

done < "$file_path"

if [ "$cmd" = "init" ]; then
	echo "# ]" >> "$LOOP_TXT_RO"

	# Filter out comments at the end of lines and compare
	if diff <(sed 's/#.*$//' "$file_path") <(sed 's/#.*$//' "$LOOP_TXT_RO") > /dev/null 2>&1; then
		rm "$LOOP_TXT_RO"
	fi
fi

